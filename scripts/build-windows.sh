#!/usr/bin/env bash
# build-windows.sh [options]
#
# Builds Mirra's Windows installers with nsgo build (go tool nsgo, the version apps/mirra/go.mod pins): an NSIS installer for x86-64 and one for ARM64. Both are cross-compiled from macOS or Linux, as the app is pure Go, but the installer needs NSIS's makensis, which Homebrew (brew install makensis) or Debian and Ubuntu (apt-get install nsis) install.
#
# The installers are unsigned unless a certificate is given. A signed one needs a .pfx with the code signing certificate in it, whose password is the environment's NSGO_CERTIFICATE_PASSWORD.
#
# Options:
#   -t, --target TARGET     x64 (x86-64) or arm64 (ARM64), or all (the default)
#   -o, --output DIR        the directory the packages go into (default: apps/mirra/dist)
#   -c, --certificate FILE  the .pfx to sign the installer with
#   -h, --help              this text
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
app=$root/apps/mirra
output=$app/dist
target=all
certificate=

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
    -c | --certificate)
      [ $# -ge 2 ] || die "$1 needs a file"
      certificate=$2
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
  x64 | x86 | x86-64 | amd64) targets=(windows_x64) ;;
  arm64 | arm) targets=(windows_arm64) ;;
  all) targets=(windows_x64 windows_arm64) ;;
  *) die "unknown target: $target (x64, arm64 or all)" ;;
esac

command -v go >/dev/null || die "Go is not on PATH: https://go.dev/dl/"
if ! command -v makensis >/dev/null; then
  case $(uname -s) in
    Darwin) die "NSIS is missing, which the Windows installer needs: brew install makensis" ;;
    Linux) die "NSIS is missing, which the Windows installer needs: apt-get install nsis" ;;
    *) die "NSIS is missing, which the Windows installer needs: install makensis" ;;
  esac
fi
[ -f "$app/nsgo.yaml" ] || die "no apps/mirra/nsgo.yaml under $root"
# The build runs in the module's directory, so a relative output path is taken from where the script was called.
case $output in
  /*) ;;
  *) output=$PWD/$output ;;
esac

args=(build -target "$(IFS=,; echo "${targets[*]}")" -output "$output")
if [ -n "$certificate" ]; then
  [ -f "$certificate" ] || die "no such certificate: $certificate"
  args+=(-certificate "$certificate")
fi

# NSIS's compiler crashes with std::bad_alloc in this machine's locale on macOS (NSIS bug 1165), so the build runs in the locale its own test uses.
if [ "$(uname -s)" = Darwin ]; then
  export LANG=en_GB.UTF-8
  export LC_ALL=en_GB.UTF-8
fi

cd "$app"
go tool nsgo "${args[@]}"

# The installers are what the user installs, so the script names them and their checksums, as the release does.
release=$output/releases
version=$(sed -nE 's/^version: *"?([0-9.]+)"? *$/\1/p' "$app/nsgo.yaml")
[ -n "$version" ] || die "apps/mirra/nsgo.yaml holds no version"
echo
for arch in "${targets[@]}"; do
  installers=("$release"/*-"$version"-"${arch//_/-}"-setup.exe)
  [ -f "${installers[0]}" ] || die "nsgo build made no installer for $arch"
  printf '%s  %s\n' "$(checksum "${installers[0]}")" "$(basename "${installers[0]}")"
done
echo "in $release"
