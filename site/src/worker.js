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
      return new Response(page.body, { status: page.status, headers });
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
