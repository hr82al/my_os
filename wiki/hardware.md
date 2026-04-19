---
tags: [hardware, reference]
---

# 01 — Целевое железо

← [Wiki Index](README.md)

## Основная машина

| Компонент | Значение |
|---|---|
| CPU | Intel Core i5-8350U |
| RAM | 32 GiB (`free -h` → `31Gi`) |
| zram (текущий) | 8 GiB (системный) |
| SSD встроенный | Samsung SSD 980 PRO 1TB (NVMe), `/dev/nvme0n1`, **931.5 GiB** |
| Ethernet | Intel I219-LM (enp0s31f6) |

## Внешний USB SSD (variant B)

| Компонент | Значение |
|---|---|
| Модель | Wodposit NVMe SSD в USB-enclosure |
| Контроллер | JMicron JMS583 (USB 3.2 Gen 2 → PCIe Gen3x2) |
| Размер | 238.5 GiB |
| Линк | 10 Gbps (~1 GB/s) |
| `by-id` | `/dev/disk/by-id/usb-Wodposit_NVMe_SSD_152D05830E2B-0:0` |

Используется в [варианте B](preseed/variant-b-usb-ssd.md) через by-id (не sdX) —
гарантирует что установка не попадёт на внутренний NVMe.

## Текущее использование встроенного NVMe (до установки)

- Fedora 42 KDE на одной партиции `nvme0n1p3` btrfs (~696 GiB смонтировано в /home)
- ESP `nvme0n1p1` (580 MiB), `/boot` `nvme0n1p2` (505 MiB)
- Занято: ~230 GB из 931

Этот диск **остаётся нетронутым** при установке variant B. Служит fallback'ом.

## PostgreSQL/Docker на текущей Fedora

Три PG-контейнера с размерами volumes:

| Контейнер | Образ | Volume | Размер |
|---|---|---|---|
| `mp-sw-pg` | postgres:16.1-alpine | `mp-sw-pg-vol` | 112 MB |
| `mp-sl-0-pg` | mp-pg:local | `mp-sl-0-pg-vol` | 65 MB |
| `mp-sl-1-pg` | mp-pg:local | `mp-sl-1-pg-vol` | **38 GB** ← основной |

`/var/lib/docker` — 19 GB реально, `docker system df` → 115 GB суммарно
(images 35 + volumes 43 + build cache 38, reclaimable ~31 GB).

Эти числа использовались при расчёте LVM-размеров в [варианте A](preseed/variant-a-nvme.md):
- `lv-docker` 220 GiB = ~2× текущего суммарного
- (раньше был split lv-docker+lv-pgdata 100+120, упрощён до одного LV)

## Ссылки

- [11 — Preseed variant A](preseed/variant-a-nvme.md) — планировалась под это железо
- [70 — Миграция данных](post-install/data-migration.md) — перенос PG на новую систему
