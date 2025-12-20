# medfit Site Redesign Proposal

**Generated:** 2025-12-20
**Context:** pkgdown site enhancement - ADHD-friendly + modern design
**Current Site:** Bootstrap 5, Litera theme, academic blue (#0054AD)

---

## Executive Summary

The current medfit site is **functional and clean** but has opportunities for:
1. **Enhanced visual hierarchy** - Better scanability for ADHD users
2. **Modern design elements** - Aligned with 2025 web standards
3. **Improved code presentation** - Better syntax highlighting and copy UX
4. **Stronger visual identity** - More distinctive branding

**Current Strengths:**
- ✅ Clean, academic aesthetic
- ✅ Good font choices (Inter, Montserrat, Fira Code)
- ✅ Well-organized navigation
- ✅ ADHD-friendly "Quick Start" emphasis

**Areas for Enhancement:**
- ⚠️ Low visual contrast in some areas
- ⚠️ Long text blocks without visual breaks
- ⚠️ Code blocks lack interactive features
- ⚠️ Limited use of color to guide attention
- ⚠️ Pure white background (#ffffff) can cause eye strain

---

## Current Site Analysis

### Color Palette
```yaml
Primary: #0054AD (academic blue)
Background: #ffffff (pure white)
Foreground: #212529 (near black)
Font size: 0.925rem (slightly reduced)
```

**ADHD Impact:**
- Pure white can be harsh for long reading sessions
- Single primary color limits ability to create visual hierarchies
- Good font size, but could benefit from stronger headings

### Navigation Structure
```
Home > Reference > Articles > Ecosystem > Status > News
```

**Observations:**
- Well-organized, logical flow
- "Ecosystem" menu is excellent for discovery
- Could benefit from visual indicators for current location

### Code Presentation
- Light gray background (#f8f9fa typical for Litera)
- Good use of Fira Code font
- Lacks: copy buttons, line highlighting, output differentiation

---

## PLAN A: Refined Academic (Conservative Enhancement)

**Effort:** ⚡ Quick (2-3 hours)
**Philosophy:** Keep academic aesthetic, enhance ADHD-friendliness through subtle changes

### Changes

#### 1. Color Refinements
```yaml
bslib:
  primary: "#0054AD"        # Keep academic blue
  secondary: "#5A6C7D"      # Add muted slate for secondary elements
  success: "#2D7B3F"        # Earthy green for success states
  bg: "#FAFBFC"             # Off-white (reduces eye strain)
  fg: "#2C3E50"             # Slightly softer black

  # Enhanced contrast ratios
  border: "#DEE2E6"         # Subtle borders
```

**ADHD Benefit:** Off-white background reduces cognitive load, softer colors are less harsh

#### 2. Enhanced Typography Scale
```yaml
bslib:
  font-size-base: 1.0rem           # Increase from 0.925rem
  headings-font-weight: 700        # Bolder headings
  headings-line-height: 1.3        # Tighter for impact

  # Rhythm system
  h1: 2.5rem
  h2: 2.0rem
  h3: 1.5rem
```

**ADHD Benefit:** Stronger headings create clear visual anchors

#### 3. Visual Hierarchy Enhancements
```yaml
# Custom CSS additions (create pkgdown/extra.css)
```

**Add:**
- Subtle drop shadows on code blocks (depth perception)
- Colored left border on callouts (visual categorization)
- Hover states on links (interaction feedback)
- Sticky table of contents with progress indicator

**ADHD Benefit:** Multiple visual cues help maintain orientation

#### 4. Code Block Improvements
- Add copy-to-clipboard buttons (via pkgdown built-in)
- Differentiate input/output with background colors
- Add line numbers for reference

**Implementation:**
```yaml
template:
  params:
    docsearch:
      api_key: YOUR_KEY
    ganalytics: YOUR_GA_ID
  includes:
    in_header: pkgdown/extra.css
```

### Files to Modify
- `_pkgdown.yml` (color updates)
- Create `pkgdown/extra.css` (custom styling)

**Pros:**
- Low risk, incremental improvement
- Maintains brand consistency
- Easy to implement and test
- Backward compatible

**Cons:**
- Conservative, may not feel "modern"
- Limited visual transformation

---

## PLAN B: Modern Academic (Balanced Modernization)

**Effort:** 🔧 Medium (5-8 hours)
**Philosophy:** Contemporary design while keeping scholarly credibility

### Changes

#### 1. Expanded Color System
```yaml
bslib:
  # Primary palette
  primary: "#0066CC"        # Brighter, more saturated blue
  secondary: "#6C757D"      # Bootstrap gray

  # Semantic colors
  success: "#28A745"
  info: "#17A2B8"
  warning: "#FFC107"
  danger: "#DC3545"

  # Background system
  bg: "#F8F9FA"             # Light gray
  body-bg: "#FFFFFF"
  sidebar-bg: "#F1F3F5"
  code-bg: "#F6F8FA"

  # Accent colors (custom)
  accent-1: "#7C3AED"       # Purple for highlights
  accent-2: "#EC4899"       # Pink for special callouts
```

**ADHD Benefit:** Color-coded sections create mental landmarks

#### 2. Enhanced Layout
```yaml
home:
  sidebar:
    structure: [custom-cta, links, license, citation, authors, dev]
    components:
      custom-cta:
        title: "Quick Start"
        text: |
          <a href="articles/getting-started.html" class="btn btn-primary btn-lg">
            Get Started in 5 Minutes →
          </a>
```

**Add prominent CTA (Call to Action) in sidebar**

#### 3. Interactive Elements

**Table of Contents:**
- Floating, collapsible TOC
- Progress indicator (% of page read)
- Auto-highlight current section

**Code Blocks:**
- One-click copy with visual feedback
- Expandable for long outputs
- "Run in RStudio" links (where applicable)

**Navigation:**
- Breadcrumbs on all pages
- "Next/Previous" article navigation
- Search autocomplete improvements

#### 4. Content Enhancements

**Homepage:**
```markdown
## Why medfit?

[Grid of 3 cards with icons]
- 🚀 **Fast** - Get results in one line
- 🎯 **Flexible** - Multiple model types
- 🔧 **Reliable** - 427 tests, 90%+ coverage
```

**Visual cards instead of bullet lists**

**Reference Page:**
- Icons for each function category
- Color-coded by function type
- Search within reference

#### 5. Bootswatch Theme Change

**Current:** Litera (traditional, serif-heavy)
**Proposed:** **Flatly** or **Cosmo**

**Flatly characteristics:**
- Modern, flat design
- Clean, sans-serif throughout
- Good contrast ratios
- Professional but friendly

**Alternative:** **Zephyr** (newer, very modern)

### Files to Modify
- `_pkgdown.yml` (comprehensive updates)
- `pkgdown/extra.css` (extensive custom CSS)
- `pkgdown/extra.js` (interactive features)
- `README.md` (add visual cards)
- `vignettes/articles/*.qmd` (add callout boxes)

### Implementation Checklist
```
[ ] Update color system in _pkgdown.yml
[ ] Change bootswatch theme to Flatly
[ ] Create custom CSS for cards/callouts
[ ] Add JavaScript for copy buttons
[ ] Create icon system for reference page
[ ] Add breadcrumbs template
[ ] Update homepage with visual cards
[ ] Add TOC enhancements
[ ] Test on mobile/tablet
[ ] Check accessibility (WCAG AA)
```

**Pros:**
- Significantly more modern feel
- Better ADHD support through visual diversity
- Improved user engagement
- Still professional

**Cons:**
- More implementation work
- Requires testing across pages
- May need iteration

---

## PLAN C: Bold & Vibrant (Maximum Modernization)

**Effort:** 🏗️ Large (10-15 hours)
**Philosophy:** Embrace modern SaaS aesthetic, stand out from typical R package sites

### Changes

#### 1. Gradient-Based Color System
```yaml
bslib:
  # Gradient primary
  primary: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)"

  # Expanded palette
  blue: "#667eea"
  purple: "#764ba2"
  pink: "#f093fb"
  orange: "#ffa45b"

  # Backgrounds
  bg: "#FAFBFC"
  hero-bg: "linear-gradient(135deg, #667eea15 0%, #764ba215 100%)"
```

**Use gradients for headers, cards, CTA buttons**

#### 2. Hero Section (Homepage)
```html
<div class="hero-section">
  <h1>Mediation Analysis. Simplified.</h1>
  <p class="lead">
    One function. Instant results.
    Built for researchers who value their time.
  </p>

  <div class="cta-buttons">
    <a href="install" class="btn btn-primary btn-lg">
      Install Now
    </a>
    <a href="getting-started" class="btn btn-outline-primary btn-lg">
      5-Minute Tutorial
    </a>
  </div>

  <!-- Animated code demo -->
  <div class="code-preview">
    result <- med(data = mydata, treatment = "X", mediator = "M", outcome = "Y")
    quick(result)
    #> NIE = 0.19 | NDE = 0.16 | PM = 55%
  </div>
</div>
```

#### 3. Card-Based Layout

**Replace text-heavy sections with cards:**
```html
<div class="feature-grid">
  <div class="feature-card">
    <div class="icon-wrapper">🚀</div>
    <h3>ADHD-Friendly API</h3>
    <p>One function to rule them all. <code>med()</code> does it all.</p>
  </div>

  <div class="feature-card">
    <div class="icon-wrapper">🎯</div>
    <h3>Effect Extractors</h3>
    <p>nie(), nde(), te() - get exactly what you need.</p>
  </div>

  <!-- 4 more cards -->
</div>
```

#### 4. Interactive Documentation

**Live Code Examples:**
- Embed Shiny apps for demos
- Interactive parameter sliders
- Real-time output updates

**Example:**
```r
# Try it yourself! (interactive widget)
med(data = [dropdown: iris/mtcars/custom],
    treatment = [text input],
    mediator = [text input],
    outcome = [text input])

[Run Code Button] [Reset]
```

#### 5. Animations & Micro-interactions
- Smooth scroll to sections
- Fade-in animations for content
- Hover effects on cards
- Progress bar while reading articles
- Confetti on successful code copy 🎉

#### 6. Dark Mode Support
```yaml
bslib:
  # Light mode (default)
  bg: "#FAFBFC"
  fg: "#2C3E50"

  # Dark mode
  bg-dark: "#1A1D23"
  fg-dark: "#E4E6EB"
  code-bg-dark: "#2D3139"
```

**Add theme toggle button in navbar**

#### 7. Typography Extremes
```yaml
bslib:
  base_font: { google: "Inter" }
  heading_font: { google: "Space Grotesk" }  # More modern, geometric
  code_font: { google: "JetBrains Mono" }    # Better ligatures than Fira Code

  font-size-base: 1.125rem  # Larger, more readable
  line-height-base: 1.7     # More breathing room
```

### Files to Modify
- `_pkgdown.yml` (complete overhaul)
- `pkgdown/hero.html` (new template)
- `pkgdown/extra.css` (extensive custom CSS)
- `pkgdown/extra.js` (animations, interactivity)
- `pkgdown/dark-mode.js` (theme switcher)
- `README.md` (restructure for hero layout)
- All vignettes (add interactive elements)

### Implementation Checklist
```
[ ] Design hero section mockup
[ ] Implement gradient color system
[ ] Create card components
[ ] Build interactive code widgets
[ ] Add animations (AOS library?)
[ ] Implement dark mode toggle
[ ] Update all content to card layout
[ ] Add Shiny app embeds
[ ] Performance optimization
[ ] Accessibility audit
[ ] Mobile optimization
[ ] Cross-browser testing
```

**Pros:**
- Truly stands out from typical R package sites
- Maximum ADHD support through visual variety
- Modern, engaging experience
- Could become a template for other packages

**Cons:**
- Significant time investment
- May be "too much" for academic audience
- Maintenance burden
- Risk of appearing unprofessional
- Need frontend expertise

---

## ADHD-Specific Features (All Plans)

### Priority Enhancements

#### 1. Visual Chunking
```css
/* Break long content into scannable sections */
.content-chunk {
  margin-bottom: 2rem;
  padding: 1.5rem;
  background: #F8F9FA;
  border-radius: 8px;
  border-left: 4px solid var(--bs-primary);
}
```

#### 2. Progress Indicators
- Reading progress bar (top of page)
- Article TOC with checkmarks
- "X minutes to read" estimates

#### 3. Quick Navigation
```html
<!-- Floating action button -->
<div class="quick-nav">
  <button>📖 Quick Start</button>
  <button>📚 Examples</button>
  <button>💬 Get Help</button>
  <button>⬆️ Top</button>
</div>
```

#### 4. Reduced Cognitive Load
- **TL;DR sections** at top of long articles
- **Key takeaways** in colored boxes
- **Visual summaries** (diagrams, flow charts)
- **Code-to-English** translations

Example:
```markdown
> **TL;DR:** Use `med()` for simple mediation.
> Add `boot = TRUE` for confidence intervals.
> Call `quick()` to see results instantly.
```

#### 5. Search Enhancements
- Fuzzy search (typo-tolerant)
- Search suggestions
- Recent searches
- Context preview in results

---

## Recommended Implementation Path

### Phase 1: Quick Wins (Week 1)
**Implement Plan A + ADHD features**

```
Day 1-2: Update _pkgdown.yml colors
Day 3:   Create extra.css for visual hierarchy
Day 4:   Add TL;DR boxes to articles
Day 5:   Implement copy buttons on code blocks
```

**Deliverable:** Noticeably better, still conservative

### Phase 2: Modernization (Week 2-3)
**Implement Plan B enhancements**

```
Week 2: Layout improvements, Flatly theme
Week 3: Interactive elements, visual cards
```

**Deliverable:** Modern, competitive with best R package sites

### Phase 3: Innovation (Month 2, Optional)
**Selectively add Plan C features**

Focus on:
- Dark mode (high value, moderate effort)
- Hero section (strong first impression)
- Interactive code demos (unique selling point)

**Skip:**
- Heavy animations (diminishing returns)
- Complete gradient system (too trendy)

---

## Technical Implementation Notes

### Custom CSS Structure
```
pkgdown/
├── extra.css           # Main custom styles
├── components/
│   ├── cards.css       # Card components
│   ├── code.css        # Code block enhancements
│   ├── nav.css         # Navigation improvements
│   └── adhd.css        # ADHD-specific features
├── dark-mode.css       # Dark theme (Plan C)
└── animations.css      # Micro-interactions (Plan C)
```

### JavaScript Additions
```
pkgdown/
├── extra.js            # Main functionality
├── copy-code.js        # Copy buttons
├── progress.js         # Reading progress
├── toc.js              # Enhanced table of contents
└── theme-toggle.js     # Dark mode switcher (Plan C)
```

### Testing Checklist
```
[ ] Desktop (Chrome, Firefox, Safari, Edge)
[ ] Mobile (iOS Safari, Android Chrome)
[ ] Tablet (iPad)
[ ] Screen readers (NVDA, VoiceOver)
[ ] Color contrast (WebAIM checker)
[ ] Print styles
[ ] 404 page
[ ] All vignettes render
[ ] All reference pages load
[ ] Search works
[ ] Links not broken
```

---

## Accessibility Compliance

All plans must maintain **WCAG 2.1 AA** compliance:

- ✅ Color contrast ≥ 4.5:1 for normal text
- ✅ Color contrast ≥ 3:1 for large text
- ✅ Keyboard navigation
- ✅ Screen reader friendly
- ✅ Focus indicators
- ✅ Alt text for images
- ✅ Semantic HTML
- ✅ Skip to content link

**Test with:**
- WAVE browser extension
- axe DevTools
- Lighthouse audit

---

## Cost-Benefit Analysis

| Plan | Time | Visual Impact | ADHD Support | Risk | ROI |
|------|------|---------------|--------------|------|-----|
| **A** | 2-3h | 6/10 | 7/10 | Low | ★★★★★ |
| **B** | 5-8h | 8/10 | 9/10 | Medium | ★★★★☆ |
| **C** | 10-15h | 10/10 | 10/10 | High | ★★★☆☆ |

### ADHD Decision Matrix

**If your priority is:**
- ✅ **Quick improvement with minimal risk** → Plan A
- ✅ **Best balance of modern + professional** → Plan B ⭐ RECOMMENDED
- ✅ **Maximum differentiation, willing to iterate** → Plan C

---

## Recommended Next Steps

### Option 1: Start with Plan A
```bash
1. Update _pkgdown.yml (colors + fonts)
2. Create pkgdown/extra.css (visual hierarchy)
3. Rebuild site: pkgdown::build_site()
4. Review and iterate
5. If satisfied → done
6. If want more → proceed to Plan B
```

### Option 2: Go Directly to Plan B
```bash
1. Create feature branch: git checkout -b site-redesign
2. Implement all Plan B changes
3. Build and preview locally
4. User testing with 2-3 people
5. Iterate based on feedback
6. Merge when satisfied
```

### Option 3: Hybrid Approach (Recommended)
```bash
Phase 1: Plan A foundation (merge immediately)
Phase 2: Plan B features (one PR per feature)
  - PR 1: New color system + Flatly theme
  - PR 2: Homepage visual cards
  - PR 3: Code block improvements
  - PR 4: Interactive TOC
  - PR 5: Reference page icons
Phase 3: Selectively add Plan C (evaluate case-by-case)
```

---

## Questions to Consider

Before choosing:
1. **Audience:** Academic researchers or broader R community?
2. **Brand:** Should medfit look "scholarly" or "accessible"?
3. **Maintenance:** Who will maintain custom CSS/JS?
4. **Differentiation:** How much do you want to stand out?
5. **Resources:** Can you dedicate 5-15 hours to this?

---

## Mockup Preview (Plan B Example)

```
┌─────────────────────────────────────────────────────────┐
│  medfit                    [Search]  [🌙 Dark]  [GitHub]│
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │  🎯 Mediation Analysis, Simplified              │    │
│  │                                                  │    │
│  │  One function. Instant results. Built for       │    │
│  │  researchers who value their time.              │    │
│  │                                                  │    │
│  │  [Get Started →]  [See Examples]                │    │
│  └────────────────────────────────────────────────┘    │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ 🚀 Fast  │  │ 🎯Flexible│  │ 🔧 Solid │              │
│  │          │  │           │  │          │              │
│  │ One-line │  │ lm, glm,  │  │ 427 tests│              │
│  │ mediation│  │ lavaan    │  │ 90% cover│              │
│  └──────────┘  └──────────┘  └──────────┘              │
│                                                          │
│  Quick Example                                           │
│  ┌────────────────────────────────────┐                 │
│  │ result <- med(                     │ [Copy]          │
│  │   data = mydata,                   │                 │
│  │   treatment = "X",                 │                 │
│  │   mediator = "M",                  │                 │
│  │   outcome = "Y"                    │                 │
│  │ )                                  │                 │
│  │ quick(result)                      │                 │
│  │ #> NIE = 0.19 | NDE = 0.16 | PM=55%│                 │
│  └────────────────────────────────────┘                 │
└─────────────────────────────────────────────────────────┘
```

---

## Conclusion

**Immediate action:** Start with Plan A (2-3 hours)
- Low risk, high return
- Can deploy immediately
- Foundation for future enhancements

**If satisfied:** Stop here. You've made meaningful improvements.

**If want more:** Incrementally add Plan B features
- Proven design patterns
- Moderate effort
- Professional, modern result

**Consider Plan C features selectively:**
- Dark mode (worth it)
- Hero section (good first impression)
- Skip heavy animations (overkill)

**Final recommendation:**
**Plan A now + Plan B features over next month = Best outcome**

---

**Ready to implement?**
Let me know which plan you'd like to start with, and I'll create the specific code changes!
