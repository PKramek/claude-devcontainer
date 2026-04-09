#compdef claude
# Zsh completion for Claude Code CLI
# Installed by the claude-code DevContainer Feature.
# To regenerate from your installed version:
#   claude completions zsh > /usr/share/zsh/site-functions/_claude

# shellcheck disable=SC2034,SC2154  # zsh completion variables are set/used by _arguments framework

_claude() {
    local -a subcommands
    subcommands=(
        'agents:List available agents'
        'auth:Manage authentication'
        'auto-mode:Toggle automatic mode'
        'doctor:Check installation health'
        'install:Install components'
        'mcp:Manage MCP servers'
        'plugin:Manage plugins'
        'plugins:List plugins'
        'setup-token:Configure authentication token'
        'update:Update Claude Code'
        'upgrade:Upgrade Claude Code'
    )

    _arguments -s \
        '(-h --help)'{-h,--help}'[Show help]' \
        '(-v --version)'{-v,--version}'[Show version]' \
        '(-p --print)'{-p,--print}'[Print response to stdout]' \
        '(-c --continue)'{-c,--continue}'[Continue previous conversation]' \
        '(-r --resume)'{-r,--resume}'[Resume a specific conversation]' \
        '(-d --debug)'{-d,--debug}'[Enable debug mode]' \
        '(-n --name)'{-n,--name}'[Name for the conversation]:name' \
        '(-w --worktree)'{-w,--worktree}'[Use git worktree]' \
        '--model[Model to use]:model' \
        '--effort[Effort level]:effort' \
        '--bare[Bare output mode]' \
        '--verbose[Verbose output]' \
        '--json-schema[JSON schema for output]:schema' \
        '--max-budget-usd[Maximum budget in USD]:budget' \
        '--output-format[Output format]:format:(text json stream-json)' \
        '--input-format[Input format]:format:(text json)' \
        '--permission-mode[Permission mode]:mode:(auto ask deny)' \
        '--system-prompt[System prompt]:prompt' \
        '--append-system-prompt[Append to system prompt]:prompt' \
        '--add-dir[Add directory to context]:directory:_directories' \
        '--allowed-tools[Allowed tools]:tools' \
        '--disallowed-tools[Disallowed tools]:tools' \
        '--tools[Tools configuration]:tools' \
        '--mcp-config[MCP configuration file]:file:_files' \
        '--settings[Settings file]:file:_files' \
        '--ide[IDE integration]:ide' \
        '--tmux[Run in tmux session]' \
        '--file[Input file]:file:_files' \
        '--agent[Agent to use]:agent' \
        '--agents[List agents]' \
        '--betas[Enable beta features]:features' \
        '--chrome[Enable Chrome integration]' \
        '--no-chrome[Disable Chrome integration]' \
        '1:command:->commands' \
        '*::arg:->args'

    case "${state}" in
        commands)
            _describe -t commands 'claude command' subcommands
            ;;
        args)
            _files
            ;;
    esac
}

_claude "$@"
