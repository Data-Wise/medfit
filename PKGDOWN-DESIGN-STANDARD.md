# R Package Design Guide
## Standard Documentation Site Design for the Mediationverse Ecosystem

**Version:** 1.0.0
**Last Updated:** 2025-12-20
**Status:** Standard Reference Document
**Scope:** All mediationverse packages (medfit, probmed, RMediation, medrobust, medsim)

---

## Purpose

This document establishes standard design patterns for R package documentation sites across the mediationverse ecosystem. It ensures:
- **Consistency**: Users recognize the ecosystem visually
- **ADHD-friendliness**: Clear visual hierarchy, reduced cognitive load
- **Professionalism**: Academic credibility with modern aesthetics
- **Accessibility**: WCAG 2.1 AA compliance across all sites

---

## Design Philosophy

### Core Principles

1. **Refined Academic**
   - Professional, scholarly appearance
   - Modern without being trendy
   - Accessible without being simplistic

2. **ADHD-Friendly**
   - Strong visual hierarchy (bolder headings, color-coded sections)
   - Visual chunking (breathing room between sections)
   - Multiple navigation cues (TOC, breadcrumbs, progress indicators)
   - Reduced cognitive load (off-white backgrounds, clear typography)

3. **Ecosystem Cohesion**
   - Shared color palette (with package-specific accents)
   - Consistent navigation patterns
   - Cross-package discoverability

---

## Standard Configuration

### pkgdown.yml Template

```yaml
url: https://data-wise.github.io/{PACKAGE_NAME}/

template:
  bootstrap: 5
  bootswatch: litera                # Academic theme with good readability
  math-rendering: mathjax
  includes:
    in_header: pkgdown/mathjax-config.html
    after_body: pkgdown/extra.html  # JavaScript enhancements
  params:
    css: pkgdown/extra.css          # Custom styling
  bslib:
    # PLAN A: Refined Academic Color System
    # Primary: Academic blue for key actions
    primary: "#0054AD"
    # Secondary: Muted slate for supporting elements
    secondary: "#5A6C7D"
    # Success: Earthy green for positive states
    success: "#2D7B3F"

    # Background: Off-white reduces eye strain vs pure white
    bg: "#FAFBFC"
    fg: "#2C3E50"

    # Modern, readable fonts
    base_font: { google: "Inter" }
    heading_font: { google: "Montserrat" }
    code_font: { google: "Fira Code" }

    # Enhanced typography scale (ADHD-friendly)
    font-size-base: 1.0rem          # Increased from default 0.875rem
    headings-font-weight: 700       # Bolder headings for visual anchors
    headings-line-height: 1.3       # Tighter spacing for impact

home:
  title: "{PACKAGE_NAME}: {SUBTITLE}"
  description: >
    {PACKAGE_DESCRIPTION}
  strip_header: false
  sidebar:
    structure: [links, license, citation, authors, dev]

navbar:
  structure:
    left:  [home, reference, articles, ecosystem, status, news]
    right: [search, github]
  components:
    ecosystem:
      text: Ecosystem
      menu:
      - text: "Core Packages"
      - text: "mediationverse (Meta-package)"
        href: https://data-wise.github.io/mediationverse/
      - text: "medfit (Foundation)"
        href: https://data-wise.github.io/medfit/
      - text: "RMediation (Confidence Intervals)"
        href: https://data-wise.github.io/rmediation/
      # Add other packages as they become available
```

### Color Palette Standards

#### Primary Colors (Shared Across Ecosystem)

| Color | Hex | Usage |
|-------|-----|-------|
| **Primary** | #0054AD | Links, primary actions, headings |
| **Secondary** | #5A6C7D | Supporting elements, muted text |
| **Success** | #2D7B3F | Success states, positive indicators |
| **Background** | #FAFBFC | Main background (off-white) |
| **Foreground** | #2C3E50 | Body text |

#### Package-Specific Accents (Optional)

Each package may add ONE accent color for distinctive branding:

