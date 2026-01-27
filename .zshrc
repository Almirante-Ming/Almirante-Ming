
eval "$(mise activate zsh)"

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

_zsh_autosuggest_strategy_histdb_top_here() {
    local query="select commands.argv from
    history left join commands on history.command_id = commands.rowid
    left join places on history.place_id = places.rowid
    where places.dir LIKE '$(sql_escape $PWD)%'
    and commands.argv LIKE '$(sql_escape $1)%'
    group by commands.argv order by count(*) desc limit 1"

    suggestion=$(_histdb_query "$query")
}

_zsh_autosuggest_strategy_histdb_top() {
    local query="
    select commands.argv from history
    left join commands on history.command_id = commands.rowid
    left join places on history.place_id = places.rowid
    where commands.argv LIKE '$(sql_escape $1)%'
    group by commands.argv, places.dir
    order by places.dir != '$(sql_escape $PWD)', count(*) desc
    limit 1
    "

    suggestion=$(_histdb_query "$query")
}

ZSH_AUTOSUGGEST_STRATEGY=histdb_top_here
ZSH_AUTOSUGGEST_STRATEGY=histdb_top

source ~/.powerlevel10k/powerlevel10k.zsh-theme
source ~/.powerlevel10k/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.powerlevel10k/custom/plugins/zsh-histdb/sqlite-history.zsh

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export PATH=$PATH:'/home/almirante_ming/go/bin'
export PATH=$PATH:'/home/almirante_ming/.local/bin'

export PATH="$HOME/.cargo/bin:$PATH"


alias ls="exa -la --icons"
alias cat="bat"
alias ps="procs"
alias grep="rg"
alias top="ytop"
alias pyserver="python -m http.server 7777"
