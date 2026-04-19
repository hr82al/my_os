---
tags: [preseed, pkgsel, packages]
---

# 13 — Пакеты (`pkgsel/include`)

← [10 — Preseed overview](README.md) | [Wiki Index](../README.md)

## Список пакетов (оба варианта)

```
# base + ssh
openssh-server sudo ca-certificates
# dev
build-essential git vim htop curl wget less
# filesystems
btrfs-progs lvm2 snapper
# X stack
xorg xinit lightdm
# WM + terminal
qtile kitty
# browser
firefox-esr
# network
network-manager network-manager-gnome
# audio
pipewire pipewire-pulse wireplumber
# misc
polkitd acpid tlp plymouth plymouth-themes
# tools
tmux rsync ncdu iotop iftop tree jq pv bash-completion
rclone privoxy bubblewrap
# media — для ffmpeg-capture (pactl, xrandr требуются)
ffmpeg pulseaudio-utils x11-utils
# graphics — скриншоты (flameshot), растр (gimp), вектор (inkscape)
flameshot gimp inkscape
# config-mgmt
ansible
# fonts
fonts-noto fonts-noto-color-emoji fonts-firacode fonts-jetbrains-mono
```

## Дополнительно в variant B

```
preload zram-tools efibootmgr
```
Нужны для [USB-оптимизаций](variant-b-usb-ssd.md#оптимизации-компенсация-usb) и NVRAM cleanup.

## Ставится отдельно (не через preseed pkgsel)

| Пакет | Способ | Где |
|---|---|---|
| **docker-ce** + plugins | upstream apt-репо `download.docker.com` | [14 — late_command](late-command.md) |
| **google-chrome-stable** | upstream apt-репо `dl.google.com/linux/chrome` | late_command |
| **JetBrainsMono Nerd Font** | `.tar.xz` с GitHub releases | late_command |
| **chezmoi** | `.deb` с GitHub releases | [ansible/site.yml](../../ansible/site.yml) (tag `chezmoi`) |
| **atuin** | официальный installer script | [60 — bootstrap.sh](../post-install/README.md) |
| **rustup** | `sh.rustup.rs` | bootstrap.sh |
| **Go tools** (dlv, gopls, ...) | `go install` | bootstrap.sh |
| **Desktop apps** (VS Code, DBeaver, Bruno, Obsidian, Throne, Postman, Redis Insight, LibreOffice, Telegram) | ansible playbook | [21 — Applications](../ansible/applications.md) |

## Подводные камни (bookworm → trixie renames)

⚠️ **Валидация имён обязательна** перед добавлением в preseed. См. правило в [CLAUDE.md](../../CLAUDE.md) раздел §3.

| Было в Debian 12 | В Debian 13 |
|---|---|
| `policykit-1` | **удалён** → `polkitd` |
| `chezmoi` | нет в Debian main → `.deb` с GitHub через ansible |
| `docker.io` | есть, но пользователь хочет `docker-ce` (upstream) |

Apt-транзакция атомарная: один несуществующий пакет валит весь pkgsel и
выдаёт **каскад фейковых** ошибок «unable to locate X» для несвязанных
пакетов. См. [51 — Lessons learned](../troubleshooting/lessons-learned.md#pkgsel-pypped-с-фейковыми-ошибками).

## Валидация пакетов

Команда (прежде чем добавлять):

```bash
docker run --rm debian:13 bash -c '
    apt-get update -qq
    for p in <пакет1> <пакет2> ...; do
        apt-cache show "$p" >/dev/null 2>&1 && echo "✅ $p" || echo "❌ $p MISSING"
    done'
```

## Ссылки

- [14 — late_command](late-command.md) — как ставятся docker-ce/chrome/Nerd Font
- [21 — Applications](../ansible/applications.md) — как ставятся desktop apps
- [60 — bootstrap.sh](../post-install/README.md) — atuin/rustup/go
- [51 — Lessons learned](../troubleshooting/lessons-learned.md) — бага `policykit-1`, `chezmoi`