| Package | Accent | Hex | Usage |
|---------|--------|-----|-------|
| medfit | Blue | #0054AD | (Uses primary) |
| probmed | Purple | #7C3AED | Probability/uncertainty visualizations |
| RMediation | Teal | #17A2B8 | Confidence interval highlights |
| medrobust | Orange | #F57C00 | Sensitivity/robustness indicators |

**Rule**: Accent colors should only be used in package-specific content (plots, callouts), NOT in navigation or core UI.

---

## Custom CSS Template

All packages should include `pkgdown/extra.css` with these ADHD-friendly enhancements:

### Core Enhancements

```css
/* ============================================================================
   {PACKAGE_NAME} pkgdown Custom Styles
   Plan A: Refined Academic + ADHD-Friendly Enhancements
   ============================================================================ */

/* VISUAL HIERARCHY */
h1 {
  font-size: 2.5rem;
  font-weight: 700;
  color: #0054AD;
  border-bottom: 3px solid #0054AD;
  padding-bottom: 0.5rem;
  margin-top: 1.5em;
}

h2 {
  font-size: 2.0rem;
  font-weight: 700;
  color: #2C3E50;
  border-left: 4px solid #0054AD;
  padding-left: 1rem;
  margin-top: 1.5em;
}

h3 {
  font-size: 1.5rem;
  font-weight: 600;
  color: #2C3E50;
  margin-top: 1.5em;
}

/* CODE BLOCKS */
.sourceCode, pre {
  background-color: #F6F8FA !important;
  border: 1px solid #DEE2E6;
  border-radius: 6px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
  padding: 1rem;
  margin: 1.5rem 0;
}

pre.r {
  border-left: 3px solid #0054AD;  /* R input */
}

pre:not(.r) {
  border-left: 3px solid #5A6C7D;  /* Output */
}

/* NAVIGATION */
.navbar a:hover,
.nav-link:hover {
  background-color: rgba(0, 84, 173, 0.1);
  border-radius: 4px;
  transition: background-color 0.2s;
}

/* SIDEBAR TOC */
.sidebar {
  position: sticky;
  top: 1rem;
  max-height: calc(100vh - 2rem);
  overflow-y: auto;
}

.sidebar nav a {
  display: block;
  padding: 0.25rem 0.75rem;
  color: #5A6C7D;
  text-decoration: none;
  border-left: 2px solid transparent;
  transition: all 0.2s;
}

.sidebar nav a:hover {
  color: #0054AD;
  border-left-color: #0054AD;
  background-color: #F6F8FA;
}

.sidebar nav a.active {
  color: #0054AD;
  font-weight: 600;
  border-left-color: #0054AD;
  background-color: #E8F4F8;
}

/* ADHD: TL;DR BOXES */
blockquote.tldr {
  background-color: #FFF8E1;
  border-left: 4px solid #FFC107;
  padding: 1rem 1.25rem;
  margin: 1.5rem 0;
  font-size: 1.05rem;
}

blockquote.tldr::before {
  content: "TL;DR:";
  display: block;
  font-weight: 700;
  color: #F57C00;
  margin-bottom: 0.5rem;
}

/* ACCESSIBILITY */
*:focus {
  outline: 2px solid #0054AD;
  outline-offset: 2px;
}

/* RESPONSIVE */
@media (max-width: 768px) {
  h1 { font-size: 2rem; }
  h2 { font-size: 1.5rem; }
  h3 { font-size: 1.25rem; }
}
```

### Optional Enhancements

Additional CSS can be added for:
- Package-specific callout boxes (use accent colors)
- Function category icons
- Visual cards for feature grids
- Dark mode (if desired)

---

## JavaScript Enhancements

Include `pkgdown/extra.html` with copy-to-clipboard functionality:

