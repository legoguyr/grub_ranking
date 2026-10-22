# StayGrubby Privacy Policy

**Effective date: October 21, 2026**

StayGrubby is a private cooking journal and personal ranking app with optional friends-only social sharing. This policy describes the implemented app, including social identity, friendships, explicit cooking posts, likes, comments, blocking and reporting. It also covers manually created Recipes, private Tickets (Want to Cook), recipe-to-cook provenance and app-first profile links. It does not describe planned community recipe-discovery, advertising or public-web cooking profiles.

## Information StayGrubby handles

When you create an account, StayGrubby uses Sign in with Apple and Supabase Authentication. Apple and Supabase may process an Apple account identifier, a Supabase user and session identifier, and an email address or Apple private-relay address supplied through Sign in with Apple. StayGrubby assigns a separate internal account identifier.

The app stores the cooking information you choose to enter, including dish and version names, cooking dates, notes, course and tag selections, source details, ranking comparisons, ranking results, and associated diagnostics needed to maintain your personal ranking. If you select photos, the app creates optimized JPEG display and thumbnail copies for the app and private backup.

## How information is used and stored

Your cooking library is stored on your device and synchronized to private account-scoped Supabase database and Storage services so it can be restored and kept consistent. Account ownership checks, Row Level Security, private Storage access, revision receipts, and deletion records protect that synchronization. Cooking data and photos are private by default.

StayGrubby does not currently include a conventional analytics SDK or advertising SDK, and it does not use your data for cross-app tracking or targeted advertising. Supabase and network infrastructure may process operational information such as IP addresses, request times, errors, and security logs under their own service practices.

## Sharing

StayGrubby does not automatically publish your cooking data. When you choose Share, the app renders a branded image on your device and opens the native iOS share sheet. You choose the destination. The exported image intentionally omits account identifiers, notes, source details, tags, and comparison history.

## Optional social identity and friends-only posts

You can keep using your private cooking library without setting up a social identity. If you choose one, StayGrubby stores your display name (a nickname is welcome), unique username and discovery preference. Discovery is off by default. When enabled, other signed-in users can search for your username and see your display name and relationship state. Existing friends can identify you even when discovery is off. Profile share links use usernames but resolve to a separate durable account identity. Discovery must be enabled for a profile link to resolve; blocks apply. Previous usernames remain reserved against reuse so an old link cannot identify a different person. After account deletion, only an unlinked username reservation remains to prevent link impersonation; it no longer resolves to a profile. StayGrubby stores mutual friend requests, friendships and blocks to enforce these choices.

An optional profile photo is social identity media, separate from your cooking photos. Only an image you select is uploaded, optimized with photo metadata removed, to separate private profile storage. It is visible to signed-in people who can see your identity through discovery, relationships or permitted social participation; blocks apply. It is not a public web avatar URL. An unfinished uploaded draft stays private and is retired during later profile cleanup after a day of profile inactivity. Replacing/removing a published photo revokes normal access to the previous version; cleanup retries and account deletion also removes profile-photo objects.

Share with Friends is separate from native image export. You may choose an account-synced Automatically Share New Dishes default for future New Dishes and New Versions; it starts OFF for legacy/unset accounts and can be overridden for each new cook. Changing the default never publishes existing history. Publication waits until the selected cook is saved and ranked; an interrupted share can remain pending for retry without changing the private cook. It creates a social snapshot of your dish title, version, timestamp, social identity and numerical score only when unlocked. For a new cook, choosing Share with Friends (including your deliberately chosen ON default) includes its food photo when present. The existing manual composer has its own photo choice. Photos are copied to separate private social storage; your private cooking-photo objects are not made readable by friends. Posts never give friends access to your private library, notes, tags, allergens, full private Source records, comparisons or sync records. Posts are available only to you and current eligible friends, subject to blocks and moderation. Turning discovery off does not remove friends. Removing a friendship or blocking someone removes normal access to each other's posts. Already viewed, copied or exported information cannot be remotely recalled; screens reflect other people's access changes on their next request/refresh, without real-time revocation.

You may optionally write a Post Description for a shared post and edit or clear that description later. It is social content visible to the post’s authorized audience under the same friendship, blocking and moderation rules. Personal Notes belong to your private cooking record; they are never automatically copied into a Post Description or published. Profile grids show only posts the viewer is currently authorized to access. Editing a description does not change your private cook or its ranking evidence.

For new posts shared with the updated app's explicit metadata choice, a separate safe snapshot may include Course, Cuisine and public cookbook/restaurant/online recipe attribution. It excludes Friend/Family details, private notes, dietary/allergen annotations and private source URLs. Older clients and existing posts do not acquire this additional disclosure automatically. Eligible friends can use Make This to prefill those safe details for their own independent cook; source attribution does not imply the StayGrubby cook authored the recipe.

Cooked With is optional and separate from Feed publication. Selecting current friends creates invitations only after your own cook is saved and ranked. Invitations disclose the title, Course, Cuisine and safe public source attribution to the selected people. Each person chooses whether to decline or review and rank their own cook. No one receives a private cooking entry, score or comparison history merely because they were invited. StayGrubby stores stable event, participant and Recreated origin references to explain this provenance; completed participation may be shown to mutual eligible friends when a related cook is shared. Joining or recreating does not force a Feed post. You retain your own cooking/ranking if friendship or access to the original activity later changes.

