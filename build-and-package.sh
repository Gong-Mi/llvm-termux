#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${LLVM_TERMUX_ROOT:-/data/data/com.termux/files/home/llvm-termux}"
PREFIX="${TERMUX_PREFIX:-/data/data/com.termux/files/usr}"
BUILD_DIR="${LLVM_TERMUX_BUILD_DIR:-$ROOT/build}"
DEB_DIR="${LLVM_TERMUX_DEB_DIR:-$ROOT/build-deb}"
OUT_DIR="${LLVM_TERMUX_OUT_DIR:-$ROOT/out}"
VERSION="${LLVM_TERMUX_VERSION:-23.0.0-git}"
PKG_NAME="${LLVM_TERMUX_PKG_NAME:-llvm-termux}"
ARCH="${LLVM_TERMUX_ARCH:-$(dpkg --print-architecture 2>/dev/null || echo aarch64)}"
LOG="${LLVM_TERMUX_LOG:-$ROOT/llvm-build-package-$(basename "$BUILD_DIR").log}"
# Large LLVM+MLIR+Flang builds on Android/Termux are memory-spiky; default low.
JOBS="${LLVM_TERMUX_JOBS:-2}"
LINK_JOBS="${LLVM_TERMUX_LINK_JOBS:-1}"

# Installed into staging under exactly this Termux prefix:
#   $DEB_DIR/data/data/com.termux/files/usr/...
# After dpkg -i, files land in:
#   /data/data/com.termux/files/usr/...
EXPECTED_PREFIX="$PREFIX"

mkdir -p "$OUT_DIR"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

say() { printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

check_location() {
  [ -d "$ROOT/llvm" ] || die "ROOT does not look like llvm-project checkout: $ROOT"
  [ -d "$BUILD_DIR" ] || die "missing build dir: $BUILD_DIR; run ./configure-termux-expanded.sh first"
  [ -f "$BUILD_DIR/build.ninja" ] || die "missing $BUILD_DIR/build.ninja; run ./configure-termux-expanded.sh first"
  local cached_prefix
  cached_prefix="$(python - "$BUILD_DIR/CMakeCache.txt" <<'PY'
import sys
p=sys.argv[1]
for line in open(p, errors='ignore'):
    if line.startswith('CMAKE_INSTALL_PREFIX:'):
        print(line.split('=',1)[1].strip())
        break
PY
)"
  [ "$cached_prefix" = "$EXPECTED_PREFIX" ] || die "install prefix mismatch: cache=$cached_prefix expected=$EXPECTED_PREFIX"
  say "install prefix verified: $cached_prefix"
}

build() {
  say "building in $BUILD_DIR jobs=$JOBS link_jobs=$LINK_JOBS"
  cmake --build "$BUILD_DIR" --parallel "$JOBS"
}

stage_install() {
  say "installing into package staging: $DEB_DIR"
  rm -rf "$DEB_DIR"
  mkdir -p "$DEB_DIR/DEBIAN"
  DESTDIR="$DEB_DIR" cmake --build "$BUILD_DIR" --target install --parallel "$JOBS"
  [ -d "$DEB_DIR$PREFIX/bin" ] || die "staged bin dir missing: $DEB_DIR$PREFIX/bin"
  [ -x "$DEB_DIR$PREFIX/bin/clang" ] || die "staged clang missing: $DEB_DIR$PREFIX/bin/clang"
  say "staged install location verified: $DEB_DIR$PREFIX"
}

fix_rpath() {
  say "cleaning build-dir rpath from staged binaries"
  local build_rpath="$BUILD_DIR/lib"
  find "$DEB_DIR$PREFIX/bin" "$DEB_DIR$PREFIX/lib" -type f -executable 2>/dev/null | while read f; do
    if patchelf --print-rpath "$f" 2>/dev/null | grep -q "$build_rpath"; then
      local cur_rpath=$(patchelf --print-rpath "$f" 2>/dev/null)
      local clean_rpath=$(echo "$cur_rpath" | sed "s|$build_rpath:||g; s|:$build_rpath||g; s|$build_rpath||g")
      patchelf --set-rpath "$clean_rpath" "$f" 2>/dev/null
      say "  fixed: ${f#$DEB_DIR}"
    fi
  done
}

control_file() {
  say "writing DEBIAN/control"
  cat > "$DEB_DIR/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $VERSION
Architecture: $ARCH
Maintainer: Builder <builder@termux>
Depends: libc++, libffi, libxml2, ncurses, zlib, zstd, libedit, python
Description: LLVM/Clang toolchain for Termux with expanded targets
 Custom Termux package built from Gong-Mi/llvm-termux.
 Includes clang, clang-tools-extra, lld, lldb, compiler-rt, polly, mlir, flang,
 libc++ runtimes, OpenMP, and expanded LLVM backends.
EOF
  chmod 755 "$DEB_DIR/DEBIAN"
  chmod 644 "$DEB_DIR/DEBIAN/control"
}

make_deb() {
  local deb="$OUT_DIR/${PKG_NAME}_${VERSION}_${ARCH}.deb"
  say "building deb: $deb"
  dpkg-deb --build "$DEB_DIR" "$deb"
  dpkg-deb -I "$deb"
  say "package contents sample"
  dpkg-deb -c "$deb" | sed -n '1,40p'
  say "created $(du -h "$deb" | awk '{print $1}') $deb"
}

check_location
build
stage_install
fix_rpath
control_file
make_deb
say "done; log: $LOG"
