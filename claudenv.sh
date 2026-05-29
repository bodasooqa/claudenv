#!/usr/bin/env bash
# claudenv — nvm-style account manager for Claude Code
# Switches between multiple Claude Code accounts via CLAUDE_CONFIG_DIR.
#
# Install:
#   mkdir -p ~/.claudenv && cp claudenv.sh ~/.claudenv/claudenv.sh
#   echo 'source ~/.claudenv/claudenv.sh' >> ~/.zshrc
#   # Optional: auto-switch when cd-ing into a project with .claudenvrc
#   echo 'claudenv_enable_auto_switch' >> ~/.zshrc
#   exec zsh
#
# Usage:
#   claudenv add work
#   claudenv use work                      # set default
#   claude                                 # /login under work
#   claudenv import personal ~/.claude     # bring in existing config
#   claudenv local personal                # writes .claudenvrc in this folder
#   claudenv use                           # re-read .claudenvrc (no args)
#   claudenv run personal -- --version     # one-off, no shell switch

CLAUDENV_DIR="${CLAUDENV_DIR:-$HOME/.claudenv}"
CLAUDENV_ACCOUNTS_DIR="$CLAUDENV_DIR/accounts"
CLAUDENV_CURRENT_FILE="$CLAUDENV_DIR/current"

# Vibe Island integration (macOS): the app keeps the list of "Claude Code Forks"
# as an array of paths under the customClaudeCodeConfigPaths key in its prefs.
# Vibe Island injects its hooks into each registered path's settings.json on
# launch. The domain and flag-file are overridable for testing/forks.
CLAUDENV_VI_DOMAIN="${CLAUDENV_VI_DOMAIN:-app.vibeisland.macos}"
CLAUDENV_VI_KEY="customClaudeCodeConfigPaths"
CLAUDENV_VI_PLIST="$HOME/Library/Preferences/$CLAUDENV_VI_DOMAIN.plist"
CLAUDENV_VI_FLAG="$CLAUDENV_DIR/vibe-island.enabled"

mkdir -p "$CLAUDENV_ACCOUNTS_DIR"

# --- internal helpers -------------------------------------------------------

# Reject empty names, dots-only, slashes, and anything outside [alnum]_.-
# This prevents path traversal via .claudenvrc or direct args.
_claudenv_validate_name() {
  local name="$1"
  case "$name" in
    "")
      echo "claudenv: account name is empty" >&2
      return 1 ;;
    .|..|*/*|*\\*)
      echo "claudenv: invalid account name '$name' (no slashes or dots-only)" >&2
      return 1 ;;
    *[![:alnum:]_.-]*)
      echo "claudenv: account name '$name' has invalid chars (allowed: a-z A-Z 0-9 _ . -)" >&2
      return 1 ;;
  esac
}

# Walk up from $PWD looking for a .claudenvrc file. Echoes its path on success.
_claudenv_find_rc() {
  local dir="$PWD"
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    if [ -f "$dir/.claudenvrc" ]; then
      echo "$dir/.claudenvrc"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

_claudenv_read_rc() {
  # Read account name from .claudenvrc, stripping comments and whitespace.
  sed -e 's/#.*//' -e 's/[[:space:]]//g' "$1" | head -n 1
}

_claudenv_apply() {
  export CLAUDE_CONFIG_DIR="$CLAUDENV_ACCOUNTS_DIR/$1"
}

_claudenv_accounts_empty() {
  [ -z "$(ls -A "$CLAUDENV_ACCOUNTS_DIR" 2>/dev/null)" ]
}

# Name of the account active in this shell (env first, then global default).
# Echoes nothing if neither is set.
_claudenv_active_name() {
  if [ -n "$CLAUDE_CONFIG_DIR" ]; then
    basename "$CLAUDE_CONFIG_DIR"
  elif [ -f "$CLAUDENV_CURRENT_FILE" ]; then
    cat "$CLAUDENV_CURRENT_FILE"
  fi
}

# --- plugin sync helpers ----------------------------------------------------

