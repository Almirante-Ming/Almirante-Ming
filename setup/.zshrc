if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source ~/.zsh/zsh-histdb/sqlite-history.zsh
source ~/.powerlevel10k/powerlevel10k.zsh-theme
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

ZSH_AUTOSUGGEST_STRATEGY=histdb_top_here
ZSH_AUTOSUGGEST_STRATEGY=histdb_top

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

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


export PATH=$PATH:'~/go/bin'
export PATH=$PATH:'~/.local/bin'
export PATH=$PATH:'~/.bun/bin'
export PATH=$PATH:'~/.cargo/bin'

export ANDROID_HOME=$HOME/.local/share/Android/Sdk 
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:'/opt/android-sdk/platform-tools/'



alias ls="exa -la --icons"
alias cat="bat"
alias ps="procs"
alias grep="rg"
alias top="ytop"
alias pyserver="python -m http.server 7777"

eval "$(mise activate zsh)"


new_pass() {
    local TIPO=${1:-hex}
    local TAMANHO=${2:-16}

    if [[ "$1" =~ ^([a-zA-Z]+)([0-9]+)$ ]]; then
        TIPO="${match[1]}"
        TAMANHO="${match[2]}"
    fi

    python3 -c "
    import secrets
    import string
    import sys

    tipo = '$TIPO'.lower()
    tamanho = int('$TAMANHO')

    if tipo == 'hex':
        # secrets.token_hex gera 2 caracteres por byte informado, ajustamos o tamanho real
        print(secrets.token_hex((tamanho + 1) // 2)[:tamanho])
    elif tipo == 'url' or tipo == 'base64':
        print(secrets.token_urlsafe(tamanho)[:tamanho])
    elif tipo == 'pass' or tipo == 'text':
        # Gera uma senha complexa com letras, números e símbolos
        caracteres = string.ascii_letters + string.digits + '!@#$%*()_+-='
        senha = ''.join(secrets.choice(caracteres) for _ in range(tamanho))
        print(senha)
    else:
        print(f'Tipo \'{tipo}\' desconhecido. Use: hex, url ou pass.', file=sys.stderr)
    "
}
