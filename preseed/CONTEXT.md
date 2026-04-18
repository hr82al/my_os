# CONTEXT — память для продолжения работы над preseed

> **Это файл-память.** Если вы (Claude) читаете это в новой сессии — здесь полный контекст работы над preseed-файлом для Debian 13. Файл создан, чтобы можно было продолжить с того же места.
>
> Для пользователя: чтобы продолжить — откройте этот файл и Claude'у достаточно `Read CONTEXT.md` чтобы восстановить контекст.

---

## Цель проекта

Сделать **скрипт автоматической установки Debian 13 (trixie)** через preseed для конкретной машины пользователя. Работаем интерактивно: Claude задаёт вопросы → пользователь выбирает → Claude правит `preseed.txt`.

## Файлы в `/home/user/mr/workspace/my_os/`

### Корень репо
- `README.md` — вводная в проект (слои, pipeline, структура)
- `bootstrap.sh` — исполняемый, оркестратор: `./bootstrap.sh [all|ansible|dotfiles|user-tools]`. Запускается на свежей Debian после preseed.

### `preseed/`
- `preseed.txt` — основной файл (правится по ходу)
- `example-preseed.txt` — оригинал из Debian (справочник, не трогать)
- `find-fastest-mirror.sh` — bash-скрипт бенчмарка официальных зеркал Debian (создан, исполняемый)
- `CONTEXT.md` — этот файл
- `POST-INSTALL.md` — чеклист проверки после установки и диагностика проблем

### `ansible/` (создан в этой сессии — пост-установочные апы)
- `inventory.ini` — просто `[local] localhost ansible_connection=local`
- `site.yml` — 8 приложений: VS Code (MS apt-repo), DBeaver CE (`.deb`), Obsidian (`.deb` с GitHub), Bruno (`.deb` с GitHub), LibreOffice (Debian-repo), Telegram (Debian-repo), Postman (tarball в `/opt/`), Redis Insight (AppImage в `/opt/`)
- `README.md` — инструкция запуска + таблица того что ставится
- Запуск: `cd ansible && sudo ansible-playbook -i inventory.ini site.yml`
- Теги на каждый app для выборочного запуска: `--tags vscode` и т.п.

## Целевое железо

```
SSD:  Samsung SSD 980 PRO 1TB (NVMe) → /dev/nvme0n1, реальный объём 931.5 GiB
RAM:  32 GiB
```

Текущая система установлена в одну партицию `nvme0n1p3` (930 GB, занято 230 GB). **Будет полностью стёрта.**

## Текущая PG/Docker инсталляция (для расчётов размеров)

| Контейнер | Образ | Размер volume |
|---|---|---|
| `mp-sw-pg` | postgres:16.1-alpine | 112 MB |
| `mp-sl-0-pg` | mp-pg:local | 65 MB |
| `mp-sl-1-pg` | mp-pg:local | **38 GB** ← основной |

`/var/lib/docker` всего ~19 GB на диске (du), но `docker system df` показывает images 35 GB + volumes 43 GB + build cache 38 GB.

Конфиг PG биндится из `/home/user/mr/mp/mp-config-local/pg/postgresql.conf`.

---

## ✅ ЗАФИКСИРОВАННЫЕ РЕШЕНИЯ

### Локализация (уже в preseed.txt)

- Primary locale: `en_US.UTF-8`
- Дополнительная: `ru_RU.UTF-8`
- Клавиатура: US + RU layouts, переключение **Right Alt (AltGr)**
- Часовой пояс: **Europe/Moscow**, UTC hwclock

### Сеть (уже в preseed.txt)

- DHCP, авто-выбор интерфейса
- hostname: `debian`, domain: `localdomain`
- non-free firmware: включено

### Аккаунты (уже в preseed.txt)

- root: пароль `changeme`
- user: `user` / `user`, пароль `changeme`, в группе sudo
- (тестовые пароли — поменять после установки!)

### Зеркало (уже в preseed.txt)

- Дефолт: `deb.debian.org`
- Скрипт `find-fastest-mirror.sh` для выбора лучшего (запустить отдельно, заменить в preseed)

