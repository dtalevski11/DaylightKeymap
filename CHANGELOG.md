# Changelog

## 1.1.1

- Search the keymap by key as well as by name. Type `shift-f` for what is on
  that combination, or `shift` on its own for everything on that layer. One
  field, no mode to switch: which question you asked is read off the shape of
  what you typed.
- Bind on hover translates the name a keypress gives into the name the
  binding table uses. Punctuation keys are the ones that disagree, which is
  why a binding put on `;` or `'` this way never appeared on the map, and did
  nothing in game either.
- Bind on hover now says so when a binding lands on a key the board does not
  draw, naming both the key and what the keypress called it. That failure
  used to look exactly like a success.
- Import split a line on the first `=` rather than the last, so a binding on
  the `=` key (`CTRL-==MASTERVOLUMEUP`) came back pointing at a key that does
  not exist. Export was never affected.
- The tooltip that appeared over the title bar on the way to dragging the
  window is gone.

## 1.1.0

- The separate Keybindings window is gone. Everything it did now lives in the
  Keymap, in one window.
- **Bind on hover**: point at a button on an action bar, press a combo, done.
  It tells you what the key was doing before it took it.
- Click an action first, then press the key you want it on.
- The actions filter cycles: All actions, On two keys, Not bound. The second
  one answers "which of these is bound twice?" in a click.
- **Export** and **Import**: copy every binding out as plain text, paste a set
  back in. Nothing saves until you press Save map, so Discard undoes an import.
- One Expand all button that collapses on a second press, instead of two.
- Clear all, on the map.
- Middle mouse button is legible, and labelled on the button rather than under
  the mouse.

## 1.0.4

- Hovering an action in the list names every key it is on, rather than the
  tag's "M5 +1" shorthand.
- New See all button beside the search box: browse every action under its own
  heading, open a heading, pick an action, without typing anything.
- Counters renamed and explained. Slots used and Free slots are two halves of
  the same board and always add up; Actions bound counts something else
  entirely, which is why it never matches.
- Clear all is a real button on each row of the keybindings list now. It used
  to appear only on hover and vanish as you reached for it.
- Thumb buttons are squares in two columns, labelled M4 upward, so a
  twelve-button mouse no longer runs over the legend.
- The selected key is no longer printed twice when its name is already short.
- Author credit now reads KillaBunny.
- The website link on the Plugins page points at the repository instead of a
  placeholder.

## 1.0.3

- Left and right click can no longer be captured as a binding. A stray click
  while the map was waiting for a combo could put an action on BUTTON1 and
  take over clicking entirely.
- Those two buttons are inert on the map now, greyed and unresponsive like the
  modifier keys. They are reserved by the game for looking, moving and
  selecting, so nothing else can take them.
- Clearing one puts the game's own action back rather than leaving it doing
  nothing at all.
- New `/dui keymapfix` restores both to the game's defaults, for anyone whose
  mouse was already left in that state.
- Every greyed key says why it is greyed on hover, modifiers included.

## 1.0.2

- Left and right click can no longer be captured as a binding. A stray click
  while the map was waiting for a combo could put an action on BUTTON1 and
  take over clicking entirely.
- Anything already stuck on left or right click is now visible on the map and
  can be cleared: the button shows what is on it and opens like any other key.
- Assigning to left or right click is refused on every route in, including
  dragging an action bar button onto them.

## 1.0.0

First public release.

- Visual map of your keyboard and mouse, colour-coded by how many bindings sit on each key
- ANSI and ISO layouts; full-size, tenkeyless and 60%; 3 to 12 mouse buttons
- Show free only, and a per-layer filter for Shift, Ctrl and Alt
- Four or eight modifier layers per key
- Click a key to see its slots, then assign, move or clear a binding
- Search every bindable action, with its current key shown beside it
- Drag a button off a Daylight UI action bar onto a key
- Separate keybindings list using the game's own categories, collapsible and searchable
- Counters for bindings, free keys, free slots and actions bound
- Account-wide or per-character bindings
- Unbindable keys greyed out rather than counted as free
- Follows your Daylight UI accent colour and font

Requires Daylight UI 1.5 or newer.
