# Hover Menu Preview

macOS hover prototype. It places a small black pill at the top of the screen and opens a dark preview panel when the mouse hovers over the text.

## Run

```bash
./script/build_and_run.sh
```

Use `./script/build_and_run.sh --verify` to build, launch, and confirm the process exists.

## Project path

```text
/Users/shotaro/code/share/hover-menu-preview
```

## Implementation note

SwiftUI's `MenuBarExtra` is mainly click-driven and only appears in the standard right-side menu bar area. This prototype uses AppKit `NSPanel` windows plus SwiftUI hover handlers so the trigger can sit at the top center like the reference recording.

## Notch sizing note

macOS screen layout values are in points, not physical pixels. On the current built-in Retina display, the measured notch-related values were:

```text
safeAreaInsets.top = 32pt
backingScaleFactor = 2.0
1px = 0.5pt
```

So a true 1-pixel compensation would be `safeAreaInsets.top + 0.5pt`. In this prototype, `33pt` looked visually correct, which means the chosen adjustment is `safeAreaInsets.top + 1pt`, or +2 physical pixels on a 2x Retina screen.

Keep this as a visual fit correction, not a universal notch rule. If the app later needs to adapt across Mac models and external displays, compute from `NSScreen.safeAreaInsets.top`, `backingScaleFactor`, and `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` instead of hard-coding the height.

The current prototype uses `auxiliaryTopLeftArea` and `auxiliaryTopRightArea` to derive the horizontal notch span. On the current built-in display, the measured notch span is:

```text
notch x = 663pt ... 848pt
notch width = 185pt
left handle width = 54pt
pill frame = x: 609pt, width: 239pt
```

This makes the visible left handle end exactly at the notch left edge, while the black base continues behind the notch.
