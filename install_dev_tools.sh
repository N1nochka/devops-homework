#!/bin/bash
#
# install_dev_tools.sh
# Автоматичне встановлення Docker, Docker Compose, Python 3.9+ та Django
# Призначений для Ubuntu / Debian
#

set -euo pipefail

# ─── Утиліти ─────────────────────────────────────────────────
log()   { echo "[INFO]  $*"; }
error() { echo "[ERROR] $*" >&2; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

# Якщо запущено від root — sudo не потрібен
if [ "${EUID:-$(id -u)}" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

# Реальний користувач і його домашня тека (важливо при запуску через sudo)
REAL_USER="$(id -un)"
REAL_HOME="$HOME"
if [ -n "${SUDO_USER:-}" ]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
fi

# ─── Перевірка ОС ────────────────────────────────────────────
check_os() {
    if [ ! -f /etc/os-release ]; then
        error "Не вдалось визначити ОС. Скрипт призначений для Ubuntu/Debian."
        exit 1
    fi
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}" in
        ubuntu|debian|linuxmint|pop) ;;
        *)
            if [[ "${ID_LIKE:-}" != *debian* ]]; then
                error "Скрипт призначений для Ubuntu/Debian. Поточна ОС: ${ID:-unknown}"
                exit 1
            fi
            ;;
    esac
    log "ОС: ${PRETTY_NAME:-${ID:-unknown}}"
}

update_apt() {
    log "Оновлення списку пакетів..."
    $SUDO apt-get update -y
}

# ─── Docker ──────────────────────────────────────────────────
install_docker() {
    if command_exists docker; then
        log "Docker вже встановлено: $(docker --version)"
        return 0
    fi
    log "Встановлення Docker (офіційний скрипт get.docker.com)..."
    local tmp
    tmp="$(mktemp)"
    curl -fsSL https://get.docker.com -o "$tmp"
    $SUDO sh "$tmp"
    rm -f "$tmp"
    log "Docker встановлено: $(docker --version)"
}

# ─── Docker Compose ──────────────────────────────────────────
install_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        log "Docker Compose (плагін V2) вже встановлено: $(docker compose version)"
        return 0
    fi
    if command_exists docker-compose; then
        log "Docker Compose (standalone V1) вже встановлено: $(docker-compose --version)"
        return 0
    fi

    log "Встановлення Docker Compose..."
    if $SUDO apt-get install -y docker-compose-plugin 2>/dev/null; then
        log "Docker Compose плагін встановлено: $(docker compose version)"
        return 0
    fi

    log "Плагін недоступний, встановлюємо standalone-бінарник..."
    local compose_version
    compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest \
        | grep 'tag_name' | cut -d'"' -f4)
    $SUDO curl -L "https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    $SUDO chmod +x /usr/local/bin/docker-compose
    log "Docker Compose встановлено: $(docker-compose --version)"
}

# ─── Python 3.9+ ─────────────────────────────────────────────
PYTHON_CMD=""

install_python() {
    if command_exists python3; then
        local ver major minor
        ver=$(python3 --version 2>&1 | awk '{print $2}')
        major=$(echo "$ver" | cut -d. -f1)
        minor=$(echo "$ver" | cut -d. -f2)
        if [ "$major" -eq 3 ] && [ "$minor" -ge 9 ]; then
            log "Python $ver вже встановлено (>= 3.9)"
            PYTHON_CMD="python3"
            return 0
        fi
    fi

    update_apt
    local v pkg
    for v in 3.9 3.10 3.11 3.12; do
        pkg="python${v}"
        if apt-cache show "$pkg" 2>/dev/null | grep -q "^Package:"; then
            log "Встановлення $pkg зі стандартних репозиторіїв..."
            if $SUDO apt-get install -y "$pkg" "${pkg}-venv" 2>/dev/null \
               || $SUDO apt-get install -y "$pkg"; then
                if command_exists "$pkg"; then
                    PYTHON_CMD="$pkg"
                    log "Python $v встановлено: $($pkg --version)"
                    return 0
                fi
            fi
        fi
    done

    if [ "${ID:-}" != "ubuntu" ]; then
        error "Не вдалося знайти Python 3.9+ у репозиторіях Debian (${ID:-unknown})."
        error "Встановіть Python 3.9+ вручну і повторіть запуск."
        exit 1
    fi

    log "Стандартні репозиторії не містять Python 3.9+. Використовуємо PPA deadsnakes..."
    if ! command_exists add-apt-repository; then
        $SUDO apt-get install -y software-properties-common
    fi
    $SUDO add-apt-repository ppa:deadsnakes/ppa -y
    update_apt
    $SUDO apt-get install -y python3.9 python3.9-venv python3.9-distutils
    PYTHON_CMD="python3.9"
    log "Python 3.9 встановлено: $($PYTHON_CMD --version)"
}

