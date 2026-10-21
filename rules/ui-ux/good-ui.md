<!-- ==============================================================================
     SYSTEM PROMPT / DIRECTIVE: PROFESSIONAL UI/UX ENGINEERING MANDATE
     Use this prompt header to enforce gold-standard, production-grade UI design.
     ============================================================================== -->

> ### 🏛️ UI/UX System Directive: High-Craft Production Engineering
> **Mandate**: When designing or implementing user interfaces, you must adhere strictly to the engineering rules, token scales, and constraints documented below. You are forbidden from building superficial "vibecoded" mockups. Every decision must be token-backed, accessible, hierarchical, and complete across all states.
> 
> **Core Operating Directives**:
> 1. **Order of Execution**: Work strictly in sequence: Tasks & Data Content → Grayscale Wireframe Hierarchy → Design Tokens → Reusable Components → Screen Assembly → Complete State Matrix (Empty, Loading, Error, Overflow) → Functional Polish.
> 2. **Token Law**: Never use arbitrary inline values (`mt-[13px]`, `text-[#...]`). If the token scale lacks a value, either formalize it in the system tokens or adjust the layout.
> 3. **The Grayscale Rule**: Layout and hierarchy must function in pure monochrome before any color is applied. Color is strictly for semantic status, selection, or primary action—never to rescue weak hierarchy.
> 4. **Restraint Over Decoration**: Zero unmotivated glassmorphism, glowing blobs, animated border sweeps, or arbitrary card hover lifts. Every decorative flourish must have a functional, articulable purpose.
> 5. **Complete State Coverage**: No component or screen is complete until Default, Loading (skeleton), Empty (actionable), Error (recovery-oriented), and Disabled states are fully specified.
> 6. **Full Keyboard & Accessible Navigation**: Native semantic elements only (`<button>`, `<a>`, `<input>`), explicit visible focus rings (`focus-visible:ring-2`), WCAG AA text contrast (4.5:1), and responsive verification down to 360px viewport width.
>
> *(Refer to the exhaustive guide and checklist below for exact token scales, CSS properties, layout geometry, component specifications, and audit criteria.)*

---

# Professional UI Design — In-Depth Guide

Oct 21, 2026 · @Chief

## What professional actually means

Professional UI is not a style. It is a small set of decisions made once, written down, and applied everywhere without exception. Gradients, glass and animation have almost nothing to do with it.

**The uncomfortable truth.** About 80% of the work is invisible: tokens, alignment, states, edge cases, keyboard support. If you skip the system and polish screens one at a time, you rebuild the vibecoded look by hand.

A professional UI has five properties you can check:

- **Consistent.** The same thing looks and behaves the same on every screen.
- **Hierarchical.** The eye lands on the most important thing first, every time.
- **Complete.** Empty, loading, error and overflow states exist, not only the happy path.
- **Accessible.** It works with a keyboard, at 200% zoom and with sufficient contrast.
- **Restrained.** Every decoration has a reason you can say out loud.

**Confidence tags used in this guide**

| Tag | Meaning |
| --- | --- |
| \[Certain\] | A published standard or verifiable fact (WCAG, CSS behaviour) |
| \[Likely\] | Strong, widely shared practice from mature design systems |
| \[Guessing\] | My judgment or a rough threshold; adjust to your product |

Untagged rules in this guide are \[Likely\].

## Process: work in this order

Most bad UIs start at step 5. Each step below has a deliverable; do not move on without it.

1. **Tasks and content.** List the user's jobs on this screen and the data each job needs. Deliverable: a plain-text list per screen, ranked by frequency.
   - Ask: what does the user do here most often? What must they never miss?
   - Use real data samples: the longest name, the biggest number, the empty case.
2. **Structure (grayscale wireframes).** No colour, no fonts, no icons. Decide primary, secondary and tertiary content and the one primary action. Deliverable: grayscale wireframes that work without any styling.
3. **System.** Define tokens for spacing, type, colour, radius, elevation and motion (sections below). Deliverable: a token file plus one page that renders every token.
4. **Components.** Build primitives with every variant and state. Deliverable: a component gallery (Storybook or a kitchen-sink page).
5. **Screens.** Assemble from components only. Any one-off style is a defect. Deliverable: screens with zero arbitrary values.
6. **States.** Design empty, loading, error, partial, overflow and permission states for every screen. Deliverable: a state matrix per screen.
7. **Polish.** Add motion and micro-interactions last, only where they explain a change. Deliverable: a short list of motions, each with its reason.

**The rule that holds this together:** when a screen needs a value the system lacks, either add it to the system on purpose or change the screen. Never hardcode it.

**Grayscale test.** \[Likely\] If the wireframe from step 2 is not usable, colour will not save it. Colour should add meaning (status, selection, primary action), never create the hierarchy.

## Spacing and layout system

Use a 4px base and a fixed scale; every margin, padding and gap must come from it.

**Scale (px):** 0, 2, 4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 80, 96. Below 24 the steps are fine; above 24 they grow roughly 1.5x, because small differences between large gaps are invisible.

