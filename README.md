# DoT OS

A rebranded fork of [Bazzite](https://bazzite.gg) (GNOME) with a macOS
Aqua/Cupertino-style desktop, built with [BlueBuild](https://blue-build.org).

- **OS name**: "DoT OS" everywhere it counts — `/etc/os-release`, the GRUB
  (BootLoaderSpec) bootloader screen, and GNOME Settings > About.
- **macOS aesthetic**:
  - WhiteSur GTK theme (Light + Dark, incl. libadwaita/GTK4 layout) system-wide
  - WhiteSur icon theme (Big Sur blue, system-wide)
  - WhiteSur GNOME Shell theme (Aqua top bar) via the User Themes extension
  - **Dash to Dock** pinned to the **bottom** with **intelligent hiding**
    (hides behind maximized windows, auto-shows on mouse-over)
  - Window controls (**minimize / maximize / close**) on the **top-left**
- **Zero manual post-install steps** — everything is baked in as system
  defaults or auto-run systemd units.
- **Tracks upstream**: the base is `ghcr.io/ublue-os/bazzite-gnome:stable`,
  so the daily rebuild picks up Bazzite updates and re-applies the DoT layers.

## Repository layout

```
recipes/recipe.yml                     BlueBuild recipe (the whole build)
containerfiles/dot-os/Containerfile    macOS theme layer (WhiteSur GTK + icons)
files/scripts/build.sh                 branding script (os-release, GRUB, dconf)
files/system/etc/systemd/system/dot-os-brand.service
                                       re-runs build.sh at every boot
files/system/etc/systemd/user/dot-os-shell-theme.service
                                       links shell theme into ~/.themes per user
files/gschema-overrides/zz1-dot-os-core.gschema.override
                                       themes, fonts, top-left window buttons
files/gschema-overrides/zz2-dot-os-dock.gschema.override
                                       bottom dock + intellihide settings
.github/workflows/build.yml            daily + on-push BlueBuild pipeline
```

## Building

Repository: <https://github.com/ma7tar84/dot-os>

1. Push this directory to `ma7tar84/dot-os` (or just commit your changes if
   it's already there).
2. Generate a cosign key pair and store the private key in the
   `SIGNING_SECRET` repository secret; commit `cosign.pub`.
3. Let the workflow run (or trigger it manually). The image is published to
   `ghcr.io/ma7tar84/dot-os` (use the `latest` tag to install).

## Installing / rebasing

Fresh install (ISO from `blue-build` or any bootable flow) or rebase an
existing Bazzite/Fedora Atomic system:

```bash
# 1. rebase to the unsigned image to install signing keys/policies
rpm-ostree rebase ostree-unverified-registry:ghcr.io/ma7tar84/dot-os:latest
systemctl reboot

# 2. rebase to the signed image
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ma7tar84/dot-os:latest
systemctl reboot
```

### VM quick start (no ISO needed)

DoT OS is a bootc image, so install it **into** a VM:

1. Create the VM (VirtualBox / VMware / KVM) — 20 GB disk, 4 GB RAM.
2. Install **Fedora Atomic (Silverblue)** from a stock Fedora ISO as a
   carrier system. (Bazzite's official GNOME ISO works too.)
3. In the VM:

   ```bash
   bootc switch ostree-unverified-registry:ghcr.io/ma7tar84/dot-os:latest
   systemctl reboot
   ```

   After reboot: GRUB says "DoT OS", WhiteSur themes, bottom Dash to Dock
   with intelligent hiding, top-left window controls.

4. Day-to-day updates inside DoT OS:

   ```bash
   rpm-ostree upgrade            # pulls new Bazzite+DoT builds
   ```

   > **Note:** anonymous pulls from GHCR only work for **public** packages.
   > `github.com/ma7tar84/dot-os` is currently **private**, so in the VM run
   > `podman login ghcr.io` (GitHub username + a fine-grained PAT with
   > "Packages: read" on `dot-os`) before the rebase/switch. Alternatively,
   > make the repo public — then no login is needed.

## How each requirement is satisfied

| Requirement | Mechanism |
|---|---|
| Rename to "DoT OS" (os-release) | `os-release` module (`ID: dot`, `NAME`/`PRETTY_NAME: DoT OS`, `ID_LIKE: fedora` kept) + `build.sh` rewrites `/usr/lib/os-release` & `/etc/os-release` at build/boot |
| Rename in GRUB screen | `build.sh` rewrites `title=` in `/boot/loader/entries/*.conf`; `dot-os-brand.service` re-applies at every boot so kernel updates can't undo it |
| Settings > About panel | Reads os-release → shows "DoT OS" |
| WhiteSur GTK theme | `containerfiles/dot-os/Containerfile` installs prebuilt Light + Dark themes to `/usr/share/themes` (with the GTK4 `libadwaita-1` layout) |
| WhiteSur icon theme | Same Containerfile installs it to `/usr/share/icons` |
| Bottom dock + intelligent hiding | `zz2-dot-os-dock.gschema.override`: `dock-position='BOTTOM'`, `intellihide=true`, `autohide=true` |
| Top-left window controls | `zz1-dot-os-core.gschema.override`: `button-layout='minimize,maximize,close:'` (also for the greeter) |
| macOS shell theme | User Themes extension + per-user unit symlinking `/usr/share/themes/WhiteSur-Light` into `~/.themes` |
| Upstream updates preserved | `base-image: ghcr.io/ublue-os/bazzite-gnome`, `image-version: stable`; all DoT layers are idempotent and re-run on every rebuild |

## Notes & caveats

- `gnome-extensions` must run **before** `gschema-overrides` in the recipe —
  the override files reference the Dash-to-Dock and User-Themes schemas,
  which only exist after the extensions are installed.
- The `os-release` module runs **near the end** so COPR/dnf logic in earlier
  modules still resolves against the Fedora ID; `ID_LIKE: fedora` is kept on
  purpose so ostree/COPR tooling keeps working.
- System gschema overrides are *defaults*: users can still change themes in
  Settings, and their changes win (dconf user layer > system layer).
- If Bazzite changes the GNOME version, the `gnome-extensions` module will
  fail the build loudly on extension incompatibility — pin
  `image-version` to a specific Fedora tag to hold your shell version.

## Credits / third-party components

- [Bazzite](https://bazzite.gg) — upstream base image
- [BlueBuild](https://blue-build.org) — build system
- [WhiteSur GTK theme](https://github.com/vinceliuice/WhiteSur-gtk-theme) (GPL-3.0)
- [WhiteSur icon theme](https://github.com/vinceliuice/WhiteSur-icon-theme) (GPL-3.0)
- [Dash to Dock](https://github.com/micheleg/dash-to-dock) (GPL-3.0)
- [User Themes](https://gitlab.gnome.org/GNOME/gnome-shell-extensions) (GPL)
