# VIV Design System

> **Vos projets, nos talents.** — Sourcing & placement des meilleurs talents pour accélérer la performance de vos projets.

VIV is a French talent-placement and staffing firm (based in Colombes, near Paris) specialising in rapid integration of expert profiles — designers, digital specialists, IT engineers, data engineers, project managers — into client teams. It positions itself as an "agile, compliant, durable" partner rather than a traditional recruitment agency, combining sourcing, administrative / legal handling, ongoing talent follow-up, and training.

## Products / surfaces represented

VIV's public surface is built around **a single corporate marketing website** at `https://viv-prod.com` in French. Sub-brands surfaced inside the ecosystem:

| Entity | Role | Logo file |
|---|---|---|
| **VIV** | Parent — talent placement / staffing | `Logo_*` (12 variants) |
| **Secure** | In-house offering: centralises already-placed talents under a compliant framework | referenced as "Secure" / "VIV Secure" |
| **VIV Recrutement** | Permanent-hire recruitment cabinet | — |
| **VIV Formation** | Qualiopi-certified training center (AI upskilling) | — at `https://viv-formation.com` |

This design system focuses on the **parent VIV brand**. Sub-brand visual identities are inferable from the main site but were not supplied as files.

## Sources consulted

- **Charte graphique VIV 2025 (PDF)** — canonical brand manual. Defines primary/secondary palettes (with CMJN), typography pair (Playfair Display Bold Italic + Noto Sans), logo usage matrix, button treatments, icon style, and imagery intent. **This is the source of truth.**
- **Logos provided** — 12 PNG files in `/uploads` (noir / blanc / vert / gris × mark / horizontal-with-baseline / vertical-with-baseline). Copied into `assets/logos/`.
- **Website** — `https://viv-prod.com` (French). Structure, copy, sections, tone of voice, palette confirmation.
- **Sector imagery** — hot-linked on viv-prod.com but not downloadable via this environment (CORS). See **Caveats**.

---

## Content fundamentals

- **Language:** French (formal register, `vous` / "nos clients"). All copy in the design system samples is preserved in French to stay faithful to the brand.
- **Voice:** confident, professional, quietly expert. Sentences are measured, not breathless. Frequent triads ("**agile, conforme et durable**"; "**plus vite, mieux et plus intelligemment**").
- **Tone:** reassuring and operational. VIV sells reliability — phrases like *"opérationnels dès le premier jour"*, *"un cadre clair et conforme"*, *"un interlocuteur unique, impliqué et disponible"*.
- **Pronouns:** first-person plural for VIV (`nous`, `notre équipe`, `nos talents`); second-person formal for the reader (`vous`, `vos projets`, `vos équipes`). Never "tu". Never "I".
- **Casing:** Sentence case for headings; the tagline "*vos projets, nos talents.*" is deliberately lowercase in the lockup. Section eyebrows are not all-caps on the live site — they're set in the serif and weighted.
- **Punctuation:** French typographic spacing (` !`, ` ?`, ` :`) when reproducing site copy. Em dashes are rare; commas do most of the work.
- **Emoji:** **never.** There is zero emoji usage on the site.
- **Acronyms / caps:** only where conventional — IA, IT, SI, CDD, CDI, ISO, EcoVadis, Qualiopi.
- **Vibe:** editorial, European, slightly luxurious (compatible with the sectors they serve: luxe, transport, industrie, santé). Feels closer to a boutique consultancy than a recruiter platform.

### Sample phrasings (lifted from viv-prod.com)

> **Hero:** "Sourcing et placement des meilleurs talents pour accélérer la performance de vos projets."
>
> **Value prop:** "Un modèle agile, conforme et durable, pour des collaborations efficaces dès le premier jour."
>
> **CTA labels:** "Découvrez nos talents", "Découvrir nos engagements", "En savoir plus".
>
> **Section headers:** "Trouvez le bon talent au bon moment !", "Plus qu'un simple partenaire", "Des solutions pensées pour vous".

---

## Visual foundations

### Color (canonical per Charte 2025)

