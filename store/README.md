# App Store submission kit — 1.1.0 (15)

Everything needed to list **Herbot Bot**, the original-only edition built by the `HerbertAppStore`
scheme, on the App Store for iPhone, iPad and Mac. One App Store Connect record covers both
platforms (universal purchase) because both share the bundle ID `info.hugogu.Herbert`.
[Device testing and the edition boundary](../docs/app-store.md) are documented separately.

## Updating from 1.0.0

Use the existing App Store Connect record. For iOS, create version **1.1.0** under the already released app. For macOS, if 1.0.0 is still an unapproved first submission, update that editable draft to **1.1.0** and replace its build; do not create a second app record. Confirm the displayed platform status before proceeding.
Select build **15** for each platform once uploaded; if that build number has already been used for
another upload, increment it in `scripts/generate_project.py` and regenerate before archiving.

The English, Simplified Chinese and Japanese descriptions, promotional text and `release_notes.txt`
now cover 50 original puzzles in ten chapters, the new 3D board and enlarged stage, and AI Battlefield
improvements. Paste `release_notes.txt` into **What's New in this Version** for the iOS update; the initial Mac release does not show that field.
The review notes include the changes and instructions for testing them, without assuming that a new
screen recording or demo key has been supplied.

All **96 screenshots** have been recaptured from **1.1.0 (15)** and visually inspected: eight scenes
for each of four device sets in English, Simplified Chinese and Japanese. iPhone and iPad images
come from the iOS 27 simulator; Mac images come from the native app. Every device/language folder
includes a `capture.json` with the version, build, source commit and image hashes. Before uploading, run:

```sh
python3 scripts/check_store_metadata.py --require-current-screenshots
```

This submission check requires every current scene and locale, the current version/build, matching
caption and image hashes, and capture manifests. The ordinary check below validates metadata and image
format only; passing it does not mean the screenshots have been refreshed.

| Path | Contents |
| --- | --- |
| `metadata/<locale>/` | Name, subtitle, description, keywords, promotional text, 1.1.0 release notes and URLs for `en-US`, `zh-Hans` and `ja` |
| `metadata/*.txt` | Copyright and categories |
| `metadata/review_information/` | App Review contact and notes |
| `screenshots/<device>/<locale>/` | Captioned screenshots for `iphone-6.3` (required), `iphone-6.9` (optional), `ipad` (13″) and `mac` |
| `screenshots/captions.json` | Eight-scene screenshot order and caption text for each language |
| `screenshots/<device>/<locale>/capture.json` | Generated version/build and screenshot hashes after a successful new capture |

