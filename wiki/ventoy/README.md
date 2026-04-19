---
tags: [ventoy, usb, flash]
---

# 30 — Ventoy (boot-флешка)

← [Wiki Index](../README.md)

## Зачем Ventoy

Одна флешка, один раз настроенная, даёт:
- Меню выбора ISO для загрузки
- Автоподстановку boot-параметров (preseed-файла) через `ventoy.json`
- Picker между несколькими preseed-шаблонами
- preseed редактируется как файл на флешке — без пересборки ISO

## Файлы на флешке

| Путь | Источник в репо |
|---|---|
| `/debian-13.4.0-amd64-DVD-1.iso` | `/home/user/Downloads/debian-13.4.0-amd64-DVD-1.iso` |
| `/preseed.txt` | [`preseed/preseed.txt`](../../preseed/preseed.txt) |
| `/preseed-usb.txt` | [`preseed/preseed-usb.txt`](../../preseed/preseed-usb.txt) |
| `/ventoy/ventoy.json` | [`preseed/ventoy.json`](../../preseed/ventoy.json) |

## `ventoy.json`

```json
{
    "control": [
        { "VTOY_LINUX_REMOUNT": "1" }
    ],
    "menu_alias": [
        { "image": "/debian-13.4.0-amd64-DVD-1.iso",
          "alias": "Debian 13 (auto-install, pick preseed)" }
    ],
    "auto_install": [
        {
            "image": "/debian-13.4.0-amd64-DVD-1.iso",
            "template": [ "/preseed.txt", "/preseed-usb.txt" ]
        }
    ]
}
```

- `template` как массив → Ventoy показывает **picker** при выборе ISO
- `VTOY_LINUX_REMOUNT=1` — позволяет Linux-инсталлятору перемонтировать ISO как rw

## Первичная установка Ventoy

Делается **один раз**. Потом только копируем файлы.

### 1. Скачать Ventoy

```bash
# последняя версия
curl -fsSL https://api.github.com/repos/ventoy/Ventoy/releases/latest | jq -r '.tag_name'
# версия
V=1.1.11
curl -fL -o ~/Downloads/ventoy-${V}-linux.tar.gz \
     "https://github.com/ventoy/Ventoy/releases/download/v${V}/ventoy-${V}-linux.tar.gz"
cd ~/Downloads && tar xzf ventoy-${V}-linux.tar.gz
```

### 2. Установка на флешку (destructive — затирает USB)

```bash
# определить флешку
lsblk -d -o NAME,SIZE,MODEL,TRAN /dev/sdX  # подтвердить что это USB

# запускать ИЗ директории Ventoy (иначе баг с PATH)
cd ~/Downloads/ventoy-1.1.11
sudo bash ./Ventoy2Disk.sh -I /dev/sdX
```

- `-I` форс-install (Claude не может отвечать на interactive prompt — используем `-I` вместо `-i`)
- Флешка получит 2 партиции: `Ventoy` exfat + `VTOYEFI` fat16

### 3. Скопировать ISO и конфиги

```bash
udisksctl mount -b /dev/sdX1
cp /home/user/Downloads/debian-13.4.0-amd64-DVD-1.iso /run/media/$USER/Ventoy/
cp /home/user/mr/workspace/my_os/preseed/preseed.txt      /run/media/$USER/Ventoy/
cp /home/user/mr/workspace/my_os/preseed/preseed-usb.txt  /run/media/$USER/Ventoy/
mkdir -p /run/media/$USER/Ventoy/ventoy
cp /home/user/mr/workspace/my_os/preseed/ventoy.json      /run/media/$USER/Ventoy/ventoy/ventoy.json

sync
udisksctl unmount -b /dev/sdX1
udisksctl power-off -b /dev/sdX
```

## Обновление флешки (когда меняется preseed)

Используется скрипт [`scripts/sync-flash.sh`](../../scripts/sync-flash.sh).

```bash
./scripts/sync-flash.sh              # выполнить синхронизацию
./scripts/sync-flash.sh -n           # dry-run (показать что будет сделано)
./scripts/sync-flash.sh -v           # verbose (показать каждый файл)
```

### Что делает скрипт

