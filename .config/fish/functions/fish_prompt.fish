function fish_prompt
    set -l last_status $status
    set -l arrow_color brblue
    test $last_status -ne 0; and set arrow_color red
    echo -n (set_color cyan)$USER@(prompt_hostname)(set_color normal) (prompt_pwd) (set_color $arrow_color)'❯ '(set_color normal)
end
