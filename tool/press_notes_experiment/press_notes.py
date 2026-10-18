"""Experiment: can a small local model read pre-match team news well enough
to feed the availability model?

Fetches one Gameweek's team-news articles from the Premier League content
API (the club articles it aggregates plus its own predicted line-ups), asks
an Ollama model (or a keyword baseline) for each player's status, and scores
every claim made before that player's kickoff against the minutes he then
played. Standard library only, so it runs on a bare GitHub runner.

  python3 press_notes.py --gameweek 7 --method rules --out results
  python3 press_notes.py --gameweek 7 --method ollama --model qwen2.5:3b --out results
"""

import argparse
import html
import json
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from html.parser import HTMLParser

FPL = 'https://fantasy.premierleague.com/api'
PL_CONTENT = 'https://api.premierleague.com/content/premierleague/en'
OLLAMA = 'http://localhost:11434'
UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/130 Safari/537.36'

# Line-ups are announced an hour before kickoff; anything later is leakage.
LINEUP_LEAD = timedelta(minutes=70)
NOT_MEN_FIRST_TEAM = re.compile(r'\b(WSL|women|bompastor|u21|u18|pl2|academy)\b', re.I)
CHUNK_WORDS = 350


def get(url, as_json=True, timeout=30):
    req = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept-Language': 'en'})
    with urllib.request.urlopen(req, timeout=timeout) as res:
        raw = res.read().decode('utf-8', 'replace')
    return json.loads(raw) if as_json else raw


def ts(value):
    return datetime.fromisoformat(value.replace('Z', '+00:00'))


def fold(text):
    text = unicodedata.normalize('NFKD', text)
    return ''.join(c for c in text if not unicodedata.combining(c)).lower()


class Paragraphs(HTMLParser):
    SKIP = {'script', 'style', 'nav', 'footer', 'header', 'aside'}

    def __init__(self):
        super().__init__()
        self.depth = self.skip = 0
        self.current, self.out = [], []

    def handle_starttag(self, tag, attrs):
        if tag in self.SKIP:
            self.skip += 1
        if tag == 'p':
            self.depth += 1
            self.current = []

    def handle_endtag(self, tag):
        if tag in self.SKIP and self.skip:
            self.skip -= 1
        if tag == 'p' and self.depth:
            self.depth -= 1
            text = ' '.join(''.join(self.current).split())
            if len(text) > 40:
                self.out.append(text)

    def handle_data(self, data):
        if self.depth and not self.skip:
            self.current.append(data)


def api_body_lines(body):
    text = re.sub(r'<(script|style)[^>]*>.*?</\1>', ' ', body or '', flags=re.S | re.I)
    text = html.unescape(re.sub(r'<[^>]+>', '\n', text))
    lines = [' '.join(line.split()) for line in text.split('\n')]
    return [line for line in lines if line and not line.startswith('window.')]


# --- Fetch -----------------------------------------------------------------

def load_fpl(gameweek):
    bootstrap = get(f'{FPL}/bootstrap-static/')
    fixtures = get(f'{FPL}/fixtures/?event={gameweek}')
    live = get(f'{FPL}/event/{gameweek}/live/')
    return bootstrap, fixtures, live


def team_lookup(bootstrap):
    by_code = {t['code']: t['id'] for t in bootstrap['teams']}
    by_name = {}
    for t in bootstrap['teams']:
        for name in (t['name'], t['short_name']):
            by_name[fold(name)] = t['id']
    aliases = {
        'man utd': 'manchester united', 'man city': 'manchester city', 'spurs': 'tottenham hotspur',
        "nott'm forest": 'nottingham forest', 'brighton': 'brighton & hove albion',
        'wolves': 'wolverhampton wanderers', 'newcastle': 'newcastle united', 'leeds': 'leeds united',
        'west ham': 'west ham united', 'ipswich': 'ipswich town', 'coventry': 'coventry city',
        'hull': 'hull city', 'palace': 'crystal palace', 'forest': 'nottingham forest',
        'villa': 'aston villa', 'bournemouth': 'afc bournemouth',
    }
    for t in bootstrap['teams']:
        for short, full in aliases.items():
            if fold(t['name']) == short:
                by_name[full] = t['id']
    return by_code, by_name


