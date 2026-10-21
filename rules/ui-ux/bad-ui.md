# STRICT UI/UX DIRECTIVE: FORBIDDEN ANTI-PATTERNS & ZERO-AI-SLOP POLICY

> **MANDATE**: This document defines strictly prohibited UI/UX anti-patterns. Designs violating these directives will fail automated quality checks and code review. Every design choice must be deliberate, consistent, functional, and token-backed.

---

### 1. Color & Lighting Anti-Patterns (STRICTLY FORBIDDEN)
- **Gradient abuse**:
  - Never use purple → blue, violet → cyan, or pink → orange gradients on hero sections, cards, surfaces, buttons, or borders.
  - Never use gradient or clipped text on headings (`bg-clip-text text-transparent`).
- **Glow & ambient blob effects**:
  - Zero blurred colored blobs, glowing mesh gradients, or ambient backlights behind content for "visual flavor".
- **Color palette chaos**:
  - Never introduce multiple unharmonized accent colors. Maintain 1 primary brand color, 1 neutral slate/gray scale, and standard semantic colors (success/warning/error).
  - No inconsistent shades across screens (e.g., slightly different blues or neutral grays on different pages).
- **Polar extremes & inverted dark mode**:
  - Never use pure black text (`#000000`) on pure white (`#ffffff`). Use softened neutral tones (e.g., `#0f172a` or `#111827`).
  - Dark mode must not simply invert light mode colors; design an intentional dark elevation system.
- **Low-contrast illegibility**:
  - Zero low-contrast gray text on gray backgrounds. Text must strictly pass WCAG AA/AAA contrast ratios.

---

### 2. Effects, Shadows & Micro-Animations (ZERO OVER-EFFECTS)
- **Gratuitous glassmorphism**:
  - Never apply `backdrop-blur` or semi-transparent cards over solid, flat, or static backgrounds where there is nothing dynamic behind to blur.
- **Shadow bloat & colored glows**:
  - No heavy, overly diffused, or saturated colored drop shadows under cards or buttons. Use subtle, single-tone elevation levels only where depth is functionally necessary.
- **Excessive card micro-interactions**:
  - Do not add hover lift (`-translate-y-*`), zoom/scale (`scale-105`), or glowing border transitions to every card.
- **Animation spam**:
  - Zero intrusive entrance animations: no scroll-triggered fade-ins, bouncing icons, glowing borders, or pulsing badges. Animations must serve only functional layout shifts or state changes.
- **Shimmer / shine effects**:
  - No gradient borders or animated shine sweeps across buttons, cards, or hero elements.

---

### 3. Typography & Hierarchy
- **Font fragmentation**:
  - Use exactly one unified, deliberate font family across the entire application (unless an explicit, documented monospace font is required for data/code).
  - Do not mix random display fonts in heroes with system/sans fonts elsewhere.
- **Arbitrary type scale**:
  - Headings must follow a strict modular type scale. Headings of the same level (e.g., H1, H2, H3) must maintain identical `font-size`, `line-height`, `letter-spacing`, and `font-weight` across every screen.
- **Bold weight overuse**:
  - Do not make every label and heading `font-bold` or oversized. Build hierarchy through placement, scale, and subtle tonal contrast rather than heavy weights everywhere.
- **Rhythm & readability**:
  - Do not center-align multi-line body text or long-form paragraphs. Keep readable content left-aligned.

---

### 4. Layout, Spacing & Spatial Rhythm
- **Generic "AI template" layouts**:
  - Avoid cookie-cutter landing page boilerplate: centered hero → three feature cards with icons → testimonials → CTA banner → footer. Tailor layouts to the exact user workflow and domain data.
- **Card-grid overuse**:
  - Do not force all data into uniform 3-column card grids. Use data tables, structured lists, side-by-side inspect panels, or dense master-detail views when appropriate.
- **Spacing inconsistency**:
  - Strict adherence to a 4px/8px spatial rhythm. Inconsistent paddings and margins (e.g., `p-4` on one card, `p-6` on the next, `p-5` on another) are forbidden.
- **Mismatched border radius**:
  - Do not mix border radii haphazardly (e.g., `rounded-lg`, `rounded-xl`, `rounded-2xl`, and `rounded-full` on peer elements). Standardize on a single, shared border-radius token.
- **Unanchored layouts**:
  - Eliminate elements that drift outside the primary grid system, random vertical gaps, and cramped micro-spacing alternating with giant empty dead-zones.

---

### 5. Components, Icons & Design System Tokens
- **Hardcoded arbitrary values**:
  - Never hardcode ad-hoc inline values (`text-[#7c3aed]`, `mt-[13px]`, `w-[317px]`). All colors, radii, and spacing must map to centralized design tokens / CSS variables.
- **Component divergence**:
  - The same component must not be implemented differently across screens (e.g., different button sizes/variants, differing modal layouts, custom checkboxes).
- **Default library styling**:
  - Do not leave raw, unmodified default styling from shadcn/ui or other UI libraries without contextual styling and refinement.
- **Icon spam & inconsistency**:
  - Do not place an icon next to every heading, list item, and button. Use icons only where they provide immediate semantic recognition or functional affordance.
  - Icons must share identical viewBox sizes, uniform stroke widths (e.g., fixed 1.5px or 2px), and matching optical weights.

---

### 6. Copy, Content & Marketing Clichés
- **Emoji clutter**:
  - Never use emojis (🚀, ✨, 💡, 🔥, ⚡) in navigation, headings, badges, or buttons.
- **Generic AI marketing fluff**:
  - Strictly banned copy phrases:
    - *"Unlock your potential"*
    - *"Supercharge your workflow"*
    - *"Seamless experience"*
    - *"Built for the future"*
    - *"✨ AI-powered"* (applied as a generic decoration badge)
- **Fake social proof & dummy statistics**:
  - No synthetic stats ("10K+ users", "99.9% uptime") or placeholder partner logos unless real production data is provided.
- **Formulaic feature cards**:
  - Avoid repetitive cards consisting exclusively of: [single generic icon] + [1-word buzzword title] + [1 generic sentence].

---

### 7. Completeness, States & Accessibility
- **Happy-path-only design**:
  - Every UI feature must explicitly design and handle all 4 core states:
    1. **Default / Populated state**
    2. **Loading / Skeleton state**
    3. **Empty state** (with helpful, actionable guidance)
    4. **Error state** (with clear recovery actions)
- **Interactive state omissions**:
  - Interactive controls must provide clear, accessible hover, active, and keyboard focus rings (`focus-visible:ring-2`).
  - Disabled controls must look noticeably attenuated and specify `aria-disabled="true"`.
- **Responsive fidelity**:
  - Layouts must be tested across mobile, tablet, and desktop breakpoints without horizontal scrollbars, truncated touch targets, or broken flex wrapping.

---

### QUICK QUALITY AUDIT
Before approving any interface, perform this 3-step check:
1. **The Consistency Test**: Inspect any 3 buttons, 3 cards, and 3 headings across multiple pages. Are their radii, paddings, and font sizes 100% token-consistent?
2. **The Slop Test**: Are there decorative gradients, glowing blobs, emojis, or AI buzzwords? If so, remove them.
3. **The Subtraction Test**: Does every decorative border, shadow, and icon serve a clear information-hierarchy or usability purpose? If not, strip it out.