# ─── Django (через venv) ─────────────────────────────────────
DJANGO_VENV="$REAL_HOME/.devops-venv"
DJANGO_PYTHON=""

ensure_venv_package() {
    local py_base
    py_base="$(basename "$PYTHON_CMD")"
    $SUDO apt-get install -y "${py_base}-venv" 2>/dev/null \
        || $SUDO apt-get install -y python3-venv 2>/dev/null \
        || true
}

install_django() {
    if [ -z "$PYTHON_CMD" ] || ! command_exists "$PYTHON_CMD"; then
        error "Python не встановлено — неможливо встановити Django"
        exit 1
    fi

    if "$PYTHON_CMD" -m django --version >/dev/null 2>&1; then
        log "Django вже встановлено (системний Python): $("$PYTHON_CMD" -m django --version)"
        DJANGO_PYTHON="$PYTHON_CMD"
        return 0
    fi

    if [ -x "$DJANGO_VENV/bin/python" ] \
       && "$DJANGO_VENV/bin/python" -m django --version >/dev/null 2>&1; then
        log "Django вже встановлено у venv: $("$DJANGO_VENV/bin/python" -m django --version)"
        DJANGO_PYTHON="$DJANGO_VENV/bin/python"
        return 0
    fi

    log "Створення віртуального середовища: $DJANGO_VENV"
    ensure_venv_package
    "$PYTHON_CMD" -m venv "$DJANGO_VENV"
    "$DJANGO_VENV/bin/pip" install --upgrade pip >/dev/null
    "$DJANGO_VENV/bin/pip" install django
    DJANGO_PYTHON="$DJANGO_VENV/bin/python"
    log "Django встановлено: $("$DJANGO_PYTHON" -m django --version)"
    log "Активувати venv: source $DJANGO_VENV/bin/activate"
}

# ─── Група docker ────────────────────────────────────────────
add_user_to_docker_group() {
    if ! getent group docker >/dev/null 2>&1; then
        log "Група docker не знайдена — пропускаємо додавання користувача"
        return 0
    fi
    if id -nG "$REAL_USER" 2>/dev/null | grep -qw docker; then
        log "Користувач $REAL_USER вже в групі docker"
        return 0
    fi
    log "Додавання $REAL_USER в групу docker..."
    $SUDO usermod -aG docker "$REAL_USER"
    log "Щоб зміни набули чинності: newgrp docker (або перезайдіть у систему)"
}

# ─── main ────────────────────────────────────────────────────
main() {
    log "Початок встановлення інструментів DevOps..."
    check_os
    update_apt

    if ! command_exists curl; then
        log "Встановлення curl..."
        $SUDO apt-get install -y curl
    fi

    install_docker
    install_docker_compose
    install_python
    install_django
    add_user_to_docker_group

    log "──────────────────────────────────────────────"
    log "Усі інструменти успішно встановлено!"
    log "Docker:         $(docker --version)"
    if docker compose version >/dev/null 2>&1; then
        log "Docker Compose: $(docker compose version)"
    elif command_exists docker-compose; then
        log "Docker Compose: $(docker-compose --version)"
    fi
    log "Python:         $("$PYTHON_CMD" --version)"
    log "Django:         $("$DJANGO_PYTHON" -m django --version)"
}

main "$@"