def article_team(article, by_code, by_name):
    for tag in article.get('tags', []):
        label = tag['label']
        if label.startswith('OptaID_t') and label[8:].isdigit():
            team = by_code.get(int(label[8:]))
            if team:
                return team
        if label.startswith('club-produced-content:'):
            slug = fold(label.split(':', 1)[1].replace('-', ' '))
            if slug in by_name:
                return by_name[slug]
    return None


FETCH_TAGS = ('ClubTeamNews', 'franchise:injury-news', 'franchise:predicted-line-ups')


def fetch_articles(start, end, max_pages=120):
    """Team-news articles published in [start, end], newest pages first."""
    articles = {}
    for tag in FETCH_TAGS:
        for page in range(max_pages):
            content = get(f'{PL_CONTENT}?contentTypes=TEXT&pageSize=30&page={page}&tagNames={tag}')['content']
            if not content:
                break
            for article in content:
                articles[article['id']] = article
            dates = [ts(a['date']) for a in content if a['date'] > '2000']
            if dates and max(dates) < start:
                break
    window = []
    for a in articles.values():
        if a['date'] < '2000' or not (start <= ts(a['date']) <= end):
            continue
        if NOT_MEN_FIRST_TEAM.search(a['title']):
            continue
        window.append(a)
    return sorted(window, key=lambda a: a['date'])


def news_window(gameweek, fixtures, previous_fixtures):
    """From the previous Gameweek's last kickoff to this one's last kickoff."""
    kickoffs = [ts(f['kickoff_time']) for f in fixtures]
    if previous_fixtures:
        start = max(ts(f['kickoff_time']) for f in previous_fixtures) + timedelta(hours=2)
    else:
        start = min(kickoffs) - timedelta(days=7)
    return start, max(kickoffs)


def article_chunks(article, team, by_name):
    """[(team id or None, text)] — the PL's own round-ups split per club."""
    lines = api_body_lines(article.get('body'))
    source = 'api'
    # Club articles carry no body, only a link to the club's own site.
    url = article.get('hotlinkUrl') or article.get('canonicalUrl')
    if sum(len(line.split()) for line in lines) < 80 and url:
        try:
            parser = Paragraphs()
            parser.feed(get(url, as_json=False))
            lines, source = parser.out, 'page'
        except Exception as error:  # noqa: BLE001 - a dead link just skips the article
            return [], f'fetch failed: {error}'
    if sum(len(line.split()) for line in lines) < 60:
        return [], f'no text ({source})'

    chunks, current_team, buffer = [], team, []

    def flush():
        if buffer:
            chunks.append((current_team, ' '.join(buffer)))
            buffer.clear()

    for line in lines:
        heading = re.fullmatch(r"([A-Za-z&' .]+):", line)
        if heading and fold(heading.group(1)) in by_name:
            flush()
            current_team = by_name[fold(heading.group(1))]
            continue
        if re.search(r'predicted line-?ups?$|^back to top$|^see:$', line, re.I):
            continue
        buffer.append(line)
        if sum(len(b.split()) for b in buffer) >= CHUNK_WORDS:
            flush()
    flush()
    return chunks, source


# --- Player names ----------------------------------------------------------