| Token | Value | Typical use |
| --- | --- | --- |
| space-1 | 4px | Icon to label, label to its input |
| space-2 | 8px | Inside compact controls, between tight list items |
| space-3 | 12px | Button horizontal padding (small), chip gaps |
| space-4 | 16px | Card padding (compact), field to field |
| space-6 | 24px | Card padding (default), between related groups |
| space-8 | 32px | Between sections inside a page |
| space-12 | 48px | Between major page regions |
| space-16+ | 64-96px | Marketing section rhythm only |

**Proximity rule.** Space inside a group must be clearly smaller than space between groups, ideally by a factor of 2 or more. Label 4-8px from its input, field 16-24px from the next field, section 32-48px from the next section. \[Likely\] Violating this is the most common reason a layout feels "off" without anyone being able to say why.

**Containers.** Pick two or three max widths and nothing else:

- Reading width: about 680-720px (prose, forms, settings).
- App content: about 1200-1280px.
- Full-bleed: tables and dashboards that genuinely need the width.

**Grid.** A 12-column grid with 24px gutters on desktop, 16px on mobile, is enough for almost everything. \[Likely\] What matters more than the grid is having few distinct left edges: count the x-positions where content starts; fewer is calmer.

**Page rhythm.** Use the same vertical gap between equivalent sections everywhere. A page header, then 24-32px, then filters, then 16px, then content is a pattern; repeat it on every list page.

**Common mistakes**

- Equal spacing everywhere, so groups dissolve.
- Padding that differs between cards of the same kind.
- Using borders to separate things that spacing alone would separate.
- Arbitrary values (13px, 18px) introduced to "make it fit"; fix the layout instead.

## Typography system

One family, one size scale, three weights and three text colours cover almost every product UI.

**Family.** \[Likely\] One sans-serif for everything; add a monospace only for code, IDs and logs. Inter, Geist, IBM Plex Sans, Source Sans 3 or the system stack are all solid. The choice matters far less than using it everywhere, including modals, toasts and dropdowns that render in portals.

**Size scale (app UI)**

| Token | Size / line-height | Weight | Use |
| --- | --- | --- | --- |
| text-xs | 12 / 16px | 500 | Captions, table meta, badges |
| text-sm | 14 / 20px | 400-500 | Default app body, labels, table cells |
| text-base | 16 / 24px | 400 | Long-form body, forms on mobile |
| text-lg | 18 / 28px | 600 | Card and section titles |
| text-xl | 20 / 28px | 600 | Page subsections |
| text-2xl | 24 / 32px | 600 | Page titles |
| text-3xl | 30 / 36px | 600 | Rare: dashboard hero numbers |

Marketing pages may add 36, 48 and 60px for heroes. \[Guessing\] An app that uses more than 7 sizes almost always has drift.

**Weights.** 400 for reading, 500 for UI labels and buttons, 600 for headings. \[Likely\] Avoid 700-900 in app UI; they look heavy at small sizes and flatten hierarchy when everything is bold.

**Line-height and measure.** Body around 1.5, headings 1.2-1.3, and tighten letter-spacing slightly (-0.01 to -0.02em) only on large headings. Keep reading text at roughly 60-80 characters per line; use `max-width: 65ch` for prose.

**Text colours.** Exactly three: primary (headings, values), secondary (labels, meta, help text) and disabled. Links and errors use semantic colours from the colour system.

**Hierarchy through type, in order of preference**

1. Colour (primary vs secondary text)
2. Weight (400 vs 500/600)
3. Size, only when the first two are not enough
4. Case and spacing (small uppercase overlines), sparingly

**Numbers.** \[Certain\] `font-variant-numeric: tabular-nums` makes every digit the same width so columns of numbers align. Use it in tables, dashboards, timers and prices.

**Common mistakes**

- Heading sizes that differ for the same level on different pages.
- Centred paragraphs longer than two lines.
- Grey text that fails contrast because it "looks elegant".
- Emphasis by bold, italic, colour and size all at once.

## Color system

Neutrals do most of the work; one primary marks action and selection; four semantic colours carry status. Everything else is drift.

**1. Neutral ramp.** 11 steps from 50 (near white) to 950 (near black), slightly tinted (cool grey, warm grey or a hint of the brand hue) rather than pure grey. \[Likely\] Neutrals cover text, backgrounds, borders, dividers and most icons, roughly 80-90% of pixels in an app.

**2. Primary.** One hue with its own 50-950 ramp. Use it for the primary button, links, focus rings, selected/active states and progress. \[Likely\] If more than about 10% of a screen is primary-coloured, it has stopped signalling anything.

**3. Semantic colours.** Success (green), warning (amber), danger (red), info (blue or the primary). Each needs three roles:

| Role | Example (danger) | Use |
| --- | --- | --- |
| Subtle background | red-50 | Alert and badge backgrounds |
| Border | red-200 | Alert borders, error input border |
| Strong text / icon | red-600 or 700 | Error text, icons, destructive buttons |

