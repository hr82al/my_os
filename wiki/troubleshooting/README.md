---
tags: [troubleshooting, debug, errors]
---

# 50 — Troubleshooting

← [Wiki Index](../README.md) | [40 — Installation](../installation/README.md)

## Инсталлятор: виртуальные консоли

Debian installer имеет несколько TTY. Переключение — **Alt+F2 / Alt+F3 / Alt+F4**
(Ctrl+Alt на GUI).

| Консоль | Содержимое |
|---|---|
| Alt+F1 | Основной UI |
| **Alt+F2** | **Shell (busybox)** — главный инструмент |
| Alt+F3 | Дополнительные сообщения |
| **Alt+F4** | **Tail главного лога** в реальном времени |

### Что делать при «Installation step failed»

1. **Запишите точное имя шага** из диалога (например `pkgsel`, `partman`, `late-command`, `grub-installer`).
2. **Alt+F4** — последние строки лога. Ищите `ERROR` / `FAILED`.
3. **Alt+F2** → shell:
   ```sh
   less +G /var/log/syslog                     # Shift+G в конец
   grep -iE "fail|error" /var/log/syslog | tail -30
   dmesg | tail -50                             # kernel-уровень
   ```
4. Сфоткайте / запишите:
   - Имя упавшего шага
   - Последнюю строку с `error`/`failed`
   - Exit code если команда упала

## Типичные проблемы

### 4.1. Ventoy меню не показывается

**Симптом:** Загрузка с USB — чёрный экран или «no bootable device».

- BIOS Legacy vs UEFI → должен быть UEFI
- Secure Boot может мешать — попробовать отключить

### 4.2. Ventoy показывает меню, но preseed не применяется

**Симптом:** Debian installer спрашивает язык/клавиатуру/диск интерактивно.

- Проверить `/ventoy/ventoy.json` на флешке — должен быть `auto_install` с правильным именем ISO
- Имя ISO должно **точно** совпадать с файлом на флешке

### 4.3. Installer останавливается на partman

**Симптом:** доходит до «Partition disks», показывает дерево разметки, ждёт подтверждения.

- Опечатка в `partman-auto/expert_recipe`
- Alt+F4 → смотреть `partman-auto` ошибки
- Правка preseed.txt прямо на Ventoy-флешке → reboot → retry

См. [14 — late_command](../preseed/late-command.md) про ручную правку скриптов.

### 4.4. pkgsel падает с «Unable to locate package X»

Это **ложный след** почти всегда. Настоящие причины:

- **Network mirror не подключён** — проверить `cat /target/etc/apt/sources.list`. Если там только `cdrom:` → пропустил `d-i apt-setup/use_mirror boolean true`
- **Package renamed** между Debian версиями (например `policykit-1` → `polkitd` в trixie)

Apt-транзакция атомарная: один несуществующий пакет валит все, выдаёт
каскад fake-ошибок для несвязанных.

Диагностика:
```sh
# Alt+F2
tail -100 /var/log/syslog | grep -iE 'apt-setup|50mirror|locate'
cat /target/etc/apt/sources.list
```

Симптомы в syslog:
- `50mirror returned error code 1; discarding output` → mirror не подключён. См. [51 — LL](lessons-learned.md#pkgsel-падает-на-use_mirror)
- `Unable to locate package X` → X переименован или отсутствует

Фикс: поправить preseed, пересинхронизировать флешку, retry.

### 4.5. late_command висит / «Finish installation» не отвечает

Проверить `/target/var/log/late-install.log` (если доступен) или `/var/log/late-install.log` на установленной системе после reboot.

Частая причина — `apt-get update` в late_command виснет потому что в
`/etc/apt/sources.list` осталась строка `deb cdrom:[...]`. apt пытается
прочитать DVD которого уже нет.

Фикс: preseed должен иметь `d-i apt-setup/disable-cdrom-entries boolean true`
+ в late_command `sed -i "/^deb cdrom:/d" /target/etc/apt/sources.list`.

См. [51 — LL: cdrom entry вешает late_command](lessons-learned.md#cdrom-entry-вешает-late_command).

### 4.6. Система не грузится (GRUB rescue / no bootable device)

**Variant A:**
- BIOS → boot order → debian entry должен быть первым
- Если пусто — GRUB не установился. Загрузиться с Ventoy → Debian ISO rescue mode

**Variant B:**
- Проверить что BIOS видит USB как bootable
- F12 → выбрать USB SSD (имя Wodposit или JMicron)
- Если NVRAM записи нет — USB грузится через fallback `/EFI/BOOT/BOOTX64.EFI` (мы это и хотели)
- Если USB вообще не виден — включить USB boot в BIOS

### 4.7. Rescue режим — починить установленную систему

Загрузиться с Ventoy → Debian ISO → «Advanced options» → «Rescue mode».

Даёт shell в установленной системе (chrooted). Можно:
- Посмотреть логи
- Редактировать конфиги
- Переустановить GRUB: `grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian`

### 4.8. Ручной перезапуск late_command

Если скрипт упал посередине:
```bash
sudo sh -x /root/late.sh           # -x показывает каждую команду
```
Можно править `/root/late.sh` вручную, закомментировать уже сделанные шаги.

## Диагностика при падении

1. **Собрать лог** — `/var/log/syslog` целиком скопировать на флешку:
   ```sh
   # Alt+F2
   mount /dev/sdX1 /mnt  # найти флешку через lsblk
   cp /var/log/syslog /mnt/syslog
   sync; umount /mnt
   ```

2. **Переместить лог на рабочий ПК** и анализировать.

3. **Искать в syslog:**
   - `50mirror returned error` → mirror не подключён
   - `Unable to locate package` → рассмотреть окружающий контекст
   - `partman` ошибки
   - `choose-mirror` — был ли вызван

## Архитектурные решения

См. [decisions.md](decisions.md) — почему сделано именно так, обсуждённые альтернативы.

## Ссылки

- [51 — Lessons learned](lessons-learned.md) — все встреченные баги
- [CLAUDE.md](../../CLAUDE.md) — правила валидации которые предотвращают многие проблемы