```html
<!-- Copy buttons for code blocks -->
<function_calls>
document.addEventListener('DOMContentLoaded', function() {
  document.querySelectorAll('pre').forEach(function(pre) {
    if (pre.querySelector('.copy-button')) return;

    var button = document.createElement('button');
    button.className = 'copy-button';
    button.textContent = 'Copy';
    button.style.float = 'right';
    button.style.marginTop = '-0.5rem';

    button.addEventListener('click', function() {
      var code = pre.textContent;
      navigator.clipboard.writeText(code).then(function() {
        button.textContent = 'Copied!';
        button.style.backgroundColor = '#2D7B3F';
        setTimeout(function() {
          button.textContent = 'Copy';
          button.style.backgroundColor = '#0054AD';
        }, 2000);
      });
    });

    pre.insertBefore(button, pre.firstChild);
  });
});
</script>
```

---

## Navigation Standards

### Required Navbar Items

All packages must include:

1. **Home** - Package homepage
2. **Reference** - Function documentation
3. **Articles** - Vignettes/guides
4. **Ecosystem** - Cross-package navigation (CRITICAL for discoverability)
5. **News** - Changelog
6. **Search** - Built-in pkgdown search
7. **GitHub** - Source repository

### Ecosystem Menu Structure

The Ecosystem dropdown creates cross-package navigation:

```yaml
ecosystem:
  text: Ecosystem
  menu:
  - text: "Core Packages"
  - text: "mediationverse (Meta-package)"
    href: https://data-wise.github.io/mediationverse/
  - text: "medfit (Foundation)"
    href: https://data-wise.github.io/medfit/
  - text: "probmed (P_med Effect Size)"
    href: https://data-wise.github.io/probmed/
  - text: "RMediation (Confidence Intervals)"
    href: https://data-wise.github.io/rmediation/
  - text: "medrobust (Sensitivity Analysis)"
    href: https://data-wise.github.io/medrobust/
  - text: "---------"
  - text: "Support Packages"
  - text: "medsim (Simulation Infrastructure)"
    href: https://data-wise.github.io/medsim/
```

**Rule**: Keep menu synchronized across all packages. When a new package is added, update ALL package sites.

---

## Typography Standards

### Font System

| Element | Font | Weight | Size |
|---------|------|--------|------|
| Body | Inter | 400 | 1.0rem |
| Headings | Montserrat | 700 | 2.5rem (h1), 2.0rem (h2), 1.5rem (h3) |
| Code | Fira Code | 400 | 0.875em |

**Rationale:**
- **Inter**: Clean sans-serif, excellent readability for long-form content
- **Montserrat**: Geometric sans-serif, strong presence for headings
- **Fira Code**: Monospace with ligatures, ideal for R code

### Line Heights

| Context | Line Height |
|---------|-------------|
| Body text | 1.7 |
| Headings | 1.3 |
| Code blocks | 1.5 |

Higher line-height (1.7) for body improves readability, especially for ADHD users.

---

## ADHD-Friendly Patterns

### Visual Hierarchy

**Problem**: Flat text walls are hard to scan.
**Solution**: Strong heading differentiation

- h1: Blue bottom border (creates visual "chapter" breaks)
- h2: Blue left border (creates visual "section" markers)
- h3: Bolder weight without decoration

### Visual Chunking

**Problem**: Long content is overwhelming.
**Solution**: Generous spacing between sections

```css
.section {
  margin-bottom: 2.5rem;  /* Breathing room */
}

h1, h2, h3 {
  margin-top: 1.5em;      /* Clear visual breaks */
}
```

### Color-Coded Elements

**Problem**: Hard to distinguish different content types.
**Solution**: Colored borders for categorization

- Code blocks: Blue left border (R input) vs gray (output)
- Callouts: Yellow (TL;DR), blue (info), green (success), orange (warning)
- Links: Blue (primary actions)

### Sticky Navigation

**Problem**: Lost context in long articles.
**Solution**: Sticky table of contents

```css
.sidebar {
  position: sticky;
  top: 1rem;
  max-height: calc(100vh - 2rem);
  overflow-y: auto;
}
```

Users always see their location in document structure.

---

## Accessibility Compliance

All sites must maintain **WCAG 2.1 Level AA** compliance.

### Color Contrast Requirements

| Element | Minimum Ratio | Our Values |
|---------|---------------|------------|
| Normal text | 4.5:1 | #2C3E50 on #FAFBFC = 11.2:1 ✅ |
| Large text (18pt+) | 3:1 | All headings > 4.5:1 ✅ |
| UI components | 3:1 | Borders, icons > 3:1 ✅ |

