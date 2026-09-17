# Upstream fixes — 2026-09-16

This pass implements the prioritized defect work from the upstream review. It
preserves the local Liquid Glass work. Community PRs were used as references;
the patches were not merged wholesale.

| Reference | Implemented change | Validation boundary |
| --- | --- | --- |
| #175 | One reusable settings window, shared by toolbar, Dock menu and Cmd+comma. Removed menu-index dispatch. | Builds; window activation/reopen needs desktop acceptance. |
| #159 / #200 | Clear hover indices on row/list/panel exit. Login toggle now calls the existing SMAppService path and only saves on success; launch state reads registration status instead of checking whether the helper happens to be running. | Builds; login approval/reboot needs manual validation. |
| #78 / #208 | Snoozing one device continues the alert loop instead of returning from it. | Regression checks for low and full alerts across three devices. |
| #124 / #206 | Atomic device upserts and visibility changes, immutable snapshots under NSLock, synchronized Bluetooth cache and internal battery status. Reconnects snapshot names and coalesce before serial background refresh; no delayed capture of IOBluetoothDevice. | 12,000 concurrent model upserts with Thread Sanitizer; not a whole-app concurrency proof. |
| #91 / #208 | AppDelegate owns alert, iDevice, widget-data, widget-reload and Nearcast timers. Work no longer depends on Dock view subscriptions. Overlapping iDevice/Pencil scans are skipped. | Builds; long-running menu-bar-only behavior needs acceptance. |
| #137 / #191 | Typed Swift log parser handles names without PID, PrNm, quoted names and known legacy/Tahoe GATT records. GATT identity must resolve uniquely; ambiguous unkeyed multi-device batches are rejected. Uses cached profiler JSON instead of spawning another profiler per log pass. | Recorded-format fixtures: valid single device, malformed values, special names and interleaved identities. Hardware support is not universal. |
| #132 / #178 / #208 | BLE probes have one in-flight connection per UUID, deadlines, retry backoff, and explicit disconnect after reads. Confirmed devices without a battery service/characteristic are remembered for this launch; transient failures aren't marked unsupported. | Compiles; actual sleep/audio/paired-device behavior needs hardware acceptance. |
| #76 / #106 | Validate both Apple manufacturer bytes and packet sizes; reject invalid decoded levels instead of inventing values. Device store rejects out-of-range battery data. | Parser/store tests; raw BLE hardware validation remains. |
| #149 | AirPods child entries inherit the base name's allow/block rule. | Regression checked. |
| #202 / #166 | MacBook Neo fallback icon and lowercase AirPods 4 ANC model lookup. | Builds; new hardware not available in this verification. |
| #152 | Read nested BatteryData cycle count when the top-level value is absent. | Builds; fallback-specific hardware not exercised. |
| #207 | Stop calling IOServiceClose on an IOServiceGetMatchingService object; release only the matching service. Release each iterated Magic-device object rather than the terminal null object. | InternalFinder returned battery data on 40/40 read-only local calls. Elimination of reported kernel logs is not established. |
| #210 | Added a read-only pairing/Bonjour MAC diagnostic. No pairing-record writes or replacement binaries. | Match/mismatch/invalid input tests; actual affected phone not exercised. |

Other corrections found during implementation:

- Widget JSON writes are atomic; 50 concurrent writes leave a decodable snapshot.
- Log cursors are passed as subprocess arguments, not a global environment variable.
  The cursor advances from scan start and the maximum look-back is bounded.
- LogReader is part of the main-app Bluetooth implementation rather than the
  support file shared with the CLI/widget targets.
- Subprocess stderr is sent to the null device rather than an undrained pipe
  that can block a noisy helper.
- The existing Xcode project already declares NSBluetoothAlwaysUsageDescription
  for the main app. No duplicate declaration was added.

## Reproduce validation

```sh
python3 Tests/run_regressions.py --tsan
bash -n AirBattery/Supports/logReader.sh
xcodebuild -project AirBattery.xcodeproj -scheme AirBattery \
  -configuration Debug -derivedDataPath /private/tmp/AirBattery-Glass-Build \
  CODE_SIGNING_ALLOWED=NO MACOSX_DEPLOYMENT_TARGET=12.0 build
```

The regression runner compiles production model, parser and alert code with
isolated defaults, filesystem, notification and network boundaries. It does not
connect to devices or send real notifications. Thread Sanitizer covers that
harness, not every scanner in the app. Xcode 27 requires the temporary macOS 12
build override; project deployment settings remain unchanged.

## Wi-Fi diagnostic

For an already paired iPhone/iPad attached by USB:

```sh
python3 Scripts/diagnose_wifi.py --udid YOUR_DEVICE_UDID
```

The script reads BonjourFullServiceName and the host pairing record through
usbmuxd. It prints only match/mismatch/unknown, never certificates or keys. It does
not modify pairing records, change private-address settings, or apply the
upstream binary. A mismatch is a candidate cause, not proof of network failure.

## Remaining acceptance and separate features

Run a signed build to verify settings reopen, hover exit, sleep/wake, persistent
menu-bar-only refresh, BLE disconnect/backoff, and login registration. No app was
installed and no login/system preferences were changed during this pass.

Widget device selection/sorting (#171/#188), supported-device CLI (#164), and
energy-mode controls (#211) are separate feature work, not completed by this bug
fix pass. Automatic host pairing repair (#210) needs affected-device evidence and
a reviewed recovery path before implementation.
