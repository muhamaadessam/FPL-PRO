# Defensible next-Gameweek FPL lineup rating

_Verified 14 September 2026. Primary sources only. This is a product model, not an official FPL forecast._

## Recommendation

Show two different outputs:

1. **Expected points (xP)** for every starter and substitute, plus the starting XI total with captaincy.
2. **Rating / 100**, a relative quality index. It must not be described as a probability of success.

Put the detail on a separate **Next Gameweek Analysis** screen opened from Recommendations. The existing Recommendations screen should show only the team rating, projected points, target Gameweek, and the link.

## First-party inputs

The JSON endpoints are operated by FPL, but there is no published, versioned developer contract. Parse missing or changed fields defensively and timestamp each input snapshot.

| Source | Fields to use | Purpose |
|---|---|---|
| [`/api/bootstrap-static/`](https://fantasy.premierleague.com/api/bootstrap-static/) | `events[].id/is_next/deadline_time/data_checked`; `elements[].id/team/element_type/status/can_select/chance_of_playing_next_round/news/minutes/starts/total_points/form/points_per_game/ep_next/goals_scored/assists/clean_sheets/goals_conceded/saves/bonus/bps/defensive_contribution/expected_goals/expected_assists/expected_goal_involvements/expected_goals_conceded`; `element_types` | Current player catalogue, season aggregates, availability, official opaque `ep_next`, positions and target Gameweek. |
| [`/api/fixtures/`](https://fantasy.premierleague.com/api/fixtures/) | `event/team_h/team_a/team_h_difficulty/team_a_difficulty/kickoff_time/started/finished/team_h_score/team_a_score/stats` | Opponent, home/away, FDR, blanks, doubles and team results. Count fixtures with `event == targetGameweek`; do not infer a Gameweek from calendar dates. |
| [`/api/event/{gw}/live/`](https://fantasy.premierleague.com/api/event/1/live/) | `elements[].id/stats/explain`; points, minutes, starts, xG, xA, xGC, BPS, saves, cards and defensive contributions | Per-Gameweek current-season observations and the final outcome used to test the model. Only treat a round as a final label when its bootstrap event has `data_checked == true`. |
| [`/api/element-summary/{playerId}/`](https://fantasy.premierleague.com/api/element-summary/165/) | `history`, `fixtures`, `history_past` | Convenient match history for the 15 owned players and prior-season aggregate shrinkage. It is optional if the app has already cached equivalent `event/live` data. |
| [`/api/entry/{entryId}/event/{gw}/picks/`](https://fantasy.premierleague.com/api/entry/107646/event/1/picks/) | `picks[].element/position/multiplier/is_captain/is_vice_captain`, `automatic_subs`, `active_chip`, `entry_history` | Historical lineups and honest backtesting of lineup decisions. Public picks describe the team at that deadline, not unpublished future changes. |
| [`/api/entry/{entryId}/history/`](https://fantasy.premierleague.com/api/entry/2434014/history/) | `current[].event/points/event_transfers_cost/points_on_bench`, `past`, `chips` | Manager-level results and evaluation context. These rows do not describe player ability. |

For the next unpublished lineup, use the app's authenticated current-team response. Public historical picks alone cannot reveal changes made before the next deadline.

## Official scoring constraints

The projection must mirror the official scoring categories: appearance gives 1 point below 60 minutes and 2 at 60+; goals give 10/6/5/4 by GKP/DEF/MID/FWD; assists give 3; clean sheets give 4 for GKP/DEF and 1 for MID; goalkeepers earn 1 per three saves; qualifying defensive contributions earn 2; bonus gives 1–3; and cards, own goals, penalty misses and goals conceded create deductions. See the [official FPL rules](https://fantasy.premierleague.com/help/rules) and the Premier League's [official scoring guide](https://www.premierleague.com/en/news/2174909/fpl-basics-explained-scoring-points).

The team calculation must also respect legal formations, captain/vice-captain fallback and bench priority. Those rules are described in the [official team-management guide](https://www.premierleague.com/en/news/2174899/fpl-basics-managing-your-team).

## Practical player model

Use completed current-season rounds, with the last six weighted by `0.75^age`. Rates are per 90 minutes. Shrink noisy rates instead of trusting four early matches:

```text
currentWeight = weightedMinutes / 90
priorWeight   = min(previousSeasonMinutes / 90, 5)
positionWeight = 3

shrunkRate = (
  currentWeight * currentRate
  + priorWeight * previousSeasonRate
  + positionWeight * currentPositionMedianRate
) / (currentWeight + priorWeight + positionWeight)
```

If a prior-season field is absent, omit that term rather than treating it as zero. Limit prior history to five match-equivalents so current role and club dominate.

Estimate playing time separately:

```text
availability = chance_of_playing_next_round / 100, when supplied
             = 0 when can_select is false or status is unavailable
             = 1.00 for available, 0.75 for doubtful, 0.25 otherwise

expectedMinutes = availability * (
  recentStartRate * recentMinutesWhenStarting
  + (1 - recentStartRate) * recentMinutesWhenSubstitute
)
```

The fallback status values are explicit heuristics and should be constants that can be calibrated later.

For each fixture `f` in the target Gameweek:

```text
minuteShare = expectedMinutes / 90
appearance  = availability * (P(1..59 minutes) + 2 * P(60+ minutes))
attack      = minuteShare * (goalPointsByPosition * xG90 + 3 * xA90)
cleanSheet  = P(60+) * cleanSheetPointsByPosition * teamCleanSheetProbability
saves       = GKP ? minuteShare * saves90 / 3 : 0
defence     = 2 * P(reaching the position's defensive-contribution threshold)
bonus       = minuteShare * shrunkBonus90
deductions  = minuteShare * shrunkCardOwnGoalPenaltyMissRate

fixtureFactor = clamp(1 + 0.08 * (3 - FDR), 0.84, 1.16)
modelXP_f = appearance + fixtureFactor *
            (attack + cleanSheet + saves + defence + bonus + deductions)
```

Estimate `teamCleanSheetProbability` from that club's current-season clean-sheet rate, shrunk by two match-equivalents toward the league rate, then apply the fixture factor and clamp to `[0, 1]`. Estimate defensive-contribution probability as the weighted share of recent matches in which the player reached the official threshold. Sum `modelXP_f` across all target fixtures; a blank therefore produces zero and a double produces two fixture terms.

Use the official but methodologically opaque `ep_next` only as a low-weight anchor:

```text
playerXP = 0.75 * sum(modelXP_f) + 0.25 * ep_next
```

If `ep_next` is absent, use `sum(modelXP_f)`. Keep all weights under a model version because they are modelling choices, not FPL rules.

### Confidence

Display confidence independently from xP:

```text
confidence = clamp((currentMinutes + 0.35 * usablePriorMinutes) / 900, 0, 1)
```

Reduce it when availability is uncertain or fixtures have no kickoff time. Do not lower xP merely to make the confidence label look cautious; expected value and uncertainty are different outputs.

## Ratings and team totals

For every selectable player who has a target fixture:

```text
playerRating = percentileRank(playerXP among players of the same position) * 100
```

Use the same rating for starters and bench players. Comparing within position avoids systematically underrating goalkeepers and defenders because positions score differently.

Normal captaincy projection:

```text
startingXI_XP = sum(starterXP)
captainExtra  = captainXP + (1 - captainPlayProbability) * viceCaptainXP
lineupXP      = startingXI_XP + captainExtra
```

Enumerate the legal XIs from the owned 15 players to find `bestLegalLineupXP`; `15 choose 11` is small enough to do directly in Dart. Then:

```text
XIQuality          = multiplier-weighted mean starter playerRating
BenchQuality       = mean(bench playerRating * bench availability)
SquadQuality       = 0.85 * XIQuality + 0.15 * BenchQuality
SelectionEfficiency = 100 * clamp(lineupXP / bestLegalLineupXP, 0, 1)

teamRating = round(0.80 * SquadQuality + 0.20 * SelectionEfficiency)
```

Show `lineupXP`, `bestLegalLineupXP`, player xP/rating/confidence, and bench xP beside the final rating. “82/100” means strong relative squad and lineup quality under this model; it does **not** mean an 82% chance of a green arrow.

## What official prior-season data can and cannot support

`element-summary.history_past` exposes season aggregates for a player still present in the current catalogue, including minutes, points and many scoring/xG fields. It is suitable only as a small prior for per-90 rates.

It does **not** provide prior-season match-by-match opponents, venue, old club/team ID, role, injuries, starting price changes through the season, or the squad of players no longer in the current game. Consequently the live official API cannot defensibly answer “how this player performed against this same opponent last season” or reliably separate performance before and after a transfer. `entry/{id}/history.past` contains only a manager's season totals and rank, not player history.

Do not scrape unofficial archives to fill these gaps under this model's evidence policy. If richer historical modelling is required later, the app must begin storing pre-deadline official snapshots and final `event/live` responses itself.

## Validation before calling the rating fair

Persist each pre-deadline input snapshot, model version and prediction. After `data_checked == true`, compare xP with official `event/live` points using MAE and bias, split by position and expected-minutes band. Also compare the chosen XI with the best legal XI from the same owned squad using historical picks and autosubs. Recalibrate weights only after a useful sample (at least 6–8 completed Gameweeks); never backtest an earlier Gameweek with end-of-season aggregates, because that leaks future information.

## Minimal Flutter implementation order

1. Extend the existing FPL models to retain the required `bootstrap`, fixture and `event/live` fields; cache one final live payload per completed Gameweek.
2. Add one pure Dart projection function and one deterministic test covering a blank, a double and an unavailable player.
3. Add `Next Gameweek Analysis` as a separate route from Recommendations, displaying team rating/xP first and the 15 player rows below.
4. Persist snapshots and calibrate after enough real predictions exist. Until then label the output “Model estimate”.
