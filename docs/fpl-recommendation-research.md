# FPL recommendation engine: official rules and first-party data

_Verified 14 September 2026. Scope: the main Fantasy Premier League game, not FPL Draft or FPL Challenge._

## Season status and evidence standard

The 2026/27 game and rules are officially live. The first-party `bootstrap-static` response identifies the `2026_27` static-content season and, when checked, marked Gameweek 4 as current. Therefore this note uses 2026/27 facts rather than carrying forward 2025/26 assumptions.

Other confirmed 2026/27 changes relevant to modelling are the revised BPS, a later post-Gameweek data lockdown, and an official price-change predictor. Unlike 2025/26, there is no AFCON free-transfer top-up in 2026/27.

Only official Premier League/FPL pages and responses served by `fantasy.premierleague.com` are treated as facts. The JSON endpoints are first-party but do not have a published, versioned developer contract; field names below are observations of the live API and must be parsed defensively.

Primary season references: [official FPL rules](https://fantasy.premierleague.com/help/rules), [2026/27 changes](https://www.premierleague.com/en/news/4679873), [2026/27 chip announcement](https://www.premierleague.com/en/news/4679879/whats-happening-with-fpl-chips-in-202627), [2026/27 scoring guide](https://www.premierleague.com/en/news/2174909/fpl-basics-explained-scoring-points), and [2026/27 team-management guide](https://www.premierleague.com/en/news/2174899/fpl-basics-managing-your-team).

## Official game constraints

| Area | Verified rule | Engine consequence |
|---|---|---|
| Squad | 15 players: 2 GKP, 5 DEF, 5 MID, 3 FWD. Initial budget is £100.0m. Maximum three players from one club. | Every proposed squad must satisfy all three constraints. Prices are integer tenths in the API: `1000` means £100.0m. |
| Starting XI | Exactly 11: 1 GKP, 3–5 DEF, 2–5 MID, 1–3 FWD. | Optimisation must choose a legal XI, not simply the 11 highest projections. These limits are also present in `element_types[].squad_min_play` and `squad_max_play`. |
| Deadline | 90 minutes before the first match of the Gameweek. It may change, but not within 24 hours of its scheduled time. Changes after it apply to the following Gameweek. | Use `events[].deadline_time` as the source of truth and refresh it; never hard-code a calendar. |
| Transfers | Unlimited before the first deadline. Afterwards, one free transfer per Gameweek; unused transfers roll up to five total. Each additional transfer costs four points. Maximum 20 transfers in a Gameweek, except when using Wildcard or Free Hit. | Compare expected gain with both the four-point hit and the option value of retaining a transfer. Reject plans above the normal transfer cap. |
| Saved transfers | Playing Wildcard or Free Hit preserves saved free transfers for the following Gameweek. | Do not reset the user's free-transfer count after these chips. |
| Prices | Sale value receives half of any profit, rounded down to the nearest £0.1m; losses are realised fully. | Use the authenticated purchase/selling prices, not `now_cost`, when testing affordability. |
| Captain | Captain's points are doubled. If the captain plays no minutes, the vice-captain becomes captain; if neither plays, nobody is doubled. | Rank captain and vice-captain separately and heavily penalise rotation/no-start risk. |
| Autosubs | A non-playing GKP can only be replaced by the reserve GKP. An outfielder is replaced by the highest-priority eligible outfield substitute who played and preserves a legal formation. Autosubs run after the Gameweek. | Simulate bench order and formation legality when estimating expected team points. A player appearing in any scheduled match in a Double Gameweek is not autosubbed. |
| Blanks/doubles | A Blank Gameweek has clubs with no fixture; their players score zero. A Double Gameweek has clubs with two fixtures. A postponed match scores in the Gameweek in which it is eventually played. | Derive blanks/doubles from the current fixtures response, not from a static label or the originally scheduled date. |

Rules sources: [official rules](https://fantasy.premierleague.com/help/rules), [picking a 2026/27 squad](https://www.premierleague.com/en/news/2174419/fpl-basics-how-to-pick-a-squad), [managing a 2026/27 team](https://www.premierleague.com/en/news/2174899/fpl-basics-managing-your-team), and [official FAQ](https://www.premierleague.com/en/news/4661030).

### Scoring facts relevant to prediction

- Appearance: 1 point below 60 minutes; 2 points at 60+ minutes, excluding stoppage time.
- Goals: GKP 10, DEF 6, MID 5, FWD 4. Assist: 3.
- Clean sheet: GKP/DEF 4, MID 1; a player substituted after 60 minutes keeps it if the team later concedes.
- Goalkeeper: 1 point per three saves; 5 for a penalty save.
- Defensive contributions: DEF gets 2 points at 10 combined clearances, blocks, interceptions and tackles; MID/FWD gets 2 at 12 when recoveries are also included.
- Bonus: 3/2/1 according to BPS, with the official tie rules. For 2026/27, being tackled no longer reduces BPS; CBI earns 1 BPS per three actions rather than two; goalkeeper save/BPS treatment also changed.
- Deductions: penalty miss −2, every two goals conceded by GKP/DEF −1, yellow −1, red −3, own goal −2.

Sources: [official 2026/27 scoring guide](https://www.premierleague.com/en/news/2174909/fpl-basics-explained-scoring-points) and [official 2026/27 BPS changes](https://www.premierleague.com/en/news/4679946/whats-new-in-202627-fantasy-changes-to-bonus-points-system). The live scoring constants are also exposed under `game_config.scoring` in [`bootstrap-static`](https://fantasy.premierleague.com/api/bootstrap-static/).

## Chips active in 2026/27

There are four chip types and two sets—one set in each half of the season—so eight uses in total. There is no fifth active chip in the live `chips` configuration. Only one chip may be active in a Gameweek.

| Chip | Official effect | 2026/27 availability and constraints |
|---|---|---|
| Wildcard | Unlimited permanent transfers, including transfers already made that Gameweek. | First: GW2–19. Second: GW20–38. It cannot be cancelled once played. |
| Free Hit | Unlimited free transfers for one Gameweek; the squad returns to its pre-chip state at the next deadline. | First: GW2–19. Second: GW20–38. Not allowed in GW1 or in consecutive Gameweeks; therefore FH in GW19 blocks FH in GW20. It cannot be cancelled once confirmed. |
| Bench Boost | Bench points are added to the total. | One in GW1–19 and one in GW20–38. It may be cancelled before the deadline. |
| Triple Captain | Captain scores triple rather than double. | One in GW1–19 and one in GW20–38. It may be cancelled before the deadline. |

The first set expires at the GW19 deadline—13:30 GMT on Saturday 2 January 2027—and does not carry over. The second set refreshes after that deadline. Saved free transfers survive Wildcard and Free Hit. The live [`bootstrap-static`](https://fantasy.premierleague.com/api/bootstrap-static/) response encodes each chip as `name`, `start_event`, `stop_event`, and `chip_type`; the non-consecutive Free Hit rule must still be enforced separately. Source: [official 2026/27 chip announcement](https://www.premierleague.com/en/news/4679879/whats-happening-with-fpl-chips-in-202627) and [official rules](https://fantasy.premierleague.com/help/rules).

## First-party data contract observed for the engine

### Public endpoints

| Endpoint | Exact useful fields observed | Prediction use |
|---|---|---|
| [`/api/bootstrap-static/`](https://fantasy.premierleague.com/api/bootstrap-static/) | `events`, `elements`, `teams`, `element_types`, `chips`, `game_config`; event fields include `id`, `deadline_time`, `finished`, `data_checked`, `is_current`, `is_next`; player fields include `id`, `team`, `element_type`, `now_cost`, `status`, `news`, `chance_of_playing_next_round`, `minutes`, `starts`, `total_points`, `event_points`, `form`, `points_per_game`, `selected_by_percent`, `transfers_in_event`, `transfers_out_event`, `price_change_percent`, `price_change_projections`, `price_change_hourly_rate`, `price_change_locked_until`, goals/assists/clean sheets/saves, `bonus`, `bps`, `defensive_contribution`, xG/xA/xGI/xGC, ICT fields, and set-piece-order fields. `game_config.settings` includes `price_change_deadlines`. | Current catalogue, availability, price, ownership, season aggregates, price-change indicators, rule constants, positions, deadlines and chip windows. |
| [`/api/fixtures/`](https://fantasy.premierleague.com/api/fixtures/) | `event`, `kickoff_time`, `team_h`, `team_a`, `team_h_difficulty`, `team_a_difficulty`, scores, state flags and `stats`. | Opponent, home/away, FDR, blank/double detection and completed-match team/player events. Filter by `event` locally. |
| `/api/element-summary/{elementId}/` | `fixtures`, `history`, `history_past`; per-match history includes `round`, `fixture`, `opponent_team`, `was_home`, `kickoff_time`, `minutes`, `starts`, `total_points`, goals/assists/clean sheets/saves, `bonus`, `bps`, defensive-action fields, xG/xA/xGI/xGC, ICT fields, `value`, selection and transfer fields. | Fixture-level rolling features, home/away splits, minutes/start probability and future schedule. Example: [`element-summary/165`](https://fantasy.premierleague.com/api/element-summary/165/). |
| `/api/event/{gameweek}/live/` | `elements[].id`, `stats`, `explain`; `stats` includes current Gameweek points and all scoring components. | Live/final Gameweek outcomes and model evaluation. Example: [`event/4/live`](https://fantasy.premierleague.com/api/event/4/live/). Do not train on a Gameweek until official data is final. |
| `/api/entry/{entryId}/` | `id`, `current_event`, `started_event`, summary points/ranks, `last_deadline_bank`, `last_deadline_value`, `last_deadline_total_transfers`. | Public manager summary and last-deadline snapshot. |
| `/api/entry/{entryId}/history/` | `current`, `past`, `chips`; current rows include `event`, `points`, `total_points`, `rank`, `overall_rank`, `bank`, `value`, `event_transfers`, `event_transfers_cost`, `points_on_bench`; chip rows include `name`, `event`, `time`. | Historical performance, hits, bench loss and chips already used. |
| `/api/entry/{entryId}/event/{gameweek}/picks/` | `active_chip`, `picks`, `automatic_subs`, `entry_history`; each pick has `element`, `position`, `multiplier`, `is_captain`, `is_vice_captain`, `element_type`. | Historical XI, bench, captain, autosubs and points for the requested Gameweek. |
| `/api/entry/{entryId}/transfers/` | Array fields: `element_in`, `element_in_cost`, `element_out`, `element_out_cost`, `entry`, `event`, `time`. | Historical transfer behaviour and realised prices. This is not the source for the unpublished next-deadline team. |

### Authenticated state required

- `/api/me/` returns `player: null` anonymously and the current manager identity after an official authenticated session.
- `/api/my-team/{entryId}/` returned HTTP 403 without authentication when checked. It is required for the unpublished current squad and authoritative transfer/bank state.
- Before implementing hit, affordability or chip recommendations, capture and contract-test an authorised response from `my-team` and map only the returned current-squad picks, purchase/selling prices, bank, transfer allowance/usage and chip availability. Do not infer exact free transfers from the public transfer history: Wildcard/Free Hit preserve saved transfers, and public history does not expose the complete current transfer state.

These are first-party response observations, not a promise of API stability. Authentication must remain through the official account flow; credentials must not be logged.

## Facts versus recommendation heuristics

### Observed facts the engine may enforce directly

- Squad, formation, budget, club limit, transfer costs/caps, deadline and chip legality.
- The user's current squad, selling prices, bank, saved transfers and remaining chips from authenticated state.
- Official fixtures, venue, FDR, player availability flags, minutes, starts, scoring events, xG-family statistics, defensive contributions, BPS, ownership and price/transfer trends.
- Blank/Double status derived by counting each club's fixtures per `event` in the latest fixture feed.

### Inferred heuristics the UI must label as estimates

- **Expected minutes:** recent starts/minutes plus `status`, news and chance-of-playing fields. These fields do not guarantee selection.
- **Expected points:** a weighted estimate from per-90 scoring components, expected metrics, defensive contributions, opponent/home-away strength, fixture count and expected minutes. `form`, `ep_next` and FDR are inputs, not official forecasts guaranteed to occur.
- **Transfer recommendation:** maximise projected multi-Gameweek gain subject to legal squad and actual selling-value constraints; subtract four points per paid transfer and include the value of rolling a free transfer. Never recommend a hit merely because the incoming player has a higher one-week projection.
- **Captain/vice-captain:** maximise expected multiplied points while accounting for start probability and upside. The vice-captain should remain a strong, likely starter; diversification from the captain's postponement/rotation risk is a heuristic, not a rule.
- **Wildcard:** recommend only when the projected multi-week gain from restructuring materially exceeds ordinary free-transfer/hit routes, or before an expiring half-season chip would otherwise be lost.
- **Free Hit:** compare the best legal one-week squad with the no-chip squad, commonly around confirmed Blank/Double Gameweeks; remember the squad reverts and another chip cannot be used that week.
- **Bench Boost:** estimate incremental points from all four bench players after expected-minutes risk; a Double Gameweek may help but is not required.
- **Triple Captain:** estimate the extra captain copy over normal double points; favour high expected minutes and high ceiling, often—but not necessarily—a Double Gameweek.

Recommendation output should show the projected gain, uncertainty, rule checks, transfer hit, remaining bank/free transfers/chips, and a plain-language reason. It must remain advice: official data describes past/current state, while future line-ups, injuries, postponements and performance are uncertain.

## Data-quality guardrails

1. Refresh `bootstrap-static` and fixtures before each recommendation and use `deadline_time` in UTC.
2. Snapshot inputs with a retrieval timestamp and model version so recommendations are reproducible.
3. Treat `null`, missing and newly added fields as unknown; do not coerce them to zero.
4. Recompute if fixtures move between Gameweeks or player status/news changes.
5. Do not finalise training labels while `events[].data_checked` is false. In 2026/27, official lockdown moved to 09:00 UK time after the final match day so post-match Opta review can alter BPS and defensive-contribution points ([official 2026/27 changes](https://www.premierleague.com/en/news/4679873)).
6. Validate chip windows from live `chips` configuration every season; never assume 2026/27 rules apply to 2027/28.
