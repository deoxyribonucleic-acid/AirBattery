# Widget appearance

AirBattery keeps its SwiftUI background in `containerBackground(for: .widget)`.
On macOS 26+, `WidgetGlassBackground.m` requests the system material through
private WidgetKit descriptor properties: transparent, removable, vibrant content,
and preferred background style 2. It targets only the four existing battery kinds,
in both Debug and Release. The host determines the final material; the app adds
no custom blur, glass overlay, or corner mask. Earlier macOS versions retain the
adaptive background asset and do not install the hook.

The runtime integration checks the callback and setter signatures, preserves the
original archive fields, and returns the original result if rebuilding fails.
These checks handle detectable incompatibilities; they cannot guarantee safety
against every future private framework change. This is a custom-build integration,
not a supported public WidgetKit API.

Battery progress belongs to the accent group. In full-color mode it retains
battery status colors; in accented/vibrant modes it uses a primary foreground
for the host to recolor. Device glyphs use template alpha and desaturated image
rendering. Text and charging symbols remain in the default group. The progress
ring's black shadow was removed to avoid dark halos in flattened rendering.
Older macOS versions use availability-guarded fallbacks.

## Build

With Xcode 27 (which no longer accepts macOS 11 as a deployment target):

```sh
xcodebuild -project AirBattery.xcodeproj -scheme AirBattery \
  -configuration Debug -derivedDataPath /private/tmp/AirBattery-Glass-Build \
  CODE_SIGNING_ALLOWED=NO MACOSX_DEPLOYMENT_TARGET=12.0 build
```

This override is only for local build validation. The project's deployment
settings are unchanged. The unsigned build is not an installed release.

## Visual verification

`BatteryAppearancePreviews` in `widget/widgetBundle.swift` provides deterministic
content for full-color, accented, vibrant, and dark previews. Preview environment
overrides exercise content rendering; they do not reproduce the desktop host's
wallpaper-dependent glass compositing.

On macOS 26 or newer, use a signed local build in the desktop widget gallery:

- Compare AirBattery beside Apple's Batteries widget in the system's default,
  clear, and tinted appearances, with both light and dark wallpapers.
- Check every gallery style: percentage rings, single-device, double-row,
  no-percentage rings, and large lists.
- Check low battery, charging, full battery, missing devices, and app-not-running
  states. Icons, values, and charging symbols should remain readable.
- Check desktop and Notification Center, including reduced transparency and
  increased contrast accessibility settings.

On September 17, the user tested the three experimental widgets in Light mode
on the current macOS 27 installation: Control was white, Clear was fully
transparent, and Blur used the system Liquid Glass material (not a simple
Gaussian blur). This validates background style 2 on that system. The production
integration applies that configuration to all four existing battery kinds and
removes the three Glass Test entries. Other OS versions and the integrated
variants still need visual checks; tests use mock descriptors, not the desktop host.

Manual acceptance after updating the local test app:

1. Remove the obsolete Glass Test widgets from the desktop.
2. Close and reopen the widget gallery and add the ordinary AirBattery widgets.
3. In Light mode, compare small, medium, list, and no-percentage variants with
   the previously verified Blur appearance. Re-add an existing widget if stale.
4. Check status colors, charging glyphs, legibility, and battery refresh.

Archive regression check:

```sh
xcrun clang -fobjc-arc -framework Foundation Tests/widget_glass_regressions.m \
  -o /private/tmp/airbattery-widget-glass-tests
/private/tmp/airbattery-widget-glass-tests
```

Implementation reference: https://github.com/pookjw/ClearAndBlurredWidgets

Reference: https://developer.apple.com/documentation/widgetkit/optimizing-your-widget-for-accented-rendering-mode-and-liquid-glass

Local ad-hoc Release testing additionally uses `ENABLE_HARDENED_RUNTIME=NO`
to avoid the Sparkle framework Team ID mismatch at launch. This is a command-line
override only; distribution signing and project hardened runtime settings are unchanged.

## Appearance branches

The gallery exposes Liquid Glass and Background variants of every existing layout.
Glass preserves the existing widget kinds. Background uses a `.background` suffix,
paints the adaptive background asset, and is excluded from the descriptor hook.
There are no Glass Test / Control / Clear / Blur gallery entries. WidgetKit may
still adapt either appearance to the user's system tint settings.
The local branch-comparison build uses build number 164 to refresh registration.
