#!/bin/bash
#
# install_dev_tools.sh
# Автоматичне встановлення Docker, Docker Compose,
# Python 3.9+ та Django
# Ubuntu / Debian
#

set -euo pipefail

# Утиліти
log() {
    echo "[INFO] $*"
}

error() {
    echo "[ERROR] $*" >&2
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Перевірка sudo
if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Визначення користувача
REAL_USER="${SUDO_USER:-$(id -un)}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

if [ -z "$REAL_HOME" ]; then
    error "Не вдалося визначити домашню директорію."
    exit 1
fi

# Перевірка ОС
check_os() {
    if [ ! -f /etc/os-release ]; then
        error "Не вдалося визначити ОС."
        exit 1
    fi

    . /etc/os-release

    case "${ID:-}" in
        ubuntu|debian|linuxmint|pop)
            ;;
        *)
            if [[ "${ID_LIKE:-}" != *debian* ]]; then
                error "Підтримуються Ubuntu та Debian."
                exit 1
            fi
            ;;
    esac

    log "Операційна система: ${PRETTY_NAME:-unknown}"
}

# Оновлення пакетів
update_apt() {
    log "Оновлення списку пакетів..."
    $SUDO apt-get update
}

# Встановлення Docker
install_docker() {
    if command_exists docker; then
        log "Docker вже встановлено: $(docker --version)"
        return 0
    fi

    log "Встановлення Docker..."

    local tmp
    tmp="$(mktemp)"

    curl -fsSL https://get.docker.com -o "$tmp"
    $SUDO sh "$tmp"
    rm -f "$tmp"

    log "Docker встановлено: $(docker --version)"
}

# Встановлення Docker Compose
install_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        log "Docker Compose вже встановлено."
        return 0
    fi

    if command_exists docker-compose; then
        log "Docker Compose standalone вже встановлено."
        return 0
    fi

    log "Встановлення Docker Compose..."

    if $SUDO apt-get install -y docker-compose-plugin; then
        log "Docker Compose встановлено."
        return 0
    fi

    log "Встановлення standalone Docker Compose..."

    local compose_version

    compose_version=$(curl -fsSL \
        https://api.github.com/repos/docker/compose/releases/latest \
        | grep '"tag_name"' | cut -d '"' -f 4)

    if [ -z "$compose_version" ]; then
        error "Не вдалося отримати версію Docker Compose."
        exit 1
    fi

    $SUDO curl -fL \
        "https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose

    $SUDO chmod +x /usr/local/bin/docker-compose

    log "Docker Compose встановлено: $(docker-compose --version)"
}

# Python 3.9+
PYTHON_CMD=""

install_python() {
    if command_exists python3; then
        local ver major minor

        ver=$(python3 --version | awk '{print $2}')
        major=$(echo "$ver" | cut -d. -f1)
        minor=$(echo "$ver" | cut -d. -f2)

        if [ "$major" -eq 3 ] && [ "$minor" -ge 9 ]; then
            PYTHON_CMD="python3"
            log "Python $ver вже встановлено."
            return 0
        fi
    fi

    update_apt

    local v pkg

    for v in 3.9 3.10 3.11 3.12; do
        pkg="python${v}"

        if apt-cache show "$pkg" 2>/dev/null | grep -q "^Package:"; then
            log "Встановлення $pkg..."

            if $SUDO apt-get install -y "$pkg" "${pkg}-venv"; then
                if command_exists "$pkg"; then
                    PYTHON_CMD="$pkg"
                    log "Python встановлено: $($pkg --version)"
                    return 0
                fi
            fi
        fi
    done

    if [ "${ID:-}" != "ubuntu" ]; then
        error "Python 3.9+ не знайдено у репозиторіях Debian."
        exit 1
    fi

    log "Встановлення Python через PPA deadsnakes..."

    if ! command_exists add-apt-repository; then
        $SUDO apt-get install -y software-properties-common
    fi

    $SUDO add-apt-repository ppa:deadsnakes/ppa -y

    update_apt

    $SUDO apt-get install -y python3.9 python3.9-venv

    PYTHON_CMD="python3.9"

    log "Python встановлено: $($PYTHON_CMD --version)"
}

# Django через віртуальне середовище
DJANGO_VENV="$REAL_HOME/.devops-venv"
DJANGO_PYTHON=""

install_django() {
    if [ -z "$PYTHON_CMD" ]; then
        error "Python не встановлено."
        exit 1
    fi

    if "$PYTHON_CMD" -m django --version >/dev/null 2>&1; then
        log "Django вже встановлено в системному Python."
        DJANGO_PYTHON="$PYTHON_CMD"
        return 0
    fi

    if [ -x "$DJANGO_VENV/bin/python" ] &&
       "$DJANGO_VENV/bin/python" -m django --version >/dev/null 2>&1; then
        log "Django вже встановлено у venv."
        DJANGO_PYTHON="$DJANGO_VENV/bin/python"
        return 0
    fi

    log "Створення віртуального середовища..."

    local py_base
    py_base="$(basename "$PYTHON_CMD")"

    $SUDO apt-get install -y "${py_base}-venv" || \
        $SUDO apt-get install -y python3-venv

    if [ ! -d "$DJANGO_VENV" ]; then
        "$PYTHON_CMD" -m venv "$DJANGO_VENV"
    fi

    if [ "$(id -u)" -eq 0 ]; then
        chown -R "$REAL_USER":"$(id -gn "$REAL_USER")" "$DJANGO_VENV"
    fi

    "$DJANGO_VENV/bin/python" -m pip install --upgrade pip
    "$DJANGO_VENV/bin/python" -m pip install django

    DJANGO_PYTHON="$DJANGO_VENV/bin/python"

    log "Django встановлено: $("$DJANGO_PYTHON" -m django --version)"
    log "Активація: source $DJANGO_VENV/bin/activate"
}

# Додавання користувача до групи Docker
add_user_to_docker_group() {
    if ! getent group docker >/dev/null 2>&1; then
        log "Групу docker не знайдено. Пропускаємо."
        return 0
    fi

    if id -nG "$REAL_USER" | grep -qw docker; then
        log "Користувач вже входить до групи docker."
        return 0
    fi

    log "Додавання користувача до групи docker..."

    $SUDO usermod -aG docker "$REAL_USER"

    log "Для застосування змін перезайдіть у систему."
}

# Головна функція
main() {
    log "Початок встановлення DevOps інструментів..."

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

    log "=========================================="
    log "Усі інструменти успішно встановлено!"
    log "Docker: $(docker --version)"

    if docker compose version >/dev/null 2>&1; then
        log "Docker Compose: $(docker compose version)"
    elif command_exists docker-compose; then
        log "Docker Compose: $(docker-compose --version)"
    fi

    log "Python: $("$PYTHON_CMD" --version)"
    log "Django: $("$DJANGO_PYTHON" -m django --version)"

    log "=========================================="
}

main "$@"
