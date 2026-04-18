# CONTEXT — память для продолжения работы над preseed

> **Это файл-память.** Если вы (Claude) читаете это в новой сессии — здесь полный контекст работы над preseed-файлом для Debian 13. Файл создан, чтобы можно было продолжить с того же места.
>
> Для пользователя: чтобы продолжить — откройте этот файл и Claude'у достаточно `Read CONTEXT.md` чтобы восстановить контекст.

---

## Цель проекта

Сделать **скрипт автоматической установки Debian 13 (trixie)** через preseed для конкретной машины пользователя. Работаем интерактивно: Claude задаёт вопросы → пользователь выбирает → Claude правит `preseed.txt`.

## Файлы в `/home/user/mr/build/preseed/`

- `preseed.txt` — основной файл (правится по ходу)
- `example-preseed.txt` — оригинал из Debian (справочник, не трогать)
- `find-fastest-mirror.sh` — bash-скрипт бенчмарка официальных зеркал Debian (создан, исполняемый)
- `CONTEXT.md` — этот файл

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
├─ p1  /boot/efi    FAT32     2 GiB
├─ p2  /boot        ext4      2 GiB     ← текущая Debian
├─ p3  LVM PV       ~399 GiB
│   └─ vg0
│       ├─ lv-root      btrfs   100 GiB   subvols: @, @home, @snapshots; compress=zstd:1
│       ├─ lv-docker    ext4    100 GiB   noatime
│       ├─ lv-pgdata    ext4    120 GiB   noatime (38 GB × 3 запас)
│       ├─ lv-swap      swap     16 GiB   (sleep only, без hibernate)
│       └─ <свободно ~63 GiB>             горячий резерв в VG для lvextend
├─ p4  /data        btrfs   ~440 GiB     compress=zstd:1, snapshots, чексуммы
└─ p5  резервная ОС  ~88 GiB              для второй Linux позже (свой /boot ext4 + root btrfs)
```

**Обоснование выбора:**
- LVM split (а не all-in-LVM и не all-btrfs) — для изоляции `/data` и резервной ОС от основной LVM
- Btrfs только на `lv-root` и `/data` — снапшоты и сжатие где это полезно
- Ext4 на `lv-pgdata` и `lv-docker` — избегаем CoW-проблем для PG (фрагментация) и overlay2 (двойной CoW)
- ESP 2 GiB (а не 1) — запас под несколько ОС в будущем
- `/boot` отдельный ext4 — надёжная загрузка, не влияет на дуалбут
- p5 (резерв ОС) **вне LVM** — изоляция: если основная LVM умрёт, резервная ОС всё равно загрузится
- Sleep only → swap 16 GiB достаточно (для hibernate нужно ≥36 GiB)

### Окружение / пакеты

- **Tasksel:** `standard` (НЕ desktop-meta)
- **Графика:** X11 + lightdm + qtile
- **Видеодрайвер:** авто (xserver-xorg)

**Пакеты для `pkgsel/include`:**
```
openssh-server
docker.io (или docker-ce — уточнить)
build-essential git vim htop curl
btrfs-progs lvm2 snapper
network-manager pipewire fonts-noto fonts-firacode
qtile xserver-xorg xinit lightdm
```
*(возможно добавить: alacritty/kitty, firefox-esr, tmux, zsh — пользователь не уточнил окончательно)*

### Подход к реализации разметки

**Вариант (A) — выбран пользователем:**
- Preseed делает базу: EFI + /boot + LVM PV с lv-root (минимально для установки) + lv-swap
- `late_command` или post-install скрипт досоздаёт: `p4`, `p5`, `lv-docker`, `lv-pgdata`, btrfs subvolumes на lv-root, fstab, snapper
- Проще отлаживать, видны все шаги

---

## ⏳ ОСТАЛОСЬ СДЕЛАТЬ

1. **Написать `partman-auto/expert_recipe`** в preseed для базовой разметки (p1, p2, p3 → vg0 → lv-root, lv-swap)
2. **Написать `late_command` скрипт** который:
   - Создаёт партицию `p4` (440 GiB, btrfs `/data`) и `p5` (88 GiB, оставляем пустой или с ext4 для будущего /boot)
   - Создаёт LV: `lv-docker` (100 GiB, ext4), `lv-pgdata` (120 GiB, ext4)
   - На `lv-root` делает btrfs subvolumes: `@` (root), `@home`, `@snapshots`
   - Монтирует всё с правильными опциями (noatime, compress=zstd:1, etc.)
   - Прописывает в `/etc/fstab`
   - Настраивает snapper для `/` и `/data`
3. **Заполнить `pkgsel/include`** в preseed.txt полным списком пакетов
4. **Возможно перенос PG-volumes** из старой `/var/lib/docker/volumes/*` на новую систему (бэкап через `pg_dump` или копирование volumes — обсудить)
5. **Валидация preseed:** `debconf-set-selections --checkonly < preseed.txt`
6. **Способ доставки preseed:** через GRUB параметры (`auto url=...`), USB (модификация ISO), netboot — выбрать с пользователем
7. **Финализировать опции монтирования** — особенно для PG (`noatime,nodiratime` обязательно; `data=writeback` опционально)

## Незакрытые мелкие вопросы

- Пользователь упомянул «Other» в доп. пакетах, но не уточнил → потом дополнит
- Бэкап-стратегия (внешние бэкапы) — спрашивал, не услышал ответ; для выбранного LVM split не критично
- Перенос данных PG со старой системы на новую — стратегия не обсуждалась

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
> «Продолжаем работу над preseed. Прочитай `/home/user/mr/build/preseed/CONTEXT.md`»

Или просто сослаться на проект `/home/user/mr/build/preseed/` — Claude увидит CONTEXT.md и восстановит контекст. Также есть memory-файлы в `~/.claude/projects/-home-user-mr-build-preseed/memory/` (загружаются автоматически).

Следующий логический шаг: **писать `partman-auto/expert_recipe` для базовой разметки + `late_command`**.
