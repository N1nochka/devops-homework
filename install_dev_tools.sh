#!/bin/bash

# install_dev_tools.sh
# Автоматичне встановлення Docker, Docker Compose, Python 3.9+ та Django
# Для Ubuntu/Debian

set -o pipefail

log()   { echo "[INFO] $1"; }
error() { echo "[ERROR] $1" >&2; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

update_apt() {
    log "Оновлення списку пакетів..."
    sudo apt-get update -y
}

install_docker() {
    if command_exists docker; then
        log "Docker вже встановлено: $(docker --version)"
    else
        log "Встановлення Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
        log "Docker встановлено: $(docker --version)"
    fi
}

install_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        log "Docker Compose (плагін) вже встановлено: $(docker compose version)"
    elif command_exists docker-compose; then
        log "Docker Compose (standalone) вже встановлено: $(docker-compose --version)"
    else
        log "Встановлення Docker Compose..."
        if sudo apt-get install -y docker-compose-plugin; then
            log "Docker Compose плагін встановлено: $(docker compose version)"
        else
            log "Плагін недоступний, встановлюємо standalone Docker Compose..."
            COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
            sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            log "Docker Compose встановлено: $(docker-compose --version)"
        fi
    fi
}

install_python() {
    if command_exists python3; then
        PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
        PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
        PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)
        if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 9 ]; then
            log "Python $PYTHON_VERSION вже встановлено (>= 3.9)"
            PYTHON_CMD="python3"
            return
        fi
    fi
    log "Встановлення Python 3.9+..."
    if ! command_exists add-apt-repository; then
        sudo apt-get install -y software-properties-common
    fi
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    update_apt
    sudo apt-get install -y python3.9 python3.9-distutils python3.9-venv
    PYTHON_CMD="python3.9"
    log "Python 3.9 встановлено: $($PYTHON_CMD --version)"
}

install_django() {
    if $PYTHON_CMD -m django --version >/dev/null 2>&1; then
        log "Django вже встановлено: $($PYTHON_CMD -m django --version)"
    else
        log "Встановлення Django..."
        if ! $PYTHON_CMD -m pip --version >/dev/null 2>&1; then
            $PYTHON_CMD -m ensurepip --upgrade
        fi
        $PYTHON_CMD -m pip install --upgrade pip
        $PYTHON_CMD -m pip install django
        log "Django встановлено: $($PYTHON_CMD -m django --version)"
    fi
}

main() {
    log "Початок встановлення інструментів DevOps..."
    update_apt
    if ! command_exists curl; then
        log "Встановлення curl..."
        sudo apt-get install -y curl
    fi
    install_docker
    install_docker_compose
    install_python
    install_django

    log "Усі інструменти успішно встановлено!"
    log "Docker: $(docker --version)"
    if docker compose version >/dev/null 2>&1; then
        log "Docker Compose: $(docker compose version)"
    elif command_exists docker-compose; then
        log "Docker Compose: $(docker-compose --version)"
    fi
    log "Python: $($PYTHON_CMD --version)"
    log "Django: $($PYTHON_CMD -m django --version)"

    if ! groups "$USER" | grep -q '\bdocker\b'; then
        log "Додавання користувача $USER в групу docker..."
        sudo usermod -aG docker "$USER"
        log "Щоб зміни набули чинності: newgrp docker або перезайдіть у систему."
    fi
}

main
