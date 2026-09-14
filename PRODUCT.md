# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

The primary user is an individual Fantasy Premier League manager checking their own squad on a phone before and between gameweeks.

## Product Purpose

Fantasy PL is a read-only Flutter client for official FPL data. It lets the user sign in through the official flow or open a public entry, review the exact squad and points for each gameweek, inspect fixtures, and receive explainable statistical recommendations for the next gameweek.

## Positioning

The app combines the user's historical squad, official fixture and player data, and transparent deterministic recommendations in one compact matchday view. It does not modify the user's FPL account.

## Operating Context

The user checks the app frequently around gameweek deadlines, compares captain and transfer options, and needs the selected gameweek's actual players, bench, captaincy, and points to stay aligned.

## Capabilities and Constraints

- Official OIDC/WebView authentication plus public entry lookup.
- Read-only team, fixtures, gameweek points, captain, transfer, and chip recommendations.
- English and Arabic with RTL support.
- Official data can be unavailable, rate-limited, or incomplete; recovery states must remain clear.
- Preserve current API, authentication, repository, and recommendation behavior during visual work.

## Brand Commitments

The team should be shown as a real formation on a pitch with recognizable shirts and club identity. The interface should feel current, compact, and professional rather than spacious or generic.

## Evidence on Hand

- Existing live FPL models and screens in `lib/`.
- Existing shirt assets in `assets/shirt/` plus official remote shirt and badge fallbacks.
- User-provided references favor a dense fantasy-football manager presentation.

## Product Principles

- Put the next decision before secondary detail.
- Keep gameweek, squad, and points visibly synchronized.
- Explain recommendations instead of presenting them as guaranteed outcomes.
- Preserve familiar native navigation and accessibility behavior.

## Accessibility & Inclusion

Support narrow phones, text scaling, minimum native touch targets, dark mode, Arabic RTL, and clear non-color-only states.
