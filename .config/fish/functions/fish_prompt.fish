# Mínimo, na paleta do portfólio: caminho em zinc, seta roxa (vermelha se o último comando falhou)
function fish_prompt
    set -l last_status $status
    set -l arrow_color ac4bff
    test $last_status -ne 0; and set arrow_color f87171
    echo -n (set_color a1a1aa)(prompt_pwd)' '(set_color $arrow_color)'❯ '(set_color normal)
end
