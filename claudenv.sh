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
        # No arg — resolve via .claudenvrc, env-only (don't touch global default)
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
          echo "Account '$name' from $rc_file not found. Create it with: claudenv add $name" >&2
          return 1
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
      for dir in "$CLAUDENV_ACCOUNTS_DIR"/*/; do
        local name
        name=$(basename "$dir")
        local marker="  "
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
        echo "Removed '$name'"
      fi
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
    if [ -d "$desired_path" ] && [ "$CLAUDE_CONFIG_DIR" != "$desired_path" ]; then
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
  local -a subcommands accounts
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
    'help:Show help'
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
    COMPREPLY=( $(compgen -W "add import use local list ls current which run remove rm help" -- "$cur") )
  elif [ "$COMP_CWORD" -eq 2 ]; then
    case "${COMP_WORDS[1]}" in
      use|local|run|remove|rm)
        local accounts
        accounts=$(ls -1 "$CLAUDENV_ACCOUNTS_DIR" 2>/dev/null)
        COMPREPLY=( $(compgen -W "$accounts" -- "$cur") ) ;;
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