### GRUB (уже в preseed.txt)

- `only_debian=true`, EFI

### Финальная разметка диска (НЕ реализована в preseed!)

```
/dev/nvme0n1 (931.5 GiB)
├─ p1  /boot/efi    FAT32     512 MiB
├─ p2  /boot        ext4      2 GiB     ← текущая Debian
├─ p3  LVM PV       ~399 GiB
│   └─ vg0
│       ├─ lv-root      btrfs   100 GiB   плоская схема: / на top-level; snapper сам создаст /.snapshots; /home — просто каталог
│       ├─ lv-docker    ext4    220 GiB   /var/lib/docker (ВСЁ: images, containers, volumes, build-cache), noatime
│       ├─ lv-swap      swap     16 GiB   (sleep only, без hibernate)
│       └─ <свободно ~63 GiB>             горячий резерв в VG для lvextend (lv-docker при нехватке)
├─ p4  /data        btrfs   ~440 GiB     compress=zstd:1, snapshots, чексуммы
└─ p5  резервная ОС  ~89.5 GiB            для второй Linux позже (свой /boot ext4 + root btrfs)
```

**Обоснование выбора:**
- LVM split (а не all-in-LVM и не all-btrfs) — для изоляции `/data` и резервной ОС от основной LVM
- Btrfs только на `lv-root` и `/data` — снапшоты и сжатие где это полезно
- Ext4 на `lv-docker` — избегаем CoW-проблем для PG (фрагментация) и overlay2 (двойной CoW)
- **Один `lv-docker` 220 GiB вместо split `lv-docker`+`lv-pgdata`** (решение S1): физической изоляции всё равно нет (один NVMe), а изоляция по квоте не стоит сложности late_command + mount-race. Квоту контролируем через `df` + `docker builder prune` при необходимости. Compose не меняется — PG-volumes остаются docker-volumes.
- ESP 512 MiB — Debian с GRUB + отдельный /boot ext4 кладёт в ESP только shim+grubx64.efi (~5–10 MB на ОС); 512 MiB с огромным запасом хватает на 2+ Debian
- `/boot` отдельный ext4 — надёжная загрузка, не влияет на дуалбут
- p5 (резерв ОС) **вне LVM** — изоляция: если основная LVM умрёт, резервная ОС всё равно загрузится
- Sleep only → swap 16 GiB достаточно (для hibernate нужно ≥36 GiB)

### Окружение / пакеты

- **Tasksel:** `standard` (НЕ desktop-meta)
- **Графика:** X11 + lightdm + qtile
- **Видеодрайвер:** авто (xserver-xorg)

**Пакеты для `pkgsel/include` (зафиксировано, записано в preseed.txt):**
```
openssh-server sudo ca-certificates
build-essential git vim htop curl wget less
btrfs-progs lvm2 snapper
xorg xinit lightdm
qtile kitty
firefox-esr
network-manager network-manager-gnome
pipewire pipewire-pulse wireplumber
policykit-1 acpid tlp plymouth plymouth-themes
tmux rsync ncdu iotop iftop tree jq pv bash-completion
rclone privoxy
ansible chezmoi
fonts-noto fonts-noto-color-emoji fonts-firacode fonts-jetbrains-mono
```

**Доустанавливается через `late_command` (не из Debian-репо):**
- `docker-ce` + `docker-ce-cli` + `containerd.io` + `docker-buildx-plugin` + `docker-compose-plugin` (upstream Docker из `download.docker.com`)
- `google-chrome-stable` (из `dl.google.com/linux/chrome/deb/`)
- **JetBrainsMono Nerd Font** — tar.xz с `github.com/ryanoasis/nerd-fonts/releases/latest`, распаковка в `/usr/local/share/fonts/JetBrainsMono-Nerd/`, `fc-cache -f`

**Явно НЕ включено в preseed (ставится вручную после boot):**
- `atuin` — user-level tool, ставится через `curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh` после первого логина

### Подход к реализации разметки

