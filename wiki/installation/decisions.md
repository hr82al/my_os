---
tags: [installation, decisions, qa]
---

# Installation — Decisions & Q&A

← [Installation](README.md) | [Wiki Index](../README.md)

## Q: Почему два варианта (A NVMe + B USB SSD), а не один?

**Контекст:** пользователь хотел:
1. Сначала поставить на внешний USB SSD и проверить
2. Оставить текущую систему (Fedora на NVMe) как **fallback**
3. Позже, если всё ок, поставить вариант A на NVMe

**Решение: два preseed.** Оба делают одно и то же (одинаковые пакеты,
late_command, autologin), отличаются **только разметкой**:

| | Variant A (NVMe) | Variant B (USB SSD) |
|---|---|---|
| Диск | `/dev/nvme0n1` (прямо) | `/dev/disk/by-id/usb-Wodposit...` (by-id) |
| FS стек | LVM + btrfs + ext4 | ext4 (one root) |
| /data | ✅ btrfs 440G | ❌ |
| snapper | ✅ root + data | ❌ (ext4 не поддерживает) |
| swap | ✅ 16 GiB LV | ❌ (zram вместо) |
| USB-оптимизации | ❌ | ✅ (tmpfs, sysctl, readahead, preload, zram) |
| GRUB режим | Regular | Portable (removable fallback) |
| NVRAM cleanup | ❌ | ✅ (не засоряем ноутбук) |

## Q: Почему by-id для внешнего диска, а не просто `/dev/sdX`?

**Риск:** `/dev/sdX` зависит от порядка enumeration USB-устройств:
- Другой USB воткнут раньше → SSD становится `sdc` вместо `sdb`
- Перезагрузка → порядок может поменяться
- Если внутренний диск как-то станет `sdb` — **установка перезапишет внутренний**

`/dev/disk/by-id/usb-Wodposit_NVMe_SSD_152D05830E2B-0:0` — стабильный
идентификатор, привязан к конкретному диску. Никогда не спутается с
внутренним NVMe (`nvme0n1` — это другое пространство).

**Решение:** by-id для variant B. Гарантирует что fallback-Fedora не пострадает.

## Q: Почему portable boot для Variant B (detail)?

См. подробности в [preseed/decisions.md#portable-boot](../preseed/decisions.md).

TL;DR: чтобы не засорять NVRAM ноутбука записью `debian`, которая
остаётся висеть и при отсутствии USB.

## Q: Порядок pre-flight проверок (что важнее)?

1. **git state** — `HEAD == origin/main` — потому что late_command клонит из GitHub
2. **Ventoy sync** — preseed на флешке должен быть актуальным
3. **Internet** — mephi, deb.debian.org, github, docker.com reachable
4. **Backup** (только для variant A) — PG + /home

Вывод в [Installation procedure](README.md).

## Q: Почему `finish installation` висит если late_command упал?

В d-i последовательность:
```
partman → bootstrap-base → apt-install-base → pkgsel → grub-installer → finish-install
                                                                              ↓
                                                                        late_command
```

late_command выполняется **внутри** finish-install. Если виснет (например,
`apt-get update` с cdrom: entry) — finish тоже виснет. User видит «Finish
installation» без прогресса. Если нажать «Abort» — система обычно грузится
(разметка, base, grub уже применены), но late_command частично не выполнился.

**Детектор:** `/var/log/late-install.log` на установленной системе.
Последняя строка = где упало.

## Q: Откуда знать что установка «прошла»?

Три уровня проверки:
1. **Система грузится + autologin работает** → partman, base-install, grub, основные пакеты — OK
2. **`sudo cat /var/log/late-install.log | tail -5`** должно заканчиваться `late.sh completed OK` → late_command полностью отработал
3. **[verify-install.sh](post-install-checks.md#4-скрипт-verify-installsh)** — полный smoke-test

Если пункт 1 есть, а 2 нет — late_command упал, частичная установка.
См. [troubleshooting](../troubleshooting/README.md#45-late_command-висит).

## Ссылки

- [Installation procedure](README.md)
- [Post-install checks](post-install-checks.md)
- [Troubleshooting](../troubleshooting/README.md)
- [Lessons learned](../troubleshooting/lessons-learned.md)
