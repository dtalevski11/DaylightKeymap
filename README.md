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
- Clear every binding at once with **Clear all**

## The actions list

Every bindable action under the game's own headings — Movement Keys, Action
Bar, Targeting, Camera and the rest, in Blizzard's order, with your addons'
categories after them. It sits in the same window as the map.

- Search across every action, each one showing the key it is already on
- One button cycles what the list shows: **All actions**, **On two keys**,
  **Not bound**
- Expand or collapse every heading with one button
- Click an action, press the combo, done

## Bind on hover

Press **Bind on hover**, point at any button on a Daylight UI action bar, and
press the combo you want. It says what the key was doing before it took it.
Escape stops.

## Export and import

**Export** gives you every binding as plain text — select, copy, keep it in a
file. **Import** takes it back. Nothing is written until you press Save map,
so Discard changes undoes an import you did not want.

## Counters

| Counter | What it means |
|---|---|
| Used slots | Key-and-modifier combinations with something on them |
| Free slots | Key-and-modifier combinations still empty |
| Free keys | Keys with nothing on any layer at all |
| Actions bound | How much of the game you have bound, out of everything available |
| On two keys | Actions reachable from two keys, WoW's limit |

Hover any of them for an explanation. The free-keys counter names the keys it found.

---

## Getting started

Open **Daylight UI options → Plugins → Keymap**, or type:

| Command | Does |
|---|---|
| `/dui keymap` | Opens the map |
| `/dui bindhover` | Starts bind on hover |
| `/dui keymapexport` | Copy your bindings out as text |
| `/dui keymapimport` | Paste bindings back in |
| `/dui keymapfix` | Restores left and right click to the game's defaults |
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