**Вариант A+S1 (упрощённый гибрид) — выбран пользователем:**
- Preseed/partman делает: EFI (p1 512 MiB) + /boot (p2 2 GiB ext4) + LVM PV (p3 399 GiB) с `lv-root` (btrfs), `lv-swap`, `lv-docker` (ext4 220 GiB, /var/lib/docker)
- `late_command` досоздаёт: `p4` (btrfs `/data`), `p5` (резерв ОС, НЕ форматируем), запись `/data` в fstab, инициализация snapper для `/` и `/data`. Никаких btrfs-subvolumes `@/@home/@snapshots` — плоская схема (root на top-level, /home просто каталог, snapper сам создаст `.snapshots`)
- Почему `lv-docker` в partman: `apt install docker.io` при установке пишет сразу на него, иначе образы осядут на lv-root
- Почему нет отдельного `lv-pgdata`: решение S1 — один LV под всё docker-хозяйство (images, containers, volumes включая PG). Изоляция по квоте не окупает сложность late_command/mount-race

---

## ✅ СДЕЛАНО в preseed.txt

1. **`partman-auto/expert_recipe`** — разметка LVM (p1 ESP 512 MiB + p2 /boot 2 GiB + p3 LVM PV 399 GiB → vg0: `lv-root` btrfs 100 GiB, `lv-docker` ext4 220 GiB с `noatime,nodiratime`, `lv-swap` 16 GiB). Свободно ~63 GiB. GPT принудительно.
2. **`late_command`** — полная inline-реализация через `printf '%s\n' ... > /target/root/late.sh`, затем `sh /target/root/late.sh`. Делает:
   - p4 (btrfs label=data, ~440 GiB), p5 (резерв ~89.5 GiB, не форматируется)
   - `mkfs.btrfs` на p4, mount, запись `/data` в fstab с `defaults,noatime,compress=zstd:1,space_cache=v2`
   - **docker-ce** из upstream-репо (`download.docker.com`) + plugins buildx/compose, `usermod -aG docker user`
   - **google-chrome-stable** из `dl.google.com/linux/chrome/deb/`
   - **JetBrainsMono Nerd Font** с `github.com/ryanoasis/nerd-fonts/releases/latest` → `/usr/local/share/fonts/JetBrainsMono-Nerd/` + `fc-cache -f`
   - **git clone `github.com/hr82al/my_os.git`** в `/home/user/mr/workspace/my_os/` (с `chown user:user`), чтобы bootstrap.sh был сразу доступен после первой загрузки
   - `snapper -c root create-config /` и `snapper -c data create-config /data`
3. **`pkgsel/include`** — полный список зафиксирован (см. выше). `tasksel standard` (НЕ desktop).
4. **GRUB**, локаль, сеть, аккаунты — раньше.

## ⏳ ОСТАЛОСЬ

5. **Валидация preseed синтаксиса** ✅ пройдена в docker (debian:13):
   ```bash
   docker run --rm -v /home/user/mr/workspace/my_os/preseed:/p debian:13 \
     bash -c 'apt-get update -qq && apt-get install -y debconf >/dev/null 2>&1 && debconf-set-selections --checkonly /p/preseed.txt'
   ```
   Оговорка: `--checkonly` проверяет только формат `owner template type value`. Семантику `expert_recipe` и `late_command` проверит только реальная установка.

