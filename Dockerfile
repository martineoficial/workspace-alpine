FROM alpine:3.21

# 1. Atualiza repositórios e instala utilitários + Runtimes + Neovim e dependências
RUN apk update && apk upgrade && apk add --no-cache \
    sudo \
    shadow \
    bash \
    zsh \
    zsh-vcs \
    git \
    curl \
    wget \
    unzip \
    jq \
    fzf \
    nano \
    neovim \
    ripgrep \
    fd \
    build-base \
    lsof \
    ca-certificates \
    nodejs \
    npm \
    go \
    musl-dev

# Argumentos do build
ARG USERNAME=dianapontes
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG GIT_NAME=""
ARG GIT_EMAIL=""

# 2. Cria usuário com shell Zsh e permissões sudo sem senha
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/zsh $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Alterna para o usuário para configurar a home
USER $USERNAME
WORKDIR /home/$USERNAME

# 3. Instala o Oh My Zsh (modo não-interativo)
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# 4. Instala o Zinit
RUN mkdir -p ~/.local/share/zinit && \
    git clone https://github.com/zdharma-continuum/zinit.git ~/.local/share/zinit/zinit.git

# 5. Configura o .zshrc: Tema agnoster, plugins nativos do OMZ e Zinit
RUN sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' ~/.zshrc \
    && sed -i 's/plugins=(git)/plugins=(git sudo ssh-agent fzf)/' ~/.zshrc

RUN cat << 'EOF' >> ~/.zshrc

# --- Zinit Package Manager ---
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
source "${ZINIT_HOME}/zinit.zsh"

# Zinit Snippets & Plugins
zinit light zdharma-continuum/fast-syntax-highlighting
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-completions

# Carrega as autocompletions registradas
autoload -U compinit && compinit

# --- Variáveis de Ambiente ---
export EDITOR="nvim"
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# --- Aliases ---
# Navegação e Sistema
alias ll="ls -la"
alias ..="cd .."
alias vim="nvim"
alias v="nvim"
alias vsc="code ."
alias mkd="mkdir"
alias hport="sudo lsof"
alias kport="kill -9 "
alias rmf="rm -rf "

# Git
alias gbv="git branch -vv"
alias gplo="git pull origin"
alias grea="git rebase --abort"
alias grec="git rebase --continue"
alias gres="git rebase --skip"
alias gpso="git push origin"
alias gbd="git branch -D"
alias greset="git reset --hard"
alias greset1="git reset --hard HEAD~1"

# NPM
alias nig="npm i -g"
alias nigv="npm i -g -v"
alias ni="npm i"
alias niv="npm i --verbose"
alias nilpd="npm i --legacy-peer-deps"
alias nilpdv="npm i --legacy-peer-deps --verbose"
alias nid="npm i -D"
alias nidv="npm i -D --verbose"
alias nidlpd="npm i -D --legacy-peer-deps"
alias nidlpdv="npm i -D --legacy-peer-deps --verbose"
alias nu="npm uninstall"
alias nuv="npm uninstall --verbose"
alias nup="npm update"
alias nupv="npm update --verbose"
alias nrun="npm run"
EOF

# 6. Configura o Git e habilita a gravação de credenciais HTTPS
RUN if [ -n "$GIT_NAME" ]; then git config --global user.name "$GIT_NAME"; fi && \
    if [ -n "$GIT_EMAIL" ]; then git config --global user.email "$GIT_EMAIL"; fi && \
    git config --global credential.helper store

WORKDIR /home/$USERNAME/workspace

CMD ["/bin/zsh"]