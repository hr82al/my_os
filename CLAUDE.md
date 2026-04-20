# CLAUDE.md — project rules

## 📐 Принципы проекта (во главу угла)

### 1. Экономия RAM в runtime — приоритет

Система используется на USB SSD (variant B, см. [preseed-usb.txt](preseed/preseed-usb.txt))
и при ограниченных ресурсах. **RAM в работе важнее чем disk install size.**

При выборе между несколькими пакетами/альтернативами — учитывать idle/active RAM.

**Порядок предпочтений (лёгкое → тяжёлое):**
1. CLI-утилита (pgcli, ncdu, htop) — `< 50 MB`
2. Native GUI (kitty, Telegram Qt) — `50-150 MB`
3. Native toolkit GUI (GIMP GTK, Inkscape) — `150-400 MB`
4. Electron app (VS Code, DBeaver, Obsidian, Chrome) — `200-800 MB each`
5. JVM-based (DBeaver, DataGrip, IntelliJ) — `400-1500 MB each`

**Правила при добавлении нового пакета:**
- Если есть native/CLI эквивалент (даже менее «красивый») — оформить как **primary вариант**
- Electron/JVM-тяжеловесы — только когда реально нужны фичи, не «на всякий случай»
- Background-демоны — только если реальная польза; `systemctl --user` предпочтительнее system
- Пример выбора: для SQL — сначала `pgcli`, только потом DBeaver (`--tags pgcli` всегда в bootstrap, DBeaver optional)

При обсуждении альтернатив — **явно показать числа** RAM idle/working set
(через `ps_mem` или `smem`), не полагаться на ощущения.

### 2. Не использовать Snap / Flatpak

**Все приложения — натив** (apt, upstream .deb, tarball в `/opt`, AppImage в
`/opt/` как последняя опция).

**Почему:**
- Snap/Flatpak = контейнеризованный runtime → **+300-700 MB оперативы на sandbox-libs** при работе приложения
- Duplication библиотек (свой Qt/GTK в каждом Flatpak)
- Файловые integration limitations (MIME handlers, theme mismatch, keyring access)
- Авто-запуск snapd/flatpakd даёт baseline RAM overhead

**Правило при выборе источника установки:**

| Источник | Приоритет | Когда использовать |
|---|---|---|
| Debian `main` / `contrib` | 🟢 **Первый** | Пакет есть в стандартной трилогии, версия приемлема |
| Upstream apt-репо | 🟢 | docker-ce, google-chrome, VS Code (версии актуальные, GPG-key) |
| Прямой `.deb` с официального / GitHub release | 🟡 | Obsidian, Bruno, Throne, DBeaver |
| `tarball` → `/opt/` + symlink + .desktop | 🟡 | Postman, Telegram (нет .deb) |
| `AppImage` в `/opt/` | 🟠 | Redis Insight (нет .deb, нет tarball) |
| **Snap** | 🔴 **НЕ ИСПОЛЬЗОВАТЬ** | — |
| **Flatpak** | 🔴 **НЕ ИСПОЛЬЗОВАТЬ** | — |

**Исключение для Snap/Flatpak:** только если нужна конкретная функциональность
которая **физически недоступна** через другие каналы AND есть чёткое обоснование.
Требует явного коммит-месседжа «Почему snap/flatpak ЗДЕСЬ».

### 3. Preseed заморожен — система успешно установлена

Дата первой успешной установки: **2026-04-19** (variant B, USB SSD).

С этого момента **НЕ ТРОГАТЬ `preseed/*.txt`** без явной необходимости. Все
новые фичи идут в другие слои:

| Задача | Куда |
|---|---|
| Новый пакет для workflow | `ansible/site.yml` (tag приложения) |
| Конфиг системы (privoxy, sysctl, systemd-unit) | `ansible/site.yml` |
| User-script в ~/.local/bin | `ansible/files/` + copy-task |
| Dotfiles (~/.bashrc, ~/.config/) | **chezmoi** (когда создан repo) |
| Документация | `wiki/` + `decisions.md` |

**Когда можно трогать preseed:**
- Критичный install-blocking баг (падение pkgsel, partman, late_command)
- Смена целевого железа (новый диск, другая архитектура)
- Обновление Debian major version (trixie → bookworm+2)

