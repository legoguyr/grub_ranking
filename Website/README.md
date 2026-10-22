# StayGrubby public website

## Owner closeout — October 20, 2026

The owner confirms staygrubby.com is publicly deployed with operational HTTPS and appropriate HTTP/HTTPS and www/non-www routing. The canonical policy is https://staygrubby.com/privacy; privacy contact is privacy@staygrubby.com and support contact is support@staygrubby.com. The owner completed the App Store Connect App Privacy questionnaire. The ninth account-deletion migration and delete-account Edge Function v2 are deployed. **Implemented and automated/security verified; real Apple credential revocation remains physically unverified.** The owner intentionally deferred that destructive physical test; it does not block continued core development. Earlier publication/disclosure/test-pending statements below describe the prior review state, superseded by this owner closeout. No new deployment, App Store Connect action or real deletion test was performed for Cuisine.

Small static Cloudflare Pages site. No browser JavaScript, external fonts, analytics, cookies, forms, Supabase client, database, authentication, or server-side application runtime. Production is deliberately light-only cream/red/charcoal, including when the browser prefers dark appearance. The PNG is copied byte-for-byte from the app's official supplied wordmark; its typography is never recreated.

## Canonical content and build

`StayGrubby/Legal/PrivacyPolicy.md` is the single policy source. Xcode bundles that document for offline reading. `python3 Website/build.py` renders its complete contents to `Website/public/privacy.html`, and copies only the canonical logo and site CSS. Never hand-edit a generated page. Change the Markdown, run the site tests/build, and ship an app update when the bundled copy needs updating. The public link remains reachable from the in-app policy sheet, itself accessible before sign-in and from Profile. No WebView is used.

The build needs only Python 3's standard library. Run from the repository root:

```
python3 -m unittest discover -s Website -p 'test_*.py' -v
python3 Website/build.py
```

Only `Website/public` may be published. The original policy-site files are `index.html`, `privacy.html`, `support.html`, `404.html`, `_headers`, `assets/site.css`, and `assets/wordmark.png`; the current profile-link extension additionally emits `kitchen.html`, `_redirects`, and `.well-known/apple-app-site-association` as described below. The output is ignored in Git and rebuilt from reviewed sources. Never publish the repository root, `StayGrubby`, `Backend`, `supabase`, backups, or internal documentation. A top-level 404 page prevents Pages' single-page-app fallback. Pages resolves `/privacy.html` to `/privacy` and `/support.html` to `/support`; no application router or directory listing is used.

## Owner connection and publication

October 20 audit verified the Cloudflare connection and active `staygrubby.com` zone; there are no Pages projects yet. No website was published by that read-only account inspection. GitHub repository access/installation and final domain publication remain owner steps. Do not confuse the local preview with a live public policy.

1. After this checkpoint is pushed, open Cloudflare **Workers & Pages → Create application → Pages → Import an existing Git repository** (the option may be labelled **Connect to Git**).
2. Connect GitHub if needed. Restrict the Cloudflare Workers and Pages GitHub App to **Only select repositories → legoguyr/StayGrubby**. Do not grant access to unrelated repositories.
3. Select that repository. Use a Pages project name available in your account; no project ID or pages.dev hostname is assumed here.
4. Production branch: **main**. Framework preset: **None**. Root directory: the **repository root** (blank). Build command: **python3 Website/build.py**. Build output directory: **Website/public**. No environment variables, secrets, bindings or Functions are needed. Keep Web Analytics off.
5. Save/deploy. Inspect the Pages-provided HTTPS preview: `/`, `/privacy`, `/support`, a missing path returning 404, the official logo, and the policy effective date **October 20, 2026**. Confirm the response headers match `_headers` and no JavaScript/analytics is injected. Disable optional Cloudflare script injection features for this site if previously enabled at zone level.
6. In the Pages project, choose **Custom domains → Set up a custom domain → staygrubby.com**. Follow Cloudflare's generated DNS/certificate steps. Use the target Cloudflare actually provides, not a guessed DNS record. Preserve existing MX/TXT/email routing records. Wait until the domain/certificate show Active.
7. Verify `https://staygrubby.com/`, `https://staygrubby.com/privacy`, and `https://staygrubby.com/support` work without authentication. Confirm HTTP redirects to HTTPS and the policy and support email links are correct. Inspect CSP, `nosniff`, referrer and permissions headers, and ensure no unexpected requests/cookies.
8. If `www` is added later, configure a permanent canonical redirect to `https://staygrubby.com` preserving path/query. Do not maintain a second copy. The HSTS policy intentionally does not include subdomains or preload, so it does not presume unrelated subdomain readiness.
9. Supply the verified live privacy URL and support URL in App Store Connect when preparing the next approved release. This task does not submit App Privacy answers or distribute a new app.

Static Pages hosting needs no paid backend. Git integration provides repeatable builds whenever the canonical policy changes. No credential should ever be needed in this repository for website hosting. Owner authorization of the GitHub App is distinct from access through the read-only Cloudflare connector.

Current Cloudflare references: [Git integration](https://developers.cloudflare.com/pages/configuration/git-integration/), [build configuration](https://developers.cloudflare.com/pages/configuration/build-configuration/), [custom domains](https://developers.cloudflare.com/pages/configuration/custom-domains/), [static routing](https://developers.cloudflare.com/pages/configuration/serving-pages/), and [headers](https://developers.cloudflare.com/pages/configuration/headers/).

## Recipe/Tickets cycle — app-first profile-link foundation

Only profile links are enabled in this cycle: `https://staygrubby.com/@username`. The native app parses exact HTTPS routes and authenticates before requesting the server resolver. The server requires discovery, active identity/account and no block. Old slugs resolve to the same durable account and cannot be reassigned; deleted owners leave an unlinked anti-impersonation reservation. Nothing on this website reads Supabase or publishes profile/recipe/social content.

The static builder now additionally emits `kitchen.html`, `_redirects`, and `.well-known/apple-app-site-association`. The `/@*` internal rewrite serves one generic app-required landing without interpolating or validating a person's name. AASA only permits the profile route; its public app identifier is `5DSB36G7LZ.com.guyrettig.StayGrubby`, verified against the existing Xcode Team and bundle configuration. The native entitlement is `applinks:staygrubby.com`. No custom URL-scheme rotation/routing hack, JavaScript, API, analytics or web account was introduced. Privacy and support remain static.

`Website/distribution.json` deliberately contains `{"url": null}`. Once the owner supplies the **actual** approved External TestFlight public link, set `url` to that Apple HTTPS join URL, rebuild/test and deploy only `Website/public`. Later it can hold the real Apple App Store product URL without changing shared profile URLs. The builder rejects arbitrary destinations, credentials, query/fragment injection and non-HTTPS links. With no destination configured, the page honestly states that external beta access is not open yet. It does not pretend to download or open an uninstalled app. For installed apps, use the original shared URL from Messages/Mail; same-domain Safari navigation is not proof of Universal Link association.

Deployment must include the extensionless AASA response with `Content-Type: application/json`, no authentication and no redirect. Check `/@sample_name` serves the generic landing, `/privacy` remains the complete canonical policy and `/support` works. Preserve all DNS/email records and publish only the allowlisted build output. Website deployment status and Apple owner actions are recorded in `RECIPE_TICKETS_SHARING_REVIEW.md`; local output alone is not live deployment evidence.
