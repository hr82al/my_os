---
tags: [preseed, late-command]
---

# 14 — `late_command`

← [10 — Preseed overview](README.md) | [Wiki Index](../README.md)

## Что это

`late_command` — строка в preseed, которая **выполняется installer'ом
перед reboot**, уже после установки базовой системы и GRUB. Здесь мы:
- Создаём дополнительные партиции/LV (вариант A)
- Применяем USB-оптимизации (вариант B)
- Ставим пакеты из сторонних репо (docker-ce, google-chrome)
- Скачиваем файлы (Nerd Font)
- Клонируем my_os репо
- Настраиваем autologin, NVRAM (вариант B)

## Техника: inline-скрипт через printf

preseed строка — одна логическая строка с `\` continuations. Не поддерживает
настоящие переносы. Трюк: `printf '%s\n' 'line1' 'line2' ... > /target/root/late.sh`.
Каждый arg становится строкой late.sh.

Структура:
```
d-i preseed/late_command string \
    printf '%s\n' \
      '#!/bin/sh' \
      'set -eux' \
      'exec >/target/var/log/late-install.log 2>&1' \
      ... \
    > /target/root/late.sh; \
    chmod +x /target/root/late.sh; \
    sh /target/root/late.sh
```

Лог установки: `/var/log/late-install.log` (на инсталлированной системе).

## Порядок операций

### Общая часть (оба варианта)

1. **Удалить `deb cdrom:` из sources.list** — иначе `apt-get update` ниже виснет
   ```sh
   sed -i "/^deb cdrom:/d" /target/etc/apt/sources.list
   ```
   См. [51 — Lessons learned](../troubleshooting/lessons-learned.md#cdrom-entry-вешает-late_command).

2. **Fallback mirror** → `/target/etc/apt/sources.list.d/fallback.list` с `deb.debian.org`.

### Variant A specific

3. **p4 + p5** через parted (`/data` btrfs + резерв)
4. **mkfs.btrfs** на p4, mount, fstab entry

### Variant B specific

3. `/tmp` tmpfs в fstab
4. sysctl USB-кэш drop-in
5. udev readahead rule
6. zramswap config + `systemctl enable`
7. `systemctl enable preload`

### Общая часть — установка пакетов из upstream

8. **docker-ce** из `download.docker.com`:
   ```sh
   in-target apt-get install -y --no-install-recommends ca-certificates curl
   in-target install -m 0755 -d /etc/apt/keyrings
   in-target curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
   echo "deb [arch=amd64 signed-by=...] https://download.docker.com/linux/debian trixie stable" \
       > /target/etc/apt/sources.list.d/docker.list
   in-target apt-get update
   in-target apt-get install -y docker-ce docker-ce-cli containerd.io \
                                 docker-buildx-plugin docker-compose-plugin
   in-target usermod -aG docker user
   ```

9. **google-chrome-stable** — аналогично (`dl.google.com/linux/chrome/deb`)

10. **JetBrainsMono Nerd Font** — API GitHub → скачать tar.xz → распаковать в `/usr/local/share/fonts/JetBrainsMono-Nerd/` → `fc-cache -f`

### Общая часть — финальные настройки

11. **Клонировать my_os** → `/home/user/mr/workspace/my_os`
    ```sh
    in-target sudo -u user git clone https://github.com/hr82al/my_os.git \
                              /home/user/mr/workspace/my_os
    ```

12. **Autologin lightdm → qtile**:
    ```sh
    cat > /target/etc/lightdm/lightdm.conf.d/50-autologin.conf <<EOF
    [Seat:*]
    autologin-user=user
    autologin-user-timeout=0
    autologin-session=qtile
    EOF
    in-target groupadd -f autologin
    in-target gpasswd -a user autologin
    ```

### Variant A only

13. **snapper configs** для `/` и `/data`

### Variant B only — NVRAM cleanup

13. **Удалить `debian` из firmware NVRAM** — USB SSD бутается через fallback-путь, NVRAM-запись не нужна (и вредна — держит firmware привязку к USB-устройству):
    ```sh
    cat > /target/root/remove-debian-nvram.sh <<EOF
    #!/bin/sh
    command -v efibootmgr >/dev/null 2>&1 || exit 0
    [ -d /sys/firmware/efi/efivars ] || exit 0
    efibootmgr | grep " debian" | sed "s/^Boot\([0-9A-F]*\)\*.*/\1/" | while read -r n; do
        [ -n "$n" ] && efibootmgr -B -b "$n" || true
    done
    EOF
    in-target /root/remove-debian-nvram.sh
    ```

## NVRAM cleanup

Подробнее: [51 — Lessons learned](../troubleshooting/lessons-learned.md) секция portable-boot.

- Работает только для Variant B
- Требует `efibootmgr` в системе (есть по умолчанию из Recommends grub-efi-amd64, плюс явно в pkgsel variant B)
- Defensive: проверяет наличие инструмента и `efivarfs`

## Ошибки late_command — где искать

| Место | Что там |
|---|---|
| `/var/log/late-install.log` | Полный stderr/stdout нашего скрипта (благодаря `exec >...`) |
| `/var/log/installer/syslog` | d-i-уровневый лог (может не быть если инсталлятор упал до финализации) |
| `/root/late.sh` | Сам скрипт — можно перезапустить вручную при нужде |

Способы отладки: [50 — Troubleshooting](../troubleshooting/README.md).

## Ссылки

- [11 — Variant A](variant-a-nvme.md)
- [12 — Variant B](variant-b-usb-ssd.md)
- [15 — Mirror](mirror.md) — fallback mirror тоже настраивается здесь
- [41 — Post-install checks](../installation/post-install-checks.md) — как проверить что late_command отработал
- [51 — Lessons learned](../troubleshooting/lessons-learned.md) — известные баги late_command