**Когда НЕЛЬЗЯ трогать preseed:**
- Добавить новое приложение → ansible
- Поменять конфиг сервиса → ansible
- Исправить typo в комментарии → ansible (не требует переустановки)
- Изменить автологин / сессию WM → ansible (идемпотентно, применяется без переустановки)

Если меняешь preseed — **объяснить зачем** в commit-message и обновить
соответствующий `decisions.md`. Потом flash sync + **переустановить систему**
для проверки (дорого — делать только когда вынужденно).

---

## Всегда валидировать изменения в install-pipeline

Перед коммитом правок в `preseed/*.txt` или `ansible/site.yml` — прогнать три проверки через Debian-13 docker (локально на Fedora `debconf-set-selections` и `ansible-playbook` недоступны).

### 1. Синтаксис preseed

```bash
for f in preseed.txt preseed-usb.txt; do
    echo -n "$f: "
    docker run --rm -v $PWD/preseed:/p debian:13 bash -c \
        "apt-get install -y debconf >/dev/null 2>&1 && debconf-set-selections --checkonly /p/$f" \
        && echo "✅" || echo "❌"
done
```

### 2. Синтаксис ansible

```bash
docker run --rm -v $PWD/ansible:/a debian:13 bash -c \
    'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ansible >/dev/null 2>&1 && cd /a && ansible-playbook -i inventory.ini site.yml --syntax-check'
```

### 3. Существование пакетов в Debian 13 (trixie)

⚠️ **Обязательно** перед добавлением любого пакета в preseed `pkgsel/include` или
ansible `apt:`. Apt-транзакция атомарная: один несуществующий пакет валит всю
установку и выдаёт **каскад фейковых** ошибок «unable to locate X» для
несвязанных пакетов.

**Два уровня валидации:**

**a) apt-cache show** — быстрая проверка что пакет есть в метаданных:
```bash
docker run --rm debian:13 bash -c '
    apt-get update -qq
    for p in <пакет1> <пакет2> ...; do
        apt-cache show "$p" >/dev/null 2>&1 && echo "✅ $p" || echo "❌ $p MISSING"
    done'
```

**b) apt-get install --simulate** — **строже**: проверяет что пакет
устанавливается, его зависимости разрешаются, нет конфликтов.
```bash
docker run --rm debian:13 bash -c '
    apt-get update -qq
    apt-get install -y --simulate --no-install-recommends <все пакеты одной строкой> 2>&1 | tail -3'
```

Если выхлоп заканчивается на `Conf <pkg>` строках — ок. Если `E: Unable to locate
package X` — валится.

**НЕ ДОВЕРЯТЬ** summary-строке типа «все найдены» — **читать полный список**
MISSING в выхлопе. Был случай: validation-скрипт показал `✅ все найдены`, а
реально один пакет (`telegram-desktop`) отсутствовал. Строка `❌ ОТСУТСТВУЮТ:`
может быть замаскирована среди другого вывода.

**Верификация что пакет нашли не по описанию.** `apt-cache search foo` возвращает
все пакеты где `foo` упоминается в описании. Нужно `apt-cache show foo` — имя в
точности. Аналогично не путать `telegram-desktop` (не существует) с
`telegram-send`, `python3-python-telegram-bot` (существуют но не то что нужно).

**Известные подводные камни** (различия bookworm → trixie):

| Было в Debian 12 | В Debian 13 |
|---|---|
| `policykit-1` | **удалён** → `polkitd` |
| `chezmoi` | **нет в Debian main** → ставить из GitHub `.deb` через ansible |

### 4. При установке с полного DVD нужен явный `use_mirror boolean true`

Installer с DVD **по умолчанию отключает сетевой mirror** (`apt-setup/use_mirror` = `false`) — считается что пакетов на DVD достаточно. Но DVD-1 не содержит всё, что в main (например `qtile`, `ansible`, `snapper`, `rclone`). Без mirror они не найдутся → pkgsel валится с ложными «Unable to locate package X».

Обязательно:
```
d-i apt-setup/use_mirror boolean true
d-i apt-setup/services-select multiselect security, updates
d-i apt-setup/security_host string security.debian.org
```

