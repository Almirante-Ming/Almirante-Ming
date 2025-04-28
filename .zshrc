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

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export PATH=$PATH:'/home/almirante_ming/.asdf/installs/rust/1.84.1/bin'
export PATH=$PATH:'/home/almirante_ming/.asdf/installs/python/3.12.0/bin'
export PATH=$PATH:'/home/almirante_ming/.asdf/installs/nodejs/23.0.0/bin'
export PATH=$PATH:'/home/almirante_ming/.asdf/installs/ruby/3.3.0/bin'

export PATH=$PATH:'/home/almirante_ming/.asdf/installs/kotlin/1.9.25/kotlinc/bin/'
export PATH=$PATH:'/home/almirante_ming/.asdf/installs/kotlin/1.9.25/kotlin-native/bin/'

export PATH=$PATH:'/home/almirante_ming/.asdf/installs/java/openjdk-17.0.2/bin/'

export PATH=$PATH:'/home/almirante_ming/go/bin'
export PATH=$PATH:'/home/almirante_ming/.local/bin'

export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools

. "$HOME/.asdf/asdf.sh"

alias ls="exa -la --icons"
alias cat="bat"
alias ps="procs"
alias grep="rg"
alias top="ytop"
