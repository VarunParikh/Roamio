---
name: Neo-Minimalist Travel & Ledger
colors:
  surface: '#fbf8ff'
  surface-dim: '#dad9e3'
  surface-bright: '#fbf8ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f4f2fd'
  surface-container: '#eeedf7'
  surface-container-high: '#e8e7f1'
  surface-container-highest: '#e3e1ec'
  on-surface: '#1a1b22'
  on-surface-variant: '#45474b'
  inverse-surface: '#2f3038'
  inverse-on-surface: '#f1effa'
  outline: '#76777b'
  outline-variant: '#c6c6cb'
  surface-tint: '#5d5e63'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#1a1c20'
  on-primary-container: '#828489'
  inverse-primary: '#c6c6cc'
  secondary: '#0051d5'
  on-secondary: '#ffffff'
  secondary-container: '#316bf3'
  on-secondary-container: '#fefcff'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#171e00'
  on-tertiary-container: '#758d00'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e2e2e8'
  primary-fixed-dim: '#c6c6cc'
  on-primary-fixed: '#1a1c20'
  on-primary-fixed-variant: '#45474b'
  secondary-fixed: '#dbe1ff'
  secondary-fixed-dim: '#b4c5ff'
  on-secondary-fixed: '#00174b'
  on-secondary-fixed-variant: '#003ea8'
  tertiary-fixed: '#caf300'
  tertiary-fixed-dim: '#b0d500'
  on-tertiary-fixed: '#171e00'
  on-tertiary-fixed-variant: '#3e4c00'
  background: '#fbf8ff'
  on-background: '#1a1b22'
  surface-variant: '#e3e1ec'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 48px
    fontWeight: '800'
    lineHeight: 52px
    letterSpacing: -0.04em
  display-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 36px
    fontWeight: '800'
    lineHeight: 40px
    letterSpacing: -0.035em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 38px
    letterSpacing: -0.03em
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.025em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 28px
    letterSpacing: -0.02em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.015em
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: -0.01em
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.01em
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: -0.01em
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.04em
  numeric-split:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '800'
    lineHeight: 28px
    letterSpacing: -0.03em
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-tablet: 1.5rem
  gutter-desktop: 2rem
  margin: 1rem
  margin-tablet: 2rem
  margin-desktop: 3rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style

This design system expresses a stripped-back, high-tempo neo-modernist sensibility tailored for nomadic Gen-Z travelers. It discards decorative clutter in favor of raw structural clarity: crisp typography, vast negative space, and aggressive functional contrast. 

The aesthetic sits at the intersection of refined Swiss editorial design and kinetic digital minimalism. Interfaces are lightweight, tactile, and frictionless, favoring glanceable financial ledgers and itinerary maps over dense data tables. High-energy chartreuse and electric cobalt punctuation marks pierce a calm, warm alabaster baseline, evoking spontaneous adventure tempered by effortless financial clarity.

## Colors

