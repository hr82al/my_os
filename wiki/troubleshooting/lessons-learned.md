---
tags: [troubleshooting, lessons-learned, bugs]
---

# 51 — Lessons learned

← [Wiki Index](../README.md) | [50 — Troubleshooting](README.md)

Список багов которые уже встретили и решили. Правила из этого файла
продублированы в [CLAUDE.md](../../CLAUDE.md) чтобы Claude применял их автоматически.

## Preseed / install

### pkgsel падает с фейковыми ошибками

**Симптом:**
```
E: Unable to locate package snapper
E: Unable to locate package qtile
E: Unable to locate package kitty
...
Menu item 'pkgsel' failed
```

Пакетов **много**, ощущение «ничего не работает».

**Причина:** apt-транзакция атомарна. Один ложный пакет валит всё и
выдаёт «Unable to locate» для каскада несвязанных. Реальная проблема —
**один** пакет, остальные ложный след.

**Детектив:** проверить что КАЖДЫЙ пакет из `pkgsel/include` существует в Debian 13:
```bash
docker run --rm debian:13 bash -c '
    apt-get update -qq
    for p in <список>; do
        apt-cache show "$p" >/dev/null 2>&1 && echo "✅ $p" || echo "❌ $p MISSING"
    done'
```

**Найденные renames bookworm → trixie:**

| Было | Стало |
|---|---|
| `policykit-1` | **удалён** → `polkitd` |
| `chezmoi` | не в main → `.deb` с GitHub через ansible |

**Правило:** перед любым добавлением пакета в preseed — docker-валидация.
[CLAUDE.md §3](../../CLAUDE.md).

---

### pkgsel падает на use_mirror

**Симптом:** в syslog:
```
apt-setup: warning: /usr/lib/apt-setup/generators/50mirror returned error code 1; discarding output
apt-setup: warning: /usr/lib/apt-setup/generators/91security returned error code 1; discarding output
apt-setup: warning: /usr/lib/apt-setup/generators/92updates returned error code 1; discarding output
```

Потом pkgsel не находит половину пакетов (которые должны быть в main).

**Причина:** При установке с **полного DVD** по умолчанию
`apt-setup/use_mirror = false` (считается что DVD достаточно). Но DVD-1
не содержит всё main — `qtile`, `ansible`, `snapper`, `rclone` — их **нет**.
Без mirror они не найдутся → каскад «Unable to locate».

**Фикс:** обязательно в preseed при DVD-install:
```
d-i apt-setup/use_mirror boolean true
d-i apt-setup/services-select multiselect security, updates
d-i apt-setup/security_host string security.debian.org
```

«discarding output» = скрипт вышел с 1 потому что use_mirror=false — это
**ожидаемое поведение** при отсутствии настройки, не реальная ошибка сети.
Симптом ложный — проблема в конфиге.

[CLAUDE.md §4](../../CLAUDE.md).

---

### cdrom entry вешает late_command

**Симптом:** `/var/log/late-install.log` обрывается на:
```
+ echo "deb [arch=amd64 ...] download.docker.com ..." > /target/etc/apt/sources.list.d/docker.list
+ in-target apt-get update
<< лог кончается здесь, установка виснет на "Finish installation" >>
```

**Причина:** После DVD-install в `/etc/apt/sources.list` остаётся строка:
```
deb cdrom:[Debian GNU/Linux 13.4.0 ...]/ trixie contrib main non-free-firmware
```
Когда late_command выполняет `apt-get update`, apt пытается смонтировать
DVD (которого уже нет) и **виснет** навсегда. Установка не завершается.

**Фикс — два слоя:**

Preseed:
```
d-i apt-setup/disable-cdrom-entries boolean true
```

Belt-and-suspenders в late_command перед первым apt-get update:
```sh
sed -i "/^deb cdrom:/d" /target/etc/apt/sources.list
```

[CLAUDE.md §5](../../CLAUDE.md).

---

### Preseed swap warning интерактивен

**Симптом:** Variant B (без swap) — installer останавливается с диалогом
«No swap space — may cause failure. Return to partitioner?».

**Фикс:**
```
d-i partman-basicfilesystems/no_swap boolean false
```
(`false` = «нет, не возвращаемся в partitioner»).

---

### partman-lvm/device_remove_lvm безусловно стирает LVM на любом диске

На Variant B (USB SSD, method=regular, без LVM) это настройка может
случайно стереть LVM на другом диске (если случайно попадёт под сканер).
Защита: **убрать** эти строки для USB-варианта:
```
#d-i partman-lvm/device_remove_lvm boolean true   — закомментировать
```