class Roster:
    def __init__(self, bootstrap):
        self.players = bootstrap['elements']
        self.by_team = {}
        for p in self.players:
            self.by_team.setdefault(p['team'], []).append(p)

    @staticmethod
    def names(p):
        full = fold(f"{p['first_name']} {p['second_name']}")
        return {fold(p['web_name']), full, fold(p['second_name']).split()[-1]}

    def match(self, name, team):
        """FPL id for a name the model wrote, or None when unknown or ambiguous."""
        name = fold(name).strip(" .'")
        if not name:
            return None
        pool = self.by_team.get(team) if team else self.players
        last = name.split()[-1]
        for test in (
            lambda p: name == fold(f"{p['first_name']} {p['second_name']}"),
            lambda p: name == fold(p['web_name']),
            lambda p: last == fold(p['second_name']).split()[-1] or last == fold(p['web_name']),
        ):
            hits = [p for p in pool if test(p)]
            if len(hits) == 1:
                return hits[0]['id']
            if len(hits) > 1:
                return None
        return None

    def mentioned(self, sentence, team):
        """Players named in a sentence; club-less text needs a full name."""
        text = fold(sentence)
        found = []
        for p in self.by_team.get(team) if team else self.players:
            full = fold(f"{p['first_name']} {p['second_name']}")
            web = fold(p['web_name'])
            if re.search(rf'\b{re.escape(full)}\b', text) or (
                team and len(web) >= 4 and re.search(rf'\b{re.escape(web)}\b', text)
            ):
                found.append(p)
        return found


# --- Extraction ------------------------------------------------------------

OUT_WORDS = re.compile(
    r"ruled out|will miss|miss(es|ed)? (out|the|this|sunday|saturday)|without|unavailable|"
    r"not ready|sidelined|suspend|surgery|out for|remain(s)? out|won'?t (be|feature)|absent|"
    r"will be out|is out|are out|injured", re.I)
DOUBT_WORDS = re.compile(
    r"doubt|assess|knock|a chance|50-50|fitness test|day by day|touch and go|"
    r"uncertain|not sure|hopes?|might|could|minor", re.I)
FIT_WORDS = re.compile(
    r"return(s|ed)?|back in|available|fit\b|fit to|ready|in contention|boost|trained|"
    r"in the squad|will start|no (fresh|new) (injury|fitness)", re.I)


def rules_extract(chunk, team, roster):
    claims = []
    for sentence in re.split(r'(?<=[.!?”"])\s+', chunk):
        players = roster.mentioned(sentence, team)
        if not players:
            continue
        if OUT_WORDS.search(sentence):
            status = 'out'
        elif DOUBT_WORDS.search(sentence):
            status = 'doubt'
        elif FIT_WORDS.search(sentence):
            status = 'fit'
        else:
            continue
        for p in players:
            claims.append({'name': p['web_name'], 'player_id': p['id'], 'status': status,
                           'evidence': sentence[:200]})
    return claims


PROMPT = """You read football news about a Premier League club's next match and \
report which players' availability is discussed.

For each player whose fitness, injury, suspension or selection status is \
mentioned, output:
- name: the player's name as written
- status: "out" (ruled out, injured, suspended, will miss the match), \
"doubt" (uncertain, being assessed, a knock, might or might not play), \
or "fit" (available, returned from injury, back in training, in contention)
- evidence: a short phrase copied word for word from the text that supports it

Skip players mentioned only for tactics or past performances. Use only the \
text below.

TEXT:
{text}"""

SCHEMA = {
    'type': 'object',
    'properties': {
        'players': {
            'type': 'array',
            'items': {
                'type': 'object',
                'properties': {
                    'name': {'type': 'string'},
                    'status': {'type': 'string', 'enum': ['out', 'doubt', 'fit']},
                    'evidence': {'type': 'string'},
                },
                'required': ['name', 'status', 'evidence'],
            },
        },
    },
    'required': ['players'],
}


