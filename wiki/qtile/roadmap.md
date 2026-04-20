---
tags: [qtile, roadmap, learning-plan]
---

# Roadmap: XFCE4 → эффективный qtile

← [qtile](README.md) | [Wiki Index](../README.md)

Фазированный план перехода с XFCE4 (или любого full-DE) к продуктивному
использованию qtile. Цель — не «выучить все биндинги за день», а плавное
привыкание без откатов в прежний DE.

## Стартовое состояние

Что **уже сделано** в preseed (см. [packages.md](../preseed/packages.md)):
- `qtile kitty lightdm flameshot` установлены
- Autologin `user` в сессию qtile через lightdm
- `network-manager-gnome` (nm-applet доступен) в preseed

Что **отсутствует** (ни в preseed, ни в ansible на момент 2026-04-20):
- `rofi picom dunst feh` — launcher, compositor, уведомления, обои
- `brightnessctl playerctl pavucontrol` — multimedia/audio контроль
- `lxappearance arandr` — GTK-theme / multi-monitor GUI
- `i3lock xss-lock` — автоблокировка экрана

Это цель фазы 1 + фазы 4 (интеграция в ansible).

## Фаза 0 — подготовка (ещё в XFCE, ~1 час)

- Прочитать [`first-steps.md`](first-steps.md) и [`keybindings.md`](keybindings.md). Cheatsheet распечатать или открыть на втором экране.
- В XFCE потренировать то что пригодится в qtile: `xprop WM_CLASS`, `xrandr`, `pactl list sinks`, `xdotool`.
- Резервная копия `~/.config/xfce4/` (для отката если понадобится).
- В lightdm greeter выбрать «Qtile» для следующего входа, либо подтвердить что `autologin-session=qtile` актуален.

## Фаза 1 — первый день (2-4 часа)

**Цель:** не сбежать обратно в XFCE в первые 15 минут.

1. Boot → autologin → пустой экран — **это нормально**, не сломано.
2. `Super+Enter` должен открыть kitty. Если открывается xterm — сразу скопировать default config и поменять `terminal = "kitty"` (см. [config.md §1-2](config.md)).
3. Освоить **5 клавиш** и больше ничего:
   - `Super+Enter` — терминал
   - `Super+r` — запуск приложения
   - `Super+w` — закрыть окно
   - `Super+1..9` — переключение групп
   - `Super+Space` — смена layout
4. Поставить essentials-минимум:
   ```bash
   sudo apt install rofi picom feh dunst pavucontrol \
                    brightnessctl playerctl lxappearance arandr
   ```
5. В `~/.config/qtile/config.py` сразу забиндить (см. [config.md §4b-4d](config.md)):
   - `Super+r` → `rofi -show drun`
   - `Print` → `flameshot gui`
   - `XF86AudioRaiseVolume / Lower / Mute` → `pactl ...`
   - `XF86MonBrightnessUp/Down` → `brightnessctl`
6. Обои: `feh --bg-scale ~/Pictures/wallpaper.jpg` (позже — в autostart).

**Критерий успеха дня 1:** открываются браузер + терминал + редактор, раздражение не зашкаливает.

## Фаза 2 — первая неделя

**Цель:** догнать XFCE по удобству.

