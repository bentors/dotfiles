fish_add_path ~/.local/bin ~/.npm-global/bin

if status is-interactive
    # GitHub MCP plugin reads this token; scoped to claude instead of exported to every process
    function claude --wraps claude
        GITHUB_PERSONAL_ACCESS_TOKEN=(gh auth token 2>/dev/null) command claude $argv
    end
end