**4. Role-based tokens.** Components never reference raw hues. They reference roles:

| Token | Light | Purpose |
| --- | --- | --- |
| --bg | white | Page background |
| --bg-subtle | neutral-50 | Sidebars, table headers, zebra rows |
| --surface | white | Cards, popovers |
| --surface-hover | neutral-100 | Row and item hover |
| --border | neutral-200 | Default borders, dividers |
| --border-strong | neutral-300 | Input borders |
| --text | neutral-900 | Primary text |
| --text-secondary | neutral-600 | Labels, meta |
| --text-disabled | neutral-400 | Disabled text |
| --primary / --primary-hover | brand-600 / 700 | Main action |
| --on-primary | white | Text on primary |
| --focus-ring | brand-500 | Focus outline |

Dark mode then becomes a second set of values for the same roles (see Dark mode).

**Contrast.** \[Certain\] WCAG 2.x AA requires 4.5:1 for normal text, 3:1 for large text (24px, or 18.66px bold) and 3:1 for UI component boundaries and meaningful icons. Check secondary text and placeholder text first; they fail most often.

**Never colour alone.** \[Certain\] WCAG 1.4.1 requires that colour is not the only way information is conveyed. Pair status colour with text or an icon.

**How to pick the primary.** Choose the hue from the brand, then pick the step (usually 600) that passes 4.5:1 with white text. Test it next to danger red; if they are hard to tell apart, shift one.

**Common mistakes**

- Several near-identical brand colours (indigo-500, violet-500, a custom hex) all used as "primary".
- Pure #000 text on pure #fff, which looks harsh; use neutral-900 on white.
- Coloured section backgrounds to create hierarchy instead of spacing and type.
- Gradients used as a default rather than a brand decision.

## Radius, borders, elevation and surfaces

Give radius and shadow a small number of values with fixed meanings; never pick them per component.

**Radius scale**

| Token | Value | Use |
| --- | --- | --- |
| radius-sm | 4px | Checkboxes, tags, small badges, table cells |
| radius-md | 6-8px | Buttons, inputs, selects, cards |
| radius-lg | 12px | Modals, popovers, large panels |
| radius-full | 9999px | Pills, avatars, toggles only |

&#91;Certain\] Nested corners look correct when inner radius = outer radius minus the padding between them. A 12px card with 8px padding needs a 4px inner image radius.

&#91;Likely\] Sharper radii (2-6px) read as serious and dense; larger radii (12-16px) read as friendly and consumer. Pick one personality and keep it.

**Separation, in order of preference**

1. Spacing
2. Background tint (--bg-subtle vs --surface)
3. A 1px border in --border
4. A shadow, only for things that float above the page

&#91;Likely\] Boxes inside boxes inside boxes is the clearest amateur signal in app UI. Before adding a border, try removing it and adding 8px more space.

**Elevation scale (meaning, not decoration)**

| Level | Shadow | Use |
| --- | --- | --- |
| 0 | none, border only | Cards and panels in the page flow |
| 1 | small, soft (0 1px 2px, \~5-8% opacity) | Sticky headers, raised buttons if any |
| 2 | medium (0 4px 12px, \~10%) | Dropdowns, popovers, tooltips |
| 3 | large (0 12px 32px, \~15%) | Modals, dialogs, command palettes |

Shadows are neutral (black or a dark neutral at low opacity), never coloured. In dark mode, raise elevation by making the surface lighter, because shadows barely show on dark backgrounds.

**Glass and blur.** Use `backdrop-filter: blur()` only where content actually scrolls behind the element (sticky nav, overlay over a busy page). \[Likely\] It costs GPU time and lowers text contrast, so it needs a functional reason.

## Motion and interaction feedback

Motion exists to explain a change of state; if it explains nothing, remove it.

**Durations and easing**

| Token | Duration | Easing | Use |
| --- | --- | --- | --- |
| motion-fast | 100-150ms | ease-out | Hover, press, colour changes |
| motion-base | 200ms | ease-out | Dropdowns, tooltips, toggles |
| motion-slow | 250-300ms | ease-in-out | Modals, drawers, page-level panels |

&#91;Likely\] Entering elements ease out (fast start, gentle stop); exiting elements can be slightly faster than entering ones. Anything over about 400ms in app UI feels sluggish.

**What deserves motion**

- Something appears or disappears (menu, modal, toast).
- Something moves between places (item reordered, drawer slides in).
- Feedback that an action registered (button press, save confirmation).
- Continuity during loading (skeleton shimmer, progress).

**What does not**

- Every section fading up on scroll.
- Hover lifts on non-clickable cards; motion implies interactivity.
- Looping or pulsing elements that do not represent live status.

**Feedback timing.** \[Likely\] Respond to any click within about 100ms (pressed state). If an action takes over about 1 second, show progress. Over about 10 seconds, show progress with an estimate or let the user leave and notify them.

**Reduced motion.** \[Certain\] `@media (prefers-reduced-motion: reduce)` lets you replace movement with simple fades or nothing. Honour it for anything larger than a colour change.

