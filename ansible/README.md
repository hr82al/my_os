# ansible — system apps

Playbook для установки desktop-приложений на свежеустановленной Debian 13
(после preseed). Все приложения ставятся **натив** — без Flatpak/Snap.

## Что ставится

| Приложение | Метод | Источник / Пакет |
|---|---|---|
| VS Code | apt-репо | `packages.microsoft.com` → `code` |
| DBeaver CE | прямой `.deb` | `dbeaver.io/files/dbeaver-ce_latest_amd64.deb` |
| Obsidian | прямой `.deb` | GitHub releases `obsidianmd/obsidian-releases` |
| Bruno | прямой `.deb` | GitHub releases `usebruno/bruno` |
| Throne (SOCKS5/VPN client) | прямой `.deb` | GitHub releases `throneproj/Throne` |
| LibreOffice (full) | Debian main | `libreoffice` |
| Telegram | Debian main | `telegram-desktop` |
| Postman | tarball в `/opt/` | `dl.pstmn.io/download/latest/linux_64` |
| Redis Insight | AppImage в `/opt/` | `download.redisinsight.redis.com` |

## Запуск

```bash
cd ~/mr/workspace/my_os/ansible
sudo ansible-playbook -i inventory.ini site.yml
```

Дополнительно:

```bash
# Только одно приложение (по тегу)
sudo ansible-playbook -i inventory.ini site.yml --tags vscode

# Сразу несколько
sudo ansible-playbook -i inventory.ini site.yml --tags "vscode,dbeaver,bruno"

# Dry-run (ничего не меняет, только показывает что будет сделано)
sudo ansible-playbook -i inventory.ini site.yml --check

# Показать только задачи без запуска
sudo ansible-playbook -i inventory.ini site.yml --list-tasks
```

## Теги

`vscode`, `dbeaver`, `obsidian`, `bruno`, `throne`, `postman`, `redisinsight`,
`libreoffice`, `telegram`, `debian-repo`, `privoxy`, `cleanup`.

## System-level конфиги (помимо установки приложений)

- **privoxy:** дописывает `forward-socks5 / 127.0.0.1:2080 .` в `/etc/privoxy/config`,
  включает сервис (`systemctl enable --now privoxy`). Это HTTP→SOCKS5 мост —
  работает совместно с вашим локальным SOCKS5 proxy на 127.0.0.1:2080.
  Если SOCKS5-порт другой — поменяйте значение в `site.yml` (tag `privoxy`).

## Требования

- Debian 13 (trixie) или совместимый
- `ansible` (уже в preseed `pkgsel/include`)
- sudo-права

## Добавить новое приложение

1. Откройте `site.yml`, найдите секцию с похожим методом установки (apt-репо
   / прямой `.deb` / tarball / AppImage).
2. Скопируйте блок задач (4–5 строк), поменяйте имена и URL.
3. Поставьте тег в `tags: [имя]` для каждой новой задачи.
4. Перезапустите playbook с `--tags имя` для быстрого теста.

## Идемпотентность

Playbook можно запускать повторно — `apt`, `get_url`, `unarchive` проверяют
состояние и применяют изменения только если оно отличается от желаемого.
Исключение: `dbeaver-ce_latest_amd64.deb` всегда перезагружается (URL
не версионный, `force: true`) — но `apt` поставит пакет только если он
отличается от установленного.

## Что НЕ делает этот playbook

- Не настраивает dotfiles (`~/.bashrc`, `~/.config/*`) — это зона `chezmoi`.
- Не создаёт user-специфичных ресурсов — все действия system-wide.
- Не ставит атуин, cargo tools, go tools — они user-level, см. `bootstrap.sh`
  (создадим на следующем этапе).
