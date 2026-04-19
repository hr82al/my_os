---
tags: [preseed, apt, mirror]
---

# 15 — Зеркало apt

← [10 — Preseed overview](README.md) | [Wiki Index](../README.md)

## Текущая конфигурация

- **Primary:** `mirror.mephi.ru` (по бенчмарку ~7 MB/s, ping 2 ms — для Москвы)
- **Fallback:** `deb.debian.org` (добавляется в `sources.list.d/fallback.list` через [late_command](late-command.md))
- **Security:** `security.debian.org` (конвенция Debian, не меняется)

## Preseed-строки

```
d-i mirror/country string manual
d-i mirror/http/hostname string mirror.mephi.ru
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string
```

## ⚠️ Обязательно для DVD-install

При установке с полного DVD (не netinst) — по умолчанию `apt-setup/use_mirror = false`
(считается что DVD содержит всё нужное). Но DVD-1 не имеет всей `main`:
`qtile`, `ansible`, `snapper`, `rclone` и т.п. — **нет на DVD**, нужны с mirror.

Обязательно:
```
d-i apt-setup/use_mirror boolean true
d-i apt-setup/services-select multiselect security, updates
d-i apt-setup/security_host string security.debian.org
```

Без этого pkgsel валится с «Unable to locate package» — см.
[51 — Lessons learned](../troubleshooting/lessons-learned.md#pkgsel-pypped-с-фейковыми-ошибками).

## Бенчмарк зеркал

Скрипт: [`preseed/find-fastest-mirror.sh`](../../preseed/find-fastest-mirror.sh)

Запуск:
```bash
./find-fastest-mirror.sh               # топ-10 по всему миру
./find-fastest-mirror.sh -c RU         # только RU
./find-fastest-mirror.sh -n 20 -t 15   # топ-20, таймаут 15с
```

### Результат последнего бенчмарка (RU, 2026-04-18)

```
KB/s    ping(ms)  URL
6968    1.88      http://mirror.mephi.ru/debian/
6774    1.97      http://ftp.ru.debian.org/debian/
6538    3.00      http://mirror.docker.ru/debian/
4316    4.79      http://ftp.psn.ru/debian/
```

Выбран `mirror.mephi.ru` (лидер, ping 1.88 мс).

## Fallback механизм

`/etc/apt/sources.list.d/fallback.list` создаётся в late_command:
```
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
```

apt проверяет все источники при update, и если основное зеркало недоступно —
берёт пакеты с fallback. Без автоматического переключения (apt не «знает»
что один быстрее) — только реплика на случай отказа.

## CDROM entry — обязательно убирать

После DVD-install в `/etc/apt/sources.list` остаётся:
```
deb cdrom:[Debian GNU/Linux 13.4.0 ...]/ trixie contrib main non-free-firmware
```

Когда late_command запускает `apt-get update`, apt пытается смонтировать
DVD (которого уже нет смонтированным) и **виснет** навсегда.

Решение в preseed:
```
d-i apt-setup/disable-cdrom-entries boolean true
```

Плюс belt-and-suspenders в late_command:
```sh
sed -i "/^deb cdrom:/d" /target/etc/apt/sources.list
```

Подробнее: [51 — Lessons learned](../troubleshooting/lessons-learned.md#cdrom-entry-вешает-late_command).

## Ссылки

- [14 — late_command](late-command.md) — там же fallback и sed-fix
- [51 — Lessons learned](../troubleshooting/lessons-learned.md) — история багов с mirror
