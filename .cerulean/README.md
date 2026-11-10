# Cerulean

Private fork of the BlueBubbles desktop client, based on upstream tag `v2.1.6+desktop.96`.

- `main` is the base release plus our changes (kept small so upstream releases rebase cleanly).
- `upstream` remote = https://github.com/BlueBubblesApp/bluebubbles-app (fetch new tags, then rebase `main`).
- Build: `./.cerulean/build.sh` (needs nix; Flutter 3.47 / Dart 3.13 from nixpkgs, native deps from `shell.nix`).
- The app shares its data folder with the installed client (`~/.local/share/app.bluebubbles.BlueBubbles`), so only one can run at a time.
- Built bundle: `build/linux/x64/release/bundle/bluebubbles`.

Planned changes: correct notification titles (and no alert for your own messages), local spellcheck instead of
the LanguageTool cloud, autocorrect, emoji-by-name suggestions.