### Keyboard Navigation

- All interactive elements must be keyboard accessible
- Visible focus indicators (2px outline)
- Logical tab order
- Skip-to-content link for screen readers

### Screen Reader Support

- Semantic HTML5 elements (`<nav>`, `<main>`, `<article>`)
- Proper heading hierarchy (no skipped levels)
- Alt text for all images
- ARIA labels where needed

### Testing Tools

- [WAVE browser extension](https://wave.webaim.org/)
- [axe DevTools](https://www.deque.com/axe/devtools/)
- Chrome Lighthouse audit

---

## Badge Standards

### Required Badges

All README.md files should include (in order):

1. **CRAN status** - `[![CRAN status](https://www.r-pkg.org/badges/version/{PKG})](https://CRAN.R-project.org/package={PKG})`
2. **Lifecycle** - Stable for released, experimental for development
3. **R-CMD-check** - CI status badge
4. **Test coverage** - Codecov badge
5. **pkgdown** - Documentation build status

### Badge Placement

```markdown
# {PACKAGE_NAME}: {SUBTITLE}

[![CRAN status](...)](...)
[![Lifecycle: stable](...)](...)
[![R-CMD-check](...)](...)
[![Codecov test coverage](...)](...)
[![pkgdown](...)](...)

<!-- badges: start -->
<!-- badges: end -->
```

**CRITICAL**: Badges must be OUTSIDE the `<!-- badges: -->` comment markers for pkgdown Bootstrap 5.

---

## Vignette Standards

### Article Organization

```
vignettes/
├── {package-name}.qmd           # Get Started (main vignette)
└── articles/
    ├── introduction.qmd         # Detailed introduction
    ├── {feature-1}.qmd          # Feature-specific guides
    ├── {feature-2}.qmd
    └── advanced.qmd             # Advanced usage
```

### Quarto Format

All vignettes use native Quarto format:

```yaml
---
title: "Article Title"
format: html
execute:
  echo: true
  message: false
  warning: false
---
```

**Chunk format** (hash-pipe, not inline):

````markdown
```{r}
#| label: chunk-name
#| echo: true
#| eval: false

code here
```
````

### TL;DR Sections

Start long articles with TL;DR summary:

```markdown
> **TL;DR:** Use `med()` for simple mediation.
> Add `boot = TRUE` for confidence intervals.
> Call `quick()` to see results instantly.
```

This renders with yellow highlighting via `blockquote.tldr` CSS.

---

## Logo Standards

### Logo Specifications

- **Format**: PNG with transparency
- **Size**: 350px width (maintains aspect ratio)
- **Location**: `man/figures/logo.png`
- **Alignment**: Right-aligned in navbar

### Logo Design Guidelines

1. **Color palette**: Use primary (#0054AD) as dominant color
2. **Typography**: Montserrat font if text included
3. **Symbol**: Package-specific iconography
4. **Background**: Transparent or subtle gradient

### Example (medfit logo)

- Hexagon shape (R package convention)
- Blue background gradient
- White mediation diagram (X → M → Y arrows)
- Package name in white Montserrat

---

## Reference Page Organization

Organize functions by purpose, not alphabetically:

```yaml
reference:
  - title: "Quick Start"
    desc: "ADHD-friendly entry points for rapid analysis"
    contents:
      - {main_function}
      - {quick_function}

  - title: "{Feature Category 1}"
    desc: "Description"
    contents:
      - func1
      - func2

  - title: "S7 Classes"
    desc: "Core S7 class definitions"
    contents:
      - starts_with("{ClassName}")

  - title: "Methods"
    desc: "Print and summary methods"
    contents:
      - starts_with("print")
```

**Rationale**: Users think in tasks, not alphabetical order.

---

## Implementation Checklist

When creating a new package site or updating an existing one:

### Initial Setup
- [ ] Copy `_pkgdown.yml` template
- [ ] Customize package-specific values (name, description, URL)
- [ ] Create `pkgdown/extra.css` from template
- [ ] Create `pkgdown/extra.html` with copy buttons
- [ ] Add ecosystem menu with ALL package links
- [ ] Configure MathJax if needed

### Visual Design
- [ ] Verify colors match standard palette
- [ ] Test typography hierarchy (h1, h2, h3 distinctive)
- [ ] Check code block styling (R input vs output differentiation)
- [ ] Ensure off-white background (#FAFBFC)
- [ ] Test on mobile/tablet (responsive breakpoints)

### Navigation
- [ ] Navbar includes all required items
- [ ] Ecosystem dropdown links to all packages
- [ ] Search functionality enabled
- [ ] Sticky sidebar TOC on article pages

### Accessibility
- [ ] Run WAVE scan (0 errors)
- [ ] Check color contrast (all > 4.5:1)
- [ ] Test keyboard navigation
- [ ] Verify focus indicators visible
- [ ] Screen reader compatibility (test with VoiceOver/NVDA)

### Content
- [ ] README badges outside comment markers
- [ ] All vignettes use Quarto format
- [ ] TL;DR sections in long articles
- [ ] Reference page organized by task
- [ ] Logo meets specifications

### Deployment
- [ ] GitHub Pages enabled (gh-pages branch)
- [ ] pkgdown.yaml workflow configured
- [ ] Site builds without errors
- [ ] All links resolve (no 404s)
- [ ] Cross-package ecosystem links work

---

## Maintenance

### When to Update

1. **New package added to ecosystem**
   - Update ecosystem menu in ALL packages
   - Add cross-references in documentation

2. **Color palette refinement**
   - Document in this guide
   - Update `extra.css` in all packages
   - Test accessibility compliance

3. **pkgdown/Bootstrap updates**
   - Test on one package first
   - Document any breaking changes
   - Roll out systematically

### Version Control

- This guide version: **1.0.0** (2025-12-20)
- Track changes in this document
- Tag releases when significant updates occur

---

## Examples

### Model Packages

**medfit** (Foundation package):
- Site: https://data-wise.github.io/medfit/
- Features: Full implementation of Plan A
- Status: ✅ Reference implementation

**probmed** (Application package):
- Site: https://data-wise.github.io/probmed/
- Accent: Purple (#7C3AED) for probability visualizations
- Status: 🚧 Pending redesign

**RMediation** (Application package):
- Site: https://data-wise.github.io/rmediation/
- Accent: Teal (#17A2B8) for CI highlights
- Status: 🚧 Pending redesign

---

## Future Enhancements (Plan B)

The following enhancements may be added in Phase 2 (Plan B implementation):

### Visual Cards
Replace bullet lists with grid cards:

```html
<div class="feature-grid">
  <div class="feature-card">
    <div class="icon-wrapper">🚀</div>
    <h3>ADHD-Friendly API</h3>
    <p>One function to rule them all.</p>
  </div>
</div>
```

### Dark Mode
Optional dark theme toggle:

```yaml
bslib:
  # Dark mode colors
  bg-dark: "#1A1D23"
  fg-dark: "#E4E6EB"
  code-bg-dark: "#2D3139"
```

### Interactive Elements
- Progress indicators for reading
- Expandable code blocks
- Hover tooltips for technical terms

### Enhanced Search
- Fuzzy matching
- Search suggestions
- Context previews

**Status**: Planned for future (see PROPOSAL-SITE-REDESIGN.md)

---

## Questions & Support

**For questions about this standard:**
- Open issue: https://github.com/data-wise/medfit/issues
- Discuss in ecosystem planning: `/Users/dt/mediation-planning/`

**For implementation help:**
- See PROPOSAL-SITE-REDESIGN.md for detailed examples
- Check medfit implementation: https://github.com/data-wise/medfit
- Review pkgdown documentation: https://pkgdown.r-lib.org/

---

## Revision History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2025-12-20 | Initial standard (Plan A) | DT |

---

**Document Status**: ✅ Active Standard
**Next Review**: After Plan B implementation in any package
**Maintained By**: mediationverse development team