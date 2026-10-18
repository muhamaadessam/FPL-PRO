# fpl_engine

Pure Dart package with the FPL data models, the match predictor
(`TeamRatings`, `FixturePredictionEngine`) and the transfer/lineup
recommendation engine. It has no Flutter dependency, so it can be reused by
scripts or a server job.

```bash
dart test                                   # unit tests
dart run tool/prediction_backtest.dart      # backtest report (needs network on first run)
dart run bin/publish_predictions.dart --out build/data   # precompute JSON
```

`bin/publish_predictions.dart` fetches the FPL API and writes
`v1/fixture-predictions.json` and `v1/player-projections.json`
(`PublishedFixturePredictions`, `PublishedPlayerProjections`). The site
deploy workflow runs it every six hours and serves the files at
`/data/v1/`; the app uses them when they match its current Gameweek and are
under 36 hours old, and otherwise computes on device. Squad-specific advice
always runs on device.

With `--news-snapshot <file>` it also writes every player's FPL status and
injury news. The deploy commits that file to the `fpl-news-snapshots` branch
whenever the news changes, so the branch history records what FPL said
before each deadline.