Симптом в `/var/log/syslog` installer'а:
```
apt-setup: warning: /usr/lib/apt-setup/generators/50mirror returned error code 1; discarding output
```
«discarding output» = скрипт вышел с 1 потому что use_mirror=false — это **ожидаемое** поведение при отсутствии настройки, не реальная ошибка сети.

### 5. DVD-installer оставляет `deb cdrom:` запись — отключать

После DVD-install'а `/etc/apt/sources.list` содержит строку вида:
```
deb cdrom:[Debian GNU/Linux 13.4.0 _Trixie_...]/ trixie contrib main non-free-firmware
```
Если в `late_command` выполнить `apt-get update` (например при добавлении docker-ce upstream-репо), apt пытается прочитать DVD, **которого уже нет** — команда виснет бесконечно. В итоге «Finish installation» в конце инсталлятора не отвечает.

Обязательно:
```
d-i apt-setup/disable-cdrom-entries boolean true
```

И belt-and-suspenders в late_command перед первым `apt-get update`:
```sh
sed -i "/^deb cdrom:/d" /target/etc/apt/sources.list
```

Симптом в `/var/log/late-install.log` на установленной системе:
```
+ echo 'deb [...] > /target/etc/apt/sources.list.d/docker.list'
+ in-target apt-get update
<< лог обрывается здесь >>
```

При обнаружении отсутствующего пакета: либо найти новое имя (часто `*-1` → `*d`,
или `lib…1` → `lib…1t64` и т.п.), либо вынести установку в `ansible/site.yml`
по паттерну Bruno/Obsidian: `uri` для latest release → `get_url` для `.deb` →
`apt: deb:`.

### 6. Робастность late_command — проводить тщательные проверки

`late_command` выполняется один раз во время установки, в ограниченном installer-окружении. Отладка: посмотреть лог → переустановить систему (долго). Поэтому **каждая внешняя команда должна быть проверена** перед коммитом.

#### Что проверять

**a. External URL downloads** — для **каждого** `curl`/`wget` в late_command:
```bash
# Проверить что URL реально отвечает 200 (а не 301, 302, 404):
curl -fsSLI -o /dev/null -w "%{http_code}\n" "<URL>"
# Если 200 — проверить что возвращает валидный контент:
curl -fsSL "<URL>" | head -c 100
```
Проверить варианты: с redirect, с TLS, с auth/rate-limit (GitHub API limits).

**b. Critical vs optional разделение в late_command**

| Категория | Примеры | Если упало |
|---|---|---|
| **Critical** — валит install | partman, GRUB, создание user, root password | ✅ fail-fast (`set -e`) |
| **System config** — нужен для boot'a | fstab, sources.list, базовые пакеты | ✅ fail-fast |
| **Apps setup** — нужен для workflow | docker-ce, git clone my_os | ⚠️ fail-fast но только после валидации URL |
| **Cosmetic / user-level** — можно доставить позже | Nerd Font, autologin, chrome, NVRAM-cleanup | ❌ **НЕ В late_command** — в ansible/bootstrap.sh |

**Правило:** если шаг — cosmetic/user-level, **вынести в ansible**. Ansible:
- Запускается на boot'нувшейся системе (легко отладить)
- Тегируется (можно повторить: `--tags <имя>`)
- Не валит install если упадёт

**c. Wrap external calls даже в critical-части late_command**

Если что-то ДОЛЖНО быть в late_command (не ansible) но external — обернуть в:
```sh
(
    curl -fsSL "<url>" -o /tmp/file
    # use file
) || { echo "WARN: <step> failed, continue"; }
```
Exit code не пропагируется, но логируется для post-install-разбора.

**d. Категоризация уже встреченных ошибок**

| Что упало | Причина | Исправление |
|---|---|---|
| Nerd Font `curl: (22) 404` в installer | GitHub CDN redirect проблемы в installer chroot | Вынести в ansible (tag `nerd-font`), не в late_command |
| apt-get update hang | cdrom: в sources.list | `disable-cdrom-entries` + sed |
| pkgsel unable to locate | use_mirror=false по умолчанию | Явный `use_mirror true` |
| pkgsel cascade «unable to locate» | один несуществующий пакет | Валидация пакетов через docker |

