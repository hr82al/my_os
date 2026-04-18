# POST-INSTALL: проверка и диагностика первой установки

Этот файл — чеклист после **первой автоматической установки Debian 13 через preseed**. Цель: быстро убедиться что всё сработало или, если что-то не так, найти где и что сломалось.

Есть **два варианта установки** — проверки частично отличаются:

| Вариант | Preseed | Диск | Разметка | Особенности |
|---|---|---|---|---|
| **A** (основной) | `preseed.txt` | `/dev/nvme0n1` | LVM + btrfs + /data | snapper, 5 партиций |
| **B** (USB SSD) | `preseed-usb.txt` | `/dev/sdX` (by-id) | простая ext4 | tmpfs /tmp, sysctl, zram, preload |

Переходы между секциями: «для варианта A» / «для варианта B».

---

## Вход

- Логин: `user`
- Пароль: `changeme` (⚠️ поменять первым делом: `passwd`)
- root пароль: `changeme` (тоже поменять: `sudo passwd root`)

---

## 1. Базовый smoke-test

Выполните на свежеустановленной системе (в терминале, через Ctrl+Alt+F2 если lightdm упал, или в kitty после GUI-логина):

### Разметка диска

**Для варианта A (NVMe, LVM+btrfs):**
```bash
lsblk /dev/nvme0n1

# Ожидаем:
# nvme0n1      931.5G
# ├─nvme0n1p1  512M    /boot/efi
# ├─nvme0n1p2  2G      /boot
# ├─nvme0n1p3  399G    (LVM PV)
# ├─nvme0n1p4  ~440G   /data
# └─nvme0n1p5  ~89.5G  (не примонтирован, резерв)

sudo vgs; sudo lvs
# Ожидаем: VG vg0, LV lv-root (btrfs 100G), lv-docker (ext4 220G), lv-swap (16G)
# Free PE ~63 GiB
```

**Для варианта B (USB SSD, ext4):**
```bash
# Определить внешний диск (обычно sda или sdb)
lsblk -d -o NAME,SIZE,MODEL,TRAN

# Проверить что внутренний NVMe цел (fallback-Fedora или что там стояло)
lsblk /dev/nvme0n1

# Убедиться что система стоит на USB (by-id)
ls -la /dev/disk/by-id/ | grep Wodposit
readlink -f /dev/disk/by-id/usb-Wodposit_NVMe_SSD_152D05830E2B-0:0
findmnt /

# Ожидаем на USB-диске:
# sdX          238.5G
# ├─sdX1       512M    /boot/efi
# ├─sdX2       2G      /boot
# └─sdX3       ~235G   /
```

### Монтирование

**Для варианта A:**
```bash
df -h / /boot /boot/efi /var/lib/docker /data
mount | grep -E 'nvme0n1|vg0'

# Ожидаем:
# /                     btrfs   (lv-root)
# /boot                 ext4    (nvme0n1p2)
# /boot/efi             vfat    (nvme0n1p1)
# /var/lib/docker       ext4    noatime,nodiratime (lv-docker)
# /data                 btrfs   noatime,compress=zstd:1,space_cache=v2 (nvme0n1p4)
```

**Для варианта B (USB SSD):**
```bash
df -h / /boot /boot/efi /tmp
mount | grep -E '/$|/boot|/tmp'

# Ожидаем:
# /         ext4    noatime,nodiratime,commit=60 (sdX3)
# /boot     ext4    (sdX2)
# /boot/efi vfat    (sdX1)
# /tmp      tmpfs   defaults,noatime,nosuid,size=8G,mode=1777
```

```bash
# fstab — без дублей, все точки монтирования есть
cat /etc/fstab
```

```bash
# Лог нашего late_command — должен заканчиваться "late.sh completed OK"
sudo cat /var/log/late-install.log | tail -50
```

## 2. Установленный софт

