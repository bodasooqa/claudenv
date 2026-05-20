# claudenv

[![ShellCheck](https://img.shields.io/github/actions/workflow/status/bodasooqa/claudenv/shellcheck.yml?branch=main&label=shellcheck&logo=githubactions&logoColor=white)](https://github.com/bodasooqa/claudenv/actions/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/github/license/bodasooqa/claudenv)](LICENSE)
![macOS](https://img.shields.io/badge/macOS-supported-000000?logo=apple&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-supported-FCC624?logo=linux&logoColor=black)

An **nvm-style** account manager for [Claude Code](https://docs.claude.com/en/docs/claude-code). Set a default account, override per-project with `.claudenvrc`, optionally auto-switch on `cd`. Zero dependencies.

```bash
claudenv import default       # save current ~/.claude as 'default' (auto-activated — first profile)
claudenv add work             # create new empty slot
claudenv use work             # switch this shell + set as global default
claude                        # /login here, isolated from 'default'
```

> When `accounts/` is empty, the first `import` or `add` auto-activates the new profile so you don't have to follow with `claudenv use`. Subsequent ones don't change the active profile.

## Is this for you?

Claude Code already supports `CLAUDE_CONFIG_DIR` for account isolation. Several tools wrap this — pick the one that fits how you work:

| | claudenv | [claude-switch](https://github.com/SaschaHeyer/claude-switch) |
|---|---|---|
| **Mental model** | Set a default, work normally | Specify account on every launch |
| **Typical command** | `claude` (after `claudenv use work`) | `claude-switch work` |
| **Per-project config** | `.claudenvrc` (walk-up resolution) | ✗ |
| **Auto-switch on `cd`** | ✓ opt-in | ✗ |
| **Shell completion** | ✓ zsh + bash | ✗ |
| **Dependencies** | none | `gum` |
| **One-shot mode** | `claudenv run <name> -- ...` | (always one-shot) |

If you switch accounts more than once a day and don't want to type the profile name every time, claudenv is for you. If you prefer explicit per-launch profiles, use claude-switch.

There are also tools that switch by patching `~/.claude.json` in place (claudectx, claude-swap, etc.) — different mechanism, different tradeoffs. claudenv and claude-switch both rely on the official `CLAUDE_CONFIG_DIR` environment variable, leaving your config files alone.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/bodasooqa/claudenv/main/install.sh | bash
```

Or with wget:

```bash
wget -qO- https://raw.githubusercontent.com/bodasooqa/claudenv/main/install.sh | bash
```

Want to inspect first? You should:

```bash
curl -fsSL https://raw.githubusercontent.com/bodasooqa/claudenv/main/install.sh -o install.sh
less install.sh
bash install.sh
```

Pin a specific version:

```bash
CLAUDENV_VERSION=v0.1.0 curl -fsSL https://raw.githubusercontent.com/bodasooqa/claudenv/v0.1.0/install.sh | bash
```

After install, open a new terminal (or `source ~/.zshrc` / `~/.bashrc`).

## Per-project pinning

```bash
cd ~/projects/clientA
claudenv local work           # writes .claudenvrc → 'work' switched for this shell
```

Commit `.claudenvrc` so the whole team gets the same account on this project.

## Auto-switch on `cd`

The installer asks whether to enable it. If you skipped, opt in later by appending to your `~/.zshrc` or `~/.bashrc`:

```bash
claudenv_enable_auto_switch
```

Now `cd`-ing into a folder with `.claudenvrc` switches the account; leaving restores your global default.

For unattended installs (CI, scripted), set `CLAUDENV_AUTO_SWITCH=1` (or `0`) before invoking the installer to skip the prompt:

```bash
CLAUDENV_AUTO_SWITCH=1 curl -fsSL https://raw.githubusercontent.com/bodasooqa/claudenv/main/install.sh | bash
```

## Commands

| Command | What it does |
|---|---|
| `claudenv add <name>` | Create a new empty account slot |
| `claudenv import <name> [dir]` | Copy an existing config (default `~/.claude`) as a new account |
| `claudenv use <name>` | Switch shell to `<name>` and set as global default |
| `claudenv use` | Re-read nearest `.claudenvrc` and switch (no default change) |
| `claudenv local <name>` | Write `./.claudenvrc` and switch this shell |
| `claudenv list` | List all accounts (`*` = active, `d` = default) |
| `claudenv current` | Print account active in this shell |
| `claudenv which` | Print active `CLAUDE_CONFIG_DIR` |
| `claudenv run <name> -- ...` | Run `claude` once under `<name>` without switching shell |
| `claudenv remove <name>` | Delete an account and all its data |

## How it works

Claude Code reads its config from `~/.claude` by default, but respects the `CLAUDE_CONFIG_DIR` environment variable if set. `claudenv` keeps a directory per account under `~/.claudenv/accounts/<name>/` and just points `CLAUDE_CONFIG_DIR` at the right one. No symlinks, no in-place patching, no daemons.

The "global default" lives in `~/.claudenv/current` and gets restored when you open a new shell. The "local override" comes from the nearest `.claudenvrc` walking up from `$PWD`.

## Updating

Re-run the install command. It overwrites `~/.claudenv/claudenv.sh` in place; your account data stays put.

```bash
curl -fsSL https://raw.githubusercontent.com/bodasooqa/claudenv/main/install.sh | bash
```

## Uninstall

```bash
rm -rf ~/.claudenv
# then remove the source line from ~/.zshrc or ~/.bashrc
```

## Requirements

- bash or zsh
- `claude` CLI installed and on `$PATH`
- `curl` or `wget` (for installer only)

## License

MIT

---

Not affiliated with Anthropic.
