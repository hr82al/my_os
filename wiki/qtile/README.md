---
tags: [qtile, desktop, wm]
---

# qtile — tiling window manager

← [Wiki Index](../README.md)

qtile — это **tiling window manager** (не «рабочий стол»). Менеджер окон
на Python. Минимализм вместо DE. Установлен в preseed вместе с lightdm,
через autologin запускается сразу после boot.

## С чего начать

Если вы пришли из GNOME/KDE/XFCE — **прочитайте по порядку**:

1. [📖 Первые шаги — основы для DE-пользователя](first-steps.md) — главный гайд
2. [⌨️ Keybindings — шпаргалка](keybindings.md) — распечатать и держать рядом
3. [⚙️ Настройка `config.py`](config.md) — первые правки под себя
4. [🧰 Essentials — что ещё поставить](essentials.md) — rofi, picom, скриншоты, блокировка
5. [📋 Decisions & Q&A](decisions.md) — почему qtile, а не i3/sway/KDE

## TL;DR цикл работы

После autologin — вы сразу в qtile, экран практически пустой. Это нормально.

```
Super + Enter       → открыть терминал (kitty)
Super + r           → запустить приложение (вводите имя)
Super + 1..9        → переключить workspace (группу)
Super + Tab         → сменить layout (tile / max / stack)
Super + w           → закрыть текущее окно
Super + Ctrl + q    → выход из qtile (вернётся на lightdm)
```

**Super** = клавиша Windows (может быть другая — зависит от вашей клавиатуры).

## Структура секции

```
qtile/
├── README.md          ← вы здесь
├── first-steps.md     Основы, первые 30 минут после boot'а
├── keybindings.md     Полная шпаргалка горячих клавиш
├── config.md          Как настраивать ~/.config/qtile/config.py
├── essentials.md      Must-have: rofi, picom, скриншоты, nm-applet
└── decisions.md       Q&A
```

## Когда что-то совсем сломалось

Переключиться в консоль (TTY):
- `Ctrl + Alt + F2` или `F3` → tty без графики
- Логиниться как `user` → `sudo systemctl restart lightdm` перезапускает графику
- `Ctrl + Alt + F7` (или `F1`) вернуться в графику

Детали: [first-steps.md → Recovery](first-steps.md#recovery-когда-всё-сломалось).

## Ссылки

- [Installation](../installation/README.md) — как qtile сконфигурирован через preseed
- [Bootstrap](../post-install/README.md) — ansible/chezmoi для остальных настроек