## Visual hierarchy techniques and tests

Hierarchy means the user's eye lands on the most important thing first without effort; you get it mostly by making other things quieter.

**Techniques**

1. **One primary action per view.** Other actions are secondary (outline or neutral) or tertiary (text or ghost). Destructive actions are never primary-coloured; they use danger styling and usually sit apart.
2. **De-emphasise instead of emphasise.** Turn labels, meta and help text to secondary colour before making the key item bigger.
3. **Values over labels.** In a detail view, "Active" (the value) should be more prominent than "Status" (the label).
4. **Group with proximity, then alignment, then containers.** Reach for a card or border only when spacing and alignment fail.
5. **Few left edges.** Align content to a small number of vertical lines. Centre only short standalone content (empty states, auth pages, marketing heroes).
6. **Reading pattern.** Put the page title and primary action at the top, filters next, content after. Users scan left to right and top to bottom in most locales; place the most important information where the scan starts.
7. **Size contrast with purpose.** If two adjacent headings differ by 2px, make them the same or differ clearly.

**Button hierarchy**

| Level | Style | Example |
| --- | --- | --- |
| Primary | Solid primary colour | Save, Create invoice |
| Secondary | Outline or neutral fill | Cancel, Export |
| Tertiary | Text or ghost | Learn more, Reset filters |
| Destructive | Solid or outline danger, often behind a confirm | Delete project |

**Tests you can run in seconds**

- **Squint test.** Blur the screenshot (or squint). You should still see the primary action, the main content area and the groups.
- **Grayscale test.** Desaturate the screen. If hierarchy disappears, it depended on colour.
- **Five-second test.** Show the screen to someone for five seconds and ask what the page is for and what they would click.
- **Remove test.** Delete one decorative element at a time. If nothing gets worse, leave it out.

## Component design

Build each component once, with every variant and state, and forbid screen-level restyling.

**Interactive states every control needs**

| State | What changes | Notes |
| --- | --- | --- |
| Default | Base style |  |
| Hover | Background or border one step darker | Pointer devices only; never the only cue |
| Focus-visible | 2px focus ring with 2px offset in --focus-ring | \[Certain\] Must be visible (WCAG 2.4.7) |
| Active / pressed | One more step darker, optional 1px shift | Confirms the click registered |
| Disabled | Reduced contrast, `cursor: not-allowed`, no hover | Explain why nearby or in a tooltip when not obvious |
| Loading | Spinner, keep width, block repeat clicks | Prevents double submits and layout jumps |
| Selected / checked | Primary colour plus a non-colour cue (check, weight) |  |

Inputs also need: placeholder (never as the label), filled, error (border plus message plus icon), read-only and with helper text.

**Size scale (shared across controls)**

| Size | Height | Horizontal padding | Font |
| --- | --- | --- | --- |
| sm | 32px | 12px | 14px |
| md | 36-40px | 16px | 14px |
| lg | 44-48px | 20px | 16px |

Buttons, inputs and selects of the same size share the same height so they align in a row.

**Component API.** \[Likely\] Expose a small, closed set of props instead of open styling:

- `variant`: primary | secondary | ghost | danger
- `size`: sm | md | lg
- `loading`, `disabled`, `icon`, `iconPosition`
- No `className` overrides for colour or spacing in product code (allow layout-only overrides such as width if needed).

In React, `class-variance-authority` (cva) with Radix primitives or a customised shadcn/ui is a solid base. Customise at least colour tokens, radius and the type scale so it stops looking default.

**Core component set for most apps:** Button, IconButton, Input, Textarea, Select, Combobox, Checkbox, Radio, Switch, Badge, Avatar, Card, Table, Tabs, Dropdown menu, Popover, Tooltip, Modal/Dialog, Drawer, Toast, Alert, Empty state, Skeleton, Pagination, Breadcrumb, Page header.

**Icons.** One icon set, one stroke width, two or three sizes (16, 20, 24px) tied to text sizes. Icon-only buttons need an accessible name (`aria-label`) and a tooltip.

**Gallery.** Render every component, variant and state on one page (Storybook or a /kitchen-sink route). Review it whenever a token changes; inconsistencies show up immediately.

## Screen states

Users spend much of their time in states the mockup never showed; designing them is the clearest single difference between professional and generated UI.

| State | Professional version | Common failure |
| --- | --- | --- |
| Empty, first use | Explains what will appear and offers the action that creates it, optionally with sample data or a short guide | Blank area or a bare "No data" |
| Empty, no results | Repeats the search or filter, offers "Clear filters" | Same message as first use, user thinks data is gone |
| Loading, first load | Skeleton that matches the final layout, so nothing jumps | Full-page spinner, then layout shift |
| Loading, refresh | Keep old content, show a subtle indicator | Content flashes to skeleton on every refresh |
| Action in progress | Button loading state, form disabled, optimistic update where safe | Double submits, no feedback |
| Error, page | Plain-language cause, what to do, a retry button, a reference ID for support | Raw exception or blank page |
| Error, partial | Failed widget shows its own error; the rest of the page works | One failure breaks everything |
| Error, field | Message under the field, says how to fix it | Toast saying "Invalid input" |
| Overflow | Long names truncate with a tooltip, large numbers abbreviate (1.2M), lists paginate or virtualise | Text overlaps, layout breaks |
| Permission | Action hidden or disabled with a reason; read-only view where useful | Button that errors after click |
| Offline / stale | Banner that data may be out of date, queued actions | Silent failure |
| Success | Inline confirmation or toast with an undo where possible | Nothing, so users repeat the action |