def ollama_extract(chunk, team, roster, model, timings):
    body = json.dumps({
        'model': model,
        'prompt': PROMPT.format(text=chunk),
        'format': SCHEMA,
        'stream': False,
        'options': {'temperature': 0, 'num_ctx': 4096, 'num_predict': 1024},
    }).encode()
    req = urllib.request.Request(f'{OLLAMA}/api/generate', data=body,
                                 headers={'Content-Type': 'application/json'})
    started = time.monotonic()
    reply = None
    for attempt in range(2):
        try:
            with urllib.request.urlopen(req, timeout=300) as res:
                reply = json.loads(res.read())
            break
        except (urllib.error.URLError, TimeoutError) as error:
            print(f'ollama failed ({error}), attempt {attempt + 1}', file=sys.stderr)
    elapsed = time.monotonic() - started
    if reply is None:
        timings.append({'seconds': round(elapsed, 2), 'failed': True})
        return []
    timings.append({
        'seconds': round(elapsed, 2),
        'prompt_tokens': reply.get('prompt_eval_count', 0),
        'output_tokens': reply.get('eval_count', 0),
        'tokens_per_second': round(reply.get('eval_count', 0) / (reply.get('eval_duration') or 1) * 1e9, 2),
    })
    try:
        players = json.loads(reply['response']).get('players', [])
    except (json.JSONDecodeError, AttributeError):
        players = []
    folded = fold(' '.join(chunk.split()))
    claims = []
    for item in players:
        if not isinstance(item, dict) or item.get('status') not in ('out', 'doubt', 'fit'):
            continue
        evidence = fold(' '.join(str(item.get('evidence', '')).split()))
        claims.append({
            'name': item.get('name', ''),
            'player_id': roster.match(str(item.get('name', '')), team),
            'status': item['status'],
            'evidence': item.get('evidence', ''),
            'evidence_found': bool(evidence) and evidence in folded,
            'name_in_text': fold(str(item.get('name', ''))) in folded,
        })
    return claims


# --- Scoring ---------------------------------------------------------------

def score(claims, bootstrap, fixtures, live):
    by_fixture = {f['id']: f for f in fixtures}
    team_fixture = {}
    for f in fixtures:
        for team in (f['team_h'], f['team_a']):
            if team not in team_fixture or f['kickoff_time'] < team_fixture[team]['kickoff_time']:
                team_fixture[team] = f
    minutes = {e['id']: e['stats']['minutes'] for e in live['elements']}
    # A player's fixture that week, from the live data, so summer transfers
    # are scored against the club they were at; else today's club.
    fixture_of = {p['id']: team_fixture.get(p['team']) for p in bootstrap['elements']}
    for e in live['elements']:
        if e.get('explain') and e['explain'][0]['fixture'] in by_fixture:
            fixture_of[e['id']] = by_fixture[e['explain'][0]['fixture']]
    names = {p['id']: p['web_name'] for p in bootstrap['elements']}

    latest = {}
    for c in claims:
        pid = c.get('player_id')
        fixture = fixture_of.get(pid)
        if fixture is None or ts(c['published']) > ts(fixture['kickoff_time']) - LINEUP_LEAD:
            continue
        if pid not in latest or c['published'] >= latest[pid]['published']:
            latest[pid] = c

    rows, buckets = [], {'out': [], 'doubt': [], 'fit': []}
    for pid, c in latest.items():
        fixture = fixture_of[pid]
        if not (fixture['finished'] or fixture['finished_provisional']):
            continue
        played = minutes.get(pid, 0) > 0
        buckets[c['status']].append(played)
        rows.append({'player': names[pid], 'status': c['status'], 'minutes': minutes.get(pid, 0),
                     'correct': {'out': not played, 'fit': played}.get(c['status']),
                     'evidence': c['evidence'][:160], 'article': c['article']})

    def rate(values):
        return round(sum(values) / len(values), 3) if values else None

    scored = [r['correct'] for r in rows if r['correct'] is not None]
    return {
        'players_scored': len(rows),
        'out': {'n': len(buckets['out']), 'precision_did_not_play': rate([not v for v in buckets['out']])},
        'fit': {'n': len(buckets['fit']), 'precision_played': rate(buckets['fit'])},
        'doubt': {'n': len(buckets['doubt']), 'played_rate': rate(buckets['doubt'])},
        'out_fit_accuracy': rate(scored),
    }, sorted(rows, key=lambda r: (r['status'], r['player']))