1. **Найти устройство** по уникальному serial (`/dev/disk/by-id/usb-JetFlash_Transcend_32GB_<SERIAL>-0:0`). Serial жёстко зашит в скрипте (`SERIAL=182UFWBDLKB3TMM7`). Если у вас другая флешка — обновить константу или через env var: `VENTOY_SERIAL=xxx ./scripts/sync-flash.sh`.
2. **Двойная проверка:** помимо serial, сверяет `LABEL=Ventoy` на partition 1.
3. **Монтирование:** если флешка уже смонтирована — использует текущую точку монтирования. Иначе монтирует через `udisksctl` (без root).
4. **Cleanup old-layout:** удаляет `/preseed.txt`, `/preseed-usb.txt` из корня флешки если они там есть (от старой схемы до reorg на `/preseed/`).
5. **`rsync preseed/` → `/preseed/`** с `--delete` (чистит старые файлы на флешке), исключая `*.iso`, `.vscode`, `.git*`, `*.swp`, `.DS_Store`.
6. **`ventoy.json` → `/ventoy/ventoy.json`** — отдельно, потому что Ventoy требует этот путь.
7. **sync** (flush буферов). **НЕ отмонтирует** — оставляет флешку смонтированной для последующих правок.

### Структура на флешке после sync

```
/Ventoy (exfat)
├── debian-13.4.0-amd64-DVD-1.iso       (не трогается)
├── preseed/                            ← mirror репо preseed/
│   ├── preseed.txt
│   ├── preseed-usb.txt
│   ├── ventoy.json (копия)             (здесь для полноты; Ventoy читает из /ventoy/)
│   ├── example-preseed.txt
│   ├── find-fastest-mirror.sh
│   └── CONTEXT.md  POST-INSTALL.md     (pointer-stubs)
└── ventoy/
    └── ventoy.json                     (обязательный путь для Ventoy)
```

### Защита от неправильной флешки

- **Уникальный serial** — если у вас 2 одинаковые флешки Transcend 32GB, перетирается только та что с нужным serial (другая игнорируется)
- **LABEL=Ventoy** — вторая проверка на случай что serial совпал, но это не Ventoy-диск
- **Exit сразу** при любой проверке — ничего не трогаем

### Размонтировать вручную

После всех правок (скрипт не делает сам, дают возможность добавить):
```bash
sync
udisksctl unmount -b /dev/sdb1
udisksctl power-off -b /dev/sdb
```
(или использовать by-id путь для независимости от sdX)

### ISO не синхронизируется

- Скрипт исключает `*.iso` — не трогает DVD image (5 GB)
- Если нужно обновить ISO — вручную `cp /path/to/new.iso /run/media/$USER/Ventoy/`

## Fedora quirks

### mkexfatfs не найден

Ventoy ищет старое имя `mkexfatfs`. На Fedora есть только `mkfs.exfat` (из `exfatprogs`).

**Плохой fix (просто symlink):** `sudo ln -sf /usr/bin/mkfs.exfat /usr/bin/mkexfatfs`.
Не работает потому что `mkfs.exfat -V` возвращает **exit 1** (печатает версию, но экзит-код ненулевой), а Ventoy проверяет через `if mkexfatfs -V > /dev/null`.

**Правильный fix — wrapper-скрипт:**
```bash
sudo tee /usr/bin/mkexfatfs >/dev/null <<'EOF'
#!/bin/sh
if [ "$1" = "-V" ] || [ "$1" = "--version" ]; then
    mkfs.exfat -V 2>/dev/null || true
    exit 0
fi
exec /usr/bin/mkfs.exfat "$@"
EOF
sudo chmod +x /usr/bin/mkexfatfs
```

### sudo PATH не включает `/usr/local/bin`

Класть wrapper'ы в `/usr/bin` (не `/usr/local/bin`), иначе `sudo` не увидит.

### Ventoy2Disk.sh баг с PATH

Скрипт берёт `$OLDDIR` (pwd на момент запуска) для `PATH`, а не директорию скрипта.
**Всегда запускать изнутри директории Ventoy:**
```bash
cd ~/Downloads/ventoy-1.1.11
sudo bash ./Ventoy2Disk.sh -I /dev/sdX
```

## Процедура загрузки с флешки

1. BIOS → Boot menu (F12 / F8 / Esc — зависит от модели)
2. Выбрать USB Ventoy
3. Ventoy меню → «Debian 13 (auto-install, pick preseed)»
4. **Picker** → выбрать `/preseed.txt` (Variant A) или `/preseed-usb.txt` (Variant B)
5. Автоустановка 20-40 мин

Подробнее: [40 — Процедура установки](../installation/README.md).

## Архитектурные решения

См. [decisions.md](decisions.md) — почему сделано именно так, обсуждённые альтернативы.

## Ссылки

- [40 — Процедура установки](../installation/README.md)
- [10 — Preseed overview](../preseed/README.md)
