# my_os

Воспроизводимая установка **Debian 13 (trixie)** для личной рабочей станции.
Цель — «кнопка восстановления»: из пустого диска → до полностью настроенной
системы одним прогоном.

## Слои

```
┌──────────────────────────────────────────────────────────────┐
│  preseed/        — установка ОС (разметка, базовые пакеты)   │  Ventoy USB
│  ↓                                                           │
│  ansible/        — desktop-приложения + system-config        │  bootstrap.sh
│  ↓                                                           │
│  chezmoi         — пользовательские dotfiles                 │  bootstrap.sh
│  ↓                                                           │
│  user-tools      — atuin, rustup, go tools                   │  bootstrap.sh
│  ↓                                                           │
│  backup restore  — PG-volumes, /home/docs, /data/*           │  ручной шаг
└──────────────────────────────────────────────────────────────┘
```

## Порядок использования

### 1. Установка ОС (один раз перед первой загрузкой)

Готовая Ventoy-флешка со встроенным preseed (процедура в
[`preseed/CONTEXT.md`](preseed/CONTEXT.md)):

- BIOS → Boot menu → USB (Ventoy)
- «Debian 13 (auto-install via preseed)» → автоустановка
- После ребута: логин `user` / `changeme` (поменяйте сразу)

Проверочный чек-лист и диагностика проблем — в
[`preseed/POST-INSTALL.md`](preseed/POST-INSTALL.md).

### 2. Поверх ОС — приложения и настройки

Клонировать этот репо на свежую систему (если preseed не положил его туда
сам), затем:

```bash
cd ~/mr/workspace/my_os
./bootstrap.sh
```

Это прогоняет:
- `ansible/site.yml` → все desktop-приложения и system-config (privoxy, …)
- `chezmoi init --apply $DOTFILES_REPO` → ваши dotfiles (если репо задан)
- `atuin`, `rustup`, `go install …` → per-user инструменты

Отдельные этапы:
```bash
./bootstrap.sh ansible     # только system apps
./bootstrap.sh dotfiles    # только chezmoi
./bootstrap.sh user-tools  # только atuin/rustup/go
```

### 3. Данные (backups) — отдельно

Не входят в этот pipeline. PG-volumes, `/home/user/docs`, `/data/*` —
восстанавливать по своей стратегии (restic/rsync и т.п.).

## Структура репо

```
my_os/
├── README.md                ← вы здесь
├── bootstrap.sh             ← one-button restore (ansible + chezmoi + user-tools)
├── preseed/
│   ├── preseed.txt          ← основной preseed-файл
│   ├── CONTEXT.md           ← полный контекст проекта (решения + следующий шаг)
│   ├── POST-INSTALL.md      ← чек-лист проверки и диагностика проблем
│   ├── find-fastest-mirror.sh
│   └── example-preseed.txt  ← оригинал из Debian (не трогать)
└── ansible/
    ├── site.yml             ← playbook с 9 приложениями + privoxy-config
    ├── inventory.ini
    └── README.md            ← запуск, теги, как добавлять новые приложения
```

## Философия

- **preseed = минимальная прослойка.** Только то что должно быть в момент
  первой загрузки (диск, user, базовые пакеты). Без дополнений «на потом».
- **ansible = system-level.** Всё что ставится/конфигурируется как root
  на системе (apps, services, repos, config-файлы в `/etc/`).
- **chezmoi = user-level.** Всё что живёт под `~/` (dotfiles, конфиги
  приложений).
- **bootstrap.sh = оркестратор.** Тупой wrapper вокруг первых трёх.

Разделение даёт тестируемость: каждый слой меняется/запускается отдельно.

## Текущий статус

См. секцию «ОСТАЛОСЬ» в [`preseed/CONTEXT.md`](preseed/CONTEXT.md) — там
полный контекст проекта, принятые решения и что ещё предстоит.

Коротко:
- ✅ preseed.txt написан и провалидирован
- ✅ Ventoy-флешка собрана
- ✅ ansible-playbook с 9 приложениями (VS Code, DBeaver, Obsidian, Bruno,
  Throne, Postman, Redis Insight, LibreOffice, Telegram) + privoxy-config
- ✅ bootstrap.sh
- ⏳ первая физическая установка (ждёт железа)
- ⏳ dotfiles repo (chezmoi) — будет после успешной установки