**e. Checklist перед добавлением шага в late_command**

1. Действительно ли это MUST-HAVE во время install? Или может быть в ansible?
2. Использует ли internet? → проверить URL (`-fsSLI`) с redirect follow
3. Использует ли пакет не из base? → проверить что пакет в pkgsel/include и существует
4. Что произойдёт если упадёт? Inst.-blocking или degraded?
5. Есть ли exit code propagation через `|| true` где нужно?

### 7. Тестировать внешние URLs регулярно (URL-rot)

⚠️ **URL сервисов меняются со временем** (ребрендинг, переезд на CDN, smartversioning).
Случаи:
- **Redis Insight:** `/latest/RedisInsight-*` → `/latest-v3/Redis-Insight-*` (смена имени + пути)
- **GitHub asset downloads:** иногда redirect на `release-assets.githubusercontent.com` даёт 404 из определённых сетей
- **dbeaver.io:** TLS handshake timeout из ограниченных сетей — надо через privoxy

Перед commit'ом — **проверить ВСЕ URL которые используются** в ansible
(`uri`, `get_url`) и preseed (curl):
```bash
for url in \
    "https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb" \
    "https://telegram.org/dl/desktop/linux" \
    "https://s3.amazonaws.com/redisinsight.download/public/latest-v3/Redis-Insight-linux-x86_64.AppImage" \
    # ... все остальные
do
    code=$(curl -sLI -o /dev/null -w "%{http_code}" --max-time 10 "$url")
    [ "$code" = "200" ] && echo "✅ $code $url" || echo "❌ $code $url"
done
```

Если какой-то URL возвращает 403 / 404 / timeout:
1. Искать замену на официальной странице (например redis.io/downloads/)
2. Обновить ansible/preseed
3. Добавить в wiki decisions.md запись об изменении

### 8. Ansible: circular dependency с privoxy

Пользователь использует **privoxy на 127.0.0.1:8118** как HTTP→SOCKS5 мост
к **throne** (SOCKS5 на 127.0.0.1:2080). Это даёт доступ к сайтам с
ограничениями.

⚠️ **НЕ использовать privoxy по умолчанию в ansible**, потому что:
- `throne` устанавливается первым запуском ansible
- После install throne **пользователь должен вручную** залогиниться в GUI и настроить subscription → SOCKS5 начнёт слушать на 2080
- Если ansible ставит privoxy в `HTTPS_PROXY` **до** настройки throne — `get_url` висит на connection refused к 127.0.0.1:2080
- **Порядок:** preseed → throne-package installed (не настроен) → bootstrap ansible без proxy → **user настраивает throne** → ansible с `-e use_proxy=true` для рестаксов где нужна прокси

**В `site.yml`:**
```yaml
environment:
  HTTPS_PROXY: "{{ (use_proxy | default(false) | bool) | ternary('http://127.0.0.1:8118', '') }}"
  HTTP_PROXY:  "{{ (use_proxy | default(false) | bool) | ternary('http://127.0.0.1:8118', '') }}"
  NO_PROXY: "localhost,127.0.0.1,::1,.local"
```
Default — **false** (не использовать). Включить: `-e use_proxy=true`.

**Alternative — обход прокси:** если URL падает на TLS handshake из
ограниченной сети — найти более надёжный endpoint (GitHub releases вместо
vendor CDN, например `dbeaver.io` → github.com/dbeaver/dbeaver).

**Симптом TLS handshake timeout:**
```
Module failed: Request failed: <urlopen error _ssl.c:1012: The handshake operation timed out>
```
→ искать альтернативный URL (обычно GitHub API → releases asset), не надеяться на proxy.

**Таймауты** в `module_defaults` play-уровня:
```yaml
module_defaults:
  ansible.builtin.get_url:
    timeout: 60           # default 10s мало для больших .deb/tarball
  ansible.builtin.uri:
    timeout: 30           # API-запросы к GitHub
```

### 9. Тестировать перед коммитом (URL + packages + syntax)

