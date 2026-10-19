# Mainland China: local learning distribution assessment

Reviewed against the official sources below on 2026-10-11. This document records
product boundaries and unresolved release requirements, not a guarantee of a
classification or a licensing exemption.

## Separate local learning product

`HerbertLearning` is a separately identified, original-only build for evaluating
a local programming learning tool. It contains the H editor/runtime, 50 original
exercises, explanations, local progress and JSON import/export. It does not link
HerbertCloud, HerbertBattlefield or the community catalog. It has no online
leaderboard, Apple login, Game Center, AI-provider calls, ads or in-app purchases.
On macOS it also has no outgoing-network entitlement. It uses the Education Mac
category; the App Store Connect category must describe the actual product.

Build it with the **HerbertLearning** scheme. Its bundle ID is
`info.hugogu.HerbertLearning`; configure it as a separate App Store record if you
choose this distribution. Audit each built/archive app:

```sh
python3 scripts/check_learning_bundle.py path/to/HerbertLearning.app
```

This is a compile-time product split, not a region check that hides online
features from reviewers or enables them after approval. GitHub/standard App Store
builds retain their existing features; the latter can use verified cloud rankings.
Game Center was not integrated in the project and is not added by this change.

## What this does and does not establish

Removing competition/account/network features supports a genuinely local learning
product scope. It **does not establish** that the remaining robot puzzles are
exempt from game approval. Simply selecting Education/Utilities or changing the
word “game” is not sufficient. Apple says games distributed in Mainland China
require an approval number and supporting material. Do not describe this build
as a confirmed way to bypass that requirement.

The MIIT app-filing notice also covers internet information services and explicitly
mentions education services. Education is therefore not a universal alternative
without its own requirements. Whether this entirely local programming tool falls
within a particular filing/licensing regime needs confirmation for the finished
product. Apple sign-in is an account authentication service, not Chinese real-name
verification for a regulated online game.

Before selecting Mainland availability, send Apple Developer Support/App Review
the actual product description, video/screenshots, offline architecture and
feature list, and ask which category and supporting documents are required.
Clarify any local filing/licensing obligations with the competent authority or a
qualified adviser; a personal Apple Developer membership alone does not resolve
publishing qualifications. If the product is treated as a game and approval
cannot be obtained, keep Mainland distribution disabled rather than conceal its
functionality. Do not silently transform this build into an online service later.

## Official sources

- [Apple: App information, availability in Mainland China](https://developer.apple.com/cn/help/app-store-connect/reference/app-information/app-information/)
- [MIIT: mobile internet application filing notice](https://www.gov.cn/zhengce/zhengceku/202308/content_6897341.htm)
- [Ministry of Education: educational mobile application filing measures](https://www.moe.gov.cn/srcsite/A16/s3342/201911/t20191122_409333.html)
- [Apple: App Review Guidelines](https://developer.apple.com/cn/app-store/review/guidelines/)
