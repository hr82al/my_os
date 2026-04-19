---
tags: [troubleshooting, decisions, qa]
---

# Troubleshooting — Decisions & Q&A

← [Troubleshooting](README.md) | [Wiki Index](../README.md)

## Q: Почему валидация через docker, а не напрямую?

**Контекст:** хост — **Fedora**, на которой:
- Нет `debconf-set-selections` (Debian-only)
- Ansible можно установить, но package-metadata (apt-cache) — debian-специфичная
- Проверить существование пакета в trixie — нельзя без Debian

**Решение:** docker `debian:13` как sandbox. Всё за ~30 секунд:
```bash
docker run --rm -v $PWD/preseed:/p debian:13 bash -c \
    'apt-get install -y debconf >/dev/null 2>&1 && debconf-set-selections --checkonly /p/preseed.txt'
```

Записано в [CLAUDE.md](../../CLAUDE.md) — правила валидации перед коммитом.

## Q: Почему apt-транзакция даёт фейковые ошибки?

Когда `apt install X Y Z` и один из пакетов не найден — apt выдаёт
`Unable to locate package X`, `Unable to locate package Y`, ... для **всех**
в том же batch. Атомарная транзакция: «не могу установить весь набор →
делаю ничего».

Результат: фейковый каскад для пакетов которые **существуют**, но упали
потому что среди них один реально отсутствует.

**Detection:** docker-валидация каждого пакета отдельно
(см. [CLAUDE.md §3](../../CLAUDE.md)) → найдёт реально отсутствующий.

## Q: Почему debug через виртуальные консоли?

Debian installer has **4 tty**:
- F1 — main UI
- F2 — shell (busybox — тут всё реальное)
- F3 — extra messages
- F4 — main log scroll

У нас нет SSH во время install (сеть работает, но sshd не настроен).
Сохранить лог — скопировать через shell на флешку или USB.

Альтернатива — `preseed/early_command` включить auto-enable ssh в installer,
но безопасность сомнительна (changeme-пароль root'а доступен всем в LAN).

**Решение:** virtual consoles + копирование на USB.

## Q: Почему NVRAM cleanup через отдельный скрипт, а не inline?

**Контекст:** команда `efibootmgr | grep debian | sed ...` внутри in-target
sh -c требует nested quotes (single inside single inside printf single) —
escaping hell.

**Решение:** создать `/target/root/remove-debian-nvram.sh` через heredoc
`<<"NVRAM_EOF"` (с quoted delimiter — no expansion) → запустить через
`in-target /root/remove-debian-nvram.sh`.

Скрипт defensive:
- Проверяет наличие `efibootmgr`
- Проверяет `/sys/firmware/efi/efivars`
- Падение не фатально (`|| true`)

## Q: Что делать если install падает на «Finish installation»?

1. **НЕ паниковать** — базовая установка обычно прошла (разметка, base, GRUB).
2. **Не нажимать Abort** — дать пару минут, возможно просто медленно.
3. Если **>10 минут** без прогресса:
   - Alt+F4 смотреть последние строки лога
   - Alt+F2 shell — `tail /var/log/syslog`
4. Если точно висит — Abort Installation. Система скорее всего загрузится.
5. После загрузки: `sudo cat /var/log/late-install.log` → где упал late_command.
6. Вручную доделать оставшиеся шаги или переустановить с исправленным preseed.

## Q: Какие логи сохранять при падении?

**На установочной машине:**
- `/var/log/syslog` — d-i полный лог (главное)
- `/var/log/messages` — kernel + userspace
- `/var/log/installer/syslog` — после reboot, если дошло до финализации
- `/target/var/log/late-install.log` — наш late_command (через Alt+F2)

**На установленной системе (после boot):**
- `/var/log/late-install.log`
- `/var/log/installer/` (если есть)
- `/root/late.sh` — сам скрипт, для перезапуска или правки

**Скопировать на флешку:**
```sh
# Alt+F2 в installer
mount /dev/sdX1 /mnt
cp /var/log/syslog /mnt/
sync; umount /mnt
```

## Ссылки

- [Common issues](README.md)
- [Lessons learned](lessons-learned.md) — все уже встреченные баги
- [CLAUDE.md](../../CLAUDE.md) — правила валидации
