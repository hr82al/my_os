---
tags: [ansible, overview]
---

# 20 — Ansible playbook: обзор

← [Wiki Index](../README.md)

## Что делает

Ansible-playbook устанавливает **desktop-приложения и system-configs**
поверх базового Debian после preseed. Запускается:
- Вручную: `sudo ansible-playbook -i inventory.ini site.yml`
- Через оркестратор: `./bootstrap.sh ansible`

Idempotent: можно перезапускать — применяются только изменения.

## Файлы

- [`ansible/site.yml`](../../ansible/site.yml) — playbook (1 play, ~30 задач)
- [`ansible/inventory.ini`](../../ansible/inventory.ini) — `[local] localhost ansible_connection=local`
- [`ansible/README.md`](../../ansible/README.md) — краткая справка по запуску

## Теги

Каждое приложение имеет свой тег для выборочного запуска:

```bash
# Одно приложение
sudo ansible-playbook -i inventory.ini site.yml --tags vscode

# Несколько
sudo ansible-playbook -i inventory.ini site.yml --tags "vscode,dbeaver,bruno"

# Dry-run
sudo ansible-playbook -i inventory.ini site.yml --check

# Список задач/тегов
sudo ansible-playbook -i inventory.ini site.yml --list-tasks
sudo ansible-playbook -i inventory.ini site.yml --list-tags
```

Список тегов: `vscode`, `dbeaver`, `obsidian`, `bruno`, `throne`, `chezmoi`,
`postman`, `redisinsight`, `libreoffice`, `telegram`, `debian-repo`, `privoxy`, `cleanup`.

## Что ставится

См. [21 — Applications](applications.md) — детали каждого приложения.

## System-level конфиги

### privoxy (HTTP→SOCKS5 мост)

Блок `tags: [privoxy]`:
- Дописывает `forward-socks5 / 127.0.0.1:2080 .` в `/etc/privoxy/config`
- `systemctl enable --now privoxy`
- Handler рестартует service при изменении конфига

Работает с локальным SOCKS5 пользователя на 127.0.0.1:2080 (Throne или аналог).
См. [21 — Applications](applications.md#throne).

## Валидация ansible

Перед любой правкой `site.yml`:

```bash
docker run --rm -v $PWD/ansible:/a debian:13 bash -c \
    'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y ansible >/dev/null 2>&1 && cd /a && ansible-playbook -i inventory.ini site.yml --syntax-check'
```

## Идемпотентность

- `apt`, `get_url`, `unarchive` — проверяют состояние, применяют только если отличается
- Исключение: `dbeaver-ce_latest_amd64.deb` — URL невeрсионный, всегда перескачивается (но `apt: deb:` не переустановит если версия та же)

## Архитектурные решения

См. [decisions.md](decisions.md) — почему сделано именно так, обсуждённые альтернативы.

## Ссылки

- [21 — Applications](applications.md)
- [60 — bootstrap.sh](../post-install/README.md) — как ansible запускается из pipeline
- [CLAUDE.md](../../CLAUDE.md) — правила валидации