- **Primaires (2) :** **Black** `#000000` et **Off-white** `#F9F9F9`. These two carry the brand — most surfaces are black or off-white, most type is one on the other.
- **Secondaires (3) :** **Electric lime** `#C1F903`, **Light grey** `#B6B6B6`, **Lime gradient** (`#63A700` → `#C1F903`). Used for accents, emphasis, and occasional large fills — never as the dominant surface color.
- **Electric lime never appears on long text passages.** Reserve it for **buttons** (primary CTA fills, icon pastilles) and **ponctuellement for links**. Every other lime use is wrong.
- On black surfaces, text is **white** (or white atténué) — never lime. Likewise, on off-white surfaces, text is black.
- The Lime gradient is named in the charte and appears on large display surfaces (hero accents, marketing collateral) — flat electric lime is the default for UI.
- Lime on black is the signature contrast **for fills**, not for runs of copy. Lime on white fails WCAG for body text — restrict to large display type or buttons-as-fills.

### Typography (canonical per Charte 2025)
- **Principal: Playfair Display Bold Italic.** Elegant high-contrast serif. Used for **titres** (headlines) and **noms + prénoms + titres de poste**. Its pronounced contrast and italic stance give force and modernity.
- **Secondary: Noto Sans.** Humanist geometric sans. Used for:
  - **Bold Italic** — sous-titres
  - **Regular / Regular Italic** — corps de texte
  - **Italic** — citations
  - **Light** — annotations secondaires
- The Playfair/Noto pairing creates harmonious contrast: Playfair brings expression, Noto brings clarity for long-form reading on screen and print.

### Spacing & layout
- Generous vertical rhythm. The site uses very spacious section padding (~96–128px between blocks).
- Content is anchored to a ~1280px max container with comfortable gutters.
- Layouts are **column-based with asymmetry** — image + text pairings where the image spans full-bleed on one side of a constrained grid, producing editorial feel.
- Strong use of **full-bleed hero imagery** with warm, human, skin-tone-leaning photography (portraits of office workers, meetings, creative environments).

### Backgrounds
- Predominantly **paper white** (`#FFFFFF`) and **warm off-white** (`#F5F5F3`).
- Ink-black sections used for emphasis (hero, footer) with lime-green text for contrast.
- **No patterns, no textures, no grain.** Backgrounds stay quiet so photography and typography carry.

### Imagery treatment
- **Photography:** warm, natural, daylight-lit. Skin tones trend warm. Professional but not stock-corporate. Some imagery feels slightly cinematic (shallow DOF, natural light).
- **Color grading:** neutral-warm, slight teal-orange balance. No heavy B&W or grain.
- Mostly **full-bleed** with soft rounded corners on cards, or **full-width banners** between content bands.

### Motion
- **Subtle** — small fades, modest upward translate-Y on scroll-in (6–12px), and mild image zoom on hover.
- Easing: soft out-cubic equivalents, no bouncy springs.
- Durations land between 200–480ms.

### Hover / press states
- Links: color shifts to a darker green (`--viv-green-600`); underline thickness stable.
- Buttons (green primary): slight darken on hover, 2–4% scale-down on press (no cartoonish scaling).
- Cards: soft shadow lifts slightly (md → lg), image inside zooms to ~1.03.
- No glow / no heavy elevation.

### Borders & cards
- Cards are **large-radius** (`--radius-lg` = 20px) with **no visible border** — separation comes from generous padding and soft shadow (`--shadow-md`).
- Where borders appear (chips, inputs), they're hair-thin (1px) at `rgba(10,10,10,0.12)`.
- **No** colored left-border accent cards (the classic AI-slop pattern).

### Shadows
- **Two-layer ambient shadows** — one short, one long. Kept quiet; this is an editorial brand, not a SaaS dashboard.
- No inner shadows, no neon glows.

### Corner radii
- Buttons / inputs: `--radius-md` (12px).
- Cards: `--radius-lg` (20px).
- Hero imagery: `--radius-xl` (32px) or full-bleed rectangle.
- Chips / pills: `--radius-pill`.
- The wordmark itself has soft organic curves — nothing should feel rectilinear.

### Transparency & blur
- Rare. A subtle frosted nav-bar on scroll (`backdrop-filter: blur(12px)` + 80% paper) is the main place blur appears. No frosted cards, no translucent overlays.

