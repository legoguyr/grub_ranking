# StayGrubby Privacy Policy

**Effective date: October 20, 2026**

StayGrubby is a private cooking journal and personal ranking app. This policy describes the current Version 1 app. It does not describe planned social, recipe-discovery, advertising, or public-profile features because those features are not in the app.

## Information StayGrubby handles

When you create an account, StayGrubby uses Sign in with Apple and Supabase Authentication. Apple and Supabase may process an Apple account identifier, a Supabase user and session identifier, and an email address or Apple private-relay address supplied through Sign in with Apple. StayGrubby assigns a separate internal account identifier.

The app stores the cooking information you choose to enter, including dish and version names, cooking dates, notes, course and tag selections, source details, ranking comparisons, ranking results, and associated diagnostics needed to maintain your personal ranking. If you select photos, the app creates optimized JPEG display and thumbnail copies for the app and private backup.

## How information is used and stored

Your cooking library is stored on your device and synchronized to private account-scoped Supabase database and Storage services so it can be restored and kept consistent. Account ownership checks, Row Level Security, private Storage access, revision receipts, and deletion records protect that synchronization. Cooking data and photos are private by default.

StayGrubby does not currently include a conventional analytics SDK or advertising SDK, and it does not use your data for cross-app tracking or targeted advertising. Supabase and network infrastructure may process operational information such as IP addresses, request times, errors, and security logs under their own service practices.

## Sharing

StayGrubby does not automatically publish your cooking data. When you choose Share, the app renders a branded image on your device and opens the native iOS share sheet. You choose the destination. The exported image intentionally omits account identifiers, notes, source details, tags, and comparison history.

## Retention and deletion

StayGrubby keeps account data while your account is active so the library can synchronize and restore. Individual cooking deletions use synchronization tombstones and receipts to prevent deleted records from returning. These synchronization records may remain while the account is active.

To permanently delete your account, open Profile → Account & sync → Delete account, confirm the request, and verify the Apple identity linked to your account. The deletion flow revokes Apple authorization, removes private cooking-photo objects, deletes your account-owned database records and synchronization history, deletes the Supabase Auth user, removes the local account library on the device completing deletion, and returns the app to sign-in. An incomplete deletion is not presented as successful and can be retried. Sign out alone does not delete your account. Locally cached copies on other devices are not remotely erased by this flow.

Infrastructure providers may retain limited security logs or backup copies for their documented retention periods and legal obligations. StayGrubby does not claim control over those provider-operated retention systems.

## Service providers

StayGrubby currently uses Apple for authentication and native sharing/Photos actions, and Supabase for authentication, private database synchronization, private photo storage, and related service security. The product website uses static hosting through Cloudflare. The site requires no analytics, tracking scripts, cookies, account sign-in, or access to your cooking library; the hosting provider processes network requests to deliver it.

## Contact and public policy URL

For privacy questions or requests, email [privacy@staygrubby.com](mailto:privacy@staygrubby.com). For general app support, email [support@staygrubby.com](mailto:support@staygrubby.com).

The permanent public policy address is [staygrubby.com/privacy](https://staygrubby.com/privacy). A bundled copy is available in the app for offline reading.

Material changes to StayGrubby's data practices require this policy and the App Store privacy disclosures to be reviewed and updated.
