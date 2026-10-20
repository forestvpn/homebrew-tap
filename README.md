# Homebrew tap for ForestVPN (direct Mac edition)

`brew install --cask forestvpn/tap/forestvpn` installs the Developer ID build of ForestVPN for Mac
(the notarized DMG, downloaded from the GitHub Releases of `forestvpn/downloads`, docs/decisions/0134; the same bytes
are on `downloads.fvpn.net` and its S3 mirror). The Mac App Store build is a different
app with a different bundle id; they are not meant to run side by side.

## Layout

The tap is the public repository `forestvpn/homebrew-tap`. This directory holds its source of truth:

```
packaging/homebrew/
  Casks/forestvpn.rb     # __VERSION__ / __SHA256__ placeholders; never committed filled in
  README.md              # this file; the tap repo carries a copy as its own README.md
```

The cask has `livecheck :sparkle` against the Mac appcast, `auto_updates true` (the app updates itself with
Sparkle) and a `zap early_script:` that runs `ForestVPN --uninstall-extension` (through a `/bin/sh` guard, so a missing app is a no-op).
It is `zap`, not `uninstall`: Homebrew 7.0.10 runs an uninstall `early_script` on `brew upgrade` and `brew reinstall` too, which would wipe the
tunnel on every update. A plain `brew uninstall --cask` keeps the extension; Settings > Remove network extension or `--zap` removes it.
Build 129 on the VM showed that deleting the app, or `brew uninstall --cask`, leaves the extension
`[activated enabled]` and running, so the app has a headless mode: it wipes the extension's bridge store, removes the VPN
configuration, submits `OSSystemExtensionRequest.deactivationRequest` and exits (no window, never an activation
request). macOS finishes a removal at the next restart (`[terminated waiting to uninstall on reboot]`), which is normal.
`must_succeed: false` keeps a failed removal from blocking the zap. `zap` also trashes the containers. The caveat
says all of this. Homebrew's own core cask repo is not a target: it asks for notability this app does not have yet.

## Cutting a release into the tap

```bash
task macos:dmg VERSION=<APP>        # builds, notarizes and writes dist/macos/<v>/ForestVPN_<v>.dmg.sha256
task macos:publish VERSION=<APP>    # the DMG must be live on both mirrors BEFORE the cask points at it
# the cask downloads from GitHub Releases (owner 2026-10-20: free, and not a domain an ISP can single out). Publish the
# SAME bytes there before the cask points at them; a release is never replaced, a fix is a new version:
printf '%s  ForestVPN_<APP>.dmg\n' "$(cut -c1-64 dist/macos/<APP>/ForestVPN_<APP>.dmg.sha256)" > /tmp/ForestVPN_<APP>.dmg.sha256
gh release create macos-<APP> --repo forestvpn/downloads --title "ForestVPN for Mac <APP> (<build>)" \
  dist/macos/<APP>/ForestVPN_<APP>.dmg /tmp/ForestVPN_<APP>.dmg.sha256
curl -sL https://github.com/forestvpn/downloads/releases/download/macos-<APP>/ForestVPN_<APP>.dmg | shasum -a 256   # == the .sha256
task macos:cask VERSION=<APP>       # renders dist/macos/<v>/forestvpn.rb from that sha256
# then, in a checkout of forestvpn/homebrew-tap:
cp <fvpn>/dist/macos/<v>/forestvpn.rb Casks/forestvpn.rb
git add Casks/forestvpn.rb && git commit -m "forestvpn <v>" && git push
```

First time only: `gh repo create forestvpn/homebrew-tap --public --description "Homebrew tap for ForestVPN"`,
then push `README.md` and `Casks/`.

## Checking a cask without the network

```bash
task macos:cask VERSION=<APP>
brew tap-new obdist/local --no-git
cp dist/macos/<v>/forestvpn.rb "$(brew --repository obdist/local)/Casks/forestvpn.rb"
brew style --cask obdist/local/forestvpn
brew audit --cask --strict obdist/local/forestvpn     # without --online
brew untap obdist/local
```
