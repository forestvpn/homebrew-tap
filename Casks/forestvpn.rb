cask "forestvpn" do
  version "4.1.0"
  sha256 "94d78f186f89082b38e166a0dea2925242d70ba1aed2a24c66325f84c6b3bc3a"

  # GitHub Releases of forestvpn/downloads: reachable wherever Homebrew itself is (brew fetches from GitHub),
  # free, and not a VPN brand domain an ISP can single out. The same bytes are on downloads.fvpn.net and S3.
  url "https://github.com/forestvpn/downloads/releases/download/macos-#{version}/ForestVPN_#{version}.dmg"
  name "ForestVPN"
  desc "VPN client with a quantum-resistant tunnel"
  homepage "https://fvpn.net/"

  livecheck do
    url "https://s3.eu-central-1.amazonaws.com/fvpn-downloads/updates/macos/appcast-s3.xml"
    strategy :sparkle, &:short_version
  end

  auto_updates true
  depends_on macos: :sonoma

  app "ForestVPN.app"

  # Deleting the app does not remove a system extension. The removal lives in `zap`, never in
  # `uninstall`: Homebrew runs an uninstall `early_script` on `brew upgrade` and `brew reinstall`
  # too (only `signal` is skipped), so the OLD app would wipe the extension store and the VPN
  # configuration on every update. `zap` runs only on `brew uninstall --zap`.
  # The app runs headless: wipes the extension's store, removes the VPN configuration, submits the
  # deactivation request, exits. macOS may finish it only after a restart. The /bin/sh wrapper
  # makes a missing app (dragged to the Trash first, or a custom --appdir) a no-op, not an error.
  zap early_script: {
        executable:   "/bin/sh",
        args:         [
          "-c", '[ -x "$0" ] && "$0" --uninstall-extension; exit 0',
          "#{appdir}/ForestVPN.app/Contents/MacOS/ForestVPN"
        ],
        must_succeed: false,
      },
      trash:        [
        "~/Library/Application Scripts/com.forestvpn.mac",
        "~/Library/Containers/com.forestvpn.mac",
        "~/Library/Group Containers/*.group.com.forestvpn.mac",
      ]

  caveats <<~EOS
    On first launch, allow the ForestVPN network extension in
    System Settings > General > Login Items & Extensions > Network Extensions.
    `brew uninstall --cask forestvpn` leaves the network extension in place (an upgrade must not remove it).
    To remove it: ForestVPN > Settings > Remove network extension, or `brew uninstall --zap --cask forestvpn`
    (this also removes the VPN configuration; macOS may finish the removal at the next restart).
  EOS
end
