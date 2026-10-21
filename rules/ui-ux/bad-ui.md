# STRICT UI/UX DIRECTIVE: FORBIDDEN ANTI-PATTERNS, VERIFICATION & ZERO-AI-SLOP POLICY

> **MANDATE**: This document defines strictly prohibited UI/UX anti-patterns, how to verify them, when they are legitimate (avoiding false positives), and a concrete audit rubric. Designs violating these directives will fail automated checks and review. Every design choice must be deliberate, consistent, functional, and backed by a design system.

---

## Why Vibecoded / AI-Slop UIs Look the Way They Do

Understanding the root causes helps spot symptoms before they slip into production:
1. **Model Statistical Averaging**: Output is the statistical median of Tailwind and shadcn landing pages from 2022–2025 (purple gradients, glass cards, centered heroes, Inter).
2. **Screen-by-Screen Prompting**: Prompts generate screens in isolation without design system context. Each screen looks plausible alone, but globally the system drifts into chaos.
3. **Decoration Over Hierarchy**: Vague prompts ("make it modern/premium") trigger glow, blur, gradients, and animations because they are cheap visual tricks. Real design solves this with spacing, typography, and contrast.

---

## 1. Color System & Gradients

| Symptom | Verification Method | Legitimate When (Exceptions) |
|---|---|---|
| **Purple→blue, pink→orange, cyan→violet gradients** on hero, cards, buttons, borders | Search code: `grep -rE '(from|via|to)-(purple|indigo|pink|cyan|violet)' src` | The brand itself is an established gradient used identically across all surfaces. |
| **Gradient/clipped text** on headings (`bg-clip-text text-transparent`) | Check for `bg-clip-text` or `text-transparent` in headings | Used on exactly one specific hero word deliberately, never scattered across sections. |
| **Blurred color blobs** behind content (`absolute`, `blur-3xl`, `opacity-30` divs) | Inspect empty absolutely-positioned ambient background divs | A single deliberate ambient background canvas for dark mode illumination. |
| **Near-duplicate color drift** (`#6366f1`, `#6d63f0`, `indigo-500`, `violet-500` mixed) | Run console style extractor (below) and count unique color tokens | **Never legitimate.** This is unmanaged color drift. |
| **No clear primary action color** (3–4 competing accents) | Check: "What color is the primary CTA?" Every screen must have the same answer | — |
| **Inconsistent status colors** (different shades of green/red/amber across screens) | Compare error toast vs. error input ring vs. error badge | — |
| **Inverted dark mode** or partial `dark:` adoption (leaving white cards on dark pages) | Toggle dark mode; look for contrast anomalies or hard inverted colors | Dark elevation scale intentionally defined with slate/zinc tokens. |
| **Low-contrast gray text on gray backgrounds** | Run automated contrast checker; WCAG AA requires 4.5:1 for body copy | — |
| **Hardcoded hex values instead of tokens** (`text-[#7c3aed]`, `bg-[#0f172a]`) | `grep -rE 'text-\[#|bg-\[#|#[0-9a-fA-F]{6}' src` | One-off bespoke marketing illustration/canvas only. |

---

## 2. Effects: Glassmorphism, Shadows, Glow & Motion

| Symptom | Verification Method | Legitimate When (Exceptions) |
|---|---|---|
| **Gratuitous glassmorphism**: `backdrop-blur` on cards over flat, solid backgrounds | Remove `backdrop-blur` in DevTools. If nothing changes visually, it's useless decoration | Real content scrolls behind (e.g. sticky nav bar over text, modal backdrop). |
| **Mixed glass and solid cards** on the exact same surface | Visual inspection of sibling card components | — |
| **Semi-transparent borders everywhere** (`border-white/10`, `border-white/20`) | `grep -rE 'border-(white|black)/[0-9]+' src` | Part of a standardized, tokenized dark theme border system. |
| **Shadow bloat & colored shadows** (`shadow-purple-500/50`) | Extract unique `box-shadow` values via console script | Standardized elevation scale of 3–5 neutral levels used consistently. |
| **Glow effects** on buttons and cards (`shadow-[0_0_20px_...]`) | `grep -rE 'shadow-\[0_0_' src` | Game or Web3 interfaces where glow is a defined brand aesthetic. |
| **Interactive effects on non-interactive cards** (hover lift/scale on static containers) | Hover cards without click handlers. If it moves, it's lying about interactivity | Card is an active link or button (`cursor-pointer` + click event). |
| **Animation spam**: scroll fade-ins, bouncing icons, pulsing badges, typewriter text | Inspect scroll behavior. Check for pervasive `framer-motion` or `animate-` | Meaningful functional motion (view transitions, collapsible accordions). |
| **Animated borders / "shine" sweeps** across buttons or containers | Look for looping CSS keyframe shines and rotating border gradients | — |
| **Missing `prefers-reduced-motion`** | `grep -rE 'prefers-reduced-motion|motion-reduce' src` | Every animation must respect reduced-motion user preferences. |

