# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-05-29

### Added
- `claudenv plugins sync [<name>|--all] [--from <dir>] [--link|--copy]` to bring plugins from a source config dir (default `~/.claude`) into isolated accounts. Plugins live per-`CLAUDE_CONFIG_DIR`, so plugins installed under `~/.claude` were invisible under claudenv accounts (the VS Code "Manage Plugins" panel showed none). `sync` copies `plugins/{cache,marketplaces}`, rewrites absolute `installPath`/`installLocation` entries to resolve inside the account, and merges `enabledPlugins` + `extraKnownMarketplaces` into the account's `settings.json` via `jq` (source wins; other settings preserved). `--link` symlinks the heavy dirs instead of copying. `claudenv plugins status [<name>]` lists installed/enabled plugins and known marketplaces for an account. Shell completion covers the new subcommands.
- `plugins sync` now derives `extraKnownMarketplaces` from the copied `known_marketplaces.json` so the marketplace's *source kind* matches the source config. Claude Code reconciles `known_marketplaces` from `settings.extraKnownMarketplaces` at launch; if an account had a marketplace registered as a generic `git` clone instead of the `github` repo the working config uses, it reverted on next start and the VS Code discover panel showed no plugins available to install. Keeping the two consistent fixes new-plugin discovery/installation under synced accounts.

### Fixed
- `bin/claude-wrapper` now execs the command the IDE hands it instead of substituting its own `claude`. VS Code / Cursor's `claude-code.processWrapper` invokes the wrapper as a *prefix* — `claude-wrapper <real-claude> <args…>` (or `… node cli.js <args…>`) — but the wrapper ignored those leading arguments, found its own `claude`, and ran `claude <real-claude> <args…>`. The real path became a stray positional, pushing flags like `--json` to the top level, so the extension failed to launch and "Manage Plugins" errored with `unknown option '--json'`. The wrapper now resolves the profile, then `exec "$@"`; the `claude`-lookup fallback (and `CLAUDENV_CLAUDE_BIN`) applies only when invoked standalone with no arguments.

### Docs
- GUI-IDE setup now shows the **absolute** wrapper path as the value to use — the extension does not expand `~`, so a `~/.claudenv/...` path fails with "native binary not found". Added a note that installs predating the wrapper need to re-run the installer to get `~/.claudenv/bin/claude-wrapper`.
- Documented that switching profiles invalidates the IDE extension's remembered conversation (sessions live per `CLAUDE_CONFIG_DIR`): on reload right after a switch it shows `No conversation found with session ID: …`. Harmless — start a new chat; old conversations reappear under their original config.
- Added GUI-IDE troubleshooting for two more failure modes: the wrapper silently falling back to `~/.claude` when `~/.claudenv/current` is empty or points to a removed account (fix: `claudenv use <name>`), and how to bring existing conversation history into an account (`claudenv import` for new accounts; `rsync -a --ignore-existing ~/.claude/projects/ …` to top up an existing one).

## [0.2.0] - 2026-05-24

### Added
- `bin/claude-wrapper` launcher for GUI-launched IDEs. Installed at `~/.claudenv/bin/claude-wrapper`; point the Claude Code extension's "Claude Process Wrapper" setting at it so VS Code / Cursor sessions started from Dock/Spotlight (where macOS launchd doesn't load `~/.zshrc`) still pick up the active profile. Falls back through common claude install locations; respects `CLAUDENV_CLAUDE_BIN` override.
- `claudenv vibe-island` subcommand (macOS) to register/unregister profiles with [Vibe Island](https://vibeisland.app)'s "Claude Code Forks" list. Manipulates `customClaudeCodeConfigPaths` in Vibe Island's plist via the built-in `defaults` tool — no `jq` or extra deps. Subcommands: `install`/`uninstall [<name>|--all]`, `status`. Running `install` flips a flag so future `add`/`import` auto-register; `uninstall --all` clears it. Installer detects Vibe Island and offers to enable auto-registration (or set `CLAUDENV_VIBE_ISLAND=1`/`0` for unattended installs). `remove` also drops the path from Vibe Island's list.
- `CLAUDENV_SOURCE` and `CLAUDENV_WRAPPER_SOURCE` are now env-overridable in `install.sh`, useful for testing and private forks.

### Fixed
- `local path` in vibe-island helpers clobbered zsh's tied `$path` array (which mirrors `$PATH`), causing "command not found" errors for `basename`, `grep`, `sed`, etc. inside `claudenv vibe-island status`. Renamed all local `path` vars to `vi_path`.

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