```bash
# Docker CE из upstream (НЕ docker.io)
docker version | grep -i version
# Version: 27.x (не 26.x)
apt-cache policy docker-ce | head
# Installed: из download.docker.com

# docker-compose plugin и buildx plugin
docker compose version
docker buildx version

# user в группе docker
groups
# должно быть: user adm cdrom sudo docker ...

# Проверить что docker работает
sudo systemctl status docker
docker run --rm hello-world
```

```bash
# Google Chrome
google-chrome --version
# Google Chrome 13X.0.XXXX.XX

# Firefox
firefox-esr --version
```

```bash
# JetBrainsMono Nerd Font
fc-list | grep -i "jetbrainsmono.*nerd" | head -3
# должен вывести несколько строк .ttf файлов из /usr/local/share/fonts/JetBrainsMono-Nerd/

# Обычный JetBrainsMono из debian-пакета
fc-list | grep -i "jetbrainsmono" | grep -v -i nerd | head -3
```

```bash
# qtile + kitty
which qtile kitty
cat /usr/share/xsessions/qtile.desktop 2>/dev/null  # должна быть Xsession-запись

# lightdm
sudo systemctl status lightdm
```

```bash
# Snapper — только для варианта A (NVMe+btrfs). На варианте B (USB/ext4) НЕТ.
sudo snapper list-configs
# A: должно быть: root и data
# B: команда завершится ошибкой или покажет пустой список — это нормально

sudo snapper -c root list
sudo snapper -c data list
```

```bash
# NetworkManager
nmcli device status

# PipeWire
systemctl --user status pipewire pipewire-pulse wireplumber
```

### Для варианта B — дополнительные проверки USB-оптимизаций

```bash
# tmpfs /tmp (8 GiB)
df -h /tmp
# Filesystem: tmpfs, Size ~8G

# sysctl-кэш-настройки
sysctl vm.vfs_cache_pressure vm.dirty_background_ratio vm.dirty_ratio \
       vm.dirty_expire_centisecs vm.dirty_writeback_centisecs
# Ожидаем:
# vm.vfs_cache_pressure = 50
# vm.dirty_background_ratio = 10
# vm.dirty_ratio = 30
# vm.dirty_expire_centisecs = 6000
# vm.dirty_writeback_centisecs = 1500

# readahead для USB
cat /sys/block/sdX/bdi/read_ahead_kb  # подставьте ваш диск
# Ожидаем: 2048

# zram-swap активен
systemctl status zramswap
swapon --show
# Ожидаем одну строку /dev/zram0 с compression zstd

# preload работает
systemctl status preload
# active (running)

# efibootmgr — NVRAM на ноутбуке должен остаться БЕЗ записи "debian"
sudo efibootmgr | grep -v debian  # все записи кроме debian
sudo efibootmgr | grep debian || echo "✅ нет NVRAM-записи debian"
```

```bash
# Прочие утилиты (выборочно)
which tmux rsync ncdu jq ansible chezmoi
```

## 3. Итоговая проверка «одной командой»

Скрипт автодетектит вариант (A/B) по наличию LVM и применяет нужный набор проверок.

```bash
#!/bin/bash
# ~/verify-install.sh
set -u
FAIL=0

check() {
    if "$@" >/dev/null 2>&1; then
        echo "✅ $*"
    else
        echo "❌ $*"
        FAIL=$((FAIL+1))
    fi
}

# Detect variant: A (NVMe+LVM+btrfs) vs B (USB ext4)
if vgs vg0 >/dev/null 2>&1; then
    VARIANT=A
else
    VARIANT=B
fi
echo "Detected variant: $VARIANT"

# ----- общие проверки (оба варианта) -----
check docker version
check docker compose version
check fc-list ":fontformat=TrueType" | grep -qi "jetbrainsmono.*nerd"
check google-chrome --version
check which qtile kitty firefox-esr
check id | grep -q docker
check test -d /var/lib/docker
check mount | grep -q " /var/lib/docker "

if [ "$VARIANT" = A ]; then
    # ----- только для варианта A -----
    check test -d /data
    check mount | grep -q " /data "
    check sudo snapper list-configs
    check lvs vg0/lv-root
    check lvs vg0/lv-docker
    check lvs vg0/lv-swap
else
    # ----- только для варианта B (USB SSD) -----
    check mount | grep -q "tmpfs on /tmp"
    check test -f /etc/sysctl.d/99-usb-ssd-cache.conf
    check test -f /etc/udev/rules.d/60-usb-readahead.rules
    check systemctl is-enabled zramswap
    check systemctl is-enabled preload
    check swapon --show | grep -q zram
    # проверяем что на ноуте НЕТ NVRAM-записи "debian"
    check bash -c '! sudo efibootmgr | grep -q debian'
fi

if [ $FAIL -eq 0 ]; then
    echo "🎉 Все проверки пройдены (вариант $VARIANT)"
else
    echo "⚠️  Проблем: $FAIL (вариант $VARIANT)"
    exit 1
fi
```