**Writing error messages.** Say what happened, why if known, and what to do next. "Couldn't save the invoice because the customer was deleted. Choose another customer and try again." beats "Error 409".

**State matrix.** For each screen, make a small grid: rows are regions (header, filters, list, detail), columns are states. Every cell needs a design or an explicit "not applicable".

**How to test.** Use DevTools network throttling (Slow 3G), block API requests, use an account with no data and one with 10,000 rows, and paste a 200-character name into every text field.

## Forms

Good forms are single-column, labelled above, validated inline and predictable about where the submit button is.

**Layout**

- &#91;Likely\] One column. Multi-column only for short, tightly related pairs (first and last name, city and postcode).
- Labels above the field, left-aligned. Placeholder text is an example, never the label; it disappears on typing.
- Field width hints at expected length: postcode short, address long.
- Group related fields under small section headings with 32px between groups.
- Primary submit at the bottom-left of the form (aligned with the fields) or in a sticky footer for long forms. Keep its position identical across all forms.

**Required and optional.** If most fields are required, mark only the optional ones ("Optional"). If most are optional, mark the required ones. Never rely on a red asterisk alone.

**Validation**

- Validate on blur, not on every keystroke; re-validate on change once a field has an error so the message clears as soon as it is fixed.
- Error message under the field, in danger text, with an icon, saying how to fix it.
- On submit with errors, scroll to and focus the first invalid field and show a summary at the top for long forms.
- &#91;Certain\] Connect messages to inputs with `aria-describedby` and set `aria-invalid="true"` so screen readers announce them.

**Input types and attributes.** Use the right `type` (email, tel, number, date), `inputmode` for mobile keyboards and `autocomplete` values so browsers can fill fields. \[Certain\] WCAG 2.2 adds 3.3.7 Redundant Entry: do not make users re-type information they already gave in the same process.

**Choosing controls**

| Choice | Control |
| --- | --- |
| 2-5 options, all visible | Radio group (single) or checkboxes (multiple) |
| On/off that applies immediately | Switch |
| On/off that applies on submit | Checkbox |
| 6-15 options | Select |
| Many options or searchable | Combobox with search |
| Dates | Date picker that also accepts typing |

**Long and multi-step forms.** Show progress (step 2 of 4), save drafts automatically, allow going back without losing data and show a review step before the final submit.

**Destructive submits.** Confirm with a dialog that names the object ("Delete project Apollo?"); for high-impact actions require typing the name.

## Tables and data-dense UI

In business software, density and scannability beat whitespace; most marketing-style design advice hurts here.

**Table anatomy**

- Header row: sticky, `--bg-subtle` background, 12-13px medium-weight secondary text, sort indicator on sortable columns.
- Rows: 36-44px default, 32px compact option. Hover tint on the whole row. Zebra striping only for very wide tables; otherwise use 1px row dividers.
- Cell padding: 12-16px horizontal; first and last columns align with the page content edge.

**Alignment rules**

| Content | Alignment | Extra |
| --- | --- | --- |
| Text, names | Left | Truncate with tooltip; never wrap the primary name column to 3 lines |
| Numbers, money | Right | \[Certain\] tabular-nums so digits line up; same decimals in a column |
| Dates | Left or right, consistent | One format across the app; relative ("2h ago") with absolute on hover |
| Status | Left | Badge with colour plus text |
| Actions | Right | Row menu (three dots) or icon buttons revealed on hover, always reachable by keyboard |

**Behaviour users expect:** sorting, filtering, column visibility, resizable or sensible fixed widths, bulk selection with a bulk-action bar, pagination or virtual scrolling for large sets, row click opens detail (with a real link so middle-click works), and preserved filter state in the URL.

**Filters.** Put common filters as visible controls above the table, advanced ones in a panel. Show active filters as removable chips with a "Clear all".

**Dashboards**

- Lead with 3-5 KPI cards: label, big number (tabular), change versus a stated period, and a small trend.
- Pick chart types by question: trend over time is a line, comparison across items is a sorted bar, part of whole is a stacked bar (avoid pies beyond 3-4 slices).
- Use one colour per series across all charts; highlight what matters and grey the rest.
- Every chart needs a title that states the takeaway, labelled axes with units and a visible time range.

**Detail pages.** Header with object name, status badge and primary action; key facts as a label/value grid (labels secondary, values primary); related data in tabs; activity log at the end.

