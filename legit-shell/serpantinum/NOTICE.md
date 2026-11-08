# NOTICE — vendored Serpantinum components

Source: https://github.com/ilyamiro/serpantinum (branch `master`, AGPL-3.0-or-later)
Copyright (C) 2026 Illia Miroshnichenko

This directory vendors the upstream shell so LEGIT OS can reuse three of its
existing components — the Settings panel (`quickshell/syspanel`), the
wallpaper switcher (`quickshell/wallpaper`) and the music widget with
equalizer (`quickshell/media`, `quickshell/singletons/audio`) — inside
LEGIT Shell.

- **Only the components above are instantiated** from LEGIT Shell
  (`legit-shell/shell.qml`); the rest of the vendored tree exists to keep
  Serpantinum's relative imports, singletons and scripts functional.
- The vendored code is unmodified upstream code except for environment
  plumbing inherited verbatim (`SERPANTINUM_DIR`, `QS_*`).
- This project is distributed under
  **GNU Affero General Public License v3.0 or later** (see `LICENSE.md`).
  Any derivative of this vendored software must also remain under AGPL-3.0
  and must keep this copyright and source notice intact.
- Upstream license anchor: https://github.com/ilyamiro/serpantinum/LICENSE.md

Serpantinum home page: https://serpantinum.dev
Audio engine (optional, not vendored nor required to render):
https://github.com/ilyamiro/serpantinum-audio — the equalizer view needs the
`serpantinum-audio` PipeWire processor installed in the running system to
actually apply EQ to the audio stream.
