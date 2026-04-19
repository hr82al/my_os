---
tags: [preseed, variant-b, usb-ssd, ext4, optimization]
---

# 12 — Variant B: USB SSD (ext4 + оптимизации)

← [10 — Preseed overview](README.md) | [Wiki Index](../README.md)

Файл: [`preseed/preseed-usb.txt`](../../preseed/preseed-usb.txt)

## Когда использовать

- Ставите Debian на **внешний USB SSD** (переносимый носитель)
- Внутренняя Fedora на `/dev/nvme0n1` остаётся как **fallback**
- Хотите простую схему без LVM/btrfs для надёжности
- Внешний SSD — portable (загружать на любом UEFI-машине через F12)

## Целевой диск

- **Wodposit NVMe SSD 238.5 GiB** в USB 3.2 Gen 2 enclosure (~1 GB/s линк)
- Адресация по `by-id`: `/dev/disk/by-id/usb-Wodposit_NVMe_SSD_152D05830E2B-0:0`
- **Гарантия**: внутренний NVMe не трогается (by-id стабилен, sdX — нет)

Подробнее: [01 — Hardware](../hardware.md#внешний-usb-ssd-variant-b).

## Разметка диска (простая, надёжная)

```
/dev/disk/by-id/usb-Wodposit... (238.5 GiB)
├─ p1  ESP FAT32   512 MiB  → /boot/efi
├─ p2  /boot ext4    2 GiB
└─ p3  / ext4      ~235 GiB  options: noatime,nodiratime,commit=60
```

**Без LVM, без btrfs, без swap, без `/data`.** Всё (включая docker
volumes, PG, images) живёт в одном корне.

### Обоснования

- `by-id` → не попадём на внутренний NVMe никогда
- Без LVM → один physical volume, легче переставить/клонировать
- Без btrfs → ext4 стабильнее для USB disconnects; snapshots не нужны (fallback-система есть)
- Без swap → USB SSD имеет меньше write-endurance; вместо swap — zram (см. ниже)
- `commit=60` → ext4 журнал коммитит раз в 60с вместо 5с. Меньше мелких записей. Риск: 60с данных на power-loss (приемлемо)

## Оптимизации (компенсация USB)

Linux уже кэширует файлы в RAM (page cache). Усиливаем механизм.

### `/tmp` в tmpfs 8 GiB
```
tmpfs  /tmp  tmpfs  defaults,noatime,nosuid,size=8G,mode=1777  0 0
```
Компиляторы, линкеры, apt, ffmpeg — все пишут в `/tmp`. RAM-backed = нулевая нагрузка на USB.

### sysctl — агрессивный кэш
`/etc/sysctl.d/99-usb-ssd-cache.conf`:
```
vm.vfs_cache_pressure = 50          # дольше держим inode/dentry кэш
vm.dirty_background_ratio = 10
vm.dirty_ratio = 30
vm.dirty_expire_centisecs = 6000    # 60s до принудительной записи
vm.dirty_writeback_centisecs = 1500 # 15s — background writeback
```

### udev — readahead 2048 KB для USB
`/etc/udev/rules.d/60-usb-readahead.rules`:
```
ACTION=="add|change", KERNEL=="sd[a-z]", SUBSYSTEMS=="usb", ATTR{bdi/read_ahead_kb}="2048"
```
8× default — полезно для apt install, cp, видео.

### zram-swap — compressed RAM swap
`/etc/default/zramswap`:
```
ALGO=zstd
PERCENT=25
PRIORITY=100
```
Это **не** запись на диск. zstd 3× → 4 GiB zram ≈ 12 GiB эффективной памяти.

### preload — предсказательный кэш
Демон наблюдает за процессами, проактивно грузит популярные файлы в page cache на boot. ~15 MB RAM overhead.

## Загрузчик (portable boot)

### Настройки preseed
```
d-i grub-installer/bootdev string /dev/disk/by-id/usb-Wodposit_...
d-i grub-installer/force-efi-extra-removable boolean true
```

- GRUB ставится только на ESP USB-SSD (не на internal NVMe)
- **`force-efi-extra-removable`** → копия GRUB в `/EFI/BOOT/BOOTX64.EFI` (fallback-путь)
- USB работает на любом UEFI через F12 → без registered NVRAM-записи

### Очистка NVRAM на ноутбуке
`late_command` удаляет все NVRAM-записи `debian` после установки
(`efibootmgr -B`). Ноутбук остаётся с pristine firmware boot-list.
См. [14 — late_command](late-command.md#nvram-cleanup).

## Что в late_command (B vs A)

Отличия от [варианта A](variant-a-nvme.md):

| | Variant A | Variant B |
|---|---|---|
| p4, p5 (дополнительные партиции) | ✅ создаются | ❌ нет |
| btrfs-`/data` | ✅ | ❌ |
| snapper | ✅ configs | ❌ не поддерживается на ext4 |
| tmpfs `/tmp` | — | ✅ |
| sysctl-тюнинг | — | ✅ |
| udev readahead | — | ✅ |
| zram-swap | — | ✅ |
| preload | — | ✅ |
| NVRAM cleanup | — | ✅ |
| docker-ce, chrome, Nerd Font, git clone my_os | ✅ | ✅ |

## Проверка после установки

См. [41 — Post-install checks](../installation/post-install-checks.md) — раздел variant B:
- `lsblk /dev/sdX` → 3 партиции
- `df -h /tmp` → tmpfs 8G
- `swapon --show` → `/dev/zram0` zstd
- `systemctl status zramswap preload`
- `sudo efibootmgr | grep debian` → пусто (cleanup отработал)

## Ссылки

- [11 — Variant A](variant-a-nvme.md) — NVMe-вариант
- [14 — late_command](late-command.md)
- [51 — Lessons learned](../troubleshooting/lessons-learned.md) — подводные камни этого варианта