In-app notifications store recipient, actor, type, target identifiers, timestamps and read state for friend requests/acceptance, shared cooking invitations/joining, completed recreations, likes and comments. They use current accessible source records rather than private notes, scores or unnecessary content snapshots. Blocks, relationship changes and deleted/inaccessible targets are applied to the list, unread count and actions. No Apple push notification service is enabled for these notices.

Likes and flat comments are optional social participation. Eligible post viewers can see visible participation counts, comment text, timestamp and the commenter's display name/username; participation can reveal this minimal identity to other eligible viewers even if the commenter is not discoverable. Blocked or no-longer-eligible participants are filtered. Social engagement never changes anyone's personal ranking. Private reports identify a profile, post or comment, reason and optional limited context for StayGrubby review. The reported person cannot read raw reports or reporter details. Reporting does not automatically hide content; StayGrubby can restrict social identities or hide posts/comments during review.

## Recipes, Tickets and cooking provenance

Recipes are separate from your private cooking library. They store the title, optional description, ingredient rows, instruction steps, Course, Cuisine, source attribution and optional HTTPS source link you deliberately enter. They do not automatically copy cooking notes, tags, allergens, photos, scores or comparisons. A Recipe is private by default; you can explicitly allow current eligible friends to read its recipe fields. Private recipe images are not uploaded or shared by this feature.

Tickets are private account-owned saves of accessible Recipes, stored in Supabase so they are available again after sign-in or restore. Saving or removing a Ticket does not cook, rank or delete a Recipe. Starting Make This only reserves provenance; the existing cooking/ranking flow creates your actual private cook. A historical recipe snapshot and revision are retained with your completed cook so later recipe edits do not rewrite its source. When an accessible social cook has an accessible Recipe, Run It Back can retain that Recipe snapshot separately from the person whose cooking inspired you. No other person's scores, comparisons, notes or private cooking photos are copied.

Deleting a Recipe removes its Tickets and nullifies the live Recipe reference in other people's recipe-cooking provenance. Their intentionally retained recipe snapshot and independently completed private cooking/ranking remain theirs. Turning sharing off or blocking a person prevents further normal recipe access; an already saved historical snapshot cannot be recalled from someone else's completed private history. Previously received copies and native exports cannot be remotely recalled.

## Retention and deletion

StayGrubby keeps account data while your account is active so the library can synchronize and restore. Individual cooking deletions use synchronization tombstones and receipts to prevent deleted records from returning. These synchronization records may remain while the account is active.

You can delete your shared posts without deleting private cooks. Existing snapshots do not change when you edit or re-rank a private cook; delete and share again to replace one. Deleting the source cook retires the shared post. Retired social photos lose normal access immediately; byte cleanup retries when you use the social screens or during account deletion. A comment's author or the post owner may remove it. Deleted comment text is cleared; an identifier tombstone prevents a delayed retry from recreating it. Block/removal can hide retained interactions; renewed friendship can make still-retained interactions visible again. Post/account erasure removes associated likes, comments and reports. Account deletion also removes social identity, linked temporary username reservations, friendship/block references and reports involving that account. Permanent profile-link reservations lose their account reference and cannot resolve or be reassigned. No separate moderation archive is introduced.

Deleting an account removes its owned Recipes and Tickets, nullifies surviving recipe references, and removes its owned Shared Cooking events/participation and actor/recipient notifications. Remaining users' social origin references are removed or nullified as appropriate, while their independently completed private cooks and ranking evidence remain theirs. Inaccessible-target notification identifiers/deduplication history and abandoned origin reservations may remain until account cleanup; they cannot recreate private cooks or expose inaccessible content.

To permanently delete your account, open Profile → Account & sync → Delete account, confirm the request, and verify the Apple identity linked to your account. The deletion flow revokes Apple authorization, removes private cooking-photo, social-photo and profile-photo objects, deletes your account-owned database records and synchronization history, deletes the Supabase Auth user, removes the local account library on the device completing deletion, and returns the app to sign-in. An incomplete deletion is not presented as successful and can be retried. Sign out alone does not delete your account. Locally cached copies on other devices are not remotely erased by this flow.

Infrastructure providers may retain limited security logs or backup copies for their documented retention periods and legal obligations. StayGrubby does not claim control over those provider-operated retention systems.

## Service providers

StayGrubby currently uses Apple for authentication and native sharing/Photos actions, and Supabase for authentication, private database synchronization, private photo storage, and related service security. The product website uses static hosting through Cloudflare. The site requires no analytics, tracking scripts, cookies, account sign-in, or access to your cooking library; the hosting provider processes network requests to deliver it.

## Contact and public policy URL

For privacy questions or requests, email [privacy@staygrubby.com](mailto:privacy@staygrubby.com). For general app support, email [support@staygrubby.com](mailto:support@staygrubby.com).

The permanent public policy address is [staygrubby.com/privacy](https://staygrubby.com/privacy). A bundled copy is available in the app for offline reading.

Material changes to StayGrubby's data practices require this policy and the App Store privacy disclosures to be reviewed and updated.