---

## 3. Typography & Hierarchy

| Symptom | Verification Method | Legitimate When (Exceptions) |
|---|---|---|
| **Inconsistent font families** (Inter here, System UI there, random display font in hero) | Count unique `font-family` declarations | Maximum 2 families: 1 sans (body/UI) and 1 monospace (data/code). |
| **Font loaded but skipped in portals** (modals/toasts falling back to System UI) | Inspect portal-rendered DOM nodes (dialogs, tooltips, toasts) | — |
| **No type scale discipline** (H2 is `text-3xl` on one page and `text-4xl` on another) | Compare H1, H2, and H3 sizes across 5 distinct routes | — |
| **Arbitrary font sizes** (`text-[15px]`, `text-[17px]`, `text-[22px]`) | `grep -rE 'text-\[[0-9]+px\]' src` | — |
| **Weight overload** (using 400, 500, 600, 700, 800 all together) | Count unique `font-weight` tokens | 2–3 weights max (e.g. 400 regular, 500 medium, 600 semibold). |
| **Oversized hero headings** (`text-6xl`/`7xl`) for utility or internal screens | Visual inspection of heading size vs. information density | High-impact top marketing landing page only. |
| **Inconsistent line-height / letter-spacing** (`tracking-tight` applied randomly) | Check heading typography tokens across files | — |
| **Excessive line length** (>90 characters) or centered paragraphs | Measure character count per line and body text alignment | Short, 1–2 sentence marketing summaries (never body paragraphs). |
| **Broken mobile type scaling** (text sizes don't scale down on mobile) | Test at 360px viewport width | — |

---

## 4. Spacing, Radius & Layout

| Symptom | Verification Method | Legitimate When (Exceptions) |
|---|---|---|
| **Padding drift** (same card variant uses `p-4`, `p-5`, `p-6`, `p-8`) | `grep -rhoE '\bp-[0-9]+' src \| sort \| uniq -c` | — |
| **Mixed border radius** (`rounded-md`, `-lg`, `-xl`, `-2xl`, `-full` on peers) | `grep -rhoE 'rounded(-[a-z0-9]+)?' src \| sort \| uniq -c` | Defined token roles (e.g. `rounded-md` for inputs, `rounded-xl` for cards). |
| **Nested radius mismatch** (inner card corner radius >= parent corner radius) | Inspect nested panels/images inside rounded cards | Inner radius mathematically matches: `R_inner = R_outer - padding`. |
| **Arbitrary spacing** (`mt-[13px]`, `gap-[18px]`, `p-[19px]`) | `grep -rE '(m\|p\|gap\|space)[trblxy]?-\[' src` | — |
| **Cookie-cutter AI landing template** (centered hero → logos → 3 feature cards → testimonials → 3 pricing tiers with middle "Popular" → FAQ → CTA → footer) | Structural page outline review | Generic marketing sites where layout directly matches content requirements. |
| **Centered body text** (everything centered, hindering readability) | Visual check: text blocks must be left-aligned for scanning | Hero kicker and headline only. |
| **Card-grid obsession** (forcing tables/lists into 3-column cards) | Evaluate data density: tables or split views used for comparative data | Browsing heterogeneous, visual catalog items. |
| **Uneven section rhythm** (`py-24` then `py-10` then `py-32`) | `grep -rE 'py-[0-9]+' src` on section containers | — |
| **Mismatched container widths** (`max-w-7xl` in one section, `max-w-5xl` in next) | `grep -rE 'max-w-[a-z0-9]+' src` | Full-width media breakout sections. |
| **Unaligned grid edges** (elements drifting without shared grid alignment) | DevTools grid inspection / left-edge guides | — |

---

## 5. Components & Icons

| Symptom | Verification Method | Legitimate When (Exceptions) |
|---|---|---|
| **Unmodified library styling** (default shadcn zinc/slate palette, default borders) | Compare against library base documentation | Internal tools where default theme is explicitly accepted. |
| **Duplicate component implementations** (two `<Button>` components, duplicate modals) | `grep -rl '<button' src` vs. shared component import | — |
| **Inconsistent button metrics** (varying heights, paddings, and font sizes across pages) | Measure computed button heights across screens | Explicit small/medium/large button variant tokens. |
| **Badge / pill overload** ("New", "Beta", "Pro", "✨ AI-powered" everywhere) | Count badge elements per view | Critical status flags on active system jobs. |
| **Icon spam** (icon on every heading, table header, button, and bullet) | Count icon count vs. text ratio | Nav menus and toolbars where icons aid quick scanning. |
| **Mixed icon sets & stroke weights** (Lucide + Heroicons + FontAwesome, mixed strokes) | Inspect SVG `stroke-width` and viewBox | — |
| **Fake metrics & social proof** ("10K+ users", "99.9% uptime", placeholder logos) | Verify source data with stakeholders | Production analytics and verifiable customer logos. |
| **Formulaic feature cards** (uniform: [1 icon] + [3-word title] + [1 generic sentence]) | Content review of feature grids | — |

---

## 6. Copy, Voice & Placeholder Residue

- **Generic AI Marketing Fluff (Strictly Banned Phrases)**:
  - *"Unlock your potential"*, *"Supercharge your workflow"*, *"Seamless experience"*, *"Effortless"*, *"Elevate"*, *"Empower"*, *"Next-generation"*, *"Built for the modern..."*, *"Your all-in-one..."*, *"Say goodbye to..."*.
- **Emoji Pollution**: Never place emojis (🚀, ✨, 💡, 🔥, ⚡) in headers, buttons, tabs, or badges.
- **Buzzword Triplets**: Avoid empty 3-word slogans ("Fast. Secure. Scalable.").
- **The Competitor Swap Test**: Swap a competitor's name into your copy. If the sentence still works without edits, it says nothing and must be rewritten with concrete product capabilities.
- **Raw / Default Error Messages**: Never show `Something went wrong` or expose raw stack traces (`TypeError: Cannot read properties of undefined`). Provide actionable error resolution copy.
- **Placeholder Residue**: Zero tolerance for "Lorem ipsum", "John Doe", "example@email.com", "Your Company", or `href="#"` links.

---

## 7. States, Behavior & Accessibility

| Symptom | Verification Method |
|---|---|
| **Missing empty states** (blank white card when no data exists) | Wipe / mock empty array response in local storage or API |
| **Missing loading states / layout shift** (page jumps abruptly when data arrives) | Throttle network to Slow 3G; verify skeletons reserve exact dimensions |
| **Missing error states** (network error fails silently or crashes page) | Block API response in DevTools network tab |
| **Missing keyboard focus rings** (hover styles exist, but no `focus-visible`) | Tab through entire UI using keyboard alone |
| **Ambiguous disabled states** (disabled buttons looking clickable or vice versa) | Submit invalid inputs; verify clear visual attenuation and `aria-disabled` |
| **Missing inline form validation** (relying only on browser defaults or generic toasts) | Submit invalid inputs to forms |
| **Mobile breakage** (horizontal overflow, cramped targets, modals taller than screen) | Test at 360px viewport width |
| **Clickable `div` elements** instead of native `<button>` or `<a>` | `grep -rE '<div[^>]+onClick' src` |
| **Missing accessible labels** (unlabelled icon buttons, missing input labels, missing `alt`) | Run Lighthouse Accessibility Audit |

---

## 8. Code-Level Architecture Tells Behind the UI

Visuals can be faked, but codebase forensics reveal whether an interface is maintained:
- **Long repeated utility strings**: 50+ character Tailwind strings copy-pasted across multiple files instead of extracted into modular UI primitives.
- **Styling schizophrenia**: Inline `style={{}}` mixed with Tailwind classes mixed with CSS modules in the same project.
- **Empty theme configuration**: `tailwind.config` has no customized tokens (colors, spacing, typography), yet the codebase is riddled with arbitrary `[#...]` and `mt-[...]` brackets.
- **Bloated monolithic files**: 300–600 line components containing repeated copies of identical markup.
- **Unused imports & dead variants**: Orphaned icon imports and dead class variants left behind from discarded prompt runs.

---

## How to Audit: 20-Minute Verification Procedure

### Step 1: Extract Real Computed Styles from Live UI
Open browser console on 4–5 key routes and run:
```js
const props = ['font-family','font-size','font-weight','line-height','color',
  'background-color','border-radius','box-shadow','padding','backdrop-filter'];
const counts = {};
document.querySelectorAll('body *').forEach(el => {
  const cs = getComputedStyle(el);
  props.forEach(p => {
    const v = cs.getPropertyValue(p);
    (counts[p] ??= new Map()).set(v, (counts[p].get(v) || 0) + 1);
  });
});
for (const p of props) {
  console.log(p, counts[p].size, [...counts[p]].sort((a,b)=>b[1]-a[1]).slice(0,12));
}
```

### Step 2: Compare Against System Thresholds
| Property | Disciplined System | Suspicious (Unmanaged Slop) |
|---|---|---|
| `font-family` | 1–2 | 3+ |
| `font-size` | 6–10 | 15+ |
| `font-weight` | 2–4 | 5+ |
| `border-radius` | 3–5 | 8+ |
| `box-shadow` | 3–6 | 10+ |
| Distinct text colors | 5–8 | 15+ |
| `backdrop-filter` | 0–2 purposeful surfaces | On standard cards |

### Step 3: Run Codebase Grep Checks
```bash
# Check border radius drift
grep -rhoE 'rounded(-[a-z0-9]+)?' src | sort | uniq -c | sort -rn

# Check arbitrary inline overrides
grep -rhoE '\[[#0-9][^]]*\]' src | sort | uniq -c | sort -rn | head -40

# Check gradient spam
grep -rhoE '(from|via|to)-[a-z]+-[0-9]+' src | sort | uniq -c | sort -rn

# Check backdrop-blur count
grep -rc 'backdrop-blur' src | grep -v ':0'

# Check clickable non-semantic divs
grep -rnE '<div[^>]+onClick' src
```

### Step 4: Run the One-Property Consistency Test
Inspect:
1. Primary button height
2. Card interior padding
3. Card corner radius
4. H2 heading size

Check each across 5 routes. If more than 2 distinct values exist for any property, the design system lacks ownership.

### Step 5: Run the State & Accessibility Test
- Force **empty**, **loading** (Slow 3G), and **error** (offline/blocked) states.
- Resize viewport to **360px width** (verify touch targets & modal sizing).
- Tab through using **keyboard only** (verify `focus-visible` indicators).

---

## Scoring & Risk Rubric

- **Low Weight (Stylistic cliches)**: Gradients, glass, Inter font, emojis, template layout.
- **Medium Weight (Sloppy execution)**: Generic copy, fake metrics, icon spam, uncontrolled animations, uncustomized shadcn defaults.
- **High Weight (Architectural failure - unowned system)**: Cross-screen token drift, duplicate component implementations, arbitrary Tailwind overrides with an empty config.
- **Highest Weight (Operational & business risk)**: Missing loading/empty/error states, broken mobile layouts, non-accessible keyboard and focus support.

> **Principle of Ownership**: This directive does not merely evaluate whether an AI assisted in authoring code. It measures **whether an engineering team actively owns and enforces the design system**. Unowned design systems will not be approved.