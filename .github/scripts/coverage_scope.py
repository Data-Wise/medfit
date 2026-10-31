"""Skip coverage only for known metadata; uncertain input always runs coverage."""
import json
import os
from pathlib import Path
import re
import subprocess


METADATA = {".STATUS", "CLAUDE.md", "AGENTS.md"}


def requires_coverage(paths):
    return not paths or any(
        path not in METADATA and not (path.startswith("planning/") and path.endswith(".md"))
        for path in paths
    )


def decide(event_name, ref, event):
    if ref == "refs/heads/main" or (
        event_name == "pull_request"
        and isinstance(event, dict)
        and isinstance(event.get("pull_request"), dict)
        and isinstance(event["pull_request"].get("base"), dict)
        and event["pull_request"]["base"].get("ref") == "main"
    ):
        return True
    try:
        if event_name == "pull_request":
            before = event["pull_request"]["base"]["sha"]
            after = event["pull_request"]["head"]["sha"]
            separator = "..."  # Entire PR, excluding unrelated base-branch changes.
        elif event_name == "push":
            before, after = event["before"], event["after"]
            separator = ".."  # Entire push, including intermediate commits.
        else:
            return True
        if any(not isinstance(sha, str) or not re.fullmatch(r"[0-9a-fA-F]{40}|[0-9a-fA-F]{64}", sha)
               or set(sha) == {"0"} for sha in (before, after)):
            return True
        result = subprocess.run(
            ["git", "diff", "--name-only", "-z", "--no-renames", before + separator + after, "--"],
            check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        # Disabling rename detection retains both old and new paths, including deleted code.
        paths = [os.fsdecode(path) for path in result.stdout.split(b"\0") if path]
        return requires_coverage(paths)
    except (KeyError, TypeError, ValueError, OSError, subprocess.CalledProcessError):
        return True


def main():
    try:
        event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
        run = decide(os.environ.get("GITHUB_EVENT_NAME"), os.environ.get("GITHUB_REF"), event)
    except (KeyError, ValueError, OSError):
        run = True
    value = str(run).lower()
    print(f"Coverage required: {value}")
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        output.write(f"run_coverage={value}\n")


if __name__ == "__main__":
    main()