File names follow the [fastlane `deliver`](https://docs.fastlane.tools/actions/deliver/) layout, so
the text can be pasted into App Store Connect or uploaded later with `deliver --metadata_path
store/metadata`. Run `python3 scripts/check_store_metadata.py` after any edit. It enforces App Store
Connect limits (30-character name and subtitle, 170-character promotional text, 4,000-character
description and release notes, 100-byte keywords, 4,000-byte review notes), checks that the name starts with the
Home Screen name and that the Mac category matches the build, and validates screenshot sizes,
counts and the absence of alpha channels.

## Screenshots

```sh
scripts/capture_store_screenshots.sh            # iphone-6.3 iphone-6.9 ipad mac, en zh-Hans ja
scripts/capture_store_screenshots.sh iphone-6.3 iphone-6.9 ipad  # simulator pass only
LANGUAGES=ja scripts/capture_store_screenshots.sh mac
```

`StoreScreenshotTests` drives the real app: it solves L01–L07 with their reference programs and captures
these scenes in order:

1. L07 solved in Modern style, with the actual program and trail.
2. The same completed board in the enlarged 3D stage.
3. The course library with 50 puzzles.
4. L41, introducing the new synthesis course, with its goal and unsolved board.
5. L18 with its first hint and a partial program.
6. The language guide.
7. An AI Battlefield match, including the updated output-speed headers.
8. The progress screen.

The match uses the debug-only fixture client with
neutral names (`--battlefield-showcase`); no real provider, key or paid model is involved.
iPhone 18 Pro (1206 × 2622), iPhone 18 Pro Max (1320 × 2868) and iPad Pro 13-inch (2752 × 2064,
landscape) run in the simulator with a 9:41 status bar. The Mac window is 1680 × 1050 points; the Mac pass takes over the
mouse and keyboard for about five minutes per language, and macOS cannot enable UI automation on a
locked screen. Ask before starting the native Mac pass while someone is using the Mac; run all native
UI automation sequentially. The script checks the built app version, uses fresh capture folders and
versioned DerivedData, and keeps a separate test log for every device/language. It composes into a
temporary folder, then replaces only the successfully generated device/language sets (including
obsolete scene filenames) and writes their manifests. It never reuses cached 1.0.0 captures.
`scripts/compose_store_screenshots.swift` adds the captions and writes opaque
PNGs at 1206 × 2622, 1320 × 2868, 2752 × 2064 and 2880 × 1800. A `\n` in a caption sets the iPhone line break
(useful for Chinese and Japanese); the wider iPad and Mac captions join it into one line.

Upload each folder to its matching device and language. This listing's medium Dynamic Island
slot uses `iphone-6.3` (1206 × 2622); `iphone-6.9` (1320 × 2868) belongs in the large Dynamic Island
slot under "View all sizes in Media Manager". The sizes are not interchangeable. Both iPhone
sets, the 13-inch iPad set and the Mac set are included in this kit. Confirm the required slots
shown for the app in App Store Connect against [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).
Apple currently states that iPhone Duo screenshots become required in April 2027 for apps built
with the iOS 27.1 SDK or later; they are outside this Xcode 27.0 capture pass.

### Header and search artwork (optional)

The "Header and Search Results" tab (iOS 27 and later) takes optional creative assets, not
screenshots: a 21:9 header at 3840 × 1646, a 3:2 search image from 1920 × 1280 to 3840 × 2560, or
one universal 5244 × 2950 PNG for both. Only a small centered safe area is guaranteed to stay
visible, and the art must be opaque. None is prepared yet; the listing is complete without it.

Review every image before uploading: captures depend on the OS version, fonts and simulator.

## Before submitting 1.1.0

1. Check the GitHub privacy policy and the dedicated support page at `https://www.hugogu.cn/apps/herbot-bot/support/`.
   Update both platforms' localized text; use What's New where available (the initial Mac release has no What's New field). The product-naming fix from PR #21 is included in this branch; archive its Herbot Bot.app product.
2. Use the refreshed screenshots and pass the strict submission check above. Recapture them if the visible app or caption text changes.
3. Test on real devices with the [checklist](../docs/app-store.md#真机检查清单), ideally through
   a TestFlight build uploaded as below.
4. Verify the App Review contact phone number and the updated review notes. If supplying a temporary
   demo API key, enter it directly in App Store Connect; never commit it here.
5. Set `DEVELOPMENT_TEAM` in `Config/Local.xcconfig`, then archive and upload:

```sh
scripts/archive_app_store.sh ios --check     # unsigned archive + bundle audit
scripts/archive_app_store.sh ios --upload    # signed upload to App Store Connect
scripts/archive_app_store.sh macos --upload
```

The script refuses to reuse an output folder, so increase `CURRENT_PROJECT_VERSION` in
`scripts/generate_project.py` and regenerate the project for every new upload. It audits the
archived `Herbot Bot.app` with `scripts/check_app_store_bundle.py` (product/display/bundle/executable
names are `Herbot Bot`, Bundle ID remains `info.hugogu.Herbert`, exactly 50 original puzzles, no community
archive or reference solutions), prints its identity, version, build and export-compliance keys, and checks
the Mac sandbox. Without `--upload` it exports an `.ipa` or `.pkg` you can send with Transporter.
Uploading requires an Xcode account with App Manager access; automatic signing may create
distribution certificates for the team.

## App Store Connect values

### New app

| Field | Value |
| --- | --- |
| Platforms | iOS and macOS |
| Name | `metadata/en-US/name.txt`: Herbot Bot: Code Puzzles |
| Primary language | English (U.S.) |
| Bundle ID | `info.hugogu.Herbert` (registered automatically by Xcode signing, or under Identifiers) |
| SKU | `herbot-bot` (internal, cannot change later) |

App names must be unique on the store. A search of the US store on October 12, 2026 found no app
named "Herbot Bot".

### App Information

| Field | Value |
| --- | --- |
| Subtitle (localized) | `metadata/<locale>/subtitle.txt` |
| Privacy Policy URL (localized) | `metadata/<locale>/privacy_url.txt` |
| Category | Primary **Education**; secondary **Games** with **Puzzle** and **Educational** |
| Content Rights | **Yes**, the app accesses third-party content (responses from AI providers that users configure); **yes**, the necessary rights are held. All bundled lessons and artwork are first-party (MIT) |
| Age Rating | See below |
| License Agreement | Apple's standard EULA |

The Mac build declares `public.app-category.education`, matching the primary category as App Store
Connect requires. Education is also accurate for 50 puzzles that build up like a course, and it avoids the game approval
number that China mainland requires for apps in Games; see China mainland below.

### Age rating

Answer **None** or **No** to every item, which yields **4+**:

- In-app controls: no parental controls and no age assurance.
- Capabilities: no unrestricted web access (links open Safari), no user-generated content shared
  with others, no social media, no messaging or chat, no advertising.
- Mature themes, medical or wellness, sexuality or nudity, violence and chance-based activities
  (including contests and loot boxes): none.

Apple asks developers to weigh AI features when estimating sensitive content. AI Battlefield only
displays responses from providers the user configures, to a fixed prompt that asks for an H program;
users can add their own prompt text. If App Review asks for a higher rating because model output is
not filtered, override to **13+** rather than removing the feature. Do not choose Made for Kids.

### App Privacy

Choose **"No, we do not collect data from this app."** Apple defines collection as data sent off the
device in a way that the developer or its third-party partners (SDKs and vendors whose code is in
the app) can access. The app has no developer server, analytics or SDK. AI Battlefield sends
requests straight from the device to providers the user chooses, with the user's own key, and the
developer never receives them. These flows are disclosed in [PRIVACY.md](../PRIVACY.md) and in the
app before a match starts, which also covers Guideline 5.1.2(i) on sharing data with third-party AI.
`Herbert/PrivacyInfo.xcprivacy` declares no tracking, no collected data and the UserDefaults reason
`CA92.1`.

### Pricing and availability

- Price **Free** (recommended); there are no in-app purchases or ads.
- Availability: all countries and regions **except China mainland** for the first release.
- Keep the iPad app off Apple Vision Pro unless it has been tested there. The native Mac app
  replaces the "iPhone and iPad apps on Apple silicon Macs" option.
- EU Digital Services Act: declare whether you are a trader; traders' contact details are shown to
  EU customers.

### Version information (both platforms)

| Field | Value |
| --- | --- |
| Screenshots | `screenshots/<device>/<locale>/` |
| Promotional text, description, keywords | `metadata/<locale>/` |
| Support URL, marketing URL | `metadata/<locale>/support_url.txt`, `marketing_url.txt` |
| Copyright | `metadata/copyright.txt`: 2026 Hugo Gu |
| Version / build | 1.1.0 (15) from `scripts/generate_project.py` |
| What's New | `metadata/<locale>/release_notes.txt` for the iOS update; not shown for an initial Mac release |
| App previews | None (optional) |
| Release | Manually release this version |

### Export compliance

The app uses only encryption provided by the operating system (HTTPS through `URLSession` and the
Keychain), which is exempt. Both app targets set `ITSAppUsesNonExemptEncryption = NO`, so uploads
skip the encryption questions.

### App Review

- Sign-in: not required.
- Contact: `metadata/review_information/` plus a phone number with country code.
- Notes: `metadata/review_information/notes.txt`. They explain the 1.1.0 changes, test steps, purpose,
  external services, regional consistency and content rights. Paste into the Notes field for both
  platforms. If providing a temporary key with a small spending limit for a real match, add its
  provider type, URL, model and key directly in App Store Connect. No key belongs in this repository.

#### Screen recording for App Review

Record on a physical iPhone running the latest iOS, with Screen Recording from Control Center, and
attach the movie to the reply. Two to three minutes is enough.

1. Remove Herbot Bot from the app switcher, start recording on the Home Screen, then open the app:
   the recording must begin with the launch.
2. Problems: tap "Take the first step" (L01). Scroll the program editor near the top of the screen
   first, because the keyboard and the Run bar cover its lower half. Tap the s key, tap Run, then
   open the next puzzle.
3. L02: tap "Show the next hint", enter `rsslsslss` and run it. Open and close "Game rules".
4. Show the Problems list with its checkmarks, scroll the Guide, and in Progress tap Export, then
   cancel the share sheet.
5. AI Battlefield: add a provider (the key field is masked), save to load models, choose one or two
   models and L01–L02 under New, and tap "Agree & start match"; open an answer when it finishes.
   Without a key, show the provider form and the match consent instead.
6. For an updated 1.1.0 recording, show a new lesson (L31 or L41), the 3D board and enlarged stage.
   During a real match, show single-answer cancellation and retry. Attach a recording only after
   making it; the review notes do not claim that an updated recording is attached.

## China mainland

Leave China mainland out of the first release:

- App Store Connect requires an **ICP filing number** (MIIT) for some apps distributed there, matched
  against the Simplified Chinese metadata.
- **Games** need an NPPA approval number. Education as the primary category avoids that, but a
  Games secondary category may still be treated as a game; drop it if you add China later.
- AI Battlefield connects to generative-AI services such as OpenAI-, Anthropic- and Gemini-compatible
  APIs. In 2023 Apple removed comparable bring-your-own-key clients from the China storefront for
  lacking permits, and Chinese rules require filing for generative-AI services.

Revisit after the ICP filing and a decision on how AI Battlefield should behave in China, ideally
with local advice. Simplified Chinese metadata still serves Chinese-speaking customers in other
storefronts.

## Accessibility Nutrition Labels

These are optional for now. Declare only features verified on devices: the app always uses a light
appearance, so do not claim Dark Interface. VoiceOver, Larger Text and Reduced Motion still need the
device checks listed in the testing checklist.
