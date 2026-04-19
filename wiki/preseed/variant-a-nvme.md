---
tags: [preseed, variant-a, nvme, lvm, btrfs]
---

# 11 — Variant A: NVMe (LVM + btrfs)

← [10 — Preseed overview](README.md) | [Wiki Index](../README.md)

Файл: [`preseed/preseed.txt`](../../preseed/preseed.txt)

## Когда использовать

- Ставите Debian как **основную** ОС на внутренний NVMe
- Готовы потерять текущую систему на `/dev/nvme0n1`
- Хотите snapshots (snapper), LVM-гибкость, отдельный `/data`

## Разметка диска

```
/dev/nvme0n1 (931.5 GiB)
├─ p1  /boot/efi    FAT32     512 MiB
├─ p2  /boot        ext4      2 GiB
├─ p3  LVM PV       ~399 GiB
│   └─ vg0
│       ├─ lv-root      btrfs   100 GiB   → /     (плоская схема, без @)
│       ├─ lv-docker    ext4    220 GiB   → /var/lib/docker (noatime,nodiratime)
│       ├─ lv-swap      swap     16 GiB   (sleep only, без hibernate)
│       └─ <свободно ~63 GiB>             горячий резерв VG для lvextend
├─ p4  /data        btrfs   ~440 GiB     compress=zstd:1, snapper-управляемый
└─ p5  резервная ОС  ~89.5 GiB            вне LVM, для второй Linux позже
```

### Обоснования

**Почему LVM split:**
- Изоляция `/data` и резерва ОС от основной LVM
- Гибкость: `lv-*` легко расширить в `vg0` (есть 63 GiB запас)

**Почему btrfs только на `lv-root` и `p4`:**
- Snapshots + сжатие полезны для системы и данных
- На `lv-docker` ext4 — избегаем CoW-проблем для PG (фрагментация) и overlay2 (двойной CoW)

**Почему один `lv-docker` 220 GiB вместо split lv-docker+lv-pgdata:**
- Один NVMe → физической изоляции всё равно нет
- Квота → одна (мониторим через `df` + `docker builder prune`)
- Сложность late_command ниже
- Решение **S1** (см. [51 — Lessons learned](../troubleshooting/lessons-learned.md#sx-решение-по-lv))

**Почему плоская btrfs (без `@`/`@home`/`@snapshots`):**
- `@`-convention (openSUSE/Ubuntu) полезна только при дуалбуте **в одной btrfs**
- У нас вторая ОС → отдельная партиция p5 со своей btrfs
- Плоская схема = без реструктуризации в late_command → проще, надёжнее
- snapper сам создаёт `.snapshots` как subvolume

**ESP 512 MiB:**
- GRUB + отдельный `/boot` ext4 → в ESP только shim+grubx64.efi (~5–10 MB на ОС)
- 512 MiB хватает с огромным запасом на 2+ Debian

**p5 (резерв ОС) вне LVM:**
- Если основная LVM умрёт, резервная ОС всё равно загрузится

## Что в late_command

См. [14 — late_command](late-command.md) для полной логики.

Для варианта A:
1. Создать p4 (btrfs, `/data`) и p5 (не форматируется)
2. Записать `/data` в fstab
3. Установить docker-ce (upstream)
4. Установить google-chrome
5. JetBrainsMono Nerd Font
6. Клонировать my_os в `~/mr/workspace/my_os`
7. Autologin lightdm → qtile
8. snapper configs для `/` и `/data`

## Пакеты pkgsel

См. [13 — Packages](packages.md) — одинаковые для обоих вариантов.

## Проверка после установки

См. [41 — Post-install checks](../installation/post-install-checks.md) — раздел для variant A:
- `lsblk /dev/nvme0n1` → 5 партиций
- `sudo vgs` → vg0 с 3 LV
- `sudo snapper list-configs` → `root` и `data`

## Ссылки

- [12 — Variant B](variant-b-usb-ssd.md) — сравнение с USB-вариантом
- [14 — late_command](late-command.md)
- [70 — Миграция PG данных](../post-install/data-migration.md)
