---
tags: [post-install, decisions, qa]
---

# Post-install — Decisions & Q&A

← [Post-install](README.md) | [Wiki Index](../README.md)

## Q: Почему bootstrap.sh — тонкий orchestrator, а не делает всё сам?

**Обсудили:** bootstrap.sh мог бы сам ставить docker, chrome, dotfiles и т.д.
Но это смешало бы слои.

**Решение — разделение:**
- `preseed` — ставит базу (ОС + packages)
- `bootstrap.sh` — оркестрирует:
  - `ansible/` → system apps (sudo, declarative)
  - `chezmoi` → dotfiles (user, via git)
  - atuin/rustup/go → user-tools (user, imperative)

Каждый слой **тестируется отдельно**:
```bash
./bootstrap.sh ansible       # только system apps
./bootstrap.sh dotfiles      # только chezmoi
./bootstrap.sh user-tools    # только atuin/rustup/go
```

## Q: chezmoi vs direct git-clone dotfiles?

**chezmoi:**
- Шаблонизация (templates с разными значениями для разных машин)
- Encrypted secrets (age/gpg)
- Один repo → разные dotfiles в зависимости от `.chezmoi.toml.tmpl`
- Легко добавить/удалить файлы через `chezmoi add ~/.bashrc`

**Direct git-clone:**
- Проще (clone → symlink → done)
- Но управление секретами и host-specific variations вручную

**Решение: chezmoi.** Встроенная поддержка scenarios (домашний лаптоп vs
рабочий, разные Linux-дистры). Overhead малый.

## Q: Почему atuin НЕ в preseed?

**atuin** — shell history с sync. Требует per-user state и config:
- `~/.config/atuin/config.toml`
- `atuin register/login/sync` — по SSH-ключу/email
- Интеграция в `~/.bashrc`

**Если поставить в preseed:** бинарь появится, но per-user setup всё равно надо
делать руками. Место переехать в bootstrap.sh.

**Решение:** в `step_user_tools()` `bootstrap.sh`:
```bash
curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
```

## Q: rustup (script) вs `rustc` (Debian package)?

| | rustup | debian rustc |
|---|---|---|
| Версия | latest stable (регулярно) | fixed (~год отставания) |
| Toolchain multiplex | ✅ (stable/nightly switch) | ❌ |
| Установка | curl + sh | apt |
| Нужно для | rust-analyzer, cargo install | редкие системные утилиты |

**Решение: rustup** в bootstrap.sh. Stable toolchain по умолчанию. Пользователь
делает rust-разработку → нужен свежий.

## Q: Go tools через `go install` vs debian-пакеты?

Debian имеет `delve`, `gopls` и т.д., но:
- Отстают (часто critical updates упущены)
- Не все tools в Debian
- `go install` стандартный workflow для Go-разработчиков

**Решение:** `go install ...@latest` в bootstrap.sh для: dlv, gopls, staticcheck.

## Q: Зачем `./bootstrap.sh all | ansible | dotfiles | user-tools`?

Selective execution:
- После изменения только ansible-роли → запустить только ansible
- Обновить Rust toolchain отдельно → только user-tools
- Переподтянуть dotfiles → только dotfiles

Без аргумента — `all` (полный прогон).

## Q: Как восстановить PG-данные?

См. [Data migration](data-migration.md). Два варианта:
1. **`pg_dump` → `psql restore`** — универсально, но медленно для больших БД (38 GB = ~30 мин)
2. **Копирование `/var/lib/docker/volumes/*/_data/`** — быстро, но требует совпадения UID/GID postgres-user в контейнере и на хосте

**Решение:** оставлено на выбор — оба работают. Для первой миграции рекомендую
`pg_dump` (чище, явный формат).

## Q: Почему data-migration не часть bootstrap.sh?

Данные — **стратегически отдельная** история:
- Бэкап-стратегия может эволюционировать (rsync → restic → cloud backup)
- Пользовательские данные не для каждой машины одинаковые
- Restore требует интерактивности (выбрать snapshot, проверить целостность)

**Решение:** оставить ручным шагом с документацией. Позже можно добавить
`./bootstrap.sh restore-data` если автоматизация окупится.

## Ссылки

- [Bootstrap.sh](README.md)
- [Data migration](data-migration.md)
- [Ansible](../ansible/README.md)