### Layout rules (fixed elements)
- Top nav is sticky and becomes frosted-white on scroll.
- Footer is always ink-black with lime accents.
- CTAs sit in logical reading positions — no floating call buttons, no chatbots.

---

## Iconography (per Charte 2025)

- **Style: rounded regular.** All icons must follow a rounded-regular line style for visual coherence.
- **Two integration modes:**
  - **Sans pastille** — icon flows inline with content (menus, secondary titles, lists). Discreet, accompanies information without dominating.
  - **Avec pastille** — icon sits inside a filled shape (circle or rounded square) in strong contrast. Used for interactive buttons, primary CTAs, high-visibility zones. Typically **black pastille with lime glyph** or the inverse.
- **Custom icons** can be created as needed but must respect the rounded-regular vocabulary.
- **Substitute in this kit:** Lucide rounded line icons @ 1.6 stroke. Swap for VIV's own custom set once provided.
- **Never emoji.** Never unicode as UI glyphs.

## Buttons (per Charte 2025 & live site)

- **Shape: pill** (`--radius-pill`) for marketing CTAs (hero, cards, sections). This is the dominant button shape on viv‑prod.com.
- **Label typography: Noto Sans Bold Italic, ~14px.** All button labels are bold italic — never upright.
- **Three canonical variants:**
  - **Primaire — lime plein** : background `#C1F903`, label black with `text-decoration: underline`, 3px underline offset. This is the accent CTA.
  - **Secondaire — noir plein** : background `#000`, label white, no underline.
  - **Outline adaptatif** : transparent background + 1px border at 50% opacity of the foreground. White border on dark surfaces, black border on light.
- **Pastille d'icône** : perfectly circular (`border-radius:50%`), 22×24px, housed inside the button. On lime buttons, pastille is black with lime glyph. On black buttons, pastille is lime with black glyph.
- **Inner-shadow** treatment exists in the charte for print / hero surfaces; it's not the digital default.
- Common labels: `Découvrez nos talents`, `Nos engagements`, `En savoir plus`, `Consulter`, `Voir plus`, `Valider`.

---

## Index — what's in this folder

```
README.md                       ← you are here
SKILL.md                        ← machine-readable skill manifest (Agent Skills compatible)
colors_and_type.css             ← canonical CSS tokens (colors, type, spacing, motion)
fonts/                          ← (empty — using Google Fonts CDN; see Caveats)
assets/
  logos/                        ← 12 VIV PNG logos (mark / horizontal / vertical × 4 colorways)
  imagery/                      ← site imagery (PLACEHOLDER — see Caveats)
  icons/                        ← (empty — see Caveats; using Lucide CDN)
preview/                        ← Design System tab cards
  01-logos.html, 02-colors-primary.html, 03-colors-neutrals.html, …
ui_kits/
  website/                      ← recreation of viv-prod.com sections
    README.md
    index.html                  ← click-through prototype
    *.jsx                       ← React components
```

### Imagery direction (per Charte 2025)

- **Natural light**, **dynamic scenes of life**, **color**. Human warmth is the core signal.
- **Three favoured types:**
  - **Portraits spontanés** — expressive faces, direct gazes, captured in real work environments under natural light.
  - **Scènes de collaboration** — candid moments of collective engagement, creativity, team dynamics.
  - **Ambiances de travail** — wide shots or detail focus (postures, objects, gestures) conveying a stimulating, modern atmosphere.
- Positioning: positive, human, grounded in the present. Young and alive — aligned with the values of proximity, energy, authenticity.
- Avoid: staged corporate stock, cold lighting, over-processed B&W, heavy grain.

## Caveats

- **Site imagery** couldn't be downloaded from the VIV CDN (CORS in this sandbox). Dark gradient placeholders stand in. Upload the `.webp` files for full fidelity.
- **Custom VIV SVG icons** (sourcing / conformité / suivi / formation) likewise weren't accessible — Lucide rounded substitutes in place.
- **Sub-brand logos** (VIV Formation, VIV Recrutement) referenced in charte but files not yet provided.
