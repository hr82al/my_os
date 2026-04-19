---
tags: [installation, procedure]
---

# 40 — Процедура установки

← [Wiki Index](../README.md)

## Pre-flight

Перед загрузкой целевой машины:

### 1. Проверить git state

```bash
cd /home/user/mr/workspace/my_os
git status --short
git log --oneline -3
```
Все изменения должны быть запушены на GitHub (`origin/main == HEAD`), потому
что late_command клонирует репо с remote'а.

### 2. Синхронизировать Ventoy-флешку

```bash
lsblk -f | grep -i ventoy                    # найти /dev/sdX
udisksctl mount -b /dev/sdX1
cp /home/user/mr/workspace/my_os/preseed/preseed.txt      /run/media/$USER/Ventoy/preseed.txt
cp /home/user/mr/workspace/my_os/preseed/preseed-usb.txt  /run/media/$USER/Ventoy/preseed-usb.txt
cp /home/user/mr/workspace/my_os/preseed/ventoy.json      /run/media/$USER/Ventoy/ventoy/ventoy.json
sync && udisksctl unmount -b /dev/sdX1 && udisksctl power-off -b /dev/sdX
```

### 3. Интернет на целевой машине

Во время install скачиваются:
- Debian mirror (mephi.ru) — base system + pkgsel
- `download.docker.com` — docker-ce
- `dl.google.com` — google-chrome
- GitHub — Nerd Font + my_os clone
- Ethernet рекомендуется (Wi-Fi в debian-installer неудобен)

### 4. Бэкап (если Variant A)

Если ставите [Variant A на NVMe](../preseed/variant-a-nvme.md) — текущая система
на `/dev/nvme0n1` **будет стёрта**. Бэкап PG и `/home`. См. [70 — Миграция](../post-install/data-migration.md).

Если [Variant B на USB SSD](../preseed/variant-b-usb-ssd.md) — fallback (Fedora на
NVMe) остаётся целым, но **всё на USB SSD будет затёрто**.

## Установка

### 1. Подключения

- **Целевая машина:** выключить
- **Ventoy-флешка:** подключить (любой USB-порт, желательно USB-3)
- **Внешний USB SSD** (только для Variant B): подключить в другой USB-порт
- **Ethernet:** подключить

### 2. Загрузка

1. Включить машину
2. **Boot menu** — обычно F12 (на Lenovo ThinkPad). Другие вендоры: F8, F10, F11, Esc.
3. Выбрать **USB Ventoy** (не USB SSD, не NVMe)
4. Откроется Ventoy меню

### 3. Выбор preseed

1. В Ventoy выбрать «Debian 13 (auto-install, pick preseed)»
2. Picker покажет два варианта:
   - `/preseed.txt` — [Variant A](../preseed/variant-a-nvme.md) (NVMe, затирает внутренний диск)
   - `/preseed-usb.txt` — [Variant B](../preseed/variant-b-usb-ssd.md) (USB SSD, NVMe не трогается)
3. Выбрать нужный

### 4. Автоустановка

20–40 мин. Этапы которые можно отслеживать:
- Partitioning (~1 мин)
- Base system (~3–5 мин)
- pkgsel — качает все пакеты с mirror (~10–20 мин, большая часть времени)
- grub-installer (~30 сек)
- **late_command** — docker/chrome/Nerd Font/git clone (~5–10 мин)
- Reboot

⚠️ **Если installer остановился на вопросе** — пропустили debconf-ключ.
Сфоткайте экран → см. [50 — Troubleshooting](../troubleshooting/README.md).

### 5. После reboot

- **Вытащить Ventoy-флешку** (иначе снова загрузит инсталлятор)
- Debian должен загрузиться в qtile через autologin (пользователь `user`)
- Если нужно залогиниться руками: `user` / `changeme`

### 6. Verify

Сразу после первой загрузки:
```bash
sudo cat /var/log/late-install.log | tail -30
# должно заканчиваться: "late.sh completed OK"
```

Полный чек-лист: [41 — Post-install checks](post-install-checks.md).

### 7. Первые действия

1. **Сменить пароли:**
   ```bash
   passwd              # для user
   sudo passwd root
   ```

2. **Запустить bootstrap** (установка desktop apps):
   ```bash
   cd ~/mr/workspace/my_os
   ./bootstrap.sh ansible
   ```
   См. [60 — bootstrap.sh](../post-install/README.md).

## Если что-то пошло не так

[50 — Troubleshooting](../troubleshooting/README.md) — диагностика по этапам:
- Ventoy не грузит
- partman остановился
- pkgsel падает
- late_command хангится
- GRUB не грузит систему

## Архитектурные решения

См. [decisions.md](decisions.md) — почему сделано именно так, обсуждённые альтернативы.

## Ссылки

- [30 — Ventoy](../ventoy/README.md) — подготовка флешки
- [41 — Post-install checks](post-install-checks.md) — что проверить
- [50 — Troubleshooting](../troubleshooting/README.md) — если упало
- [60 — bootstrap.sh](../post-install/README.md) — после установки
- [70 — Data migration](../post-install/data-migration.md) — восстановление PG
