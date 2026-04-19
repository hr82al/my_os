---
tags: [qtile, keybindings, cheatsheet]
---

# Keybindings — шпаргалка

← [qtile](README.md) | [Wiki Index](../README.md)

**Mod** = `Super` (Windows клавиша). Все keybindings для **дефолтного**
qtile config. Ваш `config.py` может их изменить — см. [config.md](config.md).

## Запуск и выход

| Клавиши | Действие |
|---|---|
| `Super + Return` | Открыть терминал (kitty или xterm) |
| `Super + r` | Prompt запуска приложения (типы имя, Tab, Enter) |
| `Super + Ctrl + r` | Перезагрузить qtile (после правки config.py) |
| `Super + Ctrl + q` | Выйти из qtile (logout в lightdm) |

## Фокус между окнами

| Клавиши | Действие |
|---|---|
| `Super + h` | Влево |
| `Super + j` | Вниз / следующее |
| `Super + k` | Вверх / предыдущее |
| `Super + l` | Вправо |
| `Super + Tab` | Переключить layout |

## Перемещение окна

| Клавиши | Действие |
|---|---|
| `Super + Shift + h` | Переместить влево |
| `Super + Shift + j` | Вниз |
| `Super + Shift + k` | Вверх |
| `Super + Shift + l` | Вправо |

## Размер окна

| Клавиши | Действие |
|---|---|
| `Super + Ctrl + h` | Grow left |
| `Super + Ctrl + j` | Grow down |
| `Super + Ctrl + k` | Grow up |
| `Super + Ctrl + l` | Grow right |
| `Super + n` | Normalize (ресет размеров) |

## Управление окном

| Клавиши | Действие |
|---|---|
| `Super + w` | Закрыть окно (kill) |
| `Super + Space` | Следующий layout |
| `Super + Shift + Return` | Split (разделить layout) |
| `Super + f` | Toggle fullscreen (в некоторых layouts) |

## Groups (virtual desktops)

| Клавиши | Действие |
|---|---|
| `Super + 1..9` | Переключиться на группу 1..9 |
| `Super + Shift + 1..9` | Перенести текущее окно в группу 1..9 |

## Спец-клавиши (если есть функциональные кнопки)

Эти биндинги **не** входят в default qtile — нужно добавить в config.py (см. [essentials.md](essentials.md)):

| Клавиша | Что должно делать | Реализация |
|---|---|---|
| Volume Up/Down | Громкость ± | `pactl set-sink-volume @DEFAULT_SINK@ ±5%` |
| Mute | Вкл/выкл звук | `pactl set-sink-mute @DEFAULT_SINK@ toggle` |
| Brightness Up/Down | Яркость ± | `brightnessctl s +5%` / `-5%` |
| Print Screen | Скриншот | `flameshot gui` |

## Терминологический словарь

| qtile | DE equivalent |
|---|---|
| **Group** | Virtual desktop / Workspace |
| **Layout** | Window arrangement mode |
| **Bar** | Taskbar / Panel |
| **Widget** | Bar item (clock, battery, etc.) |
| **Floating window** | Regular DE window (movable by mouse) |
| **Tiled window** | Auto-arranged window |
| **Screen** | Physical monitor |

## Быстрые рецепты

### Открыть 3 окна в колонках
```
Super+Enter         # kitty 1
Super+Enter         # kitty 2 (экран пополам)
Super+Enter         # kitty 3 (2/3 и 1/3 или 3 колонки)
Super+l             # фокус на правое окно
```

### Переместить окно на другой монитор
Нужно добавить в config.py keybindings для multi-screen. По умолчанию
команды типа `lazy.next_screen()` и `lazy.window.toscreen()`. Binding —
часто `Super+period/comma`.

### Разложить окна и «закрепить» — save
qtile **не сохраняет layout между сессиями** в дефолтном конфиге.
При следующем login состояние будет чистое.

Сохранить «восстановимое» состояние:
- Startup-script: в `~/.config/qtile/autostart.sh` запускать все нужные apps
- Каждое приложение «прикрепить» к группе через `Match` в `config.py` (см. [config.md](config.md))

### Как узнать имя окна для правил

```sh
# В терминале
xprop WM_CLASS
# → кликнуть на окно → покажет его class ("firefox", "kitty", etc.)
```

Дальше в config.py:
```python
from libqtile.config import Match
groups = [
    Group("1", matches=[Match(wm_class="firefox")]),
    ...
]
```

## Ссылки

- [first-steps.md](first-steps.md) — гайд с объяснениями
- [config.md](config.md) — как поменять биндинги
- qtile keybindings docs: [docs.qtile.org/en/stable/manual/config/keys.html](https://docs.qtile.org/en/stable/manual/config/keys.html)
