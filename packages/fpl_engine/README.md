# fpl_engine

Pure Dart package with the FPL data models, the match predictor
(`TeamRatings`, `FixturePredictionEngine`) and the transfer/lineup
recommendation engine. It has no Flutter dependency, so it can be reused by
scripts or a server job.

```bash
dart test                                   # unit tests
dart run tool/prediction_backtest.dart      # backtest report (needs network on first run)
```
