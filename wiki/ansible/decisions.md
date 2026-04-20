---
tags: [ansible, decisions, qa]
---

# Ansible — Decisions & Q&A

← [Ansible](README.md) | [Wiki Index](../README.md)

## Q: Почему ansible, а не bash для post-install установок?

**Обсудили:**
- **bash:** простой, никаких зависимостей, 50 строк. Минус: не идемпотентен, ошибки плохо сообщаются, плохо масштабируется.
- **ansible:** декларативный, идемпотентный, per-task status, легко добавлять новые apps.

Для 4 apps bash хватит, но план — **расширять** набор со временем.
Ansible от 9 apps уже окупает overhead.

**Решение: ansible.** Bootstrap.sh — тонкий оркестратор, внутри вызывает
ansible-playbook.

## Q: Native install или Flatpak для desktop apps?

**Контекст:** VS Code, DBeaver, Obsidian, Bruno и т.д. все есть как Flatpak.

Пользователь предпочёл **native** для:
- VS Code (MS apt-репо)
- DBeaver CE (.deb с dbeaver.io)
- Obsidian (.deb с GitHub)
- Bruno (.deb с GitHub)

**Почему:**
- Нативные пакеты обновляются через apt (единый workflow)
- Нет sandbox-ограничений Flatpak (некоторые apps глючат)
- Меньше дисковое потребление (нет дублирования runtime'ов)

Отказались от Kooha и Mattermost (из изначального списка Flatpak'ов) —
не нужны часто.

## Q: Tarball/AppImage для Postman и Redis Insight?

Оба **не имеют официального `.deb`**:
- Postman — только tarball (распаковка в `/opt/Postman`, symlink + .desktop)
- Redis Insight 2.x — AppImage (executable в `/opt/`, + .desktop)

Оба идемпотентны через ansible-модули `unarchive` и `get_url` с `mode: 0755`.

## Q: Почему по тегу на каждое приложение?

**Идемпотентность + тестируемость:**
```bash
sudo ansible-playbook -i inventory.ini site.yml --tags vscode  # только VS Code
```
- При добавлении нового приложения можно тестить только его
- Rollback при проблеме — выключить конкретный тег
- Dry-run (`--check`) селективный

## Q: `chezmoi` — почему в ansible, не в preseed?

`chezmoi` **не в Debian main** (ни в one of 30000+ packages trixie).
Пришлось выбрать способ установки:
- Go: нужен `go` → лишняя зависимость
- pip: `chezmoi` не python
- **`.deb` с GitHub** — официальный релиз, wget + dpkg
- Официальный installer script (`get.chezmoi.io`) — то же, но менее audit'uемо

**Решение:** `.deb` с GitHub releases `twpayne/chezmoi` через ansible (tag `chezmoi`).
Pattern такой же как для Bruno/Obsidian/Throne.

## Q: privoxy — почему настройка в ansible, а не в preseed?

**Preseed** — минимальная прослойка, устанавливает **пакеты**. Конфигурация
приложений — идемпотентная/меняется со временем — место для ansible.

`privoxy` ставится пакетом в preseed, но:
```
forward-socks5 / 127.0.0.1:2080 .
systemctl enable --now privoxy
```
→ в ansible (tag `privoxy`), потому что SOCKS5-порт может меняться,
и `lineinfile` идемпотентно (не дублирует строку на повторных запусках).

## Q: Почему бы не использовать `ansible-galaxy` роли?

Для 9 приложений оверкилл. Роли полезны когда:
- Множество apps с шаблонами
- Нужен переиспользуемый код
- Команда > 1 человека

У нас flat `site.yml` с тегами — достаточно. Рефакторить в роли можно
если станет 20+ apps.

## Q: Портирование fish-функции `capture` — скрипт в `~/.local/bin` vs bash-alias vs bash-функция?

**Контекст:** у пользователя в fish функция `capture` для записи экрана через `ffmpeg` (x11grab + pulse monitor). Нужно перенести на новую Debian систему.

**Обсудили варианты:**

| | alias в ~/.bashrc | function в ~/.bashrc | **script в ~/.local/bin** |
|---|---|---|---|
| Multiline code | ❌ (однострочный) | ✅ | ✅ |
| Dynamic `$(date ...)` | ⚠️ quoting hell | ✅ | ✅ |
| Из fish доступен | ❌ | ❌ | ✅ (бинарь в PATH) |
| Из zsh доступен | ❌ | ❌ | ✅ |
| Идёт через ansible | через lineinfile | через lineinfile | **простой `copy`-module** |
| Исходник в git (review, diff) | в `.bashrc` (смешано) | в `.bashrc` | **отдельный файл** |
| `which capture` видит | ❌ | ❌ | ✅ |

**Решение: script в `~/.local/bin/capture`.**
- Универсально (любой shell из PATH)
- Исходник `ansible/files/capture.sh` — версионируется отдельно
- Ansible deploy через `copy` module (tag `capture`) — идемпотентно
- `~/.local/bin` в PATH через дефолтный `~/.profile` в Debian

**Улучшения относительно оригинала:**
- Автоопределение разрешения (`xrandr`) вместо хардкода `1920x1080`
- Автоопределение audio source (default sink monitor вместо hardware-specific PCI пути)
- Fallback-значения если утилиты недоступны
- Banner печатает что записывается

**Зависимости добавлены в preseed:** `ffmpeg` (запись), `pulseaudio-utils` (`pactl` для default sink), `x11-utils` (`xrandr`).

## Q: `with-proxy` — функция в `.bashrc` vs alias vs wrapper-script?

**Контекст:** пользователь хочет `with-proxy <cmd> <args...>` → выполнить через privoxy (`HTTPS_PROXY=http://127.0.0.1:8118`).

**Варианты:**
| | alias | function в .bashrc | script в ~/.local/bin |
|---|---|---|---|
| Аргументы `"$@"` | ❌ не поддерживает | ✅ | ✅ |
| Export env перед командой | ❌ alias это expansion | ✅ (env=val cmd args) | ✅ |
| Доступен в bash | ✅ | ✅ | ✅ |
| Доступен в sh (не-interactive) | ❌ | ❌ (только interactive bash) | ✅ |
| Видно `which with-proxy` | ❌ | ❌ | ✅ |

**Решение: function в `~/.bashrc`** — user попросил именно bashrc, и типичное использование — в interactive shell.

**Деплой через ansible** `blockinfile` с маркером `# {mark} ANSIBLE MANAGED: with-proxy` — идемпотентно, можно обновлять без дубликатов.

```yaml
- ansible.builtin.blockinfile:
    path: /home/user/.bashrc
    marker: "# {mark} ANSIBLE MANAGED: with-proxy"
    block: |
      with-proxy() {
          HTTPS_PROXY=http://127.0.0.1:8118 HTTP_PROXY=http://127.0.0.1:8118 "$@"
      }
  become: true
  become_user: user
  tags: [with-proxy, user-bashrc, privoxy]
```

**HTTP_PROXY тоже добавлен** — многие утилиты (apt, apt-get, git) смотрят обе переменные. Пользователь явно просил `HTTPS_PROXY`, но `HTTP_PROXY` с тем же значением — pragmatic default. Privoxy сам слушает http://, это работает как для http-, так и для https-URL.

## Q: Nerd Font — почему перенесено из late_command в ansible?

**Контекст:** install падал на `curl: (22) 404` при скачивании JetBrainsMono.tar.xz с GitHub. Причина — редирект release-asset на `release-assets.githubusercontent.com` иногда не работает из installer chroot.

**Анализ:** Nerd Font — **cosmetic, не критичный**. Его отсутствие на первом boot'е — не блокер. Установка вполне может быть отложена. Но если падает в late_command с `set -e` — валит **весь** finish-install, что ломает установку.

**Решение: перенос в ansible** (tag `nerd-font`). Что даёт:
- Запускается на boot'нувшейся системе — легко ретраить при сбое
- Падение одной задачи не валит весь pipeline
- `--tags nerd-font` — селективный retry
- Использует `ansible.builtin.uri` + `get_url` + `unarchive` — корректная обработка ошибок с retries

**Общее правило** (теперь в CLAUDE.md §6): cosmetic/user-level шаги с external-download → в ansible, не в late_command.

## Q: DBeaver vs DbGate vs pgcli — что выбрать для PG?

**Контекст:** первоначальный выбор был DBeaver CE. Проблемы:
- JVM startup ~5 сек
- RAM idle 400-600 MB
- Editor / autocomplete на среднем уровне (жалобы пользователя)
- TLS-timeout при скачивании с `dbeaver.io` из ограниченных сетей

**Критерий (из [CLAUDE.md §1](../../CLAUDE.md)):** экономия RAM runtime приоритетнее disk size.

**Варианты:**

| | DBeaver CE | DbGate | pgcli | IntelliJ IDEA + DB plugin |
|---|---|---|---|---|
| Тип | GUI (JVM/Eclipse) | GUI (Electron) | CLI (Python) | GUI (JVM) |
| RAM idle | 400-600 MB | ~250 MB | ~30 MB | 600-1000 MB |
| Startup | ~5s | ~2s | <1s | ~8s |
| Autocomplete | Средний (schema introspection) | Средний | **Отличный** (magic) | **Gold standard** |
| Download reliability | dbeaver.io TLS глюки | GitHub CDN OK | Debian main OK | requires JetBrains tooling |
| Поддерживает | ~80 DBs | ~15 DBs | PG only | ~60 DBs |

**Решение:** 
- **pgcli** как primary (CLI, лучший autocomplete бесплатно, 30 MB RAM)
- **DbGate** как GUI-замена DBeaver (легче, быстрее, сравнимое автодополнение)
- **DBeaver убран** — ни одного преимущества которое оправдывает 400+ MB JVM overhead
- **IntelliJ IDEA Community + DB plugin** — упоминается в документации как «если autocomplete критичен», но не в default bootstrap (1 GB RAM)

**Паттерн выбора для других категорий в будущем:** соблюдать иерархию из [CLAUDE.md §1](../../CLAUDE.md) — сначала CLI, потом native GUI, потом Electron, только потом JVM.

## Q: VS Code — через apt-репо или прямой `.deb`?

**Первая попытка:** apt-repository + ключ в `/etc/apt/keyrings/microsoft.asc` + `apt install code`.

**Проблема:** VS Code `.deb` постинсталлер **сам** создаёт свой `/etc/apt/sources.list.d/vscode.list` с ключом в `/usr/share/keyrings/microsoft.gpg` (или `/etc/apt/keyrings/packages.microsoft.gpg` — зависит от версии). Это **конфликтует** с нашим:
```
E:Conflicting values set for option Signed-By regarding source
https://packages.microsoft.com/repos/code/ stable:
/etc/apt/keyrings/microsoft.asc != /usr/share/keyrings/microsoft.gpg
```
После этого **весь** `apt update` падает.

**Решение: прямой `.deb`** через `https://go.microsoft.com/fwlink/?LinkID=760868` (официальный «всегда latest» redirect).

- Мы НЕ создаём apt-source, не копируем key — postinst `.deb` сам всё настраивает
- Будущие обновления через `apt upgrade` работают автоматически
- Нет конфликта по `Signed-By`

Паттерн как у DbGate/Obsidian — `get_url` + `apt: deb:`. Общий: **не конкурировать с postinst**.

**Восстановление повреждённой системы** (если ansible уже создала свой conflicting source):
```bash
# Удалить наши файлы (если есть)
sudo rm -f /etc/apt/keyrings/microsoft.asc
# Найти все vscode-sources
sudo grep -rl "packages.microsoft.com/repos/code" /etc/apt/
# Оставить только один (тот что от postinst кода) или оба удалить и переустановить
sudo apt update
```

## Q: Electron-apps из GitHub `.deb` — почему нужны symlinks?

**Контекст:** после установки Obsidian/Bruno/DbGate/Throne из GitHub `.deb`,
команда `obsidian` / `bruno` / etc. — `command not found`. GUI (из меню /
rofi) работает.

**Причина:** Electron-based `.deb` из GitHub Releases **по convention**
кладут бинарь только в `/opt/AppName/<name>` и создают `.desktop`-entry.
`/usr/bin/<name>` symlink — **не создают**. GUI запускается через
`.desktop` Exec= с absolute path, но терминал без symlink не видит.

Это отличается от Debian-policy пакетов (`htop`, `pgcli`, `chezmoi`,
`code` от Microsoft apt-repo) которые сами кладут в `/usr/bin/`.

**Решение:** после каждого `apt: deb:` из GitHub — дополнительный
`ansible.builtin.file state: link` task:
```yaml
- ansible.builtin.file:
    src: /opt/Throne/Throne
    dest: /usr/local/bin/throne
    state: link
```

**Список приложений где это применено:**
- Throne → `/usr/local/bin/throne` (source: `/home/user/mr/apps/Throne/Throne`, portable zip)
- Obsidian → `/usr/local/bin/obsidian`
- Bruno → `/usr/local/bin/bruno`
- DbGate → `/usr/local/bin/dbgate`
- (Postman, Telegram — tarball-установка, уже с symlinks)

**Приложения где не нужно:**
- `chezmoi`, `code` (VS Code), `pgcli`, `libreoffice` — сами создают `/usr/bin/`

Правило в [CLAUDE.md §12](../../CLAUDE.md).

## Q: Throne — почему portable zip, а не .deb?

**Контекст:** раньше ansible качал `Throne-*-amd64.deb` с GitHub releases и
ставил через `apt: deb:`. Пользователь уже использует portable zip на dev-машине
(распакованный в `~/mr/apps/Throne`) и просит сделать так же в ansible.

**Обсудили:**

| Аспект | `.deb` | portable zip |
|---|---|---|
| Путь бинаря | `/opt/Throne/Throne` (root-only) | `~/mr/apps/Throne/Throne` (user-owned) |
| Config | пишется в `~/.config/Throne` | рядом с бинарём (`Throne/config/`) |
| Обновление | `dpkg -i new.deb` | `rm -rf ~/mr/apps/Throne && unzip new.zip -d ~/mr/apps` |
| Postinst-риск | есть (ставит systemd-unit в некоторых версиях) | нет |
| Совместимость с существующим config | ⚠️ разные пути config-файла | ✅ user уже работает в portable-схеме |
| Размер | ~27 MB `.deb` | ~59 MB `.zip` (не сжат) |
| Root-права для установки | нужны | не нужны для распаковки (нужны только для symlink и `.desktop`) |

**Решение:** portable zip в `/home/user/mr/apps/Throne/`.

Дополнительно:
- добавили apt-task `unzip` перед распаковкой (нет в preseed `pkgsel/include`,
  согласно CLAUDE.md §3 preseed заморожен — добавляем в ansible)
- регекс `Throne-.*-linux-amd64\.zip$` чтобы не поймать `macos-*` / `windows-*`
  assets с тем же префиксом
- `owner: user` на `unarchive` + recursive `chown` после распаковки
- `.desktop`-entry указывает на absolute path `/home/user/mr/apps/Throne/Throne`
  (captive в home — если пользователь `user` не существует, пункт меню не
  заработает, но для targeted single-user системы это ок)

**Trade-off:** приложение живёт в `~/mr/apps/` и привязано к user `user` —
это не multi-user schema. Для нашей системы (1 user, captive home) приемлемо.

## Ссылки

- [Ansible overview](README.md)
- [Applications](applications.md) — детали каждого приложения
- [Bootstrap](../post-install/README.md) — как ansible запускается
- [CLAUDE.md §1](../../CLAUDE.md) — правило экономии RAM
- [CLAUDE.md §6](../../CLAUDE.md) — правило робастности late_command
- [CLAUDE.md §12](../../CLAUDE.md) — symlinks для Electron `.deb`