# Merge enabledPlugins + extraKnownMarketplaces from a source settings.json
# into an account's settings.json. Source wins on key conflicts; everything
# else in the account file is preserved. No-op (with a note) if jq is missing.
_claudenv_plugins_merge_settings() {
  local src="$1" dst="$2"
  [ -f "$src" ] || return 0
  if ! command -v jq >/dev/null 2>&1; then
    echo "    ! jq not found — plugins copied but not enabled in settings.json" >&2
    echo "      Install jq and re-run, or enable them with /plugin inside the account." >&2
    return 0
  fi
  [ -f "$dst" ] || echo '{}' > "$dst"
  local tmp
  tmp=$(mktemp) || return 1
  if jq -s '
      .[0] as $src | .[1] as $dst |
      $dst
      | .enabledPlugins = (($dst.enabledPlugins // {}) + ($src.enabledPlugins // {}))
      | .extraKnownMarketplaces =
          (($dst.extraKnownMarketplaces // {}) + ($src.extraKnownMarketplaces // {}))
    ' "$src" "$dst" > "$tmp"; then
    mv "$tmp" "$dst"
  else
    rm -f "$tmp"
    echo "    ! failed to merge settings.json (left unchanged)" >&2
    return 1
  fi
}

# Sync plugins from a source config dir into one account.
#   $1 = account name   $2 = source config dir (no trailing slash)   $3 = copy|link
# Copies/links plugins/{cache,marketplaces}, rewrites absolute installPath
# entries to point inside the account, then merges enabled state into settings.
_claudenv_plugins_sync_one() {
  local name="$1" src="$2" mode="$3"
  local dst="$CLAUDENV_ACCOUNTS_DIR/$name"
  local src_plugins="$src/plugins" dst_plugins="$dst/plugins"

  if [ ! -d "$src_plugins" ]; then
    echo "  ✗ $name: source has no plugins dir ($src_plugins)" >&2
    return 1
  fi
  if [ "$src" = "$dst" ]; then
    echo "  = $name: source and account are the same dir, skipped"
    return 0
  fi

  mkdir -p "$dst_plugins"

  # Replace the heavy dirs wholesale so removed plugins don't linger.
  local sub
  for sub in cache marketplaces; do
    rm -rf "${dst_plugins:?}/$sub"
    [ -e "$src_plugins/$sub" ] || continue
    if [ "$mode" = link ]; then
      ln -s "$src_plugins/$sub" "$dst_plugins/$sub"
    else
      cp -R "$src_plugins/$sub" "$dst_plugins/$sub"
    fi
  done

  # Copy the manifests, rewriting the absolute source prefix → account dir so
  # installPath / installLocation resolve under the account (the rewritten
  # path still resolves through the symlink in --link mode). Path components
  # are literal here; the unescaped '.' in '.claude' can't realistically
  # collide with another existing path, so a plain prefix substitution is fine.
  local f
  for f in installed_plugins.json known_marketplaces.json; do
    [ -f "$src_plugins/$f" ] || continue
    sed "s#${src%/}#${dst%/}#g" "$src_plugins/$f" > "$dst_plugins/$f"
  done

  _claudenv_plugins_merge_settings "$src/settings.json" "$dst/settings.json"
  echo "  ✓ $name  ($mode from $src)"
}

# --- Vibe Island helpers (macOS only) ---------------------------------------

_claudenv_vi_available() {
  [ "$(uname -s)" = "Darwin" ] && [ -f "$CLAUDENV_VI_PLIST" ]
}

_claudenv_vi_path_for() {
  # Vibe Island stores entries with literal `~` (not $HOME-expanded) in its
  # plist; we match that so paths compare equal across registrations.
  # shellcheck disable=SC2088
  echo "~/.claudenv/accounts/$1"
}

_claudenv_vi_list_paths() {
  # Extract array entries from `defaults read` output (one per line, unquoted).
  # Returns 0 even if the key is missing (empty output).
  defaults read "$CLAUDENV_VI_DOMAIN" "$CLAUDENV_VI_KEY" 2>/dev/null \
    | sed -n 's/^[[:space:]]*"\(.*\)",*[[:space:]]*$/\1/p'
}

_claudenv_vi_contains() {
  _claudenv_vi_list_paths | grep -Fxq -- "$1"
}

_claudenv_vi_add_path() {
  local target="$1"
  if _claudenv_vi_contains "$target"; then
    return 0  # idempotent
  fi
  defaults write "$CLAUDENV_VI_DOMAIN" "$CLAUDENV_VI_KEY" -array-add "$target"
}

_claudenv_vi_remove_path() {
  # defaults has no array-remove; we read, filter, then rewrite the array.
  local target="$1"
  local kept
  kept=$(_claudenv_vi_list_paths | grep -Fvx -- "$target" || true)
  if [ -z "$kept" ]; then
    defaults delete "$CLAUDENV_VI_DOMAIN" "$CLAUDENV_VI_KEY" 2>/dev/null || true
    return 0
  fi
  local -a args=()
  local line
  while IFS= read -r line; do
    [ -n "$line" ] && args+=("$line")
  done <<< "$kept"
  defaults write "$CLAUDENV_VI_DOMAIN" "$CLAUDENV_VI_KEY" -array "${args[@]}"
}

# Auto-register helper used by add/import when the flag file is present.
# Silent no-op if Vibe Island isn't available or the flag isn't set.
#
# NB: `local path` would clobber zsh's tied PATH array — we use `vi_path`
# throughout this file. Same applies to other helpers below.
_claudenv_vi_autoregister() {
  [ -f "$CLAUDENV_VI_FLAG" ] || return 0
  _claudenv_vi_available || return 0
  local vi_path
  vi_path=$(_claudenv_vi_path_for "$1")
  if _claudenv_vi_add_path "$vi_path"; then
    echo "  ↳ registered with Vibe Island (relaunch VI to finish — fork will show 'Repair' until then)"
  fi
}

# --- main command -----------------------------------------------------------

claudenv() {
  local cmd="$1"
  [ $# -gt 0 ] && shift

  case "$cmd" in
    add)
      local name="$1"
      if [ -z "$name" ]; then
        echo "Usage: claudenv add <name>" >&2
        return 1
      fi
      _claudenv_validate_name "$name" || return 1
      if [ -d "$CLAUDENV_ACCOUNTS_DIR/$name" ]; then
        echo "Account '$name' already exists" >&2
        return 1
      fi
      local first=0
      _claudenv_accounts_empty && first=1
      mkdir -p "$CLAUDENV_ACCOUNTS_DIR/$name"
      echo "Added account '$name' at $CLAUDENV_ACCOUNTS_DIR/$name"
      _claudenv_vi_autoregister "$name"
      if [ "$first" = 1 ]; then
        _claudenv_apply "$name"
        echo "$name" > "$CLAUDENV_CURRENT_FILE"
        echo "→ $name  (auto-activated as global default)"
        echo "Next: claude   (then /login)"
      else
        echo "Next: claudenv use $name && claude   (then /login)"
      fi
      ;;

    import)
      local name="$1" src="${2:-$HOME/.claude}"
      if [ -z "$name" ]; then
        echo "Usage: claudenv import <name> [source-dir]" >&2
        echo "  Default source: ~/.claude" >&2
        return 1
      fi
      _claudenv_validate_name "$name" || return 1
      if [ -d "$CLAUDENV_ACCOUNTS_DIR/$name" ]; then
        echo "Account '$name' already exists" >&2
        return 1
      fi
      if [ ! -d "$src" ]; then
        echo "Source directory '$src' does not exist" >&2
        return 1
      fi
      local first=0
      _claudenv_accounts_empty && first=1
      mkdir -p "$CLAUDENV_ACCOUNTS_DIR"
      if ! cp -R "$src" "$CLAUDENV_ACCOUNTS_DIR/$name"; then
        echo "Failed to copy $src" >&2
        rm -rf "${CLAUDENV_ACCOUNTS_DIR:?}/$name"
        return 1
      fi
      echo "Imported $src → '$name'"
      _claudenv_vi_autoregister "$name"
      if [ "$first" = 1 ]; then
        _claudenv_apply "$name"
        echo "$name" > "$CLAUDENV_CURRENT_FILE"
        echo "→ $name  (auto-activated as global default)"
      else
        echo "Next: claudenv use $name"
      fi
      ;;

    use)
      local name="$1"
      if [ -z "$name" ]; then
        # No arg — resolve via .claudenvrc, env-only (don't touch global default).
        # Lazy-create the profile if the .claudenvrc references one that
        # doesn't exist yet (e.g. a teammate added .claudenvrc in the repo).
        local rc_file
        if ! rc_file=$(_claudenv_find_rc); then
          echo "No .claudenvrc found in $PWD or any parent. Usage: claudenv use <name>" >&2
          return 1
        fi
        name=$(_claudenv_read_rc "$rc_file")
        if ! _claudenv_validate_name "$name" 2>/dev/null; then
          echo "Invalid or empty account name in $rc_file" >&2
          return 1
        fi
        if [ ! -d "$CLAUDENV_ACCOUNTS_DIR/$name" ]; then
          if ! mkdir -p "$CLAUDENV_ACCOUNTS_DIR/$name"; then
            echo "Failed to create '$name' at $CLAUDENV_ACCOUNTS_DIR/$name" >&2
            return 1
          fi
          echo "claudenv: created '$name' (referenced by $rc_file but missing in accounts/)"
        fi
        _claudenv_apply "$name"
        echo "→ $name  (from $rc_file)"
        return 0
      fi

      _claudenv_validate_name "$name" || return 1
      if [ ! -d "$CLAUDENV_ACCOUNTS_DIR/$name" ]; then
        echo "Account '$name' not found. Create it with: claudenv add $name" >&2
        return 1
      fi
      _claudenv_apply "$name"
      echo "$name" > "$CLAUDENV_CURRENT_FILE"
      echo "→ $name  (default)"
      ;;

    local)
      local name="$1"
      if [ -z "$name" ]; then
        echo "Usage: claudenv local <name>" >&2
        return 1
      fi
      _claudenv_validate_name "$name" || return 1
      if [ ! -d "$CLAUDENV_ACCOUNTS_DIR/$name" ]; then
        echo "Account '$name' not found. Create it with: claudenv add $name" >&2
        return 1
      fi
      echo "$name" > .claudenvrc
      _claudenv_apply "$name"
      echo "Wrote $PWD/.claudenvrc → $name"
      ;;

    list|ls)
      local current=""
      [ -f "$CLAUDENV_CURRENT_FILE" ] && current=$(cat "$CLAUDENV_CURRENT_FILE")
      local active=""
      [ -n "$CLAUDE_CONFIG_DIR" ] && active=$(basename "$CLAUDE_CONFIG_DIR")
      if [ -z "$(ls -A "$CLAUDENV_ACCOUNTS_DIR" 2>/dev/null)" ]; then
        echo "No accounts yet. Add one with: claudenv add <name>"
        return 0
      fi
      # Declare loop-locals once, then only assign inside the loop.
      # zsh's `local name` (without `=`) prints `name=value` from the
      # second iteration onward when TYPESET_SILENT is unset (default).
      local name marker
      for dir in "$CLAUDENV_ACCOUNTS_DIR"/*/; do
        name=$(basename "$dir")
        marker="  "
        [ "$name" = "$current" ] && marker="d "
        [ "$name" = "$active" ]  && marker="* "
        echo "$marker$name"
      done
      echo
      echo "  * = active in this shell    d = global default"
      ;;

    current)
      if [ -n "$CLAUDE_CONFIG_DIR" ]; then
        basename "$CLAUDE_CONFIG_DIR"
      else
        echo "(none)"
      fi
      ;;

    which)
      echo "${CLAUDE_CONFIG_DIR:-(not set)}"
      ;;

    run)
      local name="$1"
      [ $# -gt 0 ] && shift
      if [ -z "$name" ]; then
        echo "Usage: claudenv run <name> -- [claude args]" >&2
        return 1
      fi
      _claudenv_validate_name "$name" || return 1
      if [ ! -d "$CLAUDENV_ACCOUNTS_DIR/$name" ]; then
        echo "Account '$name' not found" >&2
        return 1
      fi
      if ! command -v claude >/dev/null 2>&1; then
        echo "claudenv: 'claude' not found on PATH. Install Claude Code first:" >&2
        echo "  https://docs.claude.com/en/docs/claude-code" >&2
        return 127
      fi
      [ "$1" = "--" ] && shift
      CLAUDE_CONFIG_DIR="$CLAUDENV_ACCOUNTS_DIR/$name" claude "$@"
      ;;

    plugins)
      local sub="$1"
      [ $# -gt 0 ] && shift

      case "$sub" in
        sync)
          local mode=copy src="$HOME/.claude" all=0
          local -a targets=()
          while [ $# -gt 0 ]; do
            case "$1" in
              --from)   src="$2"; shift 2 ;;
              --from=*) src="${1#--from=}"; shift ;;
              --link)   mode=link; shift ;;
              --copy)   mode=copy; shift ;;
              --all)    all=1; shift ;;
              -*)       echo "Unknown option: $1" >&2; return 1 ;;
              *)        targets+=("$1"); shift ;;
            esac
          done

          src="${src%/}"
          if [ ! -d "$src/plugins" ]; then
            echo "Source '$src' has no plugins/ dir. Pass --from <config-dir>." >&2
            return 1
          fi

          # Resolve targets: --all, explicit names, or the active account.
          if [ "$all" = 1 ]; then
            if _claudenv_accounts_empty; then
              echo "No accounts to sync. Add one with: claudenv add <name>" >&2
              return 1
            fi
            targets=()
            local dir
            for dir in "$CLAUDENV_ACCOUNTS_DIR"/*/; do
              targets+=("$(basename "$dir")")
            done
          elif [ "${#targets[@]}" -eq 0 ]; then
            local active
            active=$(_claudenv_active_name)
            if [ -z "$active" ]; then
              echo "No active account. Pass a name: claudenv plugins sync <name>" >&2
              return 1
            fi
            targets=("$active")
          fi

          echo "Syncing plugins ($mode) from $src:"
          local n rc=0
          for n in "${targets[@]}"; do
            _claudenv_validate_name "$n" || { rc=1; continue; }
            if [ ! -d "$CLAUDENV_ACCOUNTS_DIR/$n" ]; then
              echo "  ✗ $n: account not found (claudenv add $n)" >&2
              rc=1; continue
            fi
            _claudenv_plugins_sync_one "$n" "$src" "$mode" || rc=1
          done
          echo
          echo "Restart Claude Code / reload the VS Code window to pick up changes."
          return $rc
          ;;

        status)
          local name="${1:-$(_claudenv_active_name)}"
          if [ -z "$name" ]; then
            echo "Usage: claudenv plugins status [<name>]" >&2
            return 1
          fi
          _claudenv_validate_name "$name" || return 1
          local dir="$CLAUDENV_ACCOUNTS_DIR/$name"
          if [ ! -d "$dir" ]; then
            echo "Account '$name' not found" >&2
            return 1
          fi
          echo "Account: $name"
          echo "  config dir: $dir"
          if ! command -v jq >/dev/null 2>&1; then
            echo "  (install jq for a parsed view; showing raw files)"
            echo "  --- installed_plugins.json ---"
            cat "$dir/plugins/installed_plugins.json" 2>/dev/null || echo "  (none)"
            return 0
          fi
          echo "  installed:"
          jq -r '(.plugins // {}) | keys[]? | "    " + .' \
            "$dir/plugins/installed_plugins.json" 2>/dev/null || echo "    (none)"
          echo "  enabled:"
          jq -r '(.enabledPlugins // {}) | to_entries[] | select(.value)
                 | "    " + .key' "$dir/settings.json" 2>/dev/null || echo "    (none)"
          echo "  marketplaces:"
          jq -r '(. // {}) | keys[]? | "    " + .' \
            "$dir/plugins/known_marketplaces.json" 2>/dev/null || echo "    (none)"
          ;;

        ""|help|-h|--help)
          cat <<'EOF'