- **Autostart** (`~/.config/qtile/autostart.sh` + `@hook.subscribe.startup_once`): `nm-applet picom dunst feh xss-lock i3lock` — [config.md §4f](config.md), [essentials.md](essentials.md#сводный-autostartsh).
- **Group → app matches**: Firefox → группа 1, Code → 2, kitty → 3, Obsidian → 4, DBeaver → 5 — [config.md §4a](config.md). Узнать wm_class: `xprop WM_CLASS` → клик по окну.
- **Bar widgets** — минимум `GroupBox, WindowName, Systray, Volume, Battery, Clock` — [config.md §4e](config.md).
- **GTK-тема** через `lxappearance` (иначе диалоги Chrome/Obsidian — белый Adwaita, ломает глаз).
- **Multi-monitor** (если есть): `arandr` → «Save As» → скрипт → запуск в autostart.
- **Блокировка экрана**: `xss-lock -- i3lock -c 1d1f21 &` в autostart + ручной бинд (не `Super+l` — конфликт с фокусом вправо; использовать `Super+Shift+l`).

**Проверка недели:** руки уже идут на `Super+` рефлекторно, мышь почти не нужна для переключений между окнами/группами.

## Фаза 3 — вторая/третья неделя (тюнинг)

- Поэкспериментировать с layouts: `MonadTall`, `Columns`, `Bsp`, `Max`. Выбрать 2-3 favourites, остальные убрать из `layouts = [...]`.
- Floating rules для «неудобных» окон (`pavucontrol`, калькулятор, Zoom, диалоги GIMP) — см. [decisions.md: floating](decisions.md#q-мне-нужны-окна-windowed-floating-qtile-справится).
- **Scratchpad** — dropdown-терминал по хоткею (qtile `DropDown` / `ScratchPad`). Очень удобно для «подёргать команду».
- `dunst` стилизовать: шрифт, позиция (top-right), цвета, urgency levels (`~/.config/dunst/dunstrc`).
- Сценарии «проект»: скрипт который разом открывает нужный набор apps в заранее определённых группах (через `qtile cmd-obj`).

## Фаза 4 — месяц+ (интеграция в проект)

- **Закоммитить config** — вынести `~/.config/qtile/config.py` + `autostart.sh` в **chezmoi** (см. [`post-install/README.md`](../post-install/README.md)).
- **Добавить essentials в ansible** — создать задачу/тег `qtile-essentials` в `ansible/site.yml`, которая ставит пакеты из фазы 1 идемпотентно. Сейчас в preseed есть только `qtile kitty flameshot`; всё остальное — руками. Вынести в ansible, чтобы следующая переустановка системы сразу давала готовое окружение.
- Пополнить [`decisions.md`](decisions.md) тем что встретили при привыкании: какие layouts зашли, какие нет; какие приложения потребовали floating rules; какие биндинги переназначили и почему.

## Фаза 5 — advanced

- Свои `lazy.function` в Python для нестандартных действий (например, «открой URL из clipboard в Chrome и сохрани заголовок в Obsidian daily note»).
- [qtile-extras](https://github.com/elParaguayo/qtile-extras) — расширенные widgets: `GithubNotifications`, `UPowerWidget`, decorations для bar.
- **IPC** — управлять qtile снаружи через `qtile cmd-obj -o cmd -f ...` (автоматизация из скриптов / cron).
- Перейти с встроенного prompt на rofi для **всего**:
  - `rofi -show drun` — apps
  - `rofi -show window` — переключение между окнами
  - `greenclip` + rofi — clipboard history
  - rofi power menu (reboot/shutdown/suspend)
  - `rofimoji` — emoji picker

## Честные предупреждения

- **Первые 2-3 дня — боль.** Мышечная память от XFCE будет сбивать: руки тянутся к панели задач / tray / desktop. Это проходит за неделю.
- **Electron apps** (VS Code, Obsidian, Chrome) иногда странно взаимодействуют с tiling: непрошеные popups, диалоги не float'ятся. Готовьте floating rules по ходу.
- **Screen sharing** в Zoom/Meet под X11 работает. Под Wayland было бы хуже — мы остаёмся на X11 (см. [decisions.md — Wayland vs X11](decisions.md#q-wayland-vs-x11)).
- **GIMP / Inkscape** с floating toolboxes в tiling неудобны → `Match(wm_class='gimp')` в floating_layout.
- **`Super+l` конфликт** — в дефолте это фокус вправо; если хотите lock на `Super+l`, переназначьте фокус на arrow keys или другую букву.

## Критерии «готово» (через ~1 месяц)

- `config.py` лежит в chezmoi, переживает переустановку.
- Основные apps открываются в «своих» группах автоматически (matches).
- Bar показывает то что реально нужно (не больше).
- Биндинги на функциональные клавиши (volume/brightness/media) работают.
- Autostart настроен — после boot всё готово без ручных действий.
- Ansible-тег `qtile-essentials` ставит пакеты из фазы 1 на новой системе.
- XFCE удалён (или хотя бы — руки не тянутся его вернуть).

## Ссылки

- [first-steps.md](first-steps.md) — основы для первых 30 минут
- [keybindings.md](keybindings.md) — полная шпаргалка
- [config.md](config.md) — как править `config.py`
- [essentials.md](essentials.md) — rofi/picom/dunst и остальное
- [decisions.md](decisions.md) — Q&A и trade-offs
- [qtile official docs](https://docs.qtile.org)