**Consistent page anatomy.** \[Likely\] In an app with many modules, every list page and every detail page should share one template: title plus primary action top-right, filters, content, pagination. Users learn it once and reuse that knowledge everywhere. If screens are generated from configuration, the configuration should only select components, variants and fields, never pass raw styles.

## Navigation and page anatomy

Users should always know where they are, how they got there and how to get back; pick one navigation model and apply it everywhere.

**Choosing the model**

| Situation | Navigation |
| --- | --- |
| Up to about 5-7 top-level areas | Top bar or compact sidebar |
| Many modules or nested areas | Left sidebar with collapsible groups, plus search |
| Deep hierarchies | Sidebar plus breadcrumbs on every page below level 1 |
| Power users, large apps | Add a command palette (Ctrl/Cmd+K) |
| Mobile | Bottom tab bar (3-5 items) or a drawer |

**Sidebar rules.** Current item clearly selected (background plus weight, not colour alone). Group labels in small secondary text. Icons consistent in size and style, or none at all. Keep order stable; do not reorder by usage.

**Standard page anatomy**

1. Breadcrumbs (if nested)
2. Page header: title, optional description, primary action on the right, secondary actions in a menu
3. Tabs, if the object has sections
4. Filters or toolbar
5. Content
6. Pagination or footer actions

**URLs are part of navigation.** Every meaningful view (tab, filter set, selected record) should have a URL so it can be bookmarked, shared and opened in a new tab. Use real links (`<a href>`) for navigation, not click handlers on divs.

**Wayfinding details.** Page `<title>` matches the page header. Back from a detail page returns to the list with filters and scroll position preserved. Unsaved changes trigger a confirm before navigating away.

## Responsive design

Design the narrowest layout first; most desktop-first layouts break at 360-400px because they were never designed there.

**Breakpoints.** \[Likely\] Use content-driven breakpoints, but a common set works: 640px (large phone), 768px (tablet), 1024px (small laptop), 1280px (desktop), 1536px (wide). Test at 360px, 768px, 1280px and 1920px at minimum.

**Patterns by component**

| Component | Desktop | Mobile |
| --- | --- | --- |
| Sidebar nav | Persistent | Drawer or bottom tabs |
| Multi-column layout | Columns | Single column, priority order |
| Data table | Full table | Horizontal scroll inside its container, or card list with key fields; keep the primary column sticky |
| Filters | Visible toolbar | Button opening a sheet |
| Modal | Centred dialog | Full-screen sheet |
| Page actions | Buttons in header | Primary as sticky footer button, others in a menu |
| Hover-only actions | Revealed on hover | Always visible or in a row menu |

**Rules**

- &#91;Certain\] Never let the page body scroll horizontally; wide content scrolls inside its own `overflow-x: auto` container.
- &#91;Certain\] WCAG 1.4.10 Reflow: content must work at 320 CSS px wide without two-dimensional scrolling (data tables are an allowed exception).
- Touch targets at least 24x24px \[Certain, WCAG 2.5.8\]; aim for 44x44px \[Likely\] on touch devices.
- Use 16px input text on mobile; \[Likely\] smaller sizes trigger auto-zoom in iOS Safari.
- Respect safe areas on phones with `env(safe-area-inset-*)`.
- Use relative units and `clamp()` for fluid headings instead of many breakpoint overrides.

**Container queries.** \[Likely\] For components that appear in different widths (a card in a sidebar and in the main area), `@container` queries keep them correct without page-level breakpoints.

## Accessibility essentials

Accessibility is part of professional quality, not an add-on; most of it comes free if you use semantic HTML and well-built primitives.

**The checks that catch most problems**

| Check | Standard | How to test |
| --- | --- | --- |
| Text contrast 4.5:1 (3:1 large) | \[Certain\] WCAG 1.4.3 | DevTools contrast picker, axe |
| UI and icon contrast 3:1 | \[Certain\] WCAG 1.4.11 | Input borders, focus rings, icons |
| Everything works by keyboard | \[Certain\] WCAG 2.1.1 | Unplug the mouse; Tab, Shift+Tab, Enter, Space, Esc, arrows |
| Focus is visible | \[Certain\] WCAG 2.4.7 | Tab through every page |
| Focus not hidden by sticky elements | \[Certain\] WCAG 2.4.11 (2.2) | Tab near sticky headers and footers |
| Logical focus order | \[Certain\] WCAG 2.4.3 | Order follows visual reading order |
| Inputs have labels | \[Certain\] WCAG 1.3.1, 3.3.2 | Every input has a visible `<label>` |
| Images and icon buttons have text alternatives | \[Certain\] WCAG 1.1.1, 4.1.2 | `alt`, `aria-label` |
| Works at 200% zoom and 320px width | \[Certain\] WCAG 1.4.4, 1.4.10 | Browser zoom |
| Target size at least 24x24px | \[Certain\] WCAG 2.5.8 (2.2) | Inspect small icons and links |

**Semantics first.** Use `<button>` for actions, `<a>` for navigation, real headings in order (h1, h2, h3), `<table>` for tabular data and landmarks (`<nav>`, `<main>`, `<header>`). \[Likely\] Native elements give keyboard and screen-reader behaviour for free; ARIA is for gaps, not replacements.

