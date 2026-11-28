# Package Logo

This directory contains the medfit package logo files.

## Files

- `logo.png` - Main package logo (hex sticker format)
  - Recommended size: 181px × 209px (standard R hex sticker ratio)
  - Used in pkgdown website and README

## Generating the Logo

Use the prompt in `hex-logo-prompt.md` (in the package root) with an AI image generator:
- DALL-E (ChatGPT)
- Gemini
- Midjourney
- Adobe Firefly

Once generated, save the logo as `logo.png` in this directory.

## Usage in README

After adding the logo, update README.md to include it:

```markdown
# medfit: Infrastructure for Mediation Analysis in R <img src="man/figures/logo.png" align="right" height="139" />
```

## Usage in pkgdown

The logo is automatically detected by pkgdown from the `_pkgdown.yml` configuration:

```yaml
logo:
  image: man/figures/logo.png
  align: right
  width: 350px
```
