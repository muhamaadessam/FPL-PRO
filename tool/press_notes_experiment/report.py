"""Combines press_notes.py result files into one table per method.

  python3 report.py results/   # a folder of <method>-gw<N>.json files
"""

import glob
import json
import sys
from collections import defaultdict


def main(folder):
    runs = defaultdict(dict)
    for path in glob.glob(f'{folder}/**/*.json', recursive=True):
        data = json.load(open(path))
        s = data['summary']
        runs[s['method']][s['gameweek']] = data

    lines = ['| method | GW | scored | out ✓ | fit ✓ | doubt played | out+fit acc | s/chunk | failed |',
             '|---|---|---|---|---|---|---|---|---|']
    totals = []
    for method in sorted(runs):
        correct = scored = seconds = chunks = 0
        for gw in sorted(runs[method]):
            s = runs[method][gw]['summary']
            rows = [r for r in runs[method][gw]['scored'] if r['correct'] is not None]
            correct += sum(r['correct'] for r in rows)
            scored += len(rows)
            seconds += s['extract_seconds']
            chunks += s['chunks']
            lines.append(
                f"| {method} | {gw} | {s['players_scored']} | {s['out']['precision_did_not_play']} "
                f"(n={s['out']['n']}) | {s['fit']['precision_played']} (n={s['fit']['n']}) | "
                f"{s['doubt']['played_rate']} (n={s['doubt']['n']}) | {s['out_fit_accuracy']} | "
                f"{s['seconds_per_chunk']} | {s.get('chunks_failed', 0)} |")
        totals.append(f"| {method} | {len(runs[method])} GWs | {scored} | "
                      f"{round(correct / scored, 3) if scored else None} | "
                      f"{round(seconds / chunks, 1) if chunks else None} | {round(seconds / 60, 1)} min |")
    print('\n'.join(lines))
    print('\n| method | gameweeks | out+fit scored | accuracy | s/chunk | model time |')
    print('|---|---|---|---|---|---|')
    print('\n'.join(totals))


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'results')
