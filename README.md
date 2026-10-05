# Fantasy PL

Flutter client for official Fantasy Premier League data and team management.

## What is implemented

- Public data from `bootstrap-static` and `fixtures`.
- Public team lookup by `entryId` and gameweek picks; this is enough for
  personal read-only analysis without logging in.
- Official in-app WebView sign-in with OIDC Authorization Code + PKCE.
- Access/refresh tokens stored in secure storage; passwords are never stored.
- Private team lookup through `/api/me/` and `/api/my-team/{entryId}/`.
- English/Arabic UI with RTL support.
- Team and Matches screens.
- Manage team (edit button on the Team screen, signed-in manager only), for
  the next deadline through the official write endpoints:
  - Pick team: substitutions (tap or long-press drag), captain and
    vice-captain, with the official formation rules checked before saving.
  - Bench Boost and Triple Captain: played by saving the lineup with the
    chip; deselecting and saving sends `chip: null` to cancel before the
    deadline.
  - Transfers: several transfers confirmed in one request, with bank, club
    limit (3) and points-hit checks; Wildcard and Free Hit are played with the
    confirmed transfers.
- Weekly Tips use your current authenticated squad to suggest a legal starting
  XI, captain, vice-captain and bench order, with a preview on the pitch.
- Tips refresh when opened, when the app resumes, or with pull-to-refresh.
  Transfer suggestions are alternatives for one move and require current bank,
  selling prices and free-transfer data; projected gains account for hits.

## Official auth setup

The current FPL web client uses:

- Authority: `https://account.premierleague.com/as`
- Authorization Code + PKCE (`S256`)
- FPL API header: `X-API-Authorization: Bearer <access_token>`
- Writes (`POST /api/my-team/{entry}/`, `POST /api/transfers/`) also send the
  website session cookie and `X-CSRFToken` captured during the WebView
  sign-in; sign in again if writes are rejected.

The in-app flow opens the official sign-in page in a WebView and intercepts the
approved website redirect before it navigates away. The app never posts the
email or password itself; it receives an authorization code and exchanges it
with PKCE.

The sign-in page is hosted by the official Premier League site, but the app
uses that site's current web OIDC client and an embedded WebView. The service
owner may reject third-party use of that client. Do not ship or publish this
integration until the service owner approves it. A system browser with an
approved mobile client and redirect URI is the preferred production flow.

The default app button uses the in-app WebView flow and needs no email or
password configuration. The system-browser fallback needs an approved mobile
client and redirect URI; run it with the exact values:

```sh
flutter run \
  --dart-define=FPL_OIDC_CLIENT_ID=<approved-mobile-client-id> \
  --dart-define=FPL_OIDC_REDIRECT_URI=fantasypl://oauth/callback
```

The authority and sign-in page are official FPL endpoints. The current website
client id is a public client identifier, not an approval to use the client in a
third-party app.

## Android release signing

Release builds use the local `android/key.properties` and
`android/app/upload-keystore.jks` files. Keep both backed up securely; they are
ignored by Git. Build the Play bundle with:

```sh
flutter build appbundle --release
```

Push to `closed-test` to build an Android App Bundle and upload it as a draft
to the Google Play closed-testing (`alpha`) track. Workflow build numbers start
above the current Play build and keep increasing with each run.

Configure these repository secrets in GitHub Actions before the first upload:

- `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, and `KEY_ALIAS` for
  Android signing.
- Actions variables `GCP_WORKLOAD_IDENTITY_PROVIDER` and `GCP_SERVICE_ACCOUNT`
  for branch-restricted Workload Identity Federation; no service-account key is stored.

## Closed testing uploads

Push app changes to `closed-test` to build a signed Android App Bundle and
upload it as a draft to the Google Play `alpha` track. GitHub Actions requires
the repository secrets `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`,
and `KEY_ALIAS`, plus the Actions variables `GCP_WORKLOAD_IDENTITY_PROVIDER`
and `GCP_SERVICE_ACCOUNT`. Google Cloud access uses branch-restricted
Workload Identity Federation; no service-account key is stored in GitHub.
Keep releases in draft until the FPL sign-in integration is approved.

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
