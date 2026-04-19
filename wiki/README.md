---
tags: [index, home]
aliases: [Home, Index]
---

# my_os — Wiki

Воспроизводимая установка **Debian 13 (trixie)** для рабочей станции.
Цель — «кнопка восстановления»: от пустого диска до полностью настроенной
системы одним прогоном.

## 🗺️ Структура wiki

```
wiki/
├── README.md                    ← вы здесь
├── overview.md                  — философия и слои pipeline
├── hardware.md                  — целевое железо
├── preseed/                     — автоустановка ОС
├── ansible/                     — desktop-приложения + system-config
├── ventoy/                      — boot-флешка
├── installation/                — процедура установки + проверки
├── troubleshooting/             — диагностика проблем
├── post-install/                — bootstrap.sh + data migration
└── qtile/                       — руководство по qtile WM (для DE-пользователя)
```

Каждая секция содержит:
- `README.md` — обзор и индекс темы
- Тематические файлы
- `decisions.md` — архитектурные решения и Q&A (то что обсуждалось)

## 🧭 Быстрая навигация

### Для начала
- [Обзор проекта](overview.md) — зачем, философия, структура
- [Целевое железо](hardware.md) — характеристики

### Preseed (автоустановка)
- [📂 Preseed — раздел](preseed/README.md)
  - [Variant A: NVMe (LVM+btrfs)](preseed/variant-a-nvme.md)
  - [Variant B: USB SSD (ext4)](preseed/variant-b-usb-ssd.md)
  - [Packages `pkgsel/include`](preseed/packages.md)
  - [`late_command`](preseed/late-command.md)
  - [Mirror выбор](preseed/mirror.md)
  - [📋 Decisions & Q&A](preseed/decisions.md)

### Ansible (apps)
- [📂 Ansible — раздел](ansible/README.md)
  - [Applications](ansible/applications.md)
  - [📋 Decisions & Q&A](ansible/decisions.md)

### Ventoy (boot-флешка)
- [📂 Ventoy — раздел](ventoy/README.md)
  - [📋 Decisions & Q&A](ventoy/decisions.md)

### Установка и проверка
- [📂 Installation — раздел](installation/README.md)
  - [Post-install checks](installation/post-install-checks.md)
  - [📋 Decisions & Q&A](installation/decisions.md)

### Troubleshooting
- [📂 Troubleshooting — раздел](troubleshooting/README.md)
  - [Lessons learned](troubleshooting/lessons-learned.md) — встреченные баги
  - [📋 Decisions & Q&A](troubleshooting/decisions.md)

### После установки
- [📂 Post-install — раздел](post-install/README.md) — bootstrap.sh
  - [Data migration](post-install/data-migration.md)
  - [📋 Decisions & Q&A](post-install/decisions.md)

### qtile (рабочее окружение)
- [📂 qtile — раздел](qtile/README.md) — руководство для DE-пользователя
  - [📖 Первые шаги](qtile/first-steps.md) — основы, первые 30 минут
  - [⌨️ Keybindings cheatsheet](qtile/keybindings.md)
  - [⚙️ Настройка `config.py`](qtile/config.md)
  - [🧰 Essentials — rofi/picom/скриншоты/...](qtile/essentials.md)
  - [📋 Decisions & Q&A](qtile/decisions.md)

## 📋 Decisions & Q&A — полный список

Архитектурные решения и ответы на вопросы, собранные в одном месте:
- [Preseed decisions](preseed/decisions.md) — S1 merge, flat btrfs, ESP size, mirror, use_mirror, portable boot, PG location
- [Ansible decisions](ansible/decisions.md) — ansible vs bash, native vs Flatpak, tags, chezmoi, privoxy
- [Ventoy decisions](ventoy/decisions.md) — Ventoy vs alternatives, picker array, Fedora quirks
- [Installation decisions](installation/decisions.md) — two variants, by-id, portable boot, finish hang
- [Troubleshooting decisions](troubleshooting/decisions.md) — docker validation, atomic apt, virtual consoles, NVRAM
- [Post-install decisions](post-install/decisions.md) — bootstrap orchestration, chezmoi, atuin, rustup, go
- [qtile decisions](qtile/decisions.md) — qtile vs DE, X11 vs Wayland, lightdm, kitty, multi-monitor

Поиск: в Obsidian глобальный поиск найдёт по тегу `#decisions` или `#qa`.

## Статус проекта

См. [Overview / Статус](overview.md#статус-проекта).

## Для разработчика

- [CLAUDE.md](../CLAUDE.md) — правила для Claude Code:
  - Валидация preseed/ansible через docker перед коммитом
  - Проверка существования пакетов
  - **Захват Q&A** — каждый вопрос пользователя и ответ на него → в `wiki/<section>/decisions.md`
- [Root README.md](../README.md) — TL;DR в корне
