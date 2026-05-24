# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-20

### Added
- Initial release.
- Commands: `add`, `import`, `use`, `local`, `list`, `current`, `which`, `run`, `remove`.
- Per-project `.claudenvrc` with walk-up resolution.
- Opt-in auto-switch on `cd` for zsh and bash.
- Shell completion for zsh and bash.
- Installer script (`install.sh`) with shell detection and idempotent rc-line injection.
- `add` and `import` auto-activate the new profile when it is the first one in `~/.claudenv/accounts/`, so the bootstrap flow is a single command. Subsequent `add`/`import` calls leave the active profile unchanged.
- `claudenv use` (no args) and the auto-switch `cd` hook now lazy-create a missing profile when a `.claudenvrc` references one that doesn't exist yet (typical when cloning a teammate's repo). The creation is announced before the switch; commands that take an explicit name (`claudenv use <name>`, `claudenv local <name>`) still error so typos can't silently mint stray profiles.
- Installer asks `Enable auto-switch on cd? [y/N]` (reading from `/dev/tty` so `curl | bash` works). Set `CLAUDENV_AUTO_SWITCH=1` or `0` to bypass the prompt for unattended installs; missing tty falls back to "no".
- `bin/claude-wrapper` launcher for GUI-launched IDEs. Installed at `~/.claudenv/bin/claude-wrapper`; point the Claude Code extension's "Claude Process Wrapper" setting at it so VS Code / Cursor sessions started from Dock/Spotlight (where macOS launchd doesn't load `~/.zshrc`) still pick up the active profile. Falls back through common claude install locations; respects `CLAUDENV_CLAUDE_BIN` override.
- `claudenv vibe-island` subcommand (macOS) to register/unregister profiles with [Vibe Island](https://vibeisland.app)'s "Claude Code Forks" list. Manipulates `customClaudeCodeConfigPaths` in Vibe Island's plist via the built-in `defaults` tool — no `jq` or extra deps. Subcommands: `install`/`uninstall [<name>|--all]`, `status`. Running `install` flips a flag so future `add`/`import` auto-register; `uninstall --all` clears it. Installer detects Vibe Island and offers to enable auto-registration (or set `CLAUDENV_VIBE_ISLAND=1`/`0` for unattended installs). `remove` also drops the path from Vibe Island's list.
