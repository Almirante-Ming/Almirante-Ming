#!/bin/bash

echo "Iniciando configuração padrão de Git e SSH..."

# 1. Coleta de dados
read -p "Nome para o Git: " GIT_NAME
read -p "Email para o Git e SSH: " GIT_EMAIL

# 2. Configurações Globais do Git
echo "Configurando Git..."
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global core.editor "lvim"

# 3. Geração da Chave SSH (Padrão ED25519)
SSH_DIR="$HOME/.ssh"
SSH_KEY="$SSH_DIR/id_ed25519"

if [ ! -f "$SSH_KEY" ]; then
    echo "Gerando nova chave SSH ED25519..."
    # O comando pedirá uma passphrase. É recomendado usar uma!
    ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$SSH_KEY"
else
    echo "Chave SSH já existente em $SSH_KEY. Pulando geração."
fi

# 4. Configuração do SSH Config
if [ ! -f "$SSH_DIR/config" ] || ! grep -q "AddKeysToAgent" "$SSH_DIR/config"; then
    echo "Ajustando ~/.ssh/config..."
    cat <<EOF >> "$SSH_DIR/config"

Host *
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519
EOF
    chmod 600 "$SSH_DIR/config"
fi

# 5. Integração com o Shell (Bash/Zsh)
RC_FILE="$HOME/.bashrc"
[ -f "$HOME/.zshrc" ] && RC_FILE="$HOME/.zshrc"

if ! grep -q "ssh-agent" "$RC_FILE"; then
    echo "Adicionando autostart do ssh-agent ao $RC_FILE..."
    cat <<'EOF' >> "$RC_FILE"

# Iniciar ssh-agent silenciosamente se não estiver rodando
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null
    ssh-add ~/.ssh/id_ed25519 2>/dev/null
fi
EOF
fi

echo "✅ Configuração concluída! Reinicie o terminal para aplicar."
echo "Copie a chave pública abaixo para o GitHub/GitLab:"
cat "${SSH_KEY}.pub"
