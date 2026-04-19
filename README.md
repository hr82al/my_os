# my_os

Воспроизводимая установка **Debian 13 (trixie)** для личной рабочей станции.
От пустого диска до полностью настроенной ОС одним прогоном.

📖 **Полная документация:** [wiki/](wiki/README.md)

## TL;DR

```
preseed (Ventoy USB) → установка ОС
        ↓
bootstrap.sh → ansible + chezmoi + user-tools → готовая система
```

**Установка:**
1. Подготовить Ventoy-флешку ([wiki/30-ventoy.md](wiki/30-ventoy.md))
2. Boot с флешки → выбрать preseed ([wiki/40-installation.md](wiki/40-installation.md)):
   - `preseed.txt` — на внутренний NVMe (LVM+btrfs, вариант A)
   - `preseed-usb.txt` — на внешний USB SSD (ext4, вариант B)
3. После первого boot'а: `cd ~/mr/workspace/my_os && ./bootstrap.sh`

## Структура

```
my_os/
├── README.md              ← краткое summary (этот файл)
├── CLAUDE.md              ← правила валидации для Claude Code
├── bootstrap.sh           ← one-button restore (ansible + chezmoi + user-tools)
├── scripts/
│   └── sync-flash.sh      ← обновить Ventoy-флешку из репо (rsync по serial)
├── wiki/                  ← 📖 полная документация
│   ├── README.md          ← индекс wiki
│   ├── 00-overview.md
│   ├── 01-hardware.md
│   ├── 10..15-preseed-*.md
│   ├── 20..21-ansible-*.md
│   ├── 30-ventoy.md
│   ├── 40-installation.md
│   ├── 41-post-install-checks.md
│   ├── 50-troubleshooting.md
│   ├── 51-lessons-learned.md
│   ├── 60-bootstrap.md
│   └── 70-data-migration.md
├── preseed/
│   ├── preseed.txt        ← вариант A (NVMe, LVM+btrfs)
│   ├── preseed-usb.txt    ← вариант B (USB SSD, ext4)
│   ├── ventoy.json        ← конфиг Ventoy (picker)
│   └── ...
└── ansible/
    ├── site.yml
    └── inventory.ini
```

## Навигация по wiki

| Начать с | Вопрос |
|---|---|
| [00 — Overview](wiki/00-overview.md) | Что это за проект, философия |
| [40 — Installation](wiki/40-installation.md) | Как установить |
| [41 — Post-install checks](wiki/41-post-install-checks.md) | Убедиться что всё работает |
| [50 — Troubleshooting](wiki/50-troubleshooting.md) | Что-то сломалось |
| [51 — Lessons learned](wiki/51-lessons-learned.md) | Подводные камни которые уже встречали |

Полный индекс: [wiki/README.md](wiki/README.md).
