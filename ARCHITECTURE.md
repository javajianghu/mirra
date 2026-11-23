# Mirra architecture

Mirra is an NSGo app for macOS, iOS, Android and Windows that puts a face, an outfit and a pose from three public reference galleries together and has an image model, from one of the main providers or on the user's own server, draw the person they describe. It is a single Go module in `apps/mirra`; its website is in `apps/website`.

## Code map

| Path | Responsibility |
| --- | --- |
| `apps/mirra/go.mod`, `apps/mirra/nsgo.yaml` | The only Go module and the packaging configuration; run Go and the `nsgo` tool in `apps/mirra`. |
| `apps/mirra/app.go` | Entry point; the app's state, the choice of layout by window width, generating, saving, starring and deleting a picture. |
| `apps/mirra/backgrounds.go`, `apps/mirra/backgrounds/` | The backgrounds the app ships, embedded: public domain scenes with no one in them, by group. |
| `apps/mirra/gallery.go` | Reading the three galleries' indexes live, which items are adults-only, and the chips each filters by. |
| `apps/mirra/generate.go` | The request: the prompt, the reference images in order, and OpenAI's multipart `/images/edits`. |
| `apps/mirra/sheet.go` | A sheet of all angles: the pose's angles joined side by side into one reference, and its landscape size. |
| `apps/mirra/apis.go` | The other providers' image APIs: Gemini, Volcengine Ark, xAI, OpenRouter, Model Studio and Azure OpenAI. |
| `apps/mirra/providers.go` | The preset providers, with their logos from `ai-logo`, and the settings and keys each keeps, carried over from the cloud or local service of earlier versions. |
| `apps/mirra/service.go` | The connection test and the list of image models in each provider's protocol. |
| `apps/mirra/store.go` | Where pictures are kept: files natively, memory in a browser, where the WebAssembly build has no file system. |
| `apps/mirra/works.go` | The lookbook: pictures named by when they were made, with a JSON sidecar for their number, star and look. |
| `apps/mirra/wardrobe.go` | Favorite outfits, photos of the user's own clothes, and what the look is wearing. |
| `apps/mirra/library.go` | What both layouts share: labels, a gallery's chips and grid, the look's rows, the service's status and Generate. |
| `apps/mirra/phone.go` | The phone layout: Studio, its three-step editor and the tab bar. |
| `apps/mirra/desktop.go` | The desktop studio: top bar, library, zoomable canvas or result, and the look's summary, in columns sized by the window and resized by dragging. |
| `apps/mirra/pages.go` | A result, Works and the settings: the AI service in cards of rows under a header with the connection's state, the app-wide settings, About and the sources. |
| `apps/mirra/language.go` | The language setting: the system's or one of the catalogs', kept in storage and set at start. |
| `apps/mirra/theme.yaml` | The dark amber theme the app always shows. |
| `apps/mirra/locales/` | NSGo message catalogs, English the source, in eleven languages, and the accessors the `nsgo` tool writes from them. |
| `apps/mirra/assets/`, `apps/mirra/tools/appicon` | The app icon and the program that draws it. |
| `apps/mirra/*_test.go` | Headless and target tests; `fixtures_test.go` fakes the galleries and the image API. |
| `screenshots/` | The README's and the website's screenshots. |
| `apps/website/` | The website: TanStack Start prerendered to static pages in Chinese, English and Japanese, published by `.github/workflows/website.yml`. |
| `apps/website/src/i18n/copy.ts` | The website's words in each language. |
| `apps/website/src/components/` | The website's sections, from the hero to the FAQ. |
| `apps/website/vite.config.ts` | The build: the site's address and Pages path, the pages it prerenders and the sitemap, and the version, stars, contributors and latest release's files it reads. |
| `apps/website/src/i18n/head.ts` | Each page's title, description, canonical and alternate links, Open Graph and Twitter cards and structured data. |
| `.github/workflows/ci.yml`, `package.yml`, `release.yml` | CI on pull requests and `main`; the packages of every platform, with a release's signed appcasts; the release of `main` once CI passes, versioned from its Conventional Commits. |
| `.github/scripts/` | The release's version (`next-version.sh`, `set-version.sh`), its notes from `CHANGELOG.md` (`changelog.sh`) and their test. |
| `scripts/build-macos.sh`, `scripts/build-windows.sh` | The local builds of the desktop installers: the macOS disk images for Apple Silicon and Intel, and the Windows installers for x86-64 and ARM64, each with nsgo build. |
| `apps/website/src/routes/og.$lang.tsx`, `apps/website/scripts/og.sh` | The 1200x630 card each language's Open Graph image is taken from, served by the dev server only, and the script that takes them into `public/`. |

## Boundaries

- Ship no gallery image. Read each gallery's index live, show thumbnails from the gallery while browsing, and download a full image only for the request that uses it.
- Ship only public domain backgrounds with no one in them, listed in NOTICE.md, besides the icon.
- Never put a person's photo in a request: the pose and outfit galleries' terms forbid depicting real people with their images. Faces come from the CC0 face gallery; photos the user adds are of clothes.
- Do network and file work on a goroutine and hand results back with `cx.Post`; never block a builder or a handler.
- Keep API keys in `cx.Secrets()`, never in storage. A browser has none, so the web build keeps the key in memory for the page and says so.
- Keep pictures through `pictures` (`store.go`), never with `os` directly: the web build has no file system.
- Take colors from the theme. Choose the layout from the window's width (`wideWidth`), not the device.
- Keep the website to what the app does, and show on it no pose or outfit gallery image: its pictures are CC0 faces and the app's own screenshots.

## Core flows

**A look.** The galleries load as resources at start. Choosing a face, an outfit, a pose and a background sets the studio's signals; only the pose is required, and without a background the style sets the scene. The background goes last among the request's images, so the others keep their numbers.

**Generate.** Without a configured service, Generate opens the settings. Otherwise it downloads the chosen full images, for a sheet of all angles every angle of the pose joined side by side into one, sends them with the prompt to the chosen provider's API and writes the picture to the results folder, where it waits. Generate again and the outfit swap make the same request again, the swap with another outfit. Cancel stops the request through its context.

**Save.** Saving moves the picture into the works folder under the next number and writes its sidecar; starring an unsaved picture saves it first. Opening a work brings back its look.

**Updates.** The desktop and Android copies update themselves from the latest release's `appcast-<target>.xml`, signed with the key whose public half is `nsgo.yaml`'s `updates.key`: Sparkle and WinSparkle on their daily schedule, Android as it starts, and About's Check for updates through `updater.Check`. The web build is always the latest and the iOS app is built from source, so neither offers the check.

**Service.** The service is one of the preset providers, each with its own key, address, model and size; a server the user runs may take no key. The connection test asks the provider's models, or sends Ark and Model Studio an empty request; changing the provider or any of its settings marks the service untested again.

**Wardrobe.** Favorites are kept in storage as JSON. Added clothes are copied into the uploads folder and numbered by age; their full image is read from disk when generating.
