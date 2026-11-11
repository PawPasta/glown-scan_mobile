---
design-system:
  name: "GlowScan Pink Editorial"
  version: "1.1.0"
  reference: "Website docs/design/CLAUDE.md and its shipped CSS"
  tokens:
    colors:
      ink: "#33272D"
      paper: "#FFF8FA"
      blush: "#FAEDF1"
      rose: "#C76D88"
      rose-hover: "#A94E6B"
      rose-active: "#783D52"
      muted-text: "#62545A"
      border: "#EAD8DF"
    typography:
      headings: "Playfair Display character, using the native serif fallback"
      body: "DM Sans character, using the native sans-serif fallback"
      body-line-height: 1.6
    layout:
      spacing-base: 4dp
      screen-gutter: "20-24dp"
      auth-card-max-width: 480dp
      auth-card-padding: "20-28dp"
    borders:
      card-radius: 12dp
      button-radius: 6dp
      field-radius: 6dp
      default-width: 1dp
---

# GlowScan Mobile Design Specification

Use the GlowScan Pink Editorial system from the website as the visual source of
truth, adapted for touch-first Flutter screens. The website CSS uses Playfair
Display for editorial headings and DM Sans for body text; Flutter screens use
the platform's serif and sans-serif fallbacks so the interface remains
available offline and does not fetch fonts at runtime.

## Brand and color

- Use warm ink (`#33272D`) for primary text and grounded primary actions.
- Use paper (`#FFF8FA`) for app surfaces and pale blush (`#FAEDF1`) to frame
  focused content such as authentication cards.
- Use muted rose (`#C76D88`) for selected indicators and restrained highlights.
  Use the deeper rose tokens for focus and active states.
- Use the warm muted-text and soft-border tokens for secondary copy and
  outlines. Do not use pale rose as essential body text.

## Typography

- Use serif display styles for editorial screen headings and sentence case.
- Use the platform sans-serif for labels, body copy, inputs, and controls.
- Keep body copy comfortably readable with approximately 1.6 line height.
- Eyebrows may be uppercase and letter-spaced; do not uppercase full headings
  or paragraphs.
- Keep all user-facing product copy in English.

## Mobile layout and components

- Build for narrow phones first. Verify layouts from 320dp wide and support
  text scaling, keyboard insets, and vertical scrolling without clipped fields
  or actions.
- Use 20-24dp screen gutters, a 4dp spacing rhythm, and at least 44dp touch
  targets.
- Authentication screens use a blush page background and a paper card with a
  1dp border, 12dp corners, and responsive 20-28dp internal padding. Keep the
  card at or below 480dp wide.
- Primary buttons use ink backgrounds, paper foregrounds, and 6dp corners.
  Inputs and outlined buttons use the same compact corner radius and soft
  border.
- Use clear labels, helpful validation, visible focus/error states, and
  accessible color contrast. Keep forms scrollable when the keyboard opens.
- Prefer a deliberate typographic hierarchy and whitespace over extra cards,
  dividers, icons, or decorative effects.

## Anti-patterns

- Do not use pure black (`#000000`), pure white (`#FFFFFF`), generic gradients,
  neon colors, artificial glow effects, or unnecessary shadows.
- Do not add dense card stacks, cramped spacing, or aggressive motion.
- Do not depend on network-loaded fonts for a functional screen.
- Do not present planned skincare capabilities as already available.

## Review checklist

1. Use the tokens defined above; avoid introducing one-off brand colors.
2. Check text contrast and accessible control sizes.
3. Check onboarding and authentication at 320dp and with a software keyboard.
4. Confirm all visible copy, validation, and empty/error states are in English.
5. Keep Flutter UI behavior and styling aligned with the website's design
   language without copying desktop-only layout rules.
