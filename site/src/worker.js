// Serves the static site and web app, and proxies the official FPL API and
// images. FPL sends no CORS headers, so the web app loads them through these
// same-origin paths instead.
const ROUTES = [
  // Public data changes during live matches, so it is cached only briefly.
  { prefix: '/api/', upstream: 'https://fantasy.premierleague.com/api/', cacheSeconds: 60 },
  { prefix: '/fpl/dist/img/', upstream: 'https://fantasy.premierleague.com/dist/img/', cacheSeconds: 86400 },
  {
    prefix: '/pl-resources/premierleague/badges/',
    upstream: 'https://resources.premierleague.com/premierleague/badges/',
    cacheSeconds: 86400,
  },
];

// Paths owned by the Flutter app (see lib/core/app/routes.dart). They all
// load the app's page, which then routes on the path itself.
const APP_PATHS = [
  /^\/(login|login\/web|splash)\/?$/,
  /^\/team\/\d+\/?$/,
  /^\/(home|tips|matches|leagues|settings)(\/[\w-]+)*\/?$/,
];

const SITE = 'https://fpl-pro.muhammadessam.me';

// Link previews for the app's routes. Every route serves the same page, so its
// title, description and URLs are filled in here. Only the sign-in page is
// indexed; the rest are behind sign-in or per-user.
const APP_META = {
  '/login': ['Sign in', 'Open FPL Pro in your browser: enter your Fantasy Premier League team ID to see your squad on the pitch, captain and transfer suggestions, and match predictions.'],
  '/home': ['My team', 'Your Fantasy Premier League squad on a real pitch, with gameweek, average and highest scores.'],
  '/home/manage': ['Manage team', 'Pick your lineup, captain and chips, with FPL rules checked before anything is saved.'],
  '/tips': ['Gameweek plan', 'Captain, chip and transfer suggestions for the next gameweek, with the reasoning shown.'],
  '/tips/analysis': ['Gameweek analysis', 'How your squad is expected to score next gameweek, and what would change it.'],
  '/tips/players': ['Top picks', 'The best-value Fantasy Premier League players by position for the coming gameweeks.'],
  '/tips/compare': ['Compare players', 'Compare Fantasy Premier League players side by side before you transfer.'],
  '/matches': ['Fixtures and predictions', 'Premier League fixtures, live scores and match predictions for every gameweek.'],
  '/leagues': ['Leagues', 'Your Fantasy Premier League classic and head-to-head league standings.'],
  '/settings': ['Settings', 'Language, theme and account settings for FPL Pro.'],
  '/settings/privacy': ['Privacy', 'How FPL Pro handles your data.'],
};

function appMeta(pathname) {
  const path = pathname.replace(/\/+$/, '') || '/';
  const team = path.match(/^\/team\/(\d+)$/);
  if (team) {
    return {
      path,
      title: `FPL team ${team[1]} – FPL Pro`,
      description: 'See this Fantasy Premier League squad on the pitch, with points per player, in FPL Pro.',
      index: false,
    };
  }
  const known = APP_META[path] ? path : '/login';
  const [title, description] = APP_META[known];
  return { path: known, title: `${title} – FPL Pro`, description, index: known === '/login' };
}

// Sets `attribute` to `value` on every element matching one of `selectors`.
function setAll(rewriter, selectors, attribute, value) {
  for (const selector of selectors) {
    rewriter.on(selector, { element: (e) => e.setAttribute(attribute, value) });
  }
  return rewriter;
}

function withAppMeta(page, pathname) {
  const meta = appMeta(pathname);
  const href = SITE + meta.path;
  const rewriter = new HTMLRewriter().on('title', { element: (e) => e.setInnerContent(meta.title) });
  setAll(rewriter, ['meta[property="og:title"]', 'meta[name="twitter:title"]'], 'content', meta.title);
  setAll(
    rewriter,
    ['meta[name="description"]', 'meta[property="og:description"]', 'meta[name="twitter:description"]'],
    'content',
    meta.description,
  );
  setAll(rewriter, ['meta[property="og:url"]'], 'content', href);
  setAll(rewriter, ['link[rel="canonical"]'], 'href', href);
  setAll(rewriter, ['meta[name="robots"]'], 'content', meta.index ? 'index,follow,max-image-preview:large' : 'noindex,follow');
  return rewriter.transform(page);
}

// The site's pages switch language in the browser, so crawlers would always
// see English. For ?lang=ar, swap in the Arabic text each tag keeps in data-ar.
function withArabicMeta(page) {
  let title = null;
  return new HTMLRewriter()
    .on('html', {
      element(e) {
        title = e.getAttribute('data-title-ar');
        e.setAttribute('lang', 'ar');
        e.setAttribute('dir', 'rtl');
      },
    })
    .on('title', { element: (e) => title && e.setInnerContent(title) })
    .on('[data-ar]', {
      element(e) {
        e.setAttribute(e.tagName === 'link' ? 'href' : 'content', e.getAttribute('data-ar'));
      },
    })
    .transform(page);
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // The app used to live at /app/#/...; send old links to its login page.
    if (url.pathname === '/app' || url.pathname.startsWith('/app/')) {
      return Response.redirect(new URL('/login', url), 301);
    }
    if (APP_PATHS.some((pattern) => pattern.test(url.pathname))) {
      const page = await env.ASSETS.fetch(new Request(new URL('/app', url), request));
      const headers = new Headers(page.headers);
      // The page is tiny and must pick up new builds right away.
      headers.set('Cache-Control', 'no-cache');
      return withAppMeta(new Response(page.body, { status: page.status, headers }), url.pathname);
    }
    if (url.searchParams.get('lang') === 'ar') {
      const page = await env.ASSETS.fetch(request);
      const isHtml = (page.headers.get('content-type') || '').startsWith('text/html');
      return isHtml ? withArabicMeta(page) : page;
    }

    const route = ROUTES.find((r) => url.pathname.startsWith(r.prefix));
    if (!route) {
      return env.ASSETS.fetch(request);
    }

    // Only public, read-only resources: no cookies or auth headers are
    // forwarded, so the proxy can never act on someone's account.
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Method not allowed', {
        status: 405,
        headers: { Allow: 'GET, HEAD' },
      });
    }

    const target = route.upstream + url.pathname.slice(route.prefix.length) + url.search;
    const upstream = await fetch(target, {
      method: request.method,
      headers: {
        Accept: request.headers.get('Accept') || '*/*',
        'User-Agent': 'FPL Pro web (+https://fpl-pro.muhammadessam.me)',
      },
      cf: { cacheTtl: route.cacheSeconds, cacheEverything: true },
    });

    const headers = new Headers();
    for (const name of ['content-type', 'etag', 'last-modified']) {
      const value = upstream.headers.get(name);
      if (value) headers.set(name, value);
    }
    headers.set('Cache-Control', `public, max-age=${route.cacheSeconds}`);
    headers.set('X-Content-Type-Options', 'nosniff');
    return new Response(upstream.body, {
      status: upstream.status,
      headers,
    });
  },
};
