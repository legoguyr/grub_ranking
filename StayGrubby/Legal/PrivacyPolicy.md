# StayGrubby Privacy Policy

**Effective date: October 21, 2026**

StayGrubby is a private cooking journal and personal ranking app with optional friends-only social sharing. This policy describes the implemented app, including social identity, friendships, explicit cooking posts, likes, comments, blocking and reporting. It does not describe planned recipe-discovery, advertising or public-web cooking profiles.

## Information StayGrubby handles

When you create an account, StayGrubby uses Sign in with Apple and Supabase Authentication. Apple and Supabase may process an Apple account identifier, a Supabase user and session identifier, and an email address or Apple private-relay address supplied through Sign in with Apple. StayGrubby assigns a separate internal account identifier.

The app stores the cooking information you choose to enter, including dish and version names, cooking dates, notes, course and tag selections, source details, ranking comparisons, ranking results, and associated diagnostics needed to maintain your personal ranking. If you select photos, the app creates optimized JPEG display and thumbnail copies for the app and private backup.

## How information is used and stored

Your cooking library is stored on your device and synchronized to private account-scoped Supabase database and Storage services so it can be restored and kept consistent. Account ownership checks, Row Level Security, private Storage access, revision receipts, and deletion records protect that synchronization. Cooking data and photos are private by default.

StayGrubby does not currently include a conventional analytics SDK or advertising SDK, and it does not use your data for cross-app tracking or targeted advertising. Supabase and network infrastructure may process operational information such as IP addresses, request times, errors, and security logs under their own service practices.

## Sharing

StayGrubby does not automatically publish your cooking data. When you choose Share, the app renders a branded image on your device and opens the native iOS share sheet. You choose the destination. The exported image intentionally omits account identifiers, notes, source details, tags, and comparison history.

## Optional social identity and friends-only posts

You can keep using your private cooking library without setting up a social identity. If you choose one, StayGrubby stores your display name (a nickname is welcome), unique username and discovery preference. Discovery is off by default. When enabled, other signed-in users can search for your username and see your display name and relationship state. Existing friends can identify you even when discovery is off. After a username change, the old handle is reserved to your account for 30 days. StayGrubby stores mutual friend requests, friendships and blocks to enforce these choices.

An optional profile photo is social identity media, separate from your cooking photos. Only an image you select is uploaded, optimized with photo metadata removed, to separate private profile storage. It is visible to signed-in people who can see your identity through discovery, relationships or permitted social participation; blocks apply. It is not a public web avatar URL. Replacing/removing it revokes normal access to the previous version; cleanup retries and account deletion also removes profile-photo objects.

Share with Friends is a separate, explicit action from native image export. It creates a social snapshot of your dish title, version, timestamp, social identity and numerical score only when unlocked. A photo is copied to separate private social storage only when you choose to include it. Posts never give friends access to your private library, notes, tags, allergens, Sources, comparisons or sync records. Posts are available only to you and current eligible friends, subject to blocks and moderation. Turning discovery off does not remove friends. Removing a friendship or blocking someone removes normal access to each other's posts. Already viewed, copied or exported information cannot be remotely recalled; screens reflect other people's access changes on their next request/refresh, without real-time revocation.

Likes and flat comments are optional social participation. Eligible post viewers can see visible participation counts, comment text, timestamp and the commenter's display name/username; participation can reveal this minimal identity to other eligible viewers even if the commenter is not discoverable. Blocked or no-longer-eligible participants are filtered. Social engagement never changes anyone's personal ranking. Private reports identify a profile, post or comment, reason and optional limited context for StayGrubby review. The reported person cannot read raw reports or reporter details. Reporting does not automatically hide content; StayGrubby can restrict social identities or hide posts/comments during review.

## Retention and deletion

StayGrubby keeps account data while your account is active so the library can synchronize and restore. Individual cooking deletions use synchronization tombstones and receipts to prevent deleted records from returning. These synchronization records may remain while the account is active.

You can delete your shared posts without deleting private cooks. Existing snapshots do not change when you edit or re-rank a private cook; delete and share again to replace one. Deleting the source cook retires the shared post. Retired social photos lose normal access immediately; byte cleanup retries when you use the social screens or during account deletion. A comment's author or the post owner may remove it. Deleted comment text is cleared; an identifier tombstone prevents a delayed retry from recreating it. Block/removal can hide retained interactions; renewed friendship can make still-retained interactions visible again. Post/account erasure removes associated likes, comments and reports. Account deletion also removes social identity, username reservations, friendship/block references and reports involving that account. No separate moderation archive is introduced.

To permanently delete your account, open Profile → Account & sync → Delete account, confirm the request, and verify the Apple identity linked to your account. The deletion flow revokes Apple authorization, removes private cooking-photo, social-photo and profile-photo objects, deletes your account-owned database records and synchronization history, deletes the Supabase Auth user, removes the local account library on the device completing deletion, and returns the app to sign-in. An incomplete deletion is not presented as successful and can be retried. Sign out alone does not delete your account. Locally cached copies on other devices are not remotely erased by this flow.

Infrastructure providers may retain limited security logs or backup copies for their documented retention periods and legal obligations. StayGrubby does not claim control over those provider-operated retention systems.

## Service providers

StayGrubby currently uses Apple for authentication and native sharing/Photos actions, and Supabase for authentication, private database synchronization, private photo storage, and related service security. The product website uses static hosting through Cloudflare. The site requires no analytics, tracking scripts, cookies, account sign-in, or access to your cooking library; the hosting provider processes network requests to deliver it.

## Contact and public policy URL

For privacy questions or requests, email [privacy@staygrubby.com](mailto:privacy@staygrubby.com). For general app support, email [support@staygrubby.com](mailto:support@staygrubby.com).

The permanent public policy address is [staygrubby.com/privacy](https://staygrubby.com/privacy). A bundled copy is available in the app for offline reading.

Material changes to StayGrubby's data practices require this policy and the App Store privacy disclosures to be reviewed and updated.
