# Issue #42 / UI font subset

Base main 51f0d1b. Scope only the Japanese serif font needed by #36; model/audio procurement remains open.

Use unmodified Noto Serif JP from Google Fonts commit `8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5` under SIL Open Font License 1.1. Record source and preserve the full original copyright/license before import. Keep the binary in existing Git LFS coverage. Include license as a readable file beside each platform build and in the exported resource bundle.

Validation: downloaded font and license SHA256 recorded in asset ledger; Godot4.3 FontFile loads and contains Japanese title/menu characters; export filters preserve the license. Existing gameplay validation is unaffected. PR GUT and main build/license/boot checks apply. No purchase, secrets, permissions, or release.
