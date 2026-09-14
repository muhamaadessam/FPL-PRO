# Fantasy PL

Flutter client for read-only official Fantasy Premier League data.

## What is implemented

- Public data from `bootstrap-static` and `fixtures`.
- Public team lookup by `entryId` and gameweek picks; this is enough for
  personal read-only analysis without logging in.
- Official in-app WebView sign-in with OIDC Authorization Code + PKCE.
- Access/refresh tokens stored in secure storage; passwords are never stored.
- Private team lookup through `/api/me/` and `/api/my-team/{entryId}/`.
- English/Arabic UI with RTL support.
- Read-only Team and Matches screens.

## Official auth setup

The current FPL web client uses:

- Authority: `https://account.premierleague.com/as`
- Authorization Code + PKCE (`S256`)
- FPL API header: `X-API-Authorization: Bearer <access_token>`

The in-app flow opens the official sign-in page in a WebView and intercepts the
approved website redirect before it navigates away. The app never posts the
email or password itself; it receives an authorization code and exchanges it
with PKCE.

This is suitable for a personal experiment, but the provider may reject an
embedded WebView. A system browser with an approved mobile redirect is the
preferred production flow.

The default app button uses the in-app WebView flow and needs no email or
password configuration. The system-browser fallback needs an approved mobile
client and redirect URI; run it with the exact values:

```sh
flutter run \
  --dart-define=FPL_OIDC_CLIENT_ID=<approved-mobile-client-id> \
  --dart-define=FPL_OIDC_REDIRECT_URI=fantasypl://oauth/callback
```

The authority is the official FPL OIDC authority. The current website client
id is kept as a documented reference. Do not ship or publish this integration
before the service owner approves the client and redirect URI.

## Run and verify

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Public matches and post-deadline team picks work without signing in. Enter the
number from your official team URL, for example
`fantasy.premierleague.com/entry/1234567/`. Private data such as the current
unpublished team, bank, and transfers requires a valid official OIDC session.
