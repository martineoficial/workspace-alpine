#!/bin/bash

PROFILES_FILE=".user_profiles"
IMAGE_NAME="workspace-alpine"
CONTAINER_NAME="alpine_workspace"
HOSTNAME="alpine-dev"

touch "$PROFILES_FILE"

create_new_profile() {
    echo ""
    echo "--- Cadastrar Novo Perfil ---"
    read -p "Nome de usuario Unix [padrao: dianapontes]: " SYS_USER
    SYS_USER=${SYS_USER:-dianapontes}

    read -p "Git user.name: " GIT_NAME
    read -p "Git user.email: " GIT_EMAIL

    echo "${SYS_USER}|${GIT_NAME}|${GIT_EMAIL}" >> "$PROFILES_FILE"
    echo "Perfil para '$SYS_USER' salvo com sucesso!"
}

PROFILES_COUNT=$(grep -c '^[^#[:space:]]' "$PROFILES_FILE" 2>/dev/null || echo 0)
PROFILES_COUNT=${PROFILES_COUNT//[[:space:]]/}

if [ "$PROFILES_COUNT" -eq 0 ] 2>/dev/null; then
    echo "Nenhum perfil encontrado."
    create_new_profile
    SELECTED_LINE=$(tail -n 1 "$PROFILES_FILE")
else
    echo "--- Perfis Salvos Encontrados ---"
    i=1
    while IFS='|' read -r u_name g_name g_email; do
        [ -z "$u_name" ] && continue
        echo "  [$i] Usuario: $u_name | Git Name: $g_name | Git Email: $g_email"
        i=$((i+1))
    done < "$PROFILES_FILE"
    echo "  [$i] Cadastrar um novo perfil"
    echo ""

    read -p "Escolha uma opcao [1-$i]: " CHOICE

    if [ "$CHOICE" -eq "$i" ] 2>/dev/null; then
        create_new_profile
        SELECTED_LINE=$(tail -n 1 "$PROFILES_FILE")
    else
        SELECTED_LINE=$(sed -n "${CHOICE}p" "$PROFILES_FILE")
    fi
fi

IFS='|' read -r SYS_USER GIT_NAME GIT_EMAIL <<< "$SELECTED_LINE"
WORKSPACE_DIR="/home/$SYS_USER/workspace"

# Verifica se o container ja existe
CONTAINER_EXISTS=$(docker ps -a -q -f name=^/${CONTAINER_NAME}$)

if [ -n "$CONTAINER_EXISTS" ]; then
    echo ""
    echo "Um container '$CONTAINER_NAME' ja existe."
    echo "  [1] Entrar no container existente (atualizando Git do perfil '$SYS_USER')"
    echo "  [2] Reconstruir o container do zero para '$SYS_USER'"
    echo ""
    read -p "Escolha uma opcao [1-2, padrao: 1]: " REBUILD_CHOICE
    REBUILD_CHOICE=${REBUILD_CHOICE:-1}

    if [ "$REBUILD_CHOICE" -eq 2 ]; then
        echo "Parando e removendo container antigo..."
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1
        docker rm "$CONTAINER_NAME" >/dev/null 2>&1

        echo "Construindo nova imagem para o usuario '$SYS_USER'..."
        docker build \
          --build-arg USERNAME="$SYS_USER" \
          --build-arg GIT_NAME="$GIT_NAME" \
          --build-arg GIT_EMAIL="$GIT_EMAIL" \
          -t "$IMAGE_NAME" .

        echo "Iniciando novo container..."
        docker run -d \
          --name "$CONTAINER_NAME" \
          --hostname "$HOSTNAME" \
          -v "$(pwd)":"$WORKSPACE_DIR" \
          -it "$IMAGE_NAME"
    else
        # Se o container estiver parado, inicia
        if [ -z "$(docker ps -q -f name=^/${CONTAINER_NAME}$)" ]; then
            echo "Iniciando container..."
            docker start "$CONTAINER_NAME" >/dev/null 2>&1
        fi

        # Atualiza a configuracao do Git em tempo de execucao para o perfil escolhido
        echo "Ajustando configuracoes do Git para o perfil '$SYS_USER'..."
        docker exec "$CONTAINER_NAME" git config --global user.name "$GIT_NAME"
        docker exec "$CONTAINER_NAME" git config --global user.email "$GIT_EMAIL"
    fi
else
    # Primeira criacao
    echo "Construindo imagem para o usuario '$SYS_USER'..."
    docker build \
      --build-arg USERNAME="$SYS_USER" \
      --build-arg GIT_NAME="$GIT_NAME" \
      --build-arg GIT_EMAIL="$GIT_EMAIL" \
      -t "$IMAGE_NAME" .

    echo "Iniciando container..."
    docker run -d \
      --name "$CONTAINER_NAME" \
      --hostname "$HOSTNAME" \
      -v "$(pwd)":"$WORKSPACE_DIR" \
      -it "$IMAGE_NAME"
fi

echo ""
echo "Logando no workspace como '$SYS_USER' ($GIT_EMAIL)..."
docker exec -it "$CONTAINER_NAME" zsh