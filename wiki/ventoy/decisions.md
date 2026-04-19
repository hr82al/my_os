---
tags: [ventoy, decisions, qa]
---

# Ventoy — Decisions & Q&A

← [Ventoy](README.md) | [Wiki Index](../README.md)

## Q: Почему Ventoy, а не другие способы доставки preseed?

**Обсудили варианты:**

| Вариант | Плюсы | Минусы |
|---|---|---|
| HTTP-сервер + boot-параметр `preseed/url=` | Быстрые итерации | Нужен второй ПК/LAN во время install, отладка в GRUB |
| Модификация initrd ISO | Self-contained, работает offline | Пересборка ISO при каждом изменении preseed (~5-10 мин) |
| Две партиции (flat iso9660 + FAT32 preseed) | Не пересобирать ISO | d-i не умеет авто-мount вторую партицию; требует initrd-hook |
| **Ventoy** | Одна флешка, preseed как обычный файл, picker | Сторонняя утилита |

**Решение: Ventoy.** Единственное «out-of-the-box» решение для сценария
«одна флешка + редактировать preseed как файл + работать offline».

## Q: Почему picker через массив `template` вместо двух ISO-копий?

**Контекст:** хотим выбор между `preseed.txt` и `preseed-usb.txt` в Ventoy-меню.

**Альтернативы:**
- Две копии ISO — занимает 2×5 GB на флешке
- Один `auto_install` entry с одним template — без выбора
- **Массив template** — Ventoy сам предлагает picker

```json
"auto_install": [
    {
        "image": "/debian-13.4.0-amd64-DVD-1.iso",
        "template": [ "/preseed.txt", "/preseed-usb.txt" ]
    }
]
```

**Решение: массив.** Один ISO, picker на boot → выбор варианта.

## Q: Почему установка Ventoy запускается из директории Ventoy?

**Баг в Ventoy2Disk.sh:**
```
export PATH="$OLDDIR/tool/$TOOLDIR:$PATH"   # $OLDDIR = pwd когда запустили скрипт
```
Если запустить `sudo bash ~/Downloads/ventoy-1.1.11/Ventoy2Disk.sh -I /dev/sdX`
из другой директории — `$OLDDIR` неправильный → tools не в PATH → «vtoycli not found».

**Fix:** `cd` в директорию Ventoy перед запуском. См. [Lessons learned / Ventoy quirks](../troubleshooting/lessons-learned.md#ventoy2disksh--баг-с-path-при-запуске-из-другой-директории).

## Q: Почему wrapper для `mkexfatfs` в `/usr/bin`, а не `/usr/local/bin`?

- Fedora `sudo` по умолчанию secure_path = `/sbin:/bin:/usr/sbin:/usr/bin`
- `/usr/local/bin` НЕ в этом списке → `sudo bash script.sh` не видит файлы там
- Ventoy2Disk.sh запускается через sudo → wrapper должен быть видим

**Решение:** класть wrapper в `/usr/bin`. Не путать с best practice «не трогать
системные каталоги» — здесь это exception потому что Ventoy это требует.

## Q: Почему `-I` (force install), а не `-i` (interactive)?

`-i` запрашивает подтверждение `y/Y` дважды. Claude не может отвечать на
интерактивный prompt из Bash tool → используется `-I` (force без prompt).

При ручном запуске человеком — `-i` безопаснее (даёт шанс передумать).

## Q: Насколько wiped флешку можно сохранить между установками Ventoy?

Ventoy устанавливается **один раз**. При обновлении preseed — просто
редактируете файлы на Ventoy-партиции:
```bash
udisksctl mount -b /dev/sdX1
vim /run/media/$USER/Ventoy/preseed.txt
sync && udisksctl unmount ...
```

Пересобирать Ventoy не нужно, только при обновлении **Ventoy-версии** (`-u`).

## Ссылки

- [Ventoy setup](README.md)
- [Lessons learned — Fedora quirks](../troubleshooting/lessons-learned.md)
- [Installation procedure](../installation/README.md)
