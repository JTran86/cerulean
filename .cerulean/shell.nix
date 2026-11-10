{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  # Same native dependencies the Arch "bluebubbles-desktop-app" package lists, from nix, so the build is self-contained.
  packages = with pkgs; [
    flutter cmake ninja clang pkg-config patchelf git python3 unzip curl which
    gtk3 glib gdk-pixbuf webkitgtk_4_1 mpv libnotify libayatana-appindicator libdbusmenu-gtk3
    libepoxy fontconfig libsecret sqlite xz libass
  ];
}
