# App Store submission kit

Everything needed to list **Herbot Bot**, the original-only edition built by the `HerbertAppStore`
scheme, on the App Store for iPhone, iPad and Mac. One App Store Connect record covers both
platforms (universal purchase) because both share the bundle ID `info.hugogu.Herbert`.
[Device testing and the edition boundary](../docs/app-store.md) are documented separately.

| Path | Contents |
| --- | --- |
| `metadata/<locale>/` | Name, subtitle, description, keywords, promotional text and URLs for `en-US`, `zh-Hans` and `ja` |
| `metadata/*.txt` | Copyright and categories |
| `metadata/review_information/` | App Review contact and notes |
| `screenshots/<device>/<locale>/` | Captioned screenshots for `iphone-6.3` (required), `iphone-6.9` (optional), `ipad` (13″) and `mac` |
| `screenshots/captions.json` | Screenshot order and the caption text for each language |

File names follow the [fastlane `deliver`](https://docs.fastlane.tools/actions/deliver/) layout, so
the text can be pasted into App Store Connect or uploaded later with `deliver --metadata_path
store/metadata`. Run `python3 scripts/check_store_metadata.py` after any edit. It enforces App Store
Connect limits (30-character name and subtitle, 170-character promotional text, 4,000-character
description, 100-byte keywords, 4,000-byte review notes), checks that the name starts with the
Home Screen name and that the Mac category matches the build, and validates screenshot sizes,
counts and the absence of alpha channels.

## Screenshots

```sh
scripts/capture_store_screenshots.sh            # iphone-6.3 iphone-6.9 ipad mac, en zh-Hans ja
LANGUAGES=ja scripts/capture_store_screenshots.sh mac
```

`StoreScreenshotTests` drives the real app: it solves L01–L07 with their reference programs,
shows L07 solved, the library, L18 with its first hint and a partial program, the guide, an AI
Battlefield match and the progress screen. The match uses the debug-only fixture client with
neutral names (`--battlefield-showcase`); no real provider, key or paid model is involved.
iPhone 18 Pro (1206 × 2622), iPhone 18 Pro Max (1320 × 2868) and iPad Pro 13-inch (2752 × 2064,
landscape) run in the simulator with a 9:41 status bar. The Mac window is 1680 × 1050 points; the Mac pass takes over the
mouse and keyboard for about five minutes per language, and macOS cannot enable UI automation on a
locked screen. `scripts/compose_store_screenshots.swift` then adds the captions and writes opaque
PNGs at 1206 × 2622, 1320 × 2868, 2752 × 2064 and 2880 × 1800. A `\n` in a caption sets the iPhone line break
(useful for Chinese and Japanese); the wider iPad and Mac captions join it into one line.

Upload each folder to the matching device and language. App Store Connect requires `iphone-6.3`
("iPhone with Dynamic Island, medium display": 1206 × 2622 or 1179 × 2556), `ipad` and `mac`, and
scales them to smaller devices. It rejects the 1320 × 2868 images in that slot as an invalid size.
`iphone-6.9` is optional; add it for large iPhones under "View all sizes in Media Manager".
iPhone Duo screenshots are optional for now; reports say Apple will require them from April 2027.

### Header and search artwork (optional)

The "Header and Search Results" tab (iOS 27 and later) takes optional creative assets, not
screenshots: a 21:9 header at 3840 × 1646, a 3:2 search image from 1920 × 1280 to 3840 × 2560, or
one universal 5244 × 2950 PNG for both. Only a small centered safe area is guaranteed to stay
visible, and the art must be opaque. None is prepared yet; the listing is complete without it.

Review every image before uploading: captures depend on the OS version, fonts and simulator.

## Before the first submission

1. Merge this branch to `main`. The privacy policy and support URLs point at `PRIVACY.md` and
   `SUPPORT.md` on `main`, and the app links to the same privacy policy.
2. Test on real devices with the [checklist](../docs/app-store.md#真机检查清单), ideally through
   a TestFlight build uploaded as below.
3. In App Store Connect, enter the review phone number and decide whether to give App Review a demo
   API key (see App Review below).
4. Set `DEVELOPMENT_TEAM` in `Config/Local.xcconfig`, then archive and upload:

```sh
scripts/archive_app_store.sh ios --check     # unsigned archive + bundle audit
scripts/archive_app_store.sh ios --upload    # signed upload to App Store Connect
scripts/archive_app_store.sh macos --upload
```

The script refuses to reuse an output folder, so increase `CURRENT_PROJECT_VERSION` in
`scripts/generate_project.py` and regenerate the project for every new upload. It audits the
archived app with `scripts/check_app_store_bundle.py` (exactly the 30 original puzzles, no community
archive or reference solutions), prints the version, build and export-compliance keys, and checks
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
Connect requires. Education is also accurate for 30 puzzles that build up like a course, and it avoids the game approval
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
| Version / build | 2.0.0 (15) from `scripts/generate_project.py` |
| What's New | Not shown for the first version; write `release_notes.txt` for later updates |
| App previews | None (optional) |
| Release | Manually release this version |

### Export compliance

The app uses only encryption provided by the operating system (HTTPS through `URLSession` and the
Keychain), which is exempt. Both app targets set `ITSAppUsesNonExemptEncryption = NO`, so uploads
skip the encryption questions.

### App Review

- Sign-in: not required.
- Contact: `metadata/review_information/` plus a phone number with country code.
- Notes: `metadata/review_information/notes.txt`. They explain how to play, that H programs are only
  interpreted by the game, and how AI Battlefield works. To let App Review try a real match, add a
  key with a small spending limit (for example an OpenRouter key with a credit cap) to the bracketed
  line; never put a key in the app or this repository.

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