---

## 4. Что делать при проблемах

### 4.1. Установка не начинается / зависает в Ventoy

**Симптом:** Ventoy показывает меню, но «Debian 13 (auto-install...)» не загружается или падает в ошибку.

**Диагностика:**
- В Ventoy-меню нажать `F2` или `F6` чтобы посмотреть плагины. Должна быть надпись «auto install script».
- Если нет — ошибка в `/ventoy/ventoy.json`. Примонтировать флешку на ПК, проверить `jq . /run/media/user/Ventoy/ventoy/ventoy.json`.

**Частая причина:** опечатка в имени ISO в `ventoy.json` — должно **точно совпадать** с именем файла на Ventoy-партиции (`/debian-13.4.0-amd64-DVD-1.iso`).

### 4.2. Установка останавливается на вопросе partman

**Симптом:** доходит до «Partition disks», показывает дерево разметки, ждёт подтверждения.

**Причина:** `partman-auto/expert_recipe` не распарсился. Скорее всего опечатка в синтаксисе (скобки, `{`, `.`, пробелы).

**Диагностика:**
- На экране установщика: `Ctrl+Alt+F4` → видим лог d-i.
- Или `Ctrl+Alt+F2` → shell → `less /var/log/syslog` → ищем `partman-auto`.

**Действия:**
- Вытащить флешку, поправить `/preseed.txt` на Ventoy-партиции (`vim` или `code`).
- НЕ пересобирать ISO, НЕ трогать Ventoy — только preseed.txt меняется.
- Вставить обратно, перезагрузить целевую машину, повторить.

### 4.3. late_command упал

**Симптом:** Установка прошла, перезагрузка произошла, но система работает не до конца (нет `/data`, нет docker, нет Nerd Font).

**Диагностика:**
```bash
sudo cat /var/log/late-install.log | tail -100
```
Скрипт запущен с `set -eux` — первая упавшая команда видна по stderr.

**Частые причины:**

| Ошибка | Причина | Как поправить |
|---|---|---|
| `$P3_END: command not found` **(только A)** | `parted --machine` вернул другой формат | Посмотреть `parted --script --machine --unit MiB /dev/nvme0n1 print`, поправить `grep "^3:"` и `cut -d:` |
| `partition already exists` **(только A)** | Установка повторная, p4/p5 уже созданы | Удалить `parted /dev/nvme0n1 rm 4 5`, перезапустить late.sh |
| `curl: (6) Could not resolve host` | Нет сети в in-target | Проверить `sudo cat /etc/resolv.conf`, `ping dl.google.com` |
| `apt-get: unable to locate package docker-ce` | google-chrome или docker репо не подцепились | `sudo apt-get update` вручную, смотреть `/etc/apt/sources.list.d/*.list` |
| `mkfs.btrfs: not enough space` **(только A)** | Неправильный расчёт `$P4_END` | Пересчитать руками, делать партицию через parted напрямую |
| `Error setting up efivarfs` **(только B)** | efibootmgr не может читать NVRAM при cleanup | Не критично — скрипт завершается с exit 0, запись можно удалить руками после boot: `sudo efibootmgr -B -b <N>` |
| `systemctl: enable failed` для zramswap/preload **(только B)** | Пакеты не установились через pkgsel | Проверить `dpkg -l zram-tools preload`, переустановить вручную |

