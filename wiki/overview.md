---
tags: [overview, architecture]
---

# 00 — Обзор и философия проекта

← [Wiki Index](README.md)

## Цель

Воспроизводимая установка **Debian 13 (trixie)** для личной рабочей станции.
От пустого диска до полностью настроенной ОС одним прогоном. Настройки —
под контроль версий, машина — заменяема.

## Слои pipeline

```
┌──────────────────────────────────────────────────────────────┐
│  preseed/        — установка ОС (разметка, базовые пакеты)   │  Ventoy USB
│  ↓                                                           │
│  ansible/        — desktop-приложения + system-config        │  bootstrap.sh
│  ↓                                                           │
│  chezmoi         — пользовательские dotfiles                 │  bootstrap.sh
│  ↓                                                           │
│  user-tools      — atuin, rustup, go tools                   │  bootstrap.sh
│  ↓                                                           │
│  backup restore  — PG-volumes, /home/docs, /data/*           │  ручной шаг
└──────────────────────────────────────────────────────────────┘
```

Подробнее каждый слой:
- [10 — Preseed](preseed/README.md)
- [20 — Ansible](ansible/README.md)
- [60 — bootstrap.sh](post-install/README.md) (dotfiles + user-tools)
- [70 — Миграция данных](post-install/data-migration.md)

## Философия

- **preseed = минимальная прослойка.** Только то что должно быть в момент
  первой загрузки (диск, user, базовые пакеты). Без дополнений «на потом».
- **ansible = system-level.** Всё что ставится/конфигурируется как root
  на системе (apps, services, repos, config-файлы в `/etc/`).
- **chezmoi = user-level.** Всё что живёт под `~/` (dotfiles, конфиги
  приложений).
- **bootstrap.sh = оркестратор.** Тупой wrapper вокруг первых трёх.

Разделение даёт тестируемость: каждый слой меняется/запускается отдельно.

## Структура репо

```
my_os/
├── README.md                ← краткое summary
├── CLAUDE.md                ← правила валидации для Claude Code
├── bootstrap.sh             ← one-button restore (ansible + chezmoi + user-tools)
├── preseed/
│   ├── preseed.txt          ← вариант A (NVMe, LVM+btrfs)
│   ├── preseed-usb.txt      ← вариант B (USB SSD, ext4)
│   ├── ventoy.json          ← конфиг Ventoy (picker меню)
│   └── ...
├── ansible/
│   ├── site.yml             ← playbook
│   └── ...
└── wiki/                    ← эта документация
```

## Статус проекта

### ✅ Сделано
- preseed.txt (вариант A) — валидирован через debconf-set-selections
- preseed-usb.txt (вариант B) — валидирован
- ansible/site.yml с 9 приложениями + privoxy-config
- bootstrap.sh
- Ventoy-флешка (2 варианта через picker)

### ⏳ В процессе
- Первая успешная установка (пробовали — hit 3 подводных камня, см. [51 — Lessons learned](troubleshooting/lessons-learned.md))
- После успешной установки: создать dotfiles repo для chezmoi

### 🚫 Не сделано
- Перенос PG-данных со старой системы (см. [70 — Миграция данных](post-install/data-migration.md))

## Ссылки

- [01 — Hardware](hardware.md) — что за машина
- [40 — Процедура установки](installation/README.md) — как пользоваться
- [50 — Troubleshooting](troubleshooting/README.md) — если сломалось
