# Mirra

Mirra (镜衣) is an NSGo app that puts a face, an outfit and a pose from three reference galleries together and has an image model draw the result. Read [ARCHITECTURE.md](ARCHITECTURE.md) before changing code.

## Principles

- Keep each app under `apps/`: the Go code, `nsgo.yaml` and runtime payload of Mirra in `apps/mirra`; run Go and NSGo commands there.
- The website lives in `apps/website`, built with TanStack Start and Bun; install and run its scripts there. Build web front ends with the TanStack stack, never Astro.
- Keep documentation at the repository root.
- The desktop installers are built by `scripts/build-macos.sh` and `scripts/build-windows.sh`, which run `nsgo build` for both architectures of their platform.
- Follow the galleries' terms (see [NOTICE.md](NOTICE.md)): no gallery image in the repository, no photo of a person in a request.
- Use NSGo's `ui` components with the app's theme; put every user-visible word in `apps/mirra/locales/`.
- Keep the README's screenshots free of pose and outfit gallery images; faces are CC0.
- Report problems in NSGo itself to [nsgo-dev/nsgo](https://github.com/nsgo-dev/nsgo/issues), and link the issue from any workaround here.

## Verification

From `apps/mirra`, run `go tool nsgo test .`, `go tool nsgo test -target macos .` and `go tool nsgo check -target macos,ios,android,windows,web`. For the website, from `apps/website`, run `bun run typecheck` and `bun run build`, and look at the pages in a browser. A green headless run does not prove native behavior: review UI changes in a real window.

## Documentation

- Update a document only when a fact its reader needs changes, and repair what you touch instead of appending to it.
- Record user-visible changes in [CHANGELOG.md](CHANGELOG.md).
- Keep `README.md` and `README.zh-CN.md` equivalent; everything else, including code comments, is English.
