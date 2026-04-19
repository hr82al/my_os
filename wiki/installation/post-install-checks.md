---
tags: [installation, verification, checklist]
---

# 41 — Post-install checks

← [Wiki Index](../README.md) | [40 — Installation](README.md)

После первой успешной установки — быстро убедиться что всё на месте.

## 0. Первым делом

```bash
passwd                  # сменить user пароль
sudo passwd root        # сменить root пароль
```

## 1. Smoke-test

### Разметка диска

**Variant A (NVMe):**
```bash
lsblk /dev/nvme0n1
# Ожидаем 5 партиций:
# p1 512M ESP, p2 2G /boot, p3 399G LVM, p4 ~440G /data, p5 ~89.5G reserve

sudo vgs; sudo lvs
# VG vg0 с lv-root (btrfs 100G), lv-docker (ext4 220G), lv-swap (16G), ~63G free
```

**Variant B (USB SSD):**
```bash
lsblk -d -o NAME,SIZE,MODEL,TRAN          # определить USB SSD (sdX)
lsblk /dev/sdX
# 3 партиции: sdX1 512M ESP, sdX2 2G /boot, sdX3 ~235G /

readlink -f /dev/disk/by-id/usb-Wodposit_NVMe_SSD_152D05830E2B-0:0
findmnt /                                 # должно указывать на sdX3

# Внутренний NVMe НЕ тронут
lsblk /dev/nvme0n1                        # всё как было (Fedora fallback)
```

### Монтирование

**Variant A:**
```bash
df -h / /boot /boot/efi /var/lib/docker /data
# /                 btrfs    (lv-root)
# /var/lib/docker   ext4     noatime,nodiratime (lv-docker)
# /data             btrfs    noatime,compress=zstd:1,space_cache=v2 (nvme0n1p4)
```

**Variant B:**
```bash
df -h / /boot /boot/efi /tmp
# /         ext4    noatime,nodiratime,commit=60 (sdX3)
# /tmp      tmpfs   size=8G

# USB-оптимизации
sysctl vm.vfs_cache_pressure vm.dirty_background_ratio vm.dirty_ratio \
       vm.dirty_expire_centisecs vm.dirty_writeback_centisecs
# Ожидаем: 50 / 10 / 30 / 6000 / 1500

cat /sys/block/sdX/bdi/read_ahead_kb      # 2048

systemctl status zramswap preload
swapon --show                              # /dev/zram0 zstd
```

### late_command log

```bash
sudo cat /var/log/late-install.log | tail -30
# Должно заканчиваться: "late.sh completed OK"
```

### Apt sources

```bash
cat /etc/apt/sources.list                  # НЕТ cdrom: строки
ls /etc/apt/sources.list.d/
# должны быть: docker.list, google-chrome.list, fallback.list
```

## 2. Софт

```bash
# Docker upstream (НЕ docker.io)
docker version | grep -E 'Version|Server'
apt-cache policy docker-ce | head          # установлен из download.docker.com
docker compose version                     # plugin v2
docker buildx version
groups | grep docker                       # user в группе docker
docker run --rm hello-world

# Google Chrome
google-chrome --version
# Firefox
firefox-esr --version

# JetBrainsMono Nerd Font
fc-list | grep -i "jetbrainsmono.*nerd" | head -3
# Обычный JetBrainsMono (без nerd) тоже есть
fc-list | grep -i "jetbrainsmono" | grep -v -i nerd | head -3

# Qtile + kitty + lightdm
which qtile kitty
cat /usr/share/xsessions/qtile.desktop
sudo systemctl status lightdm

# Autologin — должны быть залогинены как user сразу после boot
# Если нет: sudo cat /etc/lightdm/lightdm.conf.d/50-autologin.conf

# Snapper (только Variant A)
sudo snapper list-configs     # root и data

# Repo склонирован
ls /home/user/mr/workspace/my_os/
# должны быть: README.md, CLAUDE.md, bootstrap.sh, preseed/, ansible/, wiki/
```

## 3. Variant B специфика — NVRAM

```bash
sudo efibootmgr
# НЕ должно быть записи "debian" — cleanup-скрипт её удалил
sudo efibootmgr | grep debian || echo "✅ NVRAM чист"
```

## 4. Скрипт verify-install.sh

Автодетектит вариант (A/B) по наличию `vg0`:

```bash
#!/bin/bash
set -u
FAIL=0

check() {
    if "$@" >/dev/null 2>&1; then echo "✅ $*"; else echo "❌ $*"; FAIL=$((FAIL+1)); fi
}

if vgs vg0 >/dev/null 2>&1; then VARIANT=A; else VARIANT=B; fi
echo "Detected variant: $VARIANT"

# общие проверки
check docker version
check docker compose version
check fc-list ":fontformat=TrueType" | grep -qi "jetbrainsmono.*nerd"
check google-chrome --version
check which qtile kitty firefox-esr
check id | grep -q docker
check test -d /var/lib/docker
check test -d /home/user/mr/workspace/my_os

if [ "$VARIANT" = A ]; then
    check test -d /data
    check sudo snapper list-configs
    check lvs vg0/lv-root
    check lvs vg0/lv-docker
    check lvs vg0/lv-swap
else
    check mount | grep -q "tmpfs on /tmp"
    check test -f /etc/sysctl.d/99-usb-ssd-cache.conf
    check test -f /etc/udev/rules.d/60-usb-readahead.rules
    check systemctl is-enabled zramswap
    check systemctl is-enabled preload
    check swapon --show | grep -q zram
    check bash -c '! sudo efibootmgr | grep -q debian'
fi

[ $FAIL -eq 0 ] && echo "🎉 $VARIANT: OK" || { echo "⚠️ $VARIANT: $FAIL проблем"; exit 1; }
```

Сохраните в `~/verify-install.sh`, `chmod +x`, запустить.

## Следующие шаги после проверок

1. ✅ Smoke-test пройден → запустить bootstrap.sh: см. [60 — bootstrap.sh](../post-install/README.md)
2. ❌ Что-то упало → [50 — Troubleshooting](../troubleshooting/README.md)

## Ссылки

- [40 — Installation](README.md)
- [50 — Troubleshooting](../troubleshooting/README.md)
- [60 — bootstrap.sh](../post-install/README.md)
- [70 — Data migration](../post-install/data-migration.md)