### 4.4. Ручной перезапуск late_command

Если late_command упал посередине, а скрипт у вас лежит в `/root/late.sh` на установленной системе:
```bash
sudo /bin/sh -x /root/late.sh   # -x показывает каждую команду перед выполнением
```

Можно править скрипт (`sudo vim /root/late.sh`), выкидывать уже сделанные шаги, и гонять заново.

### 4.5. Загрузка упала (GRUB не грузит систему)

**Симптом:** После установки машина не грузится — чёрный экран, GRUB rescue, или «no bootable device».

**Диагностика:**
- Из BIOS посмотреть порядок загрузки — первой должна быть запись «debian» или UUID ESP-раздела.
- Загрузиться с Ventoy → выбрать «Rescue mode» в Debian-ISO (не auto-install!) → получить shell в установленной системе.

**Частые причины:**
- GRUB не установился в ESP → в rescue: `grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian`
- `/boot/efi` не примонтирован в fstab → проверить `cat /etc/fstab | grep efi`

### 4.6. Чтобы начать всё сначала

Если что-то ушло совсем не туда:
- Загрузить с Ventoy → auto-install → установка снова затирает диск полностью.
- Это безопасно — `partman` всегда начинает с `parted mklabel gpt` → чистая таблица.

### 4.7. Откат по snapper — только для варианта A (NVMe+btrfs)

> Для варианта B (USB/ext4) snapper не настраивается — ext4 не поддерживает snapshots. Используйте обычный backup (restic/rsync) или пересоберите систему заново через preseed.

Snapper сам не делает snapshot сразу. Чтобы создать «baseline» после успешной установки:
```bash
sudo snapper -c root create --description "baseline-after-install"
```
Потом перед любым рискованным изменением:
```bash
sudo snapper -c root create --description "before-<change>"
```
Откат:
```bash
sudo snapper -c root list
sudo snapper -c root rollback <number>   # откатит root на указанный snapshot
```

---

## 5. Восстановление данных (PG-volumes)

Если вы делали `pg_dump` перед установкой:

```bash
# Подготовить конфиги / docker-compose со старой машины (если есть бэкап)
# Запустить PG-контейнеры
cd ~/mp
docker compose up -d mp-sl-1-pg mp-sl-0-pg mp-sw-pg

# Дождаться готовности PG
docker exec mp-sl-1-pg pg_isready -U postgres

# Восстановить из дампов
cat /path/to/backup/mp-sl-1.dump | docker exec -i mp-sl-1-pg psql -U postgres
cat /path/to/backup/mp-sl-0.dump | docker exec -i mp-sl-0-pg psql -U postgres
cat /path/to/backup/mp-sw.dump   | docker exec -i mp-sw-pg    psql -U postgres
```

Если копировали volumes целиком (`/var/lib/docker/volumes/<vol>/_data/`):
```bash
# ВАЖНО: контейнеры должны быть остановлены
docker compose down

# Скопировать _data/ в новую директорию volume
sudo cp -a /external/backup/mp-sl-1-pg-vol/_data/. /var/lib/docker/volumes/mp-sl-1-pg-vol/_data/
sudo chown -R systemd-coredump:input /var/lib/docker/volumes/mp-sl-1-pg-vol/_data/
# (UID/GID должны соответствовать тому, что внутри PG-образа — обычно 999:999 для postgres)

docker compose up -d
```

---

## 6. Следующий шаг — `bootstrap.sh`

Когда смок-тест пройден и данные восстановлены — начинаем вторую фазу (см. `CONTEXT.md` раздел «🚀 СЛЕДУЮЩИЙ КРУПНЫЙ ЭТАП»):

1. Создать два git-репо: `dotfiles` и `my-os-ansible`.
2. Написать `bootstrap.sh` который клонирует их и применяет chezmoi/ansible.
3. Постепенно наполнять ansible-плейбук тем, что вы настраиваете руками.
