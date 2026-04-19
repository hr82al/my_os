---
tags: [qtile, decisions, qa]
---

# qtile — Decisions & Q&A

← [qtile](README.md) | [Wiki Index](../README.md)

## Q: Почему qtile, а не KDE / GNOME / Cinnamon?

**Trade-off:**
| | Qtile (tiling WM) | KDE / GNOME (full DE) |
|---|---|---|
| Размер установки | ~150 MB | ~2-3 GB |
| RAM idle | ~200 MB | ~800-1500 MB |
| Learning curve | Высокая | Низкая |
| Customization | Python config, полный контроль | GUI settings, ограничения |
| Клавиатурный workflow | Идеальный | OK |
| Мышиный workflow | Подходит но не родной | Идеальный |
| Диалоги приложений | Отлично (floating rules) | Отлично |
| Multi-monitor | Конфиг руками | GUI из коробки |

**Решение:** qtile — для dev-машины с клавиатурным workflow.
User coming from KDE → будет ломка первую неделю, потом прирост скорости.

Альтернативы tiling WM:
- **i3** — C, конфиг i3-специфичный dsl. Проще qtile для начинающих.
- **sway** — Wayland. Будущее, но под Wayland всё ещё есть проблемы (Chrome под Wayland с проброской через XWayland, электрон-апы).
- **dwm/awesomewm** — Lua / C. Более geek.
- **Hyprland** — Wayland, красивый, но молодой.

**Почему qtile выбран:**
- Python config → легко писать свои функции/правила
- Зрелый проект (10+ лет)
- Сообщество активное
- X11 — стабильно со всеми приложениями (важно для Electron apps, Docker GUI и т.д.)

## Q: Почему lightdm, а не sddm/gdm?

**Trade-off:**
- **lightdm** — легкий, конфигурируемый через file, autologin простой
- **sddm** — KDE-шный, больше зависимостей
- **gdm** — GNOME-шный, тянет кучу gnome-*
- **xinit/startx** без DM — ещё легче, но autologin сложнее

**Решение:** lightdm. Autologin настраивается одним файлом
`/etc/lightdm/lightdm.conf.d/50-autologin.conf` (см. [preseed/late-command.md](../preseed/late-command.md)).

## Q: Wayland vs X11?

**X11** плюсы:
- Работает с **всеми** приложениями (включая Chromium-based, Electron, NVIDIA-драйверы без проблем)
- qtile на X11 — стабильная версия
- Тулы типа `xdotool`, `xrandr`, `xprop` — зрелые

**X11** минусы:
- Считается «устаревшим» (разработка слабая, хотя поддерживается)
- Screen tearing без compositor
- Security model старая (любая программа может читать клавиатуру других)

**Wayland** плюсы: современный, безопаснее, без tearing out-of-the-box.
**Wayland** минусы: Chrome + VSCode + Electron часто работают плохо; NVIDIA драйверы проблемные; qtile под Wayland — **экспериментально**, не рекомендую.

**Решение:** X11 пока. Wayland — через 2-3 года возможно переход.

## Q: Почему kitty, а не alacritty / wezterm / tmux?

- **kitty** — GPU-accelerated, support tabs/windows в одном окне, image protocol (могут показывать картинки, Jupyter).
- **alacritty** — минималистичный, быстрый, но без tabs (использовать с tmux).
- **wezterm** — Lua config, все фичи, но тяжеловат.
- **urxvt / xterm** — легаси, не рекомендую для современного workflow.

**Решение: kitty.** Полный набор фич + GPU + zero-config работает из коробки.

## Q: Мне нужны окна windowed (floating)? Qtile справится?

Да. Qtile имеет `floating_layout` — окна по rules становятся floating
(драггаются мышью как в DE). Диалоги по умолчанию floating.

Для приложений которые хочется всегда floating (GIMP, pavucontrol, калькулятор):
```python
floating_layout = layout.Floating(float_rules=[
    *layout.Floating.default_float_rules,
    Match(wm_class='pavucontrol'),
    Match(wm_class='gimp'),
    Match(title='Calculator'),
])
```

Также можно переключать на-лету (keybinding `Super+t` в некоторых конфигах — toggle floating).

## Q: Как быть с multi-monitor?

