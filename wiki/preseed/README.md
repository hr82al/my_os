---
tags: [preseed, overview]
---

# 10 — Preseed: обзор

← [Wiki Index](../README.md)

## Что такое preseed

**Preseed** — файл который debian-installer читает вместо интерактивных
вопросов. Отвечает: какой диск, какая разметка, какие пакеты, какие
пароли, и т.д. Результат: полностью автоматическая установка.

## Два варианта

| Файл | Куда ставит | Разметка | Особенности |
|---|---|---|---|
| [`preseed.txt`](../../preseed/preseed.txt) | внутренний NVMe `/dev/nvme0n1` | LVM + btrfs + /data | [Variant A](variant-a-nvme.md): snapper, 5 партиций |
| [`preseed-usb.txt`](../../preseed/preseed-usb.txt) | внешний USB SSD (by-id) | простая ext4 | [Variant B](variant-b-usb-ssd.md): tmpfs, sysctl, zram |

Выбор варианта происходит в **Ventoy picker-меню** при загрузке с флешки.

## Общее для обоих вариантов

### Локаль и клавиатура
- Primary: `en_US.UTF-8`
- Additional: `ru_RU.UTF-8`
- Клавиатура: US + RU layouts, переключение Right Alt (AltGr)
- Timezone: Europe/Moscow, UTC hwclock

### Сеть
- DHCP, авто-выбор интерфейса
- hostname: `debian`, domain: `localdomain`
- non-free firmware: включено

### Аккаунты
- root пароль: `changeme` ⚠️ **поменять после установки**
- user `user` / password `changeme`, в группе sudo

### Зеркало apt
- Primary: `mirror.mephi.ru` (см. [15 — Mirror](mirror.md))
- Fallback: `deb.debian.org`
- Security: `security.debian.org`

### Пакеты pkgsel
См. [13 — Packages](packages.md) — полный список и подводные камни.

### late_command
См. [14 — late_command](late-command.md) — что происходит в
финальной фазе установки.

### GRUB + autologin
- GRUB EFI, установлен на целевой диск
- lightdm с autologin `user` → qtile session

## Валидация синтаксиса

Перед любыми правками — обязательная проверка (см. [CLAUDE.md](../../CLAUDE.md)):

```bash
docker run --rm -v $PWD/preseed:/p debian:13 bash -c \
    'apt-get install -y debconf >/dev/null 2>&1 && debconf-set-selections --checkonly /p/preseed.txt'
```

## Архитектурные решения

См. [decisions.md](decisions.md) — почему сделано именно так, обсуждённые альтернативы.

## Ссылки

- [11 — Variant A (NVMe)](variant-a-nvme.md)
- [12 — Variant B (USB SSD)](variant-b-usb-ssd.md)
- [13 — Пакеты](packages.md)
- [14 — late_command](late-command.md)
- [15 — Mirror](mirror.md)
- [30 — Ventoy](../ventoy/README.md) — как этот preseed доставляется
- [40 — Установка](../installation/README.md)
