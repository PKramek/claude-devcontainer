# Bash completion for Claude Code CLI
# Installed by the claude-code DevContainer Feature.
# To regenerate from your installed version:
#   claude completions bash > /usr/share/bash-completion/completions/claude

_claude() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local subcommands="agents auth auto-mode doctor install mcp plugin plugins setup-token update upgrade"

    local flags="-h --help -v --version -p --print -c --continue -r --resume \
-d --debug -n --name -w --worktree --model --effort --bare --verbose \
--json-schema --max-budget-usd --output-format --input-format \
--permission-mode --system-prompt --append-system-prompt --add-dir \
--allowed-tools --disallowed-tools --tools --mcp-config --settings --ide \
--tmux --file --agent --agents --betas --chrome --no-chrome"

    # Complete subcommands at position 1
    if [[ "${COMP_CWORD}" -eq 1 ]]; then
        mapfile -t COMPREPLY < <(compgen -W "${subcommands} ${flags}" -- "${cur}")
        return
    fi

    # Flag-specific completions
    case "${prev}" in
        --output-format)
            mapfile -t COMPREPLY < <(compgen -W "text json stream-json" -- "${cur}")
            return
            ;;
        --input-format)
            mapfile -t COMPREPLY < <(compgen -W "text json" -- "${cur}")
            return
            ;;
        --permission-mode)
            mapfile -t COMPREPLY < <(compgen -W "auto ask deny" -- "${cur}")
            return
            ;;
    esac

    # Complete flags at any position when the current word starts with -
    if [[ "${cur}" == -* ]]; then
        mapfile -t COMPREPLY < <(compgen -W "${flags}" -- "${cur}")
        return
    fi

    # Default: filename completion
    mapfile -t COMPREPLY < <(compgen -f -- "${cur}")
}

complete -F _claude claude