6. **Ventoy-флешка:** ✅ создана и готова. Процедура (для справки, уже выполнено):
   - Ventoy 1.1.11 скачан в `~/Downloads/ventoy-1.1.11/`
   - Установлен через `sudo bash ./Ventoy2Disk.sh -I /dev/sdb` (Transcend 32GB)
   - На Ventoy-партиции (`/dev/sdb1`, exFAT, 30 GB):
     - `/debian-13.4.0-amd64-DVD-1.iso` (3.8 GB)
     - `/preseed.txt` (29 KB)
     - `/ventoy/ventoy.json` с `auto_install → { image: /debian-13.4.0-amd64-DVD-1.iso, template: /preseed.txt }`, `control: VTOY_LINUX_REMOUNT=1`, `menu_alias` на «Debian 13 (auto-install via preseed)»
   - Флешка безопасно извлечена через `udisksctl unmount && udisksctl power-off`

   **Нюансы установки Ventoy на Fedora 42 (для восстановления):**
   - Ventoy ожидает старое имя `mkexfatfs`, Fedora имеет только `mkfs.exfat` из `exfatprogs`. Решено wrapper-скриптом `/usr/bin/mkexfatfs`:
     ```sh
     #!/bin/sh
     if [ "$1" = "-V" ] || [ "$1" = "--version" ]; then
         mkfs.exfat -V 2>/dev/null || true; exit 0
     fi
     exec /usr/bin/mkfs.exfat "$@"
     ```
     (потому что `mkfs.exfat -V` возвращает exit=1, а Ventoy требует exit=0).
   - Ventoy2Disk.sh имеет баг: берёт `$OLDDIR` в `PATH` до `cd` — запускать **изнутри** директории: `cd ~/Downloads/ventoy-1.1.11 && sudo bash ./Ventoy2Disk.sh -I /dev/sdb`.
   - sudo на Fedora по умолчанию не включает `/usr/local/bin` в PATH → symlink'и и wrapper'ы кладём в `/usr/bin`.

7. **Первая тестовая установка** — осталось на физической машине:
   - ⚠️ **Перед загрузкой:** `pg_dump` всех трёх баз (`mp-sw-pg`, `mp-sl-0-pg`, `mp-sl-1-pg`) на внешний носитель — целевой диск затрётся целиком.
   - Вставить флешку в целевую машину → boot menu → выбрать USB (Ventoy).
   - В Ventoy меню выбрать «Debian 13 (auto-install via preseed)».
   - После установки (~20-40 мин) — логин `user` / `changeme`.
   - Проверить: `lsblk /dev/nvme0n1` (5 партиций), `df -h /data /var/lib/docker`, `docker version`, `groups | grep docker`, `fc-list | grep -i jetbrains`, `google-chrome --version`, `snapper list`, `sudo cat /var/log/late-install.log`.
   - **Частая точка падения late_command:** парсинг конца p3 через `parted --machine`. Если формат вывода отличается — `$P3_END` пустой, `parted mkpart` валится.

8. **Перенос PG-volumes** со старой системы — через `pg_dump` всех БД перед установкой, restore после. Либо копирование каталогов `/var/lib/docker/volumes/<vol>/_data/` (с остановленными контейнерами). Стратегия обсудить отдельно.

9. **Обновить Ventoy-флешку** — на ней лежит preseed.txt версии ДО добавления rclone/privoxy. Нужно перед физическим install:
   ```bash
   udisksctl mount -b /dev/sdb1
   cp /home/user/mr/workspace/my_os/preseed/preseed.txt /run/media/user/Ventoy/preseed.txt
   sync && udisksctl unmount -b /dev/sdb1 && udisksctl power-off -b /dev/sdb
   ```

---

## 🚀 СЛЕДУЮЩИЙ КРУПНЫЙ ЭТАП — `bootstrap.sh` (отдельный от preseed)

**Идея:** preseed оставляет чистую болванку ОС. Всё поверх (dotfiles, system-config, доп. пакеты для workflow пользователя) — через `bootstrap.sh` + ansible + chezmoi. Цель: **«кнопка восстановления»** — после свежей установки по preseed запустил `./bootstrap.sh` → полностью настроенная рабочая машина.

### Роли (pipeline восстановления)

