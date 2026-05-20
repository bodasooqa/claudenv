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
