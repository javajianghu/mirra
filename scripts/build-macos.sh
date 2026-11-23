#!/usr/bin/env bash
# build-macos.sh [options]
#
# Builds Mirra's macOS installers with nsgo build (go tool nsgo, the version apps/mirra/go.mod pins): a disk image for Apple Silicon and one for Intel. Both architectures are cross-compiled from any Mac, as the app is pure Go, but the bundle needs codesign and the image hdiutil, so this runs on macOS only.
#
# The images are ad hoc signed and not notarized unless a sign identity is given. An ad hoc image opens with a Gatekeeper warning; a signed one needs the Developer ID Application certificate in the keychain, and notarizing it needs a notarytool profile (xcrun notarytool store-credentials).
#
# Options:
#   -t, --target TARGET     arm64 (Apple Silicon), x64 (Intel) or all (the default)
#   -o, --output DIR        the directory the packages go into (default: apps/mirra/dist)
#   -s, --sign IDENTITY     the codesign identity to sign with, a Developer ID Application one
#   -n, --notarize PROFILE  the notarytool keychain profile to notarize the image with
#   -h, --help              this text
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
app=$root/apps/mirra
output=$app/dist
target=all
sign=
notarize=

die() {
  echo "$*" >&2
  exit 1
}

usage() {
  awk 'NR == 1 { next } /^set -euo/ { exit } { sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
}

# checksum prints the SHA-256 of a file, which the release writes beside it.
checksum() {
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

while [ $# -gt 0 ]; do
  case $1 in
    -t | --target)
      [ $# -ge 2 ] || die "$1 needs a target"
      target=$2
      shift 2
      ;;
    -o | --output)
      [ $# -ge 2 ] || die "$1 needs a directory"
      output=$2
      shift 2
      ;;
    -s | --sign)
      [ $# -ge 2 ] || die "$1 needs an identity"
      sign=$2
      shift 2
      ;;
    -n | --notarize)
      [ $# -ge 2 ] || die "$1 needs a profile"
      notarize=$2
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

case $target in
  arm64 | apple | apple-silicon) targets=(macos_arm64) ;;
  x64 | intel | amd64) targets=(macos_x64) ;;
  all) targets=(macos_arm64 macos_x64) ;;
  *) die "unknown target: $target (arm64, x64 or all)" ;;
esac

[ "$(uname -s)" = Darwin ] || die "the macOS package needs codesign and hdiutil, so it builds on macOS only"
command -v go >/dev/null || die "Go is not on PATH: https://go.dev/dl/"
for tool in codesign ditto hdiutil tiffutil xcrun; do
  command -v "$tool" >/dev/null || die "$tool is missing, which the macOS package needs"
done
[ -f "$app/nsgo.yaml" ] || die "no apps/mirra/nsgo.yaml under $root"
# The build runs in the module's directory, so a relative output path is taken from where the script was called.
case $output in
  /*) ;;
  *) output=$PWD/$output ;;
esac

args=(build -target "$(IFS=,; echo "${targets[*]}")" -output "$output")
if [ -n "$sign" ]; then
  args+=(-sign "$sign")
fi
if [ -n "$notarize" ]; then
  args+=(-notarize "$notarize")
fi

cd "$app"
go tool nsgo "${args[@]}"

# The images are what the user installs, so the script names them and their checksums, as the release does.
release=$output/releases
version=$(sed -nE 's/^version: *"?([0-9.]+)"? *$/\1/p' "$app/nsgo.yaml")
[ -n "$version" ] || die "apps/mirra/nsgo.yaml holds no version"
echo
for arch in "${targets[@]}"; do
  images=("$release"/*-"$version"-"${arch//_/-}".dmg)
  [ -f "${images[0]}" ] || die "nsgo build made no image for $arch"
  printf '%s  %s\n' "$(checksum "${images[0]}")" "$(basename "${images[0]}")"
done
echo "in $release"