**Complex widgets.** Menus, comboboxes, dialogs, tabs and date pickers have detailed keyboard patterns. Use proven primitives (Radix, React Aria, Headless UI) rather than building your own. Dialogs must trap focus, close on Esc and return focus to the trigger.

**Tooling.** Run axe DevTools or Lighthouse on every page, add `eslint-plugin-jsx-a11y` in React projects and test once with a real screen reader (VoiceOver on macOS, NVDA on Windows). \[Likely\] Automated tools catch only a portion of issues; keyboard testing catches much of the rest.

## Dark mode done properly

Dark mode is a second set of values for the same role tokens, designed deliberately; inverting colours produces a broken UI.

**Rules**

- **Not pure black.** \[Likely\] Use a very dark neutral (around #0a0a0b to #121214) for the page; pure black with white text causes halation and harsh contrast.
- **Elevation by lightness.** Each raised layer is slightly lighter: page, then surface, then popover. Shadows barely register on dark backgrounds.
- **Desaturate and lighten accents.** Saturated brand and status colours vibrate on dark backgrounds; use lighter, slightly less saturated steps (often 400-500 instead of 600).
- **Off-white text.** Primary text around neutral-50/100, secondary around neutral-400. Re-check every contrast pair; secondary text often fails.
- **Borders matter more.** With fewer shadows, subtle borders (neutral-800) define surfaces.
- **Images and charts.** Check logos, illustrations and chart colours; transparent PNGs with dark ink disappear.

**Example role values**

| Token | Light | Dark |
| --- | --- | --- |
| --bg | #ffffff | #0b0b0d |
| --surface | #ffffff | #16161a |
| --surface-raised | #ffffff | #1e1e23 |
| --border | #e4e4e7 | #2a2a30 |
| --text | #18181b | #f4f4f5 |
| --text-secondary | #52525b | #a1a1aa |
| --primary | #2563eb | #3b82f6 |

**Implementation.** Respect `prefers-color-scheme` by default and offer a manual Light / Dark / System setting. Set `color-scheme: light dark` so native controls and scrollbars match. Because components only use role tokens, no component code changes.

## Implementing and enforcing tokens in code

A design system only exists if the code makes off-system values hard to write and easy to catch in review.

**Token layers**

1. **Primitives:** the raw palette and scales (neutral-50...950, brand-600, space-4 = 16px). Never used directly by components.
2. **Semantic tokens:** roles (--text-secondary, --surface, --border, --primary). Components use only these.
3. **Component tokens (optional):** --button-height-md, --input-border. Useful in larger systems.

**CSS variables plus Tailwind v4.** \[Likely\] Tailwind v4 defines the theme in CSS with `@theme`; setting a namespace to `initial` removes the defaults so only your values exist:

```css
@import "tailwindcss";

@theme {
  --color-*: initial;            /* drop the default palette */
  --color-bg: var(--bg);
  --color-surface: var(--surface);
  --color-border: var(--border);
  --color-text: var(--text);
  --color-text-secondary: var(--text-secondary);
  --color-primary: var(--primary);
  --color-danger: var(--danger);
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 12px;
  --font-sans: "Inter", ui-sans-serif, system-ui, sans-serif;
}

:root { --bg: #fff; --surface: #fff; --border: #e4e4e7;
        --text: #18181b; --text-secondary: #52525b;
        --primary: #2563eb; --danger: #dc2626; }
.dark { --bg: #0b0b0d; --surface: #16161a; --border: #2a2a30;
        --text: #f4f4f5; --text-secondary: #a1a1aa;
        --primary: #3b82f6; --danger: #f87171; }
```

Now `bg-surface text-text-secondary border-border rounded-md` works and `bg-purple-500` does not exist. On Tailwind v3, do the same in `tailwind.config` under `theme` (not `extend`) so defaults are replaced.

**Enforcement**

- **Lint:** forbid arbitrary values (`text-[#...]`, `mt-[13px]`). \[Guessing\] Check that your Tailwind lint plugin version supports your Tailwind version; if not, a CI grep works.
- **CI grep (read-only check):**

```bash
# fail the build if arbitrary Tailwind values or raw hex colours appear in components
if grep -rEn '\[(#|[0-9]+px)' src/components src/app; then
  echo "Arbitrary values found; use tokens"; exit 1
fi
```

- **Stylelint** for plain CSS: disallow hex colours outside the token file.
- **Component boundary:** product code imports from `components/ui` only; restyling primitives in feature code is a review rejection.
- **Visual regression:** Storybook plus Chromatic, or Playwright screenshot tests on the component gallery, catches unintended visual drift.

**Token source of truth.** \[Likely\] If designers use Figma, keep tokens in one JSON (W3C Design Tokens format) and generate CSS with Style Dictionary, so design and code never diverge. For a small team, the CSS file above can be the source of truth.

## Using AI inside a design system

AI implements a system well and invents one badly, so you write the system and let AI fill screens within it.

**Give it the system, every time.** Put the token file, the component list with their props and the page templates into project instructions or a rules file the tool always reads (for example `CLAUDE.md` or an equivalent rules file).

**Prompt with constraints, not adjectives**

| Weak prompt | Strong prompt |
| --- | --- |
| "Make a modern, premium invoices page" | "Build the invoices list using the ListPage template. Use only components from components/ui. Columns: number, customer, amount (right-aligned, tabular), due date, status badge. Include empty, loading (skeleton), error and no-results states. No arbitrary Tailwind values." |
| "Make it look better" | "Reduce visual noise: remove borders where spacing separates groups, set labels to text-secondary, keep one primary button." |
| "Add a nice hero" | "Hero: page title text-2xl, one sentence of description in text-secondary, primary action on the right. No gradients, no blur, no animation." |

**Explicitly ban the defaults it reaches for:** gradients, glassmorphism, emoji in UI text, hover lift on non-clickable cards, scroll fade-ins, generic marketing copy, new colours or font sizes outside the tokens.

**Review loop**

1. Generate one screen.
2. Run the review checklist (last section) and the CI grep.
3. Feed specific violations back ("padding on the summary card is p-5; the scale says p-6 for cards").
4. Once a screen is correct, use it as the reference example for the next prompt.

**What stays human.** Deciding the tasks and content of each screen, the hierarchy, the token values and what to remove. Those are judgment calls; delegating them is how you get the generic look.

## Developing taste

Rules get you to competent; taste comes from studying good work closely and copying it until you can explain every choice.

**References worth studying**

| Type | Examples | What to learn |
| --- | --- | --- |
| Design systems (documented) | GitHub Primer, IBM Carbon, Atlassian Design System, Shopify Polaris, Material 3, Radix Themes | Tokens, component states, density, the reasons behind rules |
| Products | Linear, Stripe Dashboard, Vercel, GitHub, Notion, Figma | Restraint, hierarchy, consistency across many screens |
| Books | *Refactoring UI* (Wathan and Schoger), *Don't Make Me Think* (Krug), *The Design of Everyday Things* (Norman) | Practical visual fixes; usability; mental models |
| Pattern libraries | Mobbin, Page Flows | How real products solve the same screen |

&#91;Likely\] Avoid Dribbble-style shots as references for product UI; they optimise for a screenshot, not for daily use.

**Exercises (in order)**

1. **Measure, don't admire.** Open a Linear or Stripe screen in DevTools and write down every font size, weight, colour, padding and radius. You will usually find a small, consistent set.
2. **Pixel copy.** Rebuild one of their screens exactly. Compare screenshots side by side and fix differences until they match.
3. **Redesign your own screen.** Apply only the rules from this guide: proximity, three text colours, one primary action, remove borders. Compare before and after.
4. **State drill.** Pick one screen and design all its states from the state matrix.
5. **Constraint drill.** Design a screen in grayscale only, then with one accent colour only.

**Critique method.** When reviewing any screen, go in this order and stop at the first failure: Is the purpose clear in five seconds? Is there one obvious primary action? Are groups clear from spacing alone? Is everything on-system? Are states covered? Does it work by keyboard and on mobile? Only then discuss aesthetics.

**Side-by-side review.** \[Likely\] Put all screens of the app on one canvas at small size. Inconsistencies in spacing, headings and buttons are obvious there and invisible page by page.

## Pre-merge review checklist

Run this on every new or changed screen before it merges.

**System**

- [ ] No arbitrary values; every colour, size, space, radius and shadow comes from tokens
- [ ] Only shared components used; no restyled primitives in feature code
- [ ] Same component looks identical to its use on other screens

**Hierarchy and layout**

- [ ] One primary action per view; destructive actions styled as danger
- [ ] Spacing inside groups is clearly smaller than between groups
- [ ] Labels and meta in secondary text; values in primary text
- [ ] Few left edges; nothing centred that should be read or scanned
- [ ] Squint and grayscale tests pass

**Typography**

- [ ] Heading sizes match the same levels on other pages
- [ ] Numbers in tables and dashboards use tabular figures
- [ ] Prose lines under about 80 characters

**States**

- [ ] Empty (first use and no results), loading, error, partial error and overflow designed
- [ ] Buttons show loading and prevent double submit
- [ ] Errors explain what happened and what to do

**Accessibility**

- [ ] Text contrast at least 4.5:1, UI contrast at least 3:1
- [ ] Fully usable by keyboard, with visible focus
- [ ] Inputs labelled, icon buttons named, images have alt text
- [ ] Works at 200% zoom

**Responsive**

- [ ] Works at 360px with no page-level horizontal scroll
- [ ] Touch targets at least 24px (44px preferred on touch)
- [ ] Hover-only actions reachable on touch

**Restraint**

- [ ] Every gradient, blur, shadow, animation and icon has a stated reason
- [ ] Copy is specific to this product; no filler phrases or emoji in UI text
- [ ] Removing any one decoration would make the screen worse; if not, remove it