# --- Main ------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--gameweek', type=int, required=True)
    parser.add_argument('--method', choices=['rules', 'ollama'], required=True)
    parser.add_argument('--model', default='qwen2.5:3b')
    parser.add_argument('--out', default='results')
    parser.add_argument('--limit', type=int, default=0, help='max chunks, for a quick local check')
    args = parser.parse_args()

    bootstrap, fixtures, live = load_fpl(args.gameweek)
    roster = Roster(bootstrap)
    by_code, by_name = team_lookup(bootstrap)
    previous = get(f'{FPL}/fixtures/?event={args.gameweek - 1}') if args.gameweek > 1 else []
    start, end = news_window(args.gameweek, fixtures, previous)
    articles = fetch_articles(start, end)

    chunks, skipped, seen = [], [], set()
    for a in articles:
        team = article_team(a, by_code, by_name)
        # Round-ups are edited after publishing, so the last edit is what counts.
        published = ts(a['date'])
        if isinstance(a.get('lastModified'), int):
            published = max(published, datetime.fromtimestamp(a['lastModified'] / 1000, timezone.utc))
        published = published.isoformat()
        parts, source = article_chunks(a, team, by_name)
        if not parts:
            skipped.append({'title': a['title'], 'reason': source})
            continue
        for chunk_team, text in parts:
            # The per-match round-up pages repeat the same paragraphs.
            if fold(text) in seen:
                continue
            seen.add(fold(text))
            chunks.append({'article': a['title'], 'published': published, 'team': chunk_team,
                           'source': source, 'text': text})
    if args.limit:
        chunks = chunks[:args.limit]
    print(f'{len(articles)} articles, {len(chunks)} chunks, {len(skipped)} skipped', file=sys.stderr)

    claims, timings = [], []
    started = time.monotonic()
    for i, chunk in enumerate(chunks, 1):
        if args.method == 'rules':
            found = rules_extract(chunk['text'], chunk['team'], roster)
        else:
            found = ollama_extract(chunk['text'], chunk['team'], roster, args.model, timings)
        for c in found:
            c.update(article=chunk['article'], published=chunk['published'])
        claims += found
        print(f'[{i}/{len(chunks)}] {len(found)} claims  {chunk["article"][:60]}', file=sys.stderr)
    total = time.monotonic() - started

    metrics, rows = score(claims, bootstrap, fixtures, live)
    label = 'rules' if args.method == 'rules' else args.model
    llm = [c for c in claims if 'evidence_found' in c]
    ok = [t for t in timings if not t.get('failed')]
    summary = {
        'method': label,
        'gameweek': args.gameweek,
        'articles': len(articles),
        'articles_skipped': len(skipped),
        'chunks': len(chunks),
        'chunk_words': sum(len(c['text'].split()) for c in chunks),
        'claims': len(claims),
        'claims_matched_to_player': sum(1 for c in claims if c.get('player_id')),
        'evidence_verbatim_rate': round(sum(c['evidence_found'] for c in llm) / len(llm), 3) if llm else None,
        'name_in_text_rate': round(sum(c['name_in_text'] for c in llm) / len(llm), 3) if llm else None,
        'extract_seconds': round(total, 1),
        'seconds_per_chunk': round(total / len(chunks), 2) if chunks else None,
        'tokens_per_second': round(sum(t['tokens_per_second'] for t in ok) / len(ok), 2) if ok else None,
        'chunks_failed': sum(1 for t in timings if t.get('failed')),
        **metrics,
    }
    import os
    os.makedirs(args.out, exist_ok=True)
    safe = re.sub(r'[^A-Za-z0-9.]+', '_', label) + f'-gw{args.gameweek}'
    with open(f'{args.out}/{safe}.json', 'w') as fh:
        json.dump({'summary': summary, 'scored': rows, 'claims': claims, 'skipped': skipped,
                   'timings': timings}, fh, indent=1, ensure_ascii=False)
    print(json.dumps(summary, indent=1))


if __name__ == '__main__':
    main()
