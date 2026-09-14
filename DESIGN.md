# Design Direction

## Thesis

Fantasy PL is a compact matchday command centre. The pitch and the next decision lead; generic stacks of equal Material cards do not.

## Visual World

- Deep aubergine and ink surfaces reference floodlit matchday screens without copying Premier League branding.
- Electric mint is the primary action and positive signal; cyan and violet are restrained secondary data accents.
- The pitch is a saturated green field with precise markings and compact shirt-led player tiles.
- Surfaces use 12–16px radii, tonal elevation, and one clear layer of depth. Pills are reserved for status and compact controls.
- System type carries body and controls; strong weight and tabular-looking number alignment create hierarchy without adding a font dependency.

## Composition

- Top-level screens have a concise contextual header, not a large empty app bar.
- Team: gameweek and score summary lead directly into the pitch; view controls remain compact.
- Recommendations: captain and chip decision form the opening composition, followed by legible transfer comparisons and positional shortlist rows.
- Fixtures: group information by match rhythm and make score/status the visual anchor.
- Bottom navigation remains a native Material navigation bar with a strongly legible selected state.

## Responsive & Platform Rules

- Preserve SafeArea and native back behavior on iOS and Android.
- Use a bottom navigation bar on compact screens and avoid custom gestures.
- Every interaction is at least 48dp; layouts must work at 320px width and with Arabic RTL.
- Honor the system light/dark choice with complete schemes; do not invert raw colors blindly.

## Motion

Use standard Material transitions and subtle state changes only. Refresh, selection, and tab changes must remain calm and immediate; honor reduced-motion settings.

## Guardrails

- No decorative glass, glow, gradient text, fake analytics, or invented player data.
- No new package or asset dependency for visual polish.
- No changes to network, authentication, repositories, or recommendation calculations.
