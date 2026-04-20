---
tags: [ansible, applications]
---

# 21 — Applications (ansible)

← [20 — Ansible overview](README.md) | [Wiki Index](../README.md)

Все приложения ставятся **натив** (не Flatpak/Snap).

## Таблица

| Приложение | Тег | Метод | Источник |
|---|---|---|---|
| [VS Code](#vs-code) | `vscode` | apt-репо | `packages.microsoft.com/repos/code` → `code` |
| [DbGate](#dbgate) | `dbgate` | прямой `.deb` | GitHub `dbgate/dbgate` (SQL-клиент Electron, 108 MB) |
| [pgcli](#pgcli) | `pgcli` | Debian main | CLI PG-client с magic autocomplete |
| [Obsidian](#obsidian) | `obsidian` | прямой `.deb` | GitHub `obsidianmd/obsidian-releases` |
| [Bruno](#bruno) | `bruno` | прямой `.deb` | GitHub `usebruno/bruno` |
| [Throne](#throne) | `throne` | portable zip → `~/mr/apps/Throne` | GitHub `throneproj/Throne` |
| [chezmoi](#chezmoi) | `chezmoi` | прямой `.deb` | GitHub `twpayne/chezmoi` |
| [LibreOffice](#libreoffice) (full) | `libreoffice` | Debian main | `libreoffice` |
| [Telegram](#telegram) | `telegram` | Debian main | `telegram-desktop` |
| [Postman](#postman) | `postman` | tarball → `/opt/` | `dl.pstmn.io/download/latest/linux_64` |
| [Redis Insight](#redis-insight) | `redisinsight` | AppImage → `/opt/` | `download.redisinsight.redis.com` |

## VS Code

Microsoft apt-репо. Ставим ключ в `/etc/apt/keyrings/microsoft.asc`, добавляем
`deb [signed-by=...] .../repos/code stable main`, ставим пакет `code`.

## DbGate

SQL-клиент на Electron (~108 MB `.deb`, ~250 MB RAM idle). Поддерживает PG,
MySQL, SQLite, Oracle, MongoDB, Redis, ClickHouse. Легче чем DBeaver (JVM
start ~5 сек vs Electron ~2 сек; RAM idle 250 MB vs 600 MB).

Метод: GitHub releases `dbgate/dbgate` → asset `dbgate-<version>-linux_amd64.deb`.

## pgcli

CLI PG-клиент из Debian main. **Лучший autocomplete среди бесплатных**:
знает таблицы, колонки с учётом JOIN aliases, keywords case-aware. Syntax
highlighting, multi-line editor, `F9` history (fzy-search).

```bash
pgcli postgres://user@localhost/mydb
```

RAM ~30 MB. Primary PG-клиент для ad-hoc queries. DbGate — когда нужен
GUI для browse/bulk-edit.

## Obsidian

Latest release через GitHub API → parse `.deb` asset → download → `apt deb:`.

## Bruno

Аналогично Obsidian, regex `bruno_.*_amd64\.deb$`.

## Throne

Клиент SOCKS5/VPN (на sing-box). Предоставляет локальный SOCKS5 на
`127.0.0.1:2080`, на который указывает [privoxy](README.md#privoxy-httpsocks5-мост).

Метод: GitHub releases → `Throne-<ver>-linux-amd64.zip` → распаковка в
`/home/user/mr/apps/Throne/` (portable). Ansible:

- `uri` → latest release
- `get_url` → `/tmp/throne.zip`
- `apt: unzip` (требуется для `unarchive` .zip)
- `unarchive` → `/home/user/mr/apps/` (создаёт `Throne/` subdir)
- `chown -R user:user` на распакованное дерево
- symlink `/home/user/mr/apps/Throne/Throne` → `/usr/local/bin/throne`
- `.desktop` entry (`Exec=/home/user/mr/apps/Throne/Throne`, `Icon=.../Throne.png`)

Почему portable zip, а не `.deb` (см. [decisions](decisions.md#q-throne--почему-portable-zip-а-не-deb)):
- config хранится рядом с бинарём (`Throne/config/`), не под `/etc`
- обновление — снести `~/mr/apps/Throne` и распаковать новую версию
- нет postinst/prerm, меньше риска сломать установку

## chezmoi

Dotfiles manager. Нет в Debian main (см. [13 — Packages](../preseed/packages.md#подводные-камни-bookworm--trixie-renames)).

Метод: GitHub releases `twpayne/chezmoi` → `chezmoi_.*_linux_amd64\.deb`.

Используется в [60 — bootstrap.sh](../post-install/README.md) для `chezmoi init --apply <url>`.

## LibreOffice

Debian main метапакет `libreoffice` (~900 MB — full suite writer/calc/impress/и т.д.).

## Telegram

Debian main `telegram-desktop`. Пакет может отставать на 1-2 версии от
официального (telegram.org tarball), но стабильнее.

## Postman

Официально только tarball (нет `.deb`). Ansible:
- `get_url` → `/tmp/postman.tar.gz`
- `unarchive` → `/opt/Postman/`
- symlink `/opt/Postman/Postman` → `/usr/local/bin/postman`
- `.desktop` entry для меню

## Redis Insight

Redis Insight 2.x — AppImage (нет `.deb`). Ansible:
- `get_url` → `/opt/RedisInsight.AppImage`, `mode: 0755`
- `.desktop` entry

## User scripts (`~/.local/bin/`)

Помимо установки приложений, ansible деплоит пользовательские скрипты.
Исходники лежат в [`ansible/files/`](../../ansible/files/), копируются в
`~/.local/bin/<name>` с `mode: 0755` под пользователем `user`.

### capture — screen recording (ffmpeg)

Портирован из fish-функции пользователя. Теги: `user-scripts`, `capture`.

- Источник: [`ansible/files/capture.sh`](../../ansible/files/capture.sh)
- Деплой: `~/.local/bin/capture`
- Требует в системе: `ffmpeg`, `pulseaudio-utils` (pactl), `x11-utils` (xrandr) — всё в preseed pkgsel

Что делает: `x11grab` + PulseAudio monitor → MP4 H.264/AAC в `~/video/record_<timestamp>.mp4`.
Автоопределяет разрешение и audio source. Детали: [qtile/essentials.md](../qtile/essentials.md#capture--запись-экрана-ffmpeg).

Selective запуск:
```bash
sudo ansible-playbook -i inventory.ini site.yml --tags capture
```

### Как добавить свой скрипт

1. Положить в `ansible/files/<name>.sh` (исполняемый bash/sh)
2. В `site.yml` добавить блок аналогично capture:
   ```yaml
   - name: User scripts | deploy <name>
     ansible.builtin.copy:
       src: <name>.sh
       dest: /home/user/.local/bin/<name>
       owner: user
       group: user
       mode: "0755"
     tags: [user-scripts, <name>]
   ```
3. `~/.local/bin` добавляется в PATH через Debian дефолтный `~/.profile`.

## Как добавить новое приложение

1. Найти метод установки (apt-репо / `.deb` / tarball / AppImage)
2. Скопировать блок задач из похожего приложения в [`site.yml`](../../ansible/site.yml)
3. Поменять имена, URL, regex
4. Добавить `tags: [имя]`
5. Если качает файл в `/tmp` — добавить в блок `cleanup`
6. Прогнать `--syntax-check` (см. [20 — Ansible](README.md#валидация-ansible))

## Ссылки

- [20 — Ansible overview](README.md)
- [13 — Packages](../preseed/packages.md) — что в preseed vs ansible
