---
tags: [bootstrap, post-install, dotfiles]
---

# 60 — bootstrap.sh

← [Wiki Index](../README.md)

## Роль

`bootstrap.sh` — оркестратор, запускается **после** preseed-установки на
новой системе. Делает три слоя:

1. **ansible** → desktop-приложения + system-configs
2. **chezmoi** → user dotfiles из git-репо (TODO: создать репо)
3. **user-tools** → atuin, rustup, go tools

## Запуск

```bash
cd ~/mr/workspace/my_os    # репо склонирован в preseed late_command
./bootstrap.sh             # все три слоя
```

Отдельные этапы:
```bash
./bootstrap.sh ansible       # только system apps
./bootstrap.sh dotfiles      # только chezmoi
./bootstrap.sh user-tools    # только atuin/rustup/go
./bootstrap.sh --help
```

Idempotent — безопасно перезапускать.

## Структура

Файл: [`bootstrap.sh`](../../bootstrap.sh)

```bash
step_ansible()    # sudo ansible-playbook -i ansible/inventory.ini ansible/site.yml
step_dotfiles()   # chezmoi init --apply $DOTFILES_REPO (если задан)
step_user_tools() # atuin install script + rustup + go install ...
```

## Что в `step_ansible`

Запускает [`ansible/site.yml`](../../ansible/site.yml) через sudo. См. [20 — Ansible](../ansible/README.md).

## Что в `step_dotfiles`

Нужна переменная `DOTFILES_REPO` в начале скрипта. Пример:
```bash
DOTFILES_REPO="https://github.com/<you>/dotfiles.git"
```

Без неё шаг пропускается с warning.

При наличии: `chezmoi init --apply "$DOTFILES_REPO"` — клонирует репо,
применяет все dotfiles под `~/`.

**Dotfiles repo пока не создан** — TODO после первой успешной установки.
Кандидаты файлов для chezmoi:
- `~/.bashrc`, `~/.bash_profile`
- `~/.config/kitty/kitty.conf`
- `~/.config/qtile/config.py`
- `~/.gitconfig`, `~/.ssh/config`
- `~/.tmux.conf`

## Что в `step_user_tools`

### atuin — shell history sync
```bash
curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
# добавляет eval "$(atuin init bash)" в ~/.bashrc
```

### rustup — Rust toolchain
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
```

### Go tools
```bash
go install github.com/go-delve/delve/cmd/dlv@latest
go install golang.org/x/tools/gopls@latest
go install honnef.co/go/tools/cmd/staticcheck@latest
```

Все idempotent — проверяют наличие бинаря перед установкой.

## Pipeline восстановления (полная картина)

```
┌────────────────────────────────────────────────────────┐
│ 1. Ventoy USB → preseed install (20-40 мин)            │
│    → Debian с docker/chrome/fonts/my_os repo           │
├────────────────────────────────────────────────────────┤
│ 2. Boot новой системы                                  │
│    → autologin user → qtile                            │
├────────────────────────────────────────────────────────┤
│ 3. cd ~/mr/workspace/my_os && ./bootstrap.sh           │
│    ├─ ansible → desktop apps + privoxy                 │
│    ├─ chezmoi → dotfiles (после того как репо создан)  │
│    └─ user-tools → atuin/rustup/go                     │
├────────────────────────────────────────────────────────┤
│ 4. (опционально) [70 Data migration](data-migration.md)│
│    → PG dumps restore, rsync /home и /data             │
└────────────────────────────────────────────────────────┘
```

## Архитектурные решения

См. [decisions.md](decisions.md) — почему сделано именно так, обсуждённые альтернативы.

## Ссылки

- [20 — Ansible playbook](../ansible/README.md)
- [21 — Applications](../ansible/applications.md)
- [70 — Data migration](data-migration.md)
