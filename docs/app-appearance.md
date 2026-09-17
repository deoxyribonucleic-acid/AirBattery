# App appearance

The app's settings, menu-bar controls, Dock panel, and battery-alert editor share
an updated native appearance. Widget changes are described separately in
`widget-appearance.md`.

- The main window uses an AppKit NSSplitViewController with SwiftUI sidebar and
  detail hosts, following the local native-via implementation. A unified native
  toolbar owns the accessible sidebar toggle and selected-page title. The window
  starts at 940 × 680 with a 740 × 560 minimum and preserves its saved frame.
- The Devices landing page shows adaptive battery cards, charge indication and
  last-update ages. It reads existing snapshots on the existing UI refresh signal;
  it never starts another scanner. Settings remain available in the sidebar.
- Section cards use 18-point corners and 20-point insets with the shared glass
  surface. Content uses 28-point page insets. Reduce Transparency supplies an
  opaque fallback; page animations honor Reduce Motion.
- Shared setting rows have a 28-point minimum height instead of a fixed 16 points.
  Switches use native small control sizing instead of a scaling transform.
  Native glass section cards share spacing across the settings pages.
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

The main window enables `fullSizeContentView` with full-height layout on the
sidebar only. AppKit keeps the detail toolbar background; a tracking separator
explicitly follows divider 0. The toolbar uses a native sidebar button and a
plain page title after the divider, avoiding nested SwiftUI glass buttons.
Manual checks: sidebar material reaches the traffic lights, header content stays
below the controls, detail title stays readable, and collapse/resize/reopen keep
both toolbar sections aligned.