claudenv plugins — sync Claude Code plugins into isolated accounts

Usage:
  claudenv plugins sync [<name>|--all] [--from <dir>] [--link|--copy]
                                Copy plugins + enabled state into account(s)
  claudenv plugins status [<name>]   Show installed/enabled plugins for account

Options for sync:
  --from <dir>   Source config dir to sync from (default: ~/.claude)
  --copy         Copy plugin files into the account (default; full isolation)
  --link         Symlink cache/marketplaces (shared, saves disk, auto-updates)
  --all          Sync every account
  <name>         Sync a specific account (default: the active one)

Plugins live in a separate config dir per account, so plugins installed under
~/.claude don't appear under claudenv. `sync` brings them across and enables
them. Restart Claude Code (or reload the VS Code window) afterward.
EOF
          ;;

        *)
          echo "Unknown subcommand: plugins $sub. Run 'claudenv plugins help'" >&2
          return 1
          ;;
      esac
      ;;

    remove|rm)
      local name="$1"
      if [ -z "$name" ]; then
        echo "Usage: claudenv remove <name>" >&2
        return 1
      fi
      _claudenv_validate_name "$name" || return 1
      if [ ! -d "$CLAUDENV_ACCOUNTS_DIR/$name" ]; then
        echo "Account '$name' not found" >&2
        return 1
      fi
      printf "Delete account '%s' and all its data? [y/N] " "$name"
      read -r ans
      if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
        rm -rf "${CLAUDENV_ACCOUNTS_DIR:?}/$name"
        if [ -f "$CLAUDENV_CURRENT_FILE" ] && [ "$(cat "$CLAUDENV_CURRENT_FILE")" = "$name" ]; then
          rm -f "$CLAUDENV_CURRENT_FILE"
          unset CLAUDE_CONFIG_DIR
        fi
        # Drop the path from Vibe Island's fork list so it doesn't dangle.
        if _claudenv_vi_available; then
          _claudenv_vi_remove_path "$(_claudenv_vi_path_for "$name")"
        fi
        echo "Removed '$name'"
      fi
      ;;

    vibe-island)
      if [ "$(uname -s)" != "Darwin" ]; then
        echo "claudenv vibe-island: macOS only (Vibe Island is a macOS app)" >&2
        return 1
      fi
      if [ ! -f "$CLAUDENV_VI_PLIST" ]; then
        echo "claudenv vibe-island: Vibe Island prefs not found at $CLAUDENV_VI_PLIST" >&2
        echo "  Install Vibe Island first, then re-run this command." >&2
        return 1
      fi

      local sub="$1"
      [ $# -gt 0 ] && shift

      case "$sub" in
        install)
          local target="$1"
          local -a names=()
          if [ -z "$target" ] || [ "$target" = "--all" ]; then
            if _claudenv_accounts_empty; then
              echo "No profiles to register. Add one first: claudenv add <name>" >&2
              return 1
            fi
            local dir
            for dir in "$CLAUDENV_ACCOUNTS_DIR"/*/; do
              names+=("$(basename "$dir")")
            done
          else
            _claudenv_validate_name "$target" || return 1
            if [ ! -d "$CLAUDENV_ACCOUNTS_DIR/$target" ]; then
              echo "Account '$target' not found" >&2
              return 1
            fi
            names=("$target")
          fi

          local added=0 already=0 n vi_path
          for n in "${names[@]}"; do
            vi_path=$(_claudenv_vi_path_for "$n")
            if _claudenv_vi_contains "$vi_path"; then
              echo "  = $n  (already registered)"
              already=$((already + 1))
            else
              _claudenv_vi_add_path "$vi_path"
              echo "  + $n  ($vi_path)"
              added=$((added + 1))
            fi
          done

          # Set the flag so future add/import auto-register.
          touch "$CLAUDENV_VI_FLAG"

          echo
          echo "Registered $added new path(s); $already already present."
          if [ "$added" -gt 0 ]; then
            echo
            echo "→ Relaunch Vibe Island to finish setup."
            echo "  (New forks show a 'Repair' button until VI re-injects hooks on launch."
            echo "   Closing and reopening VI is enough; no need to click Repair manually.)"
          fi
          ;;

        uninstall)
          local target="$1"
          local -a paths_to_remove=()
          if [ -z "$target" ] || [ "$target" = "--all" ]; then
            if ! _claudenv_accounts_empty; then
              local dir
              for dir in "$CLAUDENV_ACCOUNTS_DIR"/*/; do
                paths_to_remove+=("$(_claudenv_vi_path_for "$(basename "$dir")")")
              done
            fi
            # Disable auto-register on add/import.
            rm -f "$CLAUDENV_VI_FLAG"
          else
            _claudenv_validate_name "$target" || return 1
            paths_to_remove=("$(_claudenv_vi_path_for "$target")")
          fi

          local removed=0 p
          for p in "${paths_to_remove[@]}"; do
            if _claudenv_vi_contains "$p"; then
              _claudenv_vi_remove_path "$p"
              echo "  - $p"
              removed=$((removed + 1))
            fi
          done

          echo
          echo "Removed $removed path(s)."
          if [ "$removed" -gt 0 ]; then
            echo "→ Relaunch Vibe Island to apply."
          fi
          ;;

        status)
          echo "Vibe Island prefs:  $CLAUDENV_VI_PLIST"
          echo "Auto-register flag: $([ -f "$CLAUDENV_VI_FLAG" ] && echo enabled || echo disabled)"
          echo
          echo "Registered Claude Code Forks:"
          local listed
          listed=$(_claudenv_vi_list_paths)
          if [ -z "$listed" ]; then
            echo "  (none)"
          else
            echo "$listed" | sed 's/^/  /'
          fi
          echo
          echo "claudenv profiles:"
          if _claudenv_accounts_empty; then
            echo "  (none)"
          else
            local n vi_path mark
            for dir in "$CLAUDENV_ACCOUNTS_DIR"/*/; do
              n=$(basename "$dir")
              vi_path=$(_claudenv_vi_path_for "$n")
              if _claudenv_vi_contains "$vi_path"; then
                mark="✓"
              else
                mark="·"
              fi
              echo "  $mark $n"
            done
            echo
            echo "  ✓ = registered    · = not registered"
          fi
          ;;

        ""|help|-h|--help)
          cat <<'EOF'
claudenv vibe-island — register claudenv profiles with Vibe Island (macOS)

Usage:
  claudenv vibe-island install [<name>|--all]    Register profile(s) as Claude Code Forks
  claudenv vibe-island uninstall [<name>|--all]  Unregister profile(s)
  claudenv vibe-island status                    Show registration state
  claudenv vibe-island help                      Show this help

`install` also enables auto-registration: future `claudenv add`/`import` will
register new profiles with Vibe Island automatically. `uninstall --all`
disables it again.

After install/uninstall, relaunch Vibe Island to apply (it injects hooks
into each registered path's settings.json on launch).
EOF
          ;;

        *)
          echo "Unknown subcommand: vibe-island $sub. Run 'claudenv vibe-island help'" >&2
          return 1
          ;;
      esac
      ;;

    help|--help|-h|"")
      cat <<'EOF'
claudenv — nvm-style account manager for Claude Code

Commands:
  claudenv add <name>           Create a new account slot
  claudenv import <name> [dir]  Copy existing config (default ~/.claude) as <name>
  claudenv use <name>           Switch shell to <name> and set as global default
  claudenv use                  Read .claudenvrc from current/parent dir and switch (no default change)
  claudenv local <name>         Write ./.claudenvrc with <name> and switch this shell
  claudenv list                 List all accounts (* = active, d = default)
  claudenv current              Print account active in this shell
  claudenv which                Print active CLAUDE_CONFIG_DIR
  claudenv run <name> -- ...    Run claude once with <name>, no shell switch
  claudenv remove <name>        Delete an account and its data
  claudenv plugins ...          Sync plugins into accounts (see `plugins help`)
  claudenv vibe-island ...      Register profiles with Vibe Island (macOS; see `vibe-island help`)

Optional: claudenv_enable_auto_switch    Auto-switch on cd into folders with .claudenvrc
EOF
      ;;

    *)
      echo "Unknown command: $cmd. Run 'claudenv help'" >&2
      return 1
      ;;
  esac
}

# --- auto-switch on cd (opt-in) ---------------------------------------------

_claudenv_auto_switch_hook() {
  local rc_file desired desired_path
  if rc_file=$(_claudenv_find_rc); then
    desired=$(_claudenv_read_rc "$rc_file")
    _claudenv_validate_name "$desired" 2>/dev/null || return
    desired_path="$CLAUDENV_ACCOUNTS_DIR/$desired"
    if [ ! -d "$desired_path" ]; then
      # Lazy-create the profile referenced by .claudenvrc. Silent on
      # failure so cd doesn't spam errors if e.g. disk is full.
      mkdir -p "$desired_path" 2>/dev/null || return
      echo "claudenv: created '$desired' (referenced by $rc_file but missing in accounts/)"
    fi
    if [ "$CLAUDE_CONFIG_DIR" != "$desired_path" ]; then
      export CLAUDE_CONFIG_DIR="$desired_path"
      echo "claudenv: → $desired  (from $rc_file)"
    fi
  else
    # Left every .claudenvrc tree — restore global default if drifted.
    if [ -f "$CLAUDENV_CURRENT_FILE" ]; then
      local default default_path
      default=$(cat "$CLAUDENV_CURRENT_FILE")
      default_path="$CLAUDENV_ACCOUNTS_DIR/$default"
      if [ -d "$default_path" ] && [ "$CLAUDE_CONFIG_DIR" != "$default_path" ]; then
        export CLAUDE_CONFIG_DIR="$default_path"
        echo "claudenv: → $default  (default)"
      fi
    fi
  fi
}

claudenv_enable_auto_switch() {
  if [ -n "$ZSH_VERSION" ]; then
    autoload -U add-zsh-hook 2>/dev/null
    add-zsh-hook chpwd _claudenv_auto_switch_hook
    _claudenv_auto_switch_hook
  elif [ -n "$BASH_VERSION" ]; then
    _claudenv_last_pwd="$PWD"
    _claudenv_prompt_hook() {
      if [ "$PWD" != "$_claudenv_last_pwd" ]; then
        _claudenv_last_pwd="$PWD"
        _claudenv_auto_switch_hook
      fi
    }
    case ";$PROMPT_COMMAND;" in
      *";_claudenv_prompt_hook;"*) ;;
      *) PROMPT_COMMAND="_claudenv_prompt_hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
    esac
    _claudenv_auto_switch_hook
  else
    echo "claudenv: auto-switch needs zsh or bash" >&2
    return 1
  fi
}

# --- shell completion -------------------------------------------------------

# ShellCheck doesn't understand zsh-specific syntax used in this function:
#   - SC2034: `subcommands` is consumed by `_describe`
#   - SC2154: `$words` and `$CURRENT` are zsh completion built-ins
#   - SC2296: `${(@f)...}` is the zsh "split on newlines" parameter flag
# shellcheck disable=SC2034,SC2154,SC2296
_claudenv_complete_zsh() {
  local -a subcommands accounts vi_subs
  subcommands=(
    'add:Create a new account slot'
    'import:Import existing config as a new account'
    'use:Switch account or read .claudenvrc'
    'local:Write .claudenvrc in current dir'
    'list:List all accounts'
    'current:Show active account'
    'which:Show CLAUDE_CONFIG_DIR'
    'run:Run claude once with account'
    'remove:Delete account'
    'plugins:Sync plugins into accounts'
    'vibe-island:Register profiles with Vibe Island (macOS)'
    'help:Show help'
  )
  vi_subs=(
    'install:Register profile(s) as Claude Code Forks'
    'uninstall:Unregister profile(s)'
    'status:Show registration state'
    'help:Show vibe-island help'
  )
  local -a plugin_subs
  plugin_subs=(
    'sync:Copy plugins + enabled state into account(s)'
    'status:Show installed/enabled plugins for an account'
    'help:Show plugins help'
  )

  if [ -d "$CLAUDENV_ACCOUNTS_DIR" ]; then
    accounts=("${(@f)$(ls -1 "$CLAUDENV_ACCOUNTS_DIR" 2>/dev/null)}")
  fi

  if (( CURRENT == 2 )); then
    _describe 'command' subcommands
  elif (( CURRENT == 3 )); then
    case "${words[2]}" in
      use|local|run|remove|rm)
        _describe 'account' accounts ;;
      vibe-island)
        _describe 'subcommand' vi_subs ;;
      plugins)
        _describe 'subcommand' plugin_subs ;;
    esac
  elif (( CURRENT == 4 )); then
    case "${words[2]} ${words[3]}" in
      'vibe-island install'|'vibe-island uninstall'|'plugins status')
        _describe 'account' accounts ;;
      'plugins sync')
        _describe 'account' accounts ;;
    esac
  fi
}

# SC2207: `compgen` output into COMPREPLY via word-splitting is the
# canonical bash completion idiom; mapfile alternative requires bash 4+.
# shellcheck disable=SC2207
_claudenv_complete_bash() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=()
  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W "add import use local list ls current which run remove rm plugins vibe-island help" -- "$cur") )
  elif [ "$COMP_CWORD" -eq 2 ]; then
    case "${COMP_WORDS[1]}" in
      use|local|run|remove|rm)
        local accounts
        accounts=$(ls -1 "$CLAUDENV_ACCOUNTS_DIR" 2>/dev/null)
        COMPREPLY=( $(compgen -W "$accounts" -- "$cur") ) ;;
      vibe-island)
        COMPREPLY=( $(compgen -W "install uninstall status help" -- "$cur") ) ;;
      plugins)
        COMPREPLY=( $(compgen -W "sync status help" -- "$cur") ) ;;
    esac
  elif [ "$COMP_CWORD" -eq 3 ]; then
    case "${COMP_WORDS[1]} ${COMP_WORDS[2]}" in
      "vibe-island install"|"vibe-island uninstall"|"plugins sync"|"plugins status")
        local accounts
        accounts=$(ls -1 "$CLAUDENV_ACCOUNTS_DIR" 2>/dev/null)
        COMPREPLY=( $(compgen -W "$accounts --all" -- "$cur") ) ;;
    esac
  fi
}

if [ -n "$ZSH_VERSION" ]; then
  compdef _claudenv_complete_zsh claudenv 2>/dev/null
elif [ -n "$BASH_VERSION" ]; then
  complete -F _claudenv_complete_bash claudenv 2>/dev/null
fi

# --- startup: restore last selected account ---------------------------------

if [ -f "$CLAUDENV_CURRENT_FILE" ]; then
  __claudenv_current=$(cat "$CLAUDENV_CURRENT_FILE")
  if [ -d "$CLAUDENV_ACCOUNTS_DIR/$__claudenv_current" ]; then
    export CLAUDE_CONFIG_DIR="$CLAUDENV_ACCOUNTS_DIR/$__claudenv_current"
  fi
  unset __claudenv_current
fi