The palette relies on stark tonal tension between deep obsidian (#0F1115) and clean neutral surfaces (#F9FAFB and #FFFFFF), punctuated by focused functional accents:

- **Primary Canvas & Surfaces:** The default canvas rests on `#F9FAFB` (Alabaster stone), keeping full-screen brightness soft on the eyes. Elevated surfaces and cards use `#FFFFFF`.
- **Primary Ink:** `#0F1115` serves as the dominant structural ink, headline color, and high-priority button background.
- **Cobalt & Neon Accents:** `#2563EB` acts as the primary interactive link and route visualization color. `#D4FF00` (Electric Chartreuse) is reserved strictly for energetic status indicators, active state callouts, primary badges, and high-impact micro-interactions.
- **Financial Status Colors:** Debt, negative balance, and immediate action alerts utilize `#F43F5E` (Warm Coral). Settled debits, paid shares, and positive balance states use `#10B981` (Mint Emerald).
- **Secondary/Tertiary Inks:** Secondary metadata, timestamps, and input hints rely on `#64748B` and `#A1A1AA`.

## Typography

Typographic scale is structured around **Plus Jakarta Sans**, harnessing its geometric balance, open counters, and contemporary cut. 

- **Headlines & Display:** Set tightly tracked (`-0.02em` to `-0.04em`) with bold or extrabold weights. This provides an editorial, magazine-like punch to travel headers and summary totals.
- **Numerics & Ledger Values:** Monetary amounts and currency values share the same geometric sans family, utilizing tabular figures where ledger comparisons occur to ensure columns remain aligned during expense auditing.
- **Labels & Micro-data:** Micro-labels and status indicators use uppercase or semi-bold variants with neutral-to-slight tracking (`0.02em` to `0.04em`) to ensure legibility on badges and interactive chips.

## Layout & Spacing

The layout is anchored on an 8pt dynamic fluid grid with a 4pt baseline for micro-alignments:

- **Mobile (Default):** Single-column stack with `1rem` (16px) margins and fluid horizontal carousels for card decks (e.g., daily itineraries, active trip splits).
- **Tablet / Split View (600px - 1024px):** 6-column grid with `1.5rem` gutters and `2rem` margins. Ideal for side-by-side trip maps and live balance ledgers.
- **Desktop (1024px+):** 12-column fixed-max layout centered at `1200px` max-width, maintaining airy editorial margins (`3rem`).

Component padding prioritizes vertical breathing room (`space-lg` and `space-xl`) around headline groups while keeping dense split items compact via `space-sm` and `space-md` gaps.

## Elevation & Depth

Visual hierarchy rejects layered skeuomorphic drop shadows. Instead, it employs two principal depth techniques:

1. **Hairline Outlines with Surface Shifts:** Base layer cards sit on `#FFFFFF` atop the `#F9FAFB` canvas, bounded by an ultra-crisp `1px` stroke in `#E4E4E7` (or `#0F1115` at 6% opacity).
2. **Atmospheric Ambient Glow:** Modals, sticky action sheets, and floating bars utilize a hyper-diffused, ambient shadow (`0 20px 40px -15px rgba(15, 17, 21, 0.07)`) paired with high-specular glass backing (`backdrop-filter: blur(16px)` at 85% opacity).
3. **Pill Lift:** Floating floating actions and active pills utilize a subtle, elevated contrast ring (`box-shadow: 0 4px 12px rgba(15, 17, 21, 0.08)`), signaling instant clickability without cluttering the screen plane.

## Shapes

The shape system adopts a fluid, pill-driven silhouette throughout:

- **Cards & Sheets:** Base containers feature generous rounded corners (`1.5rem` to `2rem` on major cards) to impart a modern, tactile, and non-threatening feel.
- **Buttons, Badges, & Chips:** Micro-elements and primary action buttons are fully pill-shaped (`9999px` border radius).
- **Dividers & Track Lines:** Edge lines on timeline cards and itinerary rails use rounded end-caps with minimal 1px to 2px thicknesses.

## Components

### Buttons
- **Primary:** Obsidian background (`#0F1115`), pure white text (`#FFFFFF`), full pill radius (`rounded-full`), `h-12` or `h-14`, semi-bold typography. Active state introduces a swift spring scale (`0.97`).
- **Accent Highlight:** Chartreuse background (`#D4FF00`), obsidian text (`#0F1115`), reserved for single highest-priority conversion triggers (e.g., "Settle All Expenses").
- **Ghost/Tertiary:** Transparent fill, `1px` subtle border in `#E4E4E7`, `#0F1115` text.

### Chips & Pills
- **Filter & Category Chips:** Floating pills with `0.5rem` vertical and `1rem` horizontal padding. Inactive: `#FFFFFF` fill with `1px` border `#E4E4E7` and `#71717A` text. Selected: `#0F1115` fill with `#FFFFFF` text or vibrant cobalt `#2563EB` fill with `#FFFFFF` text.
- **Status Badges:** Compact micro-pills (`label-sm`) with 10% opacity tinted backgrounds (e.g., `#10B981` at 10% with solid `#059669` text for "Settled").

### Input Fields
- Flat, borderless or hairline-bordered fields (`#E4E4E7`).
- Large currency entry inputs feature oversized numeric styling (`display-lg`) with floating trailing currency code chips (`USD`, `EUR`) in muted slate.
- Zero decorative icons inside inputs unless functional (e.g., clear button or camera receipt scanner).

### Expense Ledger List Items
- Compact rows with avatar stacks on the left, clear participant names in `headline-sm`, and balance deltas right-aligned.
- Positive balances (owed to user) display in `#10B981` prefixed with a clean `+`.
- Debts (user owes) display in `#F43F5E` prefixed with a `-`.
- Full-width tap targets with subtle row hover/touch state `#F4F4F5`.

### Cards (Itinerary & Split Cards)
- Pure white `#FFFFFF` background, rounded-3xl (`1.5rem`), bounded by a subtle `1px` hairline border (`#E4E4E7`).
- Zero heavy elevation; items separate through whitespace and stark typography hierarchy.

### Floating Bottom Bar
- Detached, floating navigation pill positioned `1.5rem` above viewport bottom.
- Frosted glass container (`rgba(255, 255, 255, 0.85)` with `16px` backdrop blur), bounded by a hairline border (`rgba(15, 17, 21, 0.08)`).
- Contains primary trip hub icons with an integrated neon chartreuse quick-add expense button nested in the center.