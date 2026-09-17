# App appearance

The app's settings, menu-bar controls, Dock panel, and battery-alert editor share
an updated native appearance. Widget changes are described separately in
`widget-appearance.md`.

- Settings use NavigationSplitView on macOS 13+, with NavigationView fallback.
  The window has a 720 × 540 minimum, a flexible sidebar, and scrollable pages.
- Shared setting rows have a 28-point minimum height instead of a fixed 16 points.
  Switches use native small control sizing instead of a scaling transform.
  Quiet rounded content groups separate sections without adding layered glass.
- Menu-bar header buttons have larger hit targets and accessibility labels.
  The NSPopover retains its system background. Device and Nearcast rows use
  semantic colors and softer group boundaries.
- The custom Dock panel and battery-alert window use regular Liquid Glass on
  macOS 26+, with NSVisualEffectView fallback and an opaque background when
  Reduce Transparency is enabled.
- Dock and alert window heights are measured from hosted content instead of
  estimated from fixed row counts. Alert Save is prominent; Escape cancels.
- About, standard system menus, sheets, and native battery indicators retain
  their system presentation. These appearance changes preserve the existing alert settings.

## Validation

Full Debug build passed with Xcode 27 using the temporary
`MACOSX_DEPLOYMENT_TARGET=12.0` override and `CODE_SIGNING_ALLOWED=NO`.
Project deployment settings are unchanged. See `widget-appearance.md` for the
build command. A signed local test build has since been launched. Full app-panel visual
acceptance remains pending; the user confirmed the widget material experiment.

Manual acceptance with a signed build:

1. Open every settings page; resize the window and scroll to the bottom. Check
   the blocklist viewport and Debug page, including hiding the selected Debug tab.
2. Open the menu-bar popover and Dock panel with no devices, multiple devices,
   hidden devices, and Nearcast enabled. Confirm all rows and header buttons fit.
3. Open an alert for a long device name. Check Save, Delete, Escape, sound toggles,
   keyboard focus, and both sliders without changing their original constraints.
4. Compare light/dark appearances and Reduce Transparency. Confirm panel edges,
   label contrast, focus indicators, and that controls aren't clipped.

Reference: https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views

## Menu-bar battery options

The icon styles are named Classic macOS and Modern macOS / iOS. The stored
`iosBatteryStyle` key remains unchanged to preserve existing preferences.
Modern battery fill uses only the SVG body (65.6 of 73.6 source units); the
terminal stays at a fixed opacity. The hide-percentage threshold supports
Always (-1), Never (100), and existing percentage thresholds. Always hides
both inside and outside text, including at 0%, and uses the compact status width.
