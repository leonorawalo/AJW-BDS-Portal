# Licences and credits

Every font, image, icon set and animation in the AJW BAGS Portal, with its source and licence. In the app, the open-source licences are under **Settings and privacy → Credits and licences**: Flutter lists every package's licence automatically, and `lib/core/legal/font_licenses.dart` adds the fonts' licences.

## Fonts

| Font | Used for | Source | Licence | Commercial use |
|---|---|---|---|---|
| Poppins Bold | headings | Google Fonts / [itfoundry/Poppins](https://github.com/itfoundry/Poppins) | SIL Open Font License 1.1 (`assets/fonts/OFL-Poppins.txt`) | yes; the licence text must ship with the font (it does, in the app's licence page) |
| Livvic Medium | sub-headings | Google Fonts / [Fonthausen/Livvic](https://github.com/Fonthausen/Livvic) | SIL OFL 1.1 (`assets/fonts/OFL-Livvic.txt`) | yes |
| Work Sans Regular and Medium | body text | Google Fonts / [weiweihuanghuang/Work-Sans](https://github.com/weiweihuanghuang/Work-Sans) | SIL OFL 1.1 (`assets/fonts/OFL-WorkSans.txt`) | yes |
| Material Icons | all interface icons | Google, bundled with Flutter | Apache License 2.0 | yes |
| Cupertino Icons | icon font a dependency uses | Flutter (`cupertino_icons` package) | MIT | yes |
| System fonts (website pages) | `system-ui` stack | the visitor's own device | not distributed | — |

The AJW Brand Guideline's own typefaces (Henderson Sans, Jeko, Ambit) are commercial MyFonts fonts with **no confirmed web or app licence**. They are not in the app, the website or git (`.gitignore` and the deploy check block them). See `DO_NOT_BREAK.md` section 8.

## Images and logos

| Asset | Source | Licence |
|---|---|---|
| AJW logo: `lib/core/branding/ajw_logo_paths.dart` (vector), `web/brand/ajw-mark.svg`, `ajw-mark-on-dark.svg`, `ajw-logo.png`, `assets/images/ajw_logo.webp` | traced from the AJW Brand Guideline PDF cover | © AJW Africa, all rights reserved; used by AJW for its own portal |
| App and web icons: `assets/launcher/*.png`, `web/icons/*.png`, `web/favicon.png` | rendered from the AJW logo above | © AJW Africa |
| Brand stripes (`lib/core/branding/brand_stripes.dart`) | drawn in code from the brand guideline's colours | © AJW Africa |

## Animations

| Animation | Source | Licence |
|---|---|---|
| Drifting dashboard shapes (`lib/core/widgets/drifting_shapes.dart`), loading dots (`ajw_loader.dart`, `web/index.html`), sign-in intro (`auth_layout.dart`) | written for this project | part of the portal's own code |

No stock photos, illustrations, Lottie files or third-party animations are used.

## Software

- **Flutter packages:** see `pubspec.yaml`. Their licences (BSD, MIT, Apache 2.0) are bundled in the build (`NOTICES`) and shown on the app's licence page.
- **Website build tools:** [marked](https://github.com/markedjs/marked) (MIT) turns `legal/*.md` into the public pages. It runs only at build time.
- **CanvasKit** (Flutter's web graphics engine, loaded from gstatic.com): BSD-3-Clause.

## Checked

17 October 2026: every asset listed above has a licence that allows commercial use. Nothing needed replacing.