Перед любой правкой ansible/site.yml или preseed/*.txt:
```bash
# 1. syntax preseed
for f in preseed.txt preseed-usb.txt; do
    docker run --rm -v $PWD/preseed:/p debian:13 bash -c \
        "apt-get install -y debconf >/dev/null 2>&1 && debconf-set-selections --checkonly /p/$f"
done

# 2. syntax ansible
docker run --rm -v $PWD/ansible:/a debian:13 bash -c \
    'apt-get update -qq && apt-get install -y --no-install-recommends ansible >/dev/null 2>&1 && cd /a && ansible-playbook -i inventory.ini site.yml --syntax-check'

# 3. ALL URLs used in ansible + preseed — все должны быть 200
for url in $(grep -hoE 'https?://[^[:space:]"]*' ansible/site.yml preseed/*.txt | sort -u | grep -v example\\.com); do
    code=$(curl -sLI -o /dev/null -w "%{http_code}" --max-time 10 "$url")
    [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "302" ] && echo "✅ $code $url" || echo "❌ $code $url"
done

# 4. ALL packages in pkgsel — валидировать через apt-get install --simulate
# (см. §3 выше)
```

Если URL возвращает не-2xx — искать замену до коммита, не после install'а.

### 10. Regex для GitHub assets — **обязательно** тестировать на реальном API-response

⚠️ **URL возвращает 200 ≠ regex матчит asset.** Это разные проверки. Naming convention assets у проектов меняется: Bruno переходил от `bruno_<v>_amd64.deb` на `bruno_<v>_amd64_linux.deb` — URL работал, regex упал с `No first item, sequence was empty`.

Перед коммитом ansible-задач с `selectattr('name', 'match', 'xxx')`:

```bash
# Вставить в /tmp/check-regex.sh и запустить
check() {
    local repo="$1" regex="$2" name="$3"
    local result
    result=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
        | jq -r ".assets[] | select(.name | test(\"$regex\")) | .name" | head -3)
    if [ -n "$result" ]; then
        echo "✅ $name  →  $result"
    else
        echo "❌ $name  — regex '$regex' не матчит ни одного asset"
        echo "   Реальные имена:"
        curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
            | jq -r '.assets[].name' | head -5 | sed 's/^/     /'
    fi
}

# вызов для каждого repo + regex который используется в site.yml
check "usebruno/bruno"     'bruno_.*_amd64_linux\\.deb$'         "bruno"
check "obsidianmd/obsidian-releases" 'obsidian_.*_amd64\\.deb$'  "obsidian"
# ... etc
```

**Симптом проблемы в runtime ansible:**
```
Error while resolving value for 'xxx_deb_url': No first item, sequence was empty.
```
→ regex не матчит ни одного asset. Fix — смотреть **реальные** имена в release, обновить regex.

**Ошибки naming которые встречали:**
- `bruno_<v>_amd64.deb` → `bruno_<v>_amd64_linux.deb` (добавили `_linux` перед `.deb`)
- Redis Insight: `/latest/RedisInsight-*` → `/latest-v3/Redis-Insight-*` (split в имени)

### 11. Паттерн альтернативных источников для «рискованных» downloads

Некоторые URL **стабильно блокируются** из определённых сетей (DPI/ISP):
- `telegram.org` — часто заблокирован в РФ провайдерами (`Errno 101 Network is unreachable`)
- `dbeaver.io` — TLS timeout (перешли на GitHub releases)
- Vendor CDN в момент glitch дают 404

**Правило:** для таких задач используем **fallback-цепочку** с 3-4 альтернативными источниками + `block/rescue` для non-fatal failure:

```yaml
- name: <App> | install
  vars:
    # Путь по умолчанию где пользователь может pre-download положить
    app_local_path: /home/user/Downloads/offline/app.tar.xz
    # URL можно переопределить через -e app_url=...
    app_url: "{{ app_url | default('https://vendor.com/download') }}"
  block:
    - name: App | check pre-downloaded file
      ansible.builtin.stat:
        path: "{{ app_local_path }}"
      register: app_local

    - name: App | use pre-downloaded tarball
      ansible.builtin.copy:
        src: "{{ app_local_path }}"
        dest: /tmp/app.tar.xz
        remote_src: true
      when: app_local.stat.exists

    - name: App | download (fallback)
      ansible.builtin.get_url:
        url: "{{ app_url }}"
        dest: /tmp/app.tar.xz
      when: not app_local.stat.exists

    # ... остальные шаги (extract, symlink, .desktop) ...
  rescue:
    - ansible.builtin.debug:
        msg: |
          ⚠️ App install failed. Альтернативы:
          1. Pre-download: ~/Downloads/offline/app.tar.xz
          2. Proxy: -e use_proxy=true (после настройки throne)
          3. Local HTTP: python3 -m http.server + -e app_url=http://...
          4. rclone: rclone copy remote:offline-apps/ ~/Downloads/offline/
  tags: [app]
```

### Fallback-цепочка порядка проверки

Для каждого рискованного приложения:

1. **Pre-downloaded local file** (`~/Downloads/offline/<app>.tar.xz`)
   - Пользователь заранее скачал на dev-машине (где работает VPN)
   - Перенёс на целевую машину (rsync/USB/rclone)
   - Если есть — используется без network запроса
2. **Direct URL** (через privoxy если `use_proxy=true`)
   - Через throne → SOCKS5 → external сайт
3. **Overridable URL** (через `-e <app>_url=...`)
   - User запускает свой HTTP-server локально
   - Или указывает другой mirror
4. **Fallback: rescue + warning**
   - Весь play продолжается, печатается инструкция

### Признаки что apply этот паттерн

- Vendor-specific CDN (не GitHub Releases) — `telegram.org`, `*.amazonaws.com/redis-insight.*`, `dl.pstmn.io`
- Сайты из geoблокировок (РФ, Китай, Иран и т.п.)
- Cosmetic/non-essential (fonts, AppImage)

### НЕ оборачивать в rescue

- Apt из Debian main (обязательное для системы)
- `docker.com` / `packages.microsoft.com` (должны работать всегда)
- GitHub releases (обычно надёжно; retry через `-e use_proxy=true` если timeout)

### Симптомы network-failure

| Ошибка | Уровень | Причина |
|---|---|---|
| `Errno 101 Network is unreachable` | route / firewall | DNS работает, но route блокирован (DPI) |
| `urlopen error _ssl.c:1012: handshake timed out` | TLS | DPI sniffs TLS, drops connections |
| HTTP 403/404 от vendor CDN (не GitHub) | HTTP | URL-rot или геоблок API |
| `Connection refused` | local | privoxy/throne не запущены |

### 12. Electron `.deb` с GitHub releases — **обязательно** добавлять symlink в PATH

⚠️ **Electron-based `.deb`** (Obsidian, Bruno, DbGate, Throne и т.п.) **НЕ создают**
`/usr/bin/<name>` symlink при установке. Их postinst кладёт бинарь только в
`/opt/AppName/<name>` и `.desktop`-entry. GUI запускается (меню/rofi → `.desktop`
→ absolute path), но **в терминале команда не найдена**.

Это отличается от Debian-policy пакетов (`apt install htop` → `/usr/bin/htop`) —
для Electron-`.deb` это convention upstream-проектов, не баг.

**Правило:** после каждой `apt: deb:` установки `.deb` из GitHub Releases —
**обязательно** добавить `ansible.builtin.file: state: link`:

```yaml
- name: App | install
  ansible.builtin.apt:
    deb: /tmp/app.deb
  tags: [app]

- name: App | symlink to /usr/local/bin (для терминала)
  ansible.builtin.file:
    src: /opt/AppName/app-binary
    dest: /usr/local/bin/app
    state: link
  tags: [app]
```

**Симптом проблемы:**
```
$ myapp
bash: myapp: command not found
```
При этом запускается из меню / rofi.

**Как найти правильный путь к бинарю:**
```bash
# На установленной системе:
dpkg -L <package> | grep -E '^/opt/.+/[^/]+$' | xargs file | grep ELF
# Или через find:
find /opt/AppName -maxdepth 1 -type f -executable -not -name '*.so*'
```

**Приложения которые имеют правильный `/usr/bin/` сами:**
- Native Debian пакеты (pgcli, libreoffice)
- Apt-репо от vendor (VS Code → `/usr/bin/code`)
- Go-based (chezmoi → `/usr/bin/chezmoi`)

**Приложения требующие manual symlink:**
- Electron + nwjs + similar frameworks (Obsidian, Bruno, DbGate, Throne, VS Code когда через .deb, …)
- Tarball'ы в `/opt/` (Postman, Telegram) — мы уже добавляем symlink в pattern

**При добавлении нового приложения:** после успешной установки прогнать
`which <app>` в docker-test. Если пусто — добавить symlink task.

Симптом в syslog который означает «late_command сломал installer»:
```
finish-install: /bin/preseed_command: return: line 88: Illegal number:
log-output: sh: syntax error: unterminated quoted string
init: process '/sbin/debian-installer' ... exited. Scheduling for restart.
main-menu: INFO: Menu item 'finish-install' succeeded but requested to be left unconfigured.
```
«succeeded but requested to be left unconfigured» на re-tries = late_command ломает installer → installer крэшнулся → «Finish installation» не отвечает.

## Документация — всё в `wiki/`

Структура wiki с вложенностью по секциям (preseed/, ansible/, ventoy/,
installation/, troubleshooting/, post-install/). Главный индекс —
[`wiki/README.md`](wiki/README.md).

**При редактировании кода (preseed, ansible, bootstrap.sh) — синхронно обновлять соответствующий файл в wiki.**

## Захват Q&A — правило

⚠️ **КАЖДЫЙ вопрос пользователя с архитектурным/дизайнерским смыслом и ответ на него** должен попасть в `wiki/<section>/decisions.md`.

### Что считать «вопросом для decisions»

Вопросы и ответы, которые стоит сохранять:

✅ **Сохранять:**
- «Почему X, а не Y?» (любой trade-off выбор)
- «Можно ли сделать X?» — и обсуждение альтернатив
- «Как это работает?» — объяснение механизма/поведения
- «А что если...» — what-if анализ
- Решения по размерам, путям, именам (`ESP 512 MiB потому что...`)
- Обнаруженные баги и их фиксы (в `troubleshooting/lessons-learned.md`)

❌ **Не сохранять (ephemeral):**
- «Обнови флешку» / «продолжай» / «комитить буду сам»
- Опечатки, уточнения вроде «я подключил, проверь»
- Шаг-за-шагом подтверждения
- Повторяющиеся команды, которые уже есть в документации

### Формат записи

Каждая Q&A в `decisions.md` — как секция:

```md
## Q: Почему X, а не Y?

**Контекст:** коротко в чём дилемма.

**Обсудили:** таблица или bullet list альтернатив с плюсами/минусами.

**Решение:** выбранный вариант + краткое почему.

Trade-off: [если есть]
```

### Куда писать

| Тема вопроса | Файл |
|---|---|
| Разметка диска, partman, late_command, mirror, packages | [`wiki/preseed/decisions.md`](wiki/preseed/decisions.md) |
| Playbook, apps install methods, privoxy | [`wiki/ansible/decisions.md`](wiki/ansible/decisions.md) |
| Ventoy setup, Fedora quirks | [`wiki/ventoy/decisions.md`](wiki/ventoy/decisions.md) |
| Процедура установки, variants, portable boot | [`wiki/installation/decisions.md`](wiki/installation/decisions.md) |
| Debug methodology, логи, валидация | [`wiki/troubleshooting/decisions.md`](wiki/troubleshooting/decisions.md) |
| bootstrap.sh, chezmoi, atuin, rustup | [`wiki/post-install/decisions.md`](wiki/post-install/decisions.md) |
| **Встреченные баги и фиксы** | [`wiki/troubleshooting/lessons-learned.md`](wiki/troubleshooting/lessons-learned.md) |

### Когда писать

- **Немедленно** после того как вопрос/ответ произошёл (не в конце сессии — забудется)
- Если решение сложное — короткую версию в `decisions.md`, длинную — в тематическом файле (например `preseed/late-command.md`) со ссылкой
- При повторном вопросе о том же — обновить существующую запись, не дублировать

## Стиль коммуникации

- Русский язык, технические термины en — не переводить
- Честная аргументация плюсов/минусов, не «бери A»
- Перед архитектурным решением — проверять реальные числа через `lsblk`/`du`/`free`
- Коротко: пользователь часто говорит «продолжаем» — это не «подожди новых инструкций»