| Слой | Что восстанавливает | Репозиторий |
|---|---|---|
| preseed | ОС, разметка, базовые пакеты, user | (папка `preseed/`, Ventoy) |
| **ansible** | System apps (VS Code, DBeaver, Obsidian, Bruno, LibreOffice, Telegram, Postman, Redis Insight); в планах: services, `/srv` каталоги, docker-demons | ✅ СКЕЛЕТ ГОТОВ: `ansible/` (8 apps), инкрементально дополняется |
| **chezmoi** | User config: `~/.bashrc`, `~/.config/kitty/`, `~/.config/qtile/`, git/ssh configs | TODO: создать `dotfiles` repo |
| backup | ДАННЫЕ (PG-volumes, /home/docs, /data/*) | Отдельная стратегия (restic/rsync) |

### `bootstrap.sh` — скелет, сделать при начале работы

```bash
#!/bin/bash
set -eux

# System-level apps (ansible playbook из этого же репо)
cd ~/mr/workspace/my_os/ansible
sudo ansible-playbook -i inventory.ini site.yml

# User-level (dotfiles via chezmoi)
chezmoi init --apply https://github.com/<you>/dotfiles.git

# atuin (user-level, shell history sync)
curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
echo 'eval "$(atuin init bash)"' >> ~/.bashrc

# rustup toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Go tools
go install github.com/go-delve/delve/cmd/dlv@latest
go install golang.org/x/tools/gopls@latest
go install honnef.co/go/tools/cmd/staticcheck@latest

# Data restore (optional, separate step)
# restic -r <repo> restore latest --target /
```

### Что решили по автоматизации

- Выбран вариант **(B)**: `bootstrap.sh` кладётся на машину, запускается **вручную** после первого логина. Не (C) полный автомат через systemd-unit — потому что ansible иногда требует интерактива (sudo password, apt-key confirm), и отладка silent systemd-unit сложнее чем `./bootstrap.sh`.
- `atuin` отложен сюда (user-level, per-user config, логичнее в post-install).
- Dotfiles / ansible-playbook сейчас **не существуют** — создадутся когда дойдём.

### План работы над bootstrap

1. После первой успешной установки через preseed — создать два пустых git-репо: `dotfiles` и `my-os-ansible`.
2. Определить список «что должно быть в ansible» (сейчас в планах: docker-compose.yml для mp-pg контейнеров, каталоги `/srv/*`, systemd user-units, tlp-конфиг, etc.). Наполнять инкрементально — по мере использования системы.
3. `bootstrap.sh` пишется один раз, дальше дополняется редко.

### Для продолжения в новой сессии

> «Продолжаем bootstrap — preseed пройден, нужно создать `bootstrap.sh` + скелет ansible-playbook + chezmoi-dotfiles структуру»

---

## Незакрытые мелкие вопросы

- **Бэкап-стратегия** (внешние бэкапы) — не обсуждалась. Для S1 (один lv-docker) квота критичнее, т.к. PG и images делят диск → мониторить `df`. Бэкапы — отдельная задача.
- **Перенос данных PG** со старой системы на новую — стратегия не зафиксирована (вариант: `pg_dump` всех БД → restore после; либо копирование volume-каталогов с остановленными контейнерами).
- **atuin sync server** — cloud (app.atuin.sh) или self-hosted? Если self-hosted — это ещё один docker-контейнер в ansible-роли.

---

## Стиль общения с пользователем

- Язык: русский (технические термины en — ОК)
- Любит обсуждать варианты с честной аргументацией, а не «бери A»
- Часто спрашивает «почему именно так», «а если иначе» — нужно обосновывать
- Просит проверять реальные числа через команды (`lsblk`, `du`, `free`)
- Может прерывать вопрос новой темой — нормально, переключаться

---

## Как продолжить (для пользователя)

В новой сессии Claude'у достаточно сказать что-то вроде:
> «Продолжаем работу над preseed. Прочитай `/home/user/mr/workspace/my_os/preseed/CONTEXT.md`»

Или просто сослаться на проект `/home/user/mr/workspace/my_os/preseed/` — Claude увидит CONTEXT.md и восстановит контекст. Также есть memory-файлы в `~/.claude/projects/-home-user-mr-workspace-my-os/memory/` (загружаются автоматически).

> **Примечание:** проект переехал из `/home/user/mr/build/preseed/` в git-репозиторий `/home/user/mr/workspace/my_os/` (папка `preseed/`). Старые memory под `-home-user-mr-build-preseed` перенесены под `-home-user-mr-workspace-my-os`.

Следующий логический шаг: **писать `partman-auto/expert_recipe` для базовой разметки + `late_command`**.
