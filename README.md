# Keymap (DaylightUI Plugin)

**Stop guessing which keys are free.**

WoW is the game of a thousand keybinds, and you usually find out a key is taken only when something else quietly stops working. Keymap draws your actual keyboard and mouse, colours every key by how crowded it is, and lets you rebind without leaving the map.

> **Requires [Daylight UI](https://www.curseforge.com/wow/addons/daylightui) 1.5 or newer.** This is a Daylight UI plugin and will not load on its own.

[Download on CurseForge](https://www.curseforge.com/wow/addons/keymap-daylightui-plugin)

---

## The map

- Your keyboard and mouse drawn to scale — ANSI or ISO, full-size, tenkeyless or 60%, and 3 to 12 mouse buttons
- Every key coloured by how many bindings sit on it, five steps from empty to full, in Daylight UI's own palette
- A count on each key showing how many modifier layers are taken
- **Show free only** — everything bound drops away and the free keys light up
- Filter to a single layer: no modifier, Shift, Ctrl or Alt
- Keys the game will not bind are greyed out, so they never pad the free count: Ctrl, Shift, Alt, Win, Fn, Menu, and the left and right mouse buttons

## Rebinding

- Click a key to see all its modifier slots
- Click a slot, then click an action, to bind it
- Right-click a slot to move its binding to another key; the **x** clears it
- Search every bindable action, each one showing the key it is already on
- Drag a button off a Daylight UI action bar straight onto a key

## The keybindings list

A second window with every bindable action under the game's own headings — Movement Keys, Action Bar, Targeting, Camera and the rest, in Blizzard's order, with your addons' categories after them.

- Headings open and close, with expand and collapse all
- Search across every action
- Click an action, press the combo, done

## Counters

| Counter | What it means |
|---|---|
| Bindings | How many sit on the keys drawn |
| Free keys | Keys with nothing on any layer |
| Free slots | Every empty key-and-modifier combination |
| Actions with a key | How much of the game you have bound, out of everything available |

Hover any of them for an explanation. The free-keys counter names the keys it found.

---

## Getting started

Open **Daylight UI options → Plugins → Keymap**, or type:

| Command | Does |
|---|---|
| `/dui keymap` | Opens the map |
| `/dui keybinds` | Opens the keybindings list |
| `/dui keymapraw` | Prints the raw binding data, for bug reports |

## Installing by hand

1. Download the latest release
2. Extract it so you have `Interface\AddOns\DaylightKeymap\DaylightKeymap.toc`
3. Restart the game

## Notes

- Rebinding is blocked during combat. That is the game's rule, not the addon's — the map stays readable, the changes wait.
- Bindings save to your account by default; per-character is a setting.
- Nothing is written until you press **Save map**, or close the window.

## Reporting a problem

[Open an issue](https://github.com/dtalevski11/DaylightKeymap/issues) with the error text, and the output of `/dui keymapraw` if a category or key name looks wrong.

## Licence

MIT. See [LICENSE](LICENSE).

Built on [Daylight UI](https://daylightui.com). Contains none of Daylight UI's code, art or text.