qtile auto-detect экранов. Настройка в config.py:
```python
screens = [
    Screen(top=bar.Bar([...], 24)),   # первый монитор
    Screen(top=bar.Bar([...], 24)),   # второй
]
```

Перенос окна между мониторами:
```python
Key([mod], "period", lazy.next_screen()),
Key([mod], "comma",  lazy.prev_screen()),
```

Раскладка мониторов (left-of, right-of, resolution) — через `xrandr` или
GUI-обёртка `arandr`. Сохранить через `arandr` → скрипт → запуск в autostart.

## Q: Можно ли откатиться на KDE если не понравится?

Да, легко. В любой момент:
```bash
sudo apt install kde-plasma-desktop
sudo systemctl set-default graphical.target
# при следующем logout в lightdm — выбрать KDE session
```

qtile остаётся в системе. Можно переключаться между session'ами в lightdm.

Но это ~2 GB download, обратного пути к минималистичному qtile будет
хотеться меньше — раз уже стоит KDE, lazy мышь :)

## Q: Куда девать «иконки рабочего стола»?

В tiling WM концепция рабочего стола отсутствует. Типичные решения:
- **Без иконок** — запускать apps через rofi или keybindings. Самый qtile-way.
- **nautilus-desktop / pcmanfm --desktop** — добавляют desktop с иконками.
  Но ломают эстетику WM.
- **variety / nitrogen** — только обои, без иконок.

Мой совет: привыкнуть к rofi. 3-4 дня и станет роднее.

## Q: Где искать помощь?

- `/usr/share/doc/qtile/` — встроенные примеры
- [docs.qtile.org](https://docs.qtile.org)
- `#qtile` на Libera Chat IRC
- [r/qtile](https://reddit.com/r/qtile), [r/unixporn](https://reddit.com/r/unixporn)
- GitHub: [qtile/qtile](https://github.com/qtile/qtile)

## Q: Screenshot — `kde-spectacle` или `flameshot`?

**Контекст:** пользователь привык к `spectacle` из KDE. На qtile-системе без KDE.

**Числа:**

| | `kde-spectacle` | `flameshot` | `maim` (CLI) |
|---|---:|---:|---:|
| Сам пакет | 6.3 MB | 3.4 MB | 0.3 MB |
| Зависимости | KF6 Frameworks + Qt6 QML + KIO + Kirigami + OpenCV + 30+ libkf6-* | Qt5 widgets + svg | ничего особого |
| **Total install** | **~300–500 MB** | **~50–100 MB** | **~5 MB** |

**Spectacle тянет полный runtime KDE Frameworks 6 + Qt6 QML**, которого в qtile-системе нет. 400 MB «параллельной KDE-экосистемы» ради одного приложения.

**Flameshot** покрывает 90% сценариев (region, annotations, text/arrows, copy, save/upload) в 5-10× меньшем объёме.

**Решение: flameshot.** Если захочется spectacle — `sudo apt install kde-spectacle` поставит позже (добавит те же 400 MB). Не жечь место превентивно.

## Q: Qtile стек «жирный»?

**Нет.** Числа для нашей инсталляции:

| Категория | Размер |
|---|---:|
| qtile + xorg + lightdm + kitty | ~250 MB |
| Desktop apps (VS Code, DBeaver, Chrome, Obsidian, Postman, Redis Insight, LibreOffice full) | ~5 GB |
| Dev база (build-essential, git, docker-ce, ffmpeg, gimp, inkscape) | ~1-2 GB |
| **Итого** | **~6-7 GB** |

**Qtile-специфичная нагрузка — только ~250 MB** (сам WM + display manager + xorg + terminal). Всё остальное нужно в любом DE. KDE Plasma поверх этих же приложений дал бы +2-3 GB на DE-компоненты.

**Qtile экономит**, не раздувает.

**Что можно урезать если мало места:**
- LibreOffice full (1 GB) → `libreoffice-writer libreoffice-calc` (~400 MB)
- Chrome **или** Firefox (оставить один) → ~400 MB
- `--skip-tags postman,redisinsight,obsidian` в ansible если не используете

## Ссылки

- [first-steps.md](first-steps.md)
- [config.md](config.md)
- [essentials.md](essentials.md)
