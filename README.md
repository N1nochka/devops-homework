# DevOps Homeworks

Репозиторій з домашніми завданнями курсу DevOps.

## Структура

- install_dev_tools.sh — Bash-скрипт встановлення Docker, Docker Compose, Python 3.9+ і Django (гілка lesson-3).
- django_docker/ — Dockerized Django-проєкт з PostgreSQL і Nginx (гілка lesson-4).

---

## ДЗ3. Bash-скрипт install_dev_tools.sh

Скрипт автоматично встановлює Docker, Docker Compose, Python 3.9+ та Django на Ubuntu/Debian. Перевіряє, чи інструменти вже встановлені, щоб уникнути повторного встановлення.

Запуск:

    chmod u+x install_dev_tools.sh
    ./install_dev_tools.sh

Важливо: після додавання користувача в групу docker треба перезайти в систему (або виконати newgrp docker), щоб запускати docker без sudo.

---

## ДЗ4. Django + PostgreSQL + Nginx у Docker

Проєкт у папці django_docker/. Містить:
- Django-застосунок (myproject + app core)
- PostgreSQL 16 як базу даних
- Nginx як reverse proxy
- Dockerfile, docker-compose.yml, nginx/nginx.conf

Запуск:

    cd django_docker
    docker compose up --build -d

Після запуску застосунок доступний за адресою http://localhost.

Зупинка:

    docker compose down
