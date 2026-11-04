# Locating widgets: AT-SPI and DOM rects

`scripts/ui.py` reads the accessibility tree (AT-SPI) and turns widget positions into screen pixels. It then clicks with ydotool. Run it with `/usr/bin/python3`, because the Nix python has no `gi`. Wrap each call in `timeout 30`.

```sh
ui() { timeout 30 /usr/bin/python3 -W ignore <skill-dir>/scripts/ui.py "$@"; }
ui apps                                         # accessible apps (soffice, GTK/Qt apps)
ui --app soffice --window Calc tree --named     # showing widgets: center, size, role, name, = text, states
ui --app soffice find '^Bold$'                  # match names (regex); --role 'toggle button'
ui --app soffice click '^OK$' --role button     # click the center of match --nth N (default 0)
ui --app soffice focus                          # focused widget and its text
ui --app soffice text 'LibreOffice Document' --role 'document text' --attrs size,weight
ui --app soffice --window Calc cell C5 [--click]  # spreadsheet cell: position and value
ui --app soffice do 'Character\.\.\.' --role 'menu item' --all   # AT-SPI action, NOT real input
ui move X Y / ui clickat X Y [--button right]   # screen pixels, scale-corrected
```

Common role names are `button`, `toggle button`, `menu`, `menu item`, `combo box`, `text`, `page tab`, `table cell`, `paragraph` and `document text`. States appear as `focused`, `checked` and `selected`. Use these values for assertions, for example `ui find 'Formatting Marks'` then check for `checked`.

## Window origin (`UI_ORIGIN`)

On Wayland a client does not know where its window is on screen. `ui.py` therefore needs the window's top-left screen pixel in `UI_ORIGIN=x,y`. Set it for each window, and use `--window` to limit the walk to that window. Get exact window and dialog titles from `ui apps`:

| Window | `UI_ORIGIN` on eDP-1 |
| --- | --- |
| Tiled master or only window (default) | `0,18` (below the 18 px bar) |
| Tiled stack window | `<master width>,18`. Master width is `mfact × 1920` (config 0.6, changed at runtime by Super+H/L; it was 1250 on 2026-10-12). Read it from the screenshot. |
| Floating window or dialog | `384,210`: Reach sizes it 0.6 × 0.65 and centres it on the whole output, bar included (`(1920−1152)/2`, `(1200−780)/2`). Verified with the Character dialog. |

To check the origin, run `ui find '^Close$'` and compare the result with the close button in a screenshot. A correct origin is within about 2 px. If the result is off by a constant amount, fix the origin. Do not adjust each click.

## Limits found in LibreOffice 25.8 (gtk3)

- **Popup menus and dropdown lists use their own surface**, so their item coordinates are wrong. Open a menu with Alt+letter or a click on its title, then use arrows and Enter, or the mnemonic letter. You can also take a screenshot and use `clickat`.
- **The menu bar appears twice.** The copy under `root pane` reports the toolbar row. Use the first match, which is the header-bar copy, or use the keyboard.
- **`focused` can be stale on toolbar buttons** after a click. Trust the focused `paragraph`, `table` or text field.
- **Many dialog fields have no name.** Find them by position next to their label in `tree`, for example `label 'Size:'` at y=660 and `text '' = '12 pt'` at y=660. Alt+mnemonic also works in dialogs.
- **A Calc sheet reports 2³¹ children.** `ui.py` does not walk any node with more than 2000 children. Use `cell REF` instead. The cell value is the displayed text, not the formula. To read a formula, select the cell and read the formula bar.
- **Writer keeps text in `paragraph` children.** `text` joins them. `--attrs` prints formatting runs (`size`, `weight`, `style`, `underline`, `family-name`, `fg-color`), which shows whether formatting was really applied.

## Obsidian and Electron

Electron apps here do not expose an AT-SPI tree. Obsidian was not listed by `ui apps`. Chromium-based apps expose the tree only when they are started with `--force-renderer-accessibility`. This is untested here and requires restarting the app. Use DOM rects instead:

```sh
obsidian eval code="window.__m=JSON.stringify((r=>({x:r.x+r.width/2,y:r.y+r.height/2,dpr:devicePixelRatio}))(document.querySelector('.workspace-tab-header.is-active').getBoundingClientRect()))"
obsidian eval code="window.__m"
```

Calculate the screen position as `origin + css × devicePixelRatio`. Obsidian's zoom gave `devicePixelRatio = 0.833` on 2026-10-12, with a viewport of 1497×1418 CSS px for a 1247 px wide window. Obsidian is frameless, so CSS (0,0) is the window's top-left corner. Its origin is that corner's screen position, the same as for any tiled window. Obsidian opens on desktop 2; as the only window there it is the master, so its origin is `0,18`.

## When neither applies

For apps without accessibility (games, canvas UIs, some Qt or Electron apps), use screenshot pixels and `ui clickat`. OCR is not installed. If text-finding becomes a frequent need, `tesseract` would be worth installing. Ask Miles first.