## Ventoy / Fedora host

### mkexfatfs нет на Fedora → -V возвращает 1

**Симптом:** Ventoy2Disk.sh падает:
```
./tool/ventoy_lib.sh: line 63: mkexfatfs: command not found
```

Или (после создания symlink):
```
mkexfatfs test fail
```
даже если `mkexfatfs -V` выводит версию.

**Причина:** Fedora имеет `mkfs.exfat` (из `exfatprogs`), но не `mkexfatfs`.
Ventoy ищет старое имя. Простой symlink не работает потому что `mkfs.exfat -V`
возвращает **exit 1** (print version но код ненулевой), а Ventoy проверяет
через `if mkexfatfs -V > /dev/null`.

**Фикс — wrapper в `/usr/bin`:**
```bash
sudo tee /usr/bin/mkexfatfs >/dev/null <<'EOF'
#!/bin/sh
if [ "$1" = "-V" ] || [ "$1" = "--version" ]; then
    mkfs.exfat -V 2>/dev/null || true
    exit 0
fi
exec /usr/bin/mkfs.exfat "$@"
EOF
sudo chmod +x /usr/bin/mkexfatfs
```

NB: в `/usr/bin`, не `/usr/local/bin` — `sudo` по умолчанию не включает `/usr/local/bin` в PATH.

---

### Ventoy2Disk.sh — баг с PATH при запуске из другой директории

**Симптом:** «vtoycli: command not found».

**Причина:** Ventoy2Disk.sh берёт `$OLDDIR` (текущий pwd на момент запуска)
в PATH, а `cd`'ит позже в свою директорию. Если запускать из другого места
— PATH остаётся неправильным.

**Фикс:** всегда запускать изнутри директории Ventoy:
```bash
cd ~/Downloads/ventoy-1.1.11
sudo bash ./Ventoy2Disk.sh -I /dev/sdX
```

## Дизайн-решения

### SX-решение по LV: один lv-docker вместо split

**Дилемма:** разделить docker-хозяйство на два LV (`lv-docker` для
images/layers + `lv-pgdata` для volumes) или объединить в один.

**Контекст:**
- PG данные в docker volumes (`mp-sl-1-pg-vol` = 38 GB — основной)
- images + build cache ~70 GB
- Всё на одном NVMe → физической изоляции IO нет в любом случае

**Анализ:**
| | Split (lv-docker + lv-pgdata) | Merge (S1: один lv-docker) |
|---|---|---|
| LV | 2 | 1 |
| partman-recipe сложность | средняя | низкая |
| late_command для docker/PG | ✅ нужен (для /var/lib/docker/volumes mount) | ❌ не нужен |
| Изоляция квоты | ✅ | ❌ (одна) |
| Mount-race риск | ✅ есть | ❌ нет |
| Compose не меняется | ✅ | ✅ |

**Решение:** Merge (S1). Изоляция квоты не окупает сложность late_command
+ mount-race. Квоту контролируем через `df` + `docker builder prune`.

### Плоская btrfs на lv-root (без @-subvolumes)

**Дилемма:** делать openSUSE-like `@/@home/@snapshots` или плоскую схему.

**Анализ:**
- `@` convention полезна только при дуалбуте **в одной btrfs**
- У нас вторая ОС → своя партиция p5 → отдельная btrfs → `@` бессмысленен
- Snapper сам создаёт `.snapshots` subvolume автоматически

**Решение:** плоская схема. late_command проще (не нужно перемещать
установленные файлы в `@`, не нужно править GRUB под `subvol=@`).

### Portable boot для Variant B

**Дилемма:** installer добавляет NVRAM-запись `debian` в firmware ноутбука.
Это:
- Полезно: ноутбук автоматом грузит USB-debian если подключён
- Плохо: запись остаётся даже без USB (boot висит на timeout'е, потом fallback), засоряет NVRAM ноута

**Решение:** portable режим —
- `d-i grub-installer/force-efi-extra-removable boolean true` → GRUB также в `/EFI/BOOT/BOOTX64.EFI`
- В late_command удаляем NVRAM запись `debian` через `efibootmgr -B`
- USB грузится через F12 → firmware видит fallback-путь → работает без NVRAM

Ноутбук остаётся pristine. USB работает на любой UEFI-машине.

## Ссылки

- [CLAUDE.md](../../CLAUDE.md) — правила валидации, которые предотвращают повтор этих ошибок
- [50 — Troubleshooting](README.md)
