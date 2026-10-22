# ==========================================
# 1. POWERLEVEL10K INSTANT PROMPT (Deve ficar no topo)
# ==========================================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ==========================================
# 2. VARIÁVEIS DE AMBIENTE E PATH
# ==========================================
# Export de binários no PATH (usando $HOME para evitar bugs de aspas)
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.bun/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# Configurações do Android SDK
export ANDROID_HOME="$HOME/.local/share/Android/Sdk"
export PATH="$PATH:$ANDROID_HOME/emulator"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"


# Carregamento dos Plugins
source ~/.zsh/zsh-histdb/zsh-histdb.zsh
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-venvautoswitch/zsh-venvautoswitch.zsh

source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ==========================================
# 4. TEMA E APARÊNCIA
# ==========================================
source ~/.powerlevel10k/powerlevel10k.zsh-theme

# ==========================================
# 5. INTEGRACÕES DE FERRAMENTAS & ALIASES
# ==========================================
eval "$(mise activate zsh)"

# Aliases
alias ls="exa -la --icons"
alias cat="bat"
alias ps="procs"
alias grep="rg"
alias top="ytop"
alias pyserver="python -m http.server 7777"
alias load_env="set -a && source .env && set +a"

# ==========================================
# 6. FUNÇÕES CUSTOMIZADAS
# ==========================================
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
    print(secrets.token_hex((tamanho + 1) // 2)[:tamanho])
  elif tipo in ('url', 'base64'):
    print(secrets.token_urlsafe(tamanho)[:tamanho])
  elif tipo in ('pass', 'text'):
    caracteres = string.ascii_letters + string.digits + '!@#$%*()_+-='
    senha = ''.join(secrets.choice(caracteres) for _ in range(tamanho))
    print(senha)
  else:
    print(f'Tipo \'{tipo}\' desconhecido. Use: hex, url ou pass.', file=sys.stderr)
  "
}

# ==========================================
# 7. CONFIGURAÇÃO FINAL DO POWERLEVEL10K
# ==========================================
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
