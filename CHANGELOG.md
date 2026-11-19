# Changelog

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
