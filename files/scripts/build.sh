#!/usr/bin/env bash
# =============================================================================
# build.sh — DoT OS branding & macOS-layout build/post-install script
# -----------------------------------------------------------------------------
# What it does (idempotent, safe to re-run any number of times):
#   1. Rebrands the OS identity files (/usr/lib/os-release and /etc/os-release)
#      from "Bazzite" -> "DoT OS".
#   2. Rebrands the GRUB bootloader entries (BootLoaderSpec files in
#      /boot/loader/entries/*.conf) so the GRUB screen shows "DoT OS".
#
# Note: the macOS layout itself (themes, dock, window buttons) is applied by
# the gschema-overrides module as compiled schema defaults — no runtime step
# is needed for that part.
#
# How it runs
#   * At IMAGE BUILD time (BlueBuild `script` module): /usr is writable, so
#     this is the authoritative writer for /usr/lib/os-release.
#   * At BOOT time (dot-os-brand.service): /usr is read-only (ostree
#     deployment), so the os-release edits become a no-op and the BlueBuild
#     `os-release` module is what owns the persistent identity. The GRUB BLS
#     files live on the rw /boot mount, so GRUB rebranding works at boot and
#     survives kernel updates / rebases.
#
# Everything is best-effort and non-fatal: a read-only target is skipped, a
# missing file is skipped, and no step can break the boot.
# =============================================================================
set -uo pipefail

OS_NAME="DoT OS"
OS_PRETTY="DoT OS"
OS_ID="dot"
OS_ID_LIKE="fedora"

log() { echo "[dot-os] $*"; }

# Rebrand a single os-release file, skipping read-only targets gracefully.
brand_os_release_file() {
  local f="$1"
  [ -f "$f" ] || { log "skip $f (not present)"; return 0; }
  # Resolve symlinks (/etc/os-release -> /usr/lib/os-release) to the real file.
  local real
  real="$(readlink -f "$f" 2>/dev/null || echo "$f")"
  if [ ! -w "$real" ]; then
    log "skip $f (read-only; the build-time 'os-release' module owns it)"
    return 0
  fi
  log "rebranding $real"
  sed -i \
    -e "s/^ID=.*/ID=${OS_ID}/" \
    -e "s/^ID_LIKE=.*/ID_LIKE=${OS_ID_LIKE}/" \
    -e "s/^NAME=.*/NAME=${OS_NAME}/" \
    -e "s/^PRETTY_NAME=.*/PRETTY_NAME=${OS_PRETTY}/" \
    "$real"
  grep -q '^ID='          "$real" || echo "ID=${OS_ID}"              >> "$real"
  grep -q '^ID_LIKE='     "$real" || echo "ID_LIKE=${OS_ID_LIKE}"    >> "$real"
  grep -q '^NAME='        "$real" || echo "NAME=${OS_NAME}"          >> "$real"
  grep -q '^PRETTY_NAME=' "$real" || echo "PRETTY_NAME=${OS_PRETTY}" >> "$real"
  return 0
}

brand_os_release() {
  brand_os_release_file /usr/lib/os-release
  brand_os_release_file /etc/os-release
  return 0
}

# Rebrand GRUB (BootLoaderSpec) entries — they live on the rw /boot mount, so
# this works both at build time and at boot time, and survives rebases.
brand_grub() {
  local d="/boot/loader/entries"
  [ -d "$d" ] || { log "no BLS dir at $d (skip GRUB rebrand)"; return 0; }
  shopt -s nullglob
  local conf rest new
  for conf in "$d"/*.conf; do
    grep -q '^title=' "$conf" || continue
    rest="$(sed -n 's/^title=//p' "$conf" | head -n1)"
    # Strip a leading brand (ours or Bazzite) to stay idempotent.
    new="$(echo "$rest" | sed -e 's/^Bazzite//' -e "s/^${OS_NAME}//" \
                 | sed -e 's/^[[:space:]|_-]*//')"
    if [ -n "$new" ]; then
      sed -i "s|^title=.*|title=${OS_NAME} ${new}|" "$conf"
    else
      sed -i "s|^title=.*|title=${OS_NAME}|" "$conf"
    fi
    log "GRUB entry rebranded: $(basename "$conf")"
  done
  return 0
}

main() {
  log "=== DoT OS branding start ==="
  brand_os_release
  brand_grub
  log "=== DoT OS branding done ==="
  return 0
}

main "$@"
