---
tags: [preseed, decisions, qa]
---

# Preseed — Decisions & Q&A

← [Preseed](README.md) | [Wiki Index](../README.md)

Архитектурные решения по preseed и ответы на вопросы пользователя.
Для хронологии багов и их фиксов — см. [Troubleshooting / Lessons learned](../troubleshooting/lessons-learned.md).

## Q: Почему один `lv-docker` 220 GiB, а не split `lv-docker` + `lv-pgdata` (S1 vs S2)?

**Контекст:** на NVMe было планирование 2 отдельных LV: `lv-docker` (100 GiB, images/layers) + `lv-pgdata` (120 GiB, PG volumes).

**Обсудили:**
| | Split S2 | Merge S1 |
|---|---|---|
| LV | 2 | 1 |
| partman-recipe | средней сложности | минимальный |
| late_command для docker/PG | ✅ нужен для mount | ❌ не нужен |
| Физ. изоляция IO | ❌ (один NVMe) | ❌ (тот же факт) |
| Изоляция квот | ✅ | ❌ |
| Mount-race риск | ✅ есть | ❌ |

**Решение: S1 (merge).** Физ. изоляции всё равно нет (один NVMe), изоляция квот не
окупает сложность late_command + mount-race. Квоту контролируем через
`df` + `docker builder prune`. Compose не меняется.

## Q: Почему плоская btrfs на `lv-root` без `@/@home/@snapshots`?

**Контекст:** изначально решили делать как все (openSUSE-like с `@`-subvolumes).

**Обсудили:** `@`-convention полезна только при дуалбуте **в одной btrfs-ФС**.
У нас вторая ОС → отдельная партиция p5 со своей btrfs → `@`-префикс
бессмыслен. При этом `@`-layout требует в late_command:
- Создать `@` subvolume
- Переместить установленные файлы в `@` (umount /target → umount deep → mount top-level → mv → remount → fix GRUB)
- Править fstab под `subvol=@`

Всё это хрупко: d-i после late_command ещё что-то делает, и сломанная
mount-структура может завалить финализацию.

**Решение: плоская схема.** root на top-level, snapper сам создаёт
`.snapshots` subvolume при инициализации. Никакой реструктуризации.

## Q: Почему ESP 512 MiB, а не 2 GiB?

**Контекст:** планировали 2 GiB «с запасом на будущее».

**Обсудили:** при схеме GRUB + отдельный `/boot` ext4, в ESP кладутся только:
- `shimx64.efi` (~1 MB)
- `grubx64.efi` (~2 MB)
- `mmx64.efi` (~1 MB)
- Fallback `/EFI/BOOT/BOOTX64.EFI` (~1 MB)

≈ 5-10 MB на одну Debian. Две Debian + Windows ≈ 50 MB максимум.
512 MiB даёт 50-кратный запас.

**Решение: 512 MiB.** Освободившиеся 1.5 GiB добавили к `p5` (резерв ОС).

Исключения когда 2 GiB нужен:
- systemd-boot с UKI (ядра в ESP) — не наш случай
- Windows + BitLocker — не планируется

## Q: Куда монтировать PG-данные?

**Обсудили:**
1. `/var/lib/docker/volumes` — все docker-volumes там. Compose не трогаем. Риск: `docker volume prune` может снести PG; race при mount order.
2. `/srv/pg` с bind-mount в контейнер — чисто, но надо править compose.
3. PG как docker volume на общем `lv-docker` — самый простой, риск: один диск под всё.

**Решение: (3) через S1** — один LV под всё docker-хозяйство (images + volumes). См. S1 выше.

## Q: Почему docker-ce (upstream), а не `docker.io` из Debian?

- Версия свежее (27.x vs 26.x)
- Включает `docker-compose-plugin` и `docker-buildx-plugin` как зависимости
- Пользователь уже использует upstream → сохранена консистентность

**Trade-off:** требует setup upstream-репо в late_command (+5 строк), но зато не зависим от Debian-lag.

## Q: Почему `mirror.mephi.ru` и не `deb.debian.org`?

Бенчмарк через [`find-fastest-mirror.sh`](../../preseed/find-fastest-mirror.sh) на 2026-04-18:
```
7 MB/s  ping 2ms   mirror.mephi.ru         ← выбран primary
7 MB/s  ping 2ms   ftp.ru.debian.org
6 MB/s  ping 3ms   mirror.docker.ru
```

**Решение:** primary mephi для скорости, fallback `deb.debian.org`
добавляется в late_command как `sources.list.d/fallback.list`.

Trade-off: специфичное зеркало = один хост, если ляжет — apt berёт с fallback.

## Q: Нужно ли explicit `use_mirror=true` для DVD-install?

**Да, обязательно.** Default при DVD = `false` (DVD-1 считается «self-sufficient»),
но DVD-1 не содержит `qtile/ansible/snapper/rclone/...` Получаем каскад
«unable to locate». См. [Lessons learned](../troubleshooting/lessons-learned.md#pkgsel-падает-на-use_mirror).

## Q: Swap на USB SSD?

**Нет.** USB SSD имеет меньше write-endurance чем NVMe. Swap = постоянные мелкие записи.
Плюс suppress warning через `d-i partman-basicfilesystems/no_swap boolean false`.

**Взамен:** `zram-tools` — compressed RAM swap, pure memory, disk не пишет.

## Q: Почему Portable Boot для Variant B (без NVRAM-записи на ноутбуке)?

**Контекст:** grub-installer по умолчанию добавляет NVRAM-запись `debian` в firmware ноутбука.

**Плюсы записи:** USB воткнут → автоматом грузит debian.
**Минусы:** USB отключён → ноут всё равно пытается грузить `debian` (timeout), засоряет NVRAM. Увезёте USB на другой комп — здесь остаётся битая запись.

**Решение:**
- `d-i grub-installer/force-efi-extra-removable boolean true` → GRUB также в `/EFI/BOOT/BOOTX64.EFI` (fallback-путь firmware)
- В late_command удаляем NVRAM записи `debian` через `efibootmgr -B`
- USB грузится через F12 → firmware находит fallback → работает на любой UEFI-машине

Ноутбук firmware остаётся чистым.

## Ссылки

- [Packages](packages.md) — package naming & validation
- [Late-command](late-command.md) — как реализованы решения
- [Mirror](mirror.md) — зеркало + fallback
- [Lessons learned](../troubleshooting/lessons-learned.md) — bugs из реализации
