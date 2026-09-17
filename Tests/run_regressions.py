#!/usr/bin/env python3
"""Compile production Swift code with isolated OS boundaries; no real device access."""
from pathlib import Path
import subprocess
import tempfile
import sys
import importlib.util
sys.dont_write_bytecode = True

root = Path(__file__).resolve().parents[1]
model = (root / 'AirBattery/BatteryInfo/AirBatteryModel.swift').read_text()
btd = (root / 'AirBattery/BatteryInfo/BTDBattery.swift').read_text()
parser = btd[btd.index('struct BluetoothLogRecord'):btd.index('class BTDBattery')]
alerts = (root / 'AirBattery/ViewModel/BatteryAlertView.swift').read_text()
alert_types = alerts[alerts.index('struct btAlert'):alerts.index('struct AlertInputView')]
alert_function = alerts[alerts.index('func batteryAlert()'):]
stubs = r'''
import Foundation
import SwiftUI

final class TestDefaults {
    var values: [String: Any] = ["disappearTime": 20, "deviceName": "Test Mac"]
    func object(forKey key: String) -> Any? { values[key] }
    func string(forKey key: String) -> String? { values[key] as? String }
    func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    func get<T>(objectType: T.Type, forKey key: String) -> T? { values[key] as? T }
}
let ud = TestDefaults()
let testDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
struct TestFiles {
    func urls(for directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask) -> [URL] { [testDirectory] }
}
let fd = TestFiles()
let ncFolder = testDirectory
func getFiles(withExtension: String, in folder: URL) -> [URL] { [] }
struct InternalBattery { static let status = Device(hasBattery: false, deviceID: "internal", deviceType: "mac", deviceName: "Internal", batteryLevel: 0, isCharging: 0, lastUpdate: 0) }
func ib2ab(_ device: Device) -> Device { device }
extension String { var local: String { self } }
var lowPowerNoteDelay: [String: Double] = [:]
var notices: [String] = []
func createNotification(title: String, message: String, alertSound: Bool, delay: Bool, info: String) { notices.append(info) }
struct TestNetwork {
    func createInfo(title: String, info: String) -> String? { nil }
    func sendMessage(_ info: String) { }
}
let netcastService = TestNetwork()
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
    print("PASS: " + message)
}
'''
tests = r'''
let now = Date().timeIntervalSince1970
DispatchQueue.concurrentPerform(iterations: 12000) { index in
    let name = "device-\(index % 80)"
    AirBatteryModel.updateDevice(Device(deviceID: name, deviceType: "keyboard", deviceName: name, batteryLevel: index % 100, isCharging: 0, lastUpdate: now + Double(index)))
    _ = AirBatteryModel.getAll(noFilter: true)
}
check(AirBatteryModel.Devices.count == 80, "concurrent upserts do not drop or duplicate devices")
AirBatteryModel.updateDevice(Device(deviceID: "invalid", deviceType: "headphones", deviceName: "invalid", batteryLevel: 125, isCharging: 0, lastUpdate: now))
check(AirBatteryModel.getByName("invalid") == nil, "invalid scanner data never reaches the device store")
check(AirBatteryModel.getByName("device-79")?.lastUpdate == now + 11999, "late older snapshots do not overwrite newer data")
AirBatteryModel.hideDevice("device-0")
check(!AirBatteryModel.getAll().contains { $0.deviceName == "device-0" }, "hide excludes the device")
AirBatteryModel.unhideDevice("device-0")
check(AirBatteryModel.getAll().contains { $0.deviceName == "device-0" }, "unhide restores the device")
ud.values["blockedDevices"] = ["My AirPods"]
check(AirBatteryModel.checkIfBlocked(name: "My AirPods 🄻"), "block rule applies to AirPods children")
ud.values["whitelistMode"] = true
check(!AirBatteryModel.checkIfBlocked(name: "My AirPods (Case)"), "allow rule applies to AirPods case")
ud.values["whitelistMode"] = false
ud.values["blockedDevices"] = [String]()
try FileManager.default.createDirectory(at: AirBatteryModel.getJsonURL().deletingLastPathComponent(), withIntermediateDirectories: true)
DispatchQueue.concurrentPerform(iterations: 50) { _ in AirBatteryModel.writeData() }
check(AirBatteryModel.readData().count == 80, "concurrent atomic widget writes leave complete JSON")

let direct = "2026-09-16 12:00:00.000 bluetoothd: CBDevice 123, BDA AA:BB:CC:DD:EE:FF, Nm 'NuPhy Air75 V2-1', DsFl 0x800000, DvT Keyboard, Battery M -85%"
let named = BluetoothLogParser.parse(direct, profilerJSON: "{}")
check(named.count == 1 && named[0].name == "NuPhy Air75 V2-1" && named[0].level == 85, "NuPhy name without PID is retained")
let special = direct.replacingOccurrences(of: "NuPhy Air75 V2-1", with: "Sam's, \"Keyboard\"")
check(BluetoothLogParser.parse(special, profilerJSON: "{}").first?.name == "Sam's, \"Keyboard\"", "quotes and commas survive name parsing")
check(BluetoothLogParser.parse(direct.replacingOccurrences(of: "-85%", with: "-125%"), profilerJSON: "{}").isEmpty, "invalid battery levels are rejected")
check(BluetoothLogParser.parse(direct + ", VID 0x004C", profilerJSON: "{}").isEmpty, "Apple advertisements stay out of generic HID parsing")
let modern = direct.replacingOccurrences(of: "Nm 'NuPhy Air75 V2-1'", with: "PrNm Roccat Mouse")
check(BluetoothLogParser.parse(modern, profilerJSON: "{}").first?.name == "Roccat Mouse", "Tahoe PrNm names are recognized")
let profile = #"{"SPBluetoothDataType":[{"device_connected":[{"Roccat":{"device_vendorID":"0x1234","device_productID":"0x5678","device_address":"AA:BB:CC:DD:EE:FF","device_minorType":"Mouse"}}]}]}"#
let pnp = "2026-09-16 12:00:00.000 statedump: 0x0011 Characteristic Value [ 01 34 12 78 56 00 01 ]"
let battery = "2026-09-16 12:00:01.000 statedump: 0x0014 Characteristic Value [ 55 ]"
let gatt = BluetoothLogParser.parse(pnp + "\n" + battery, profilerJSON: profile)
check(gatt.count == 1 && gatt[0].level == 85, "unambiguous Tahoe GATT battery is decoded")
let other = pnp.replacingOccurrences(of: "78 56", with: "90 78")
check(BluetoothLogParser.parse(pnp + "\n" + other + "\n" + battery, profilerJSON: profile).isEmpty, "interleaved unkeyed devices are never cross-associated")
check(BluetoothLogParser.parse(pnp + "\n" + battery, profilerJSON: "{}").isEmpty, "GATT data without a connected identity is ignored")

let rules = (0..<3).map { btAlert(name: "alert-\($0)", full: 90, fullOn: true, fullSound: false, low: 20, lowOn: true, lowSound: false) }
ud.values["alertList"] = rules
for rule in rules { AirBatteryModel.updateDevice(Device(deviceID: rule.name, deviceType: "keyboard", deviceName: rule.name, batteryLevel: 10, isCharging: 0, lastUpdate: now)) }
lowPowerNoteDelay["alert-0"] = now + 1000
batteryAlert()
check(notices == ["alert-1", "alert-2"], "one snoozed device does not suppress later low-battery alerts")
notices = []
for rule in rules { AirBatteryModel.updateDevice(Device(deviceID: rule.name, deviceType: "keyboard", deviceName: rule.name, batteryLevel: 99, isCharging: 1, lastUpdate: now + 1)) }
batteryAlert()
check(notices == ["alert-1", "alert-2"], "one snoozed device does not suppress later charged alerts")
print("All regression checks passed")
'''
with tempfile.TemporaryDirectory(prefix='airbattery-tests-') as folder:
    path = Path(folder)
    (path / 'main.swift').write_text(stubs + model + parser + alert_types + alert_function + tests)
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-module-cache-path', '/private/tmp/airbattery-test-module-cache', *(['-sanitize=thread'] if '--tsan' in sys.argv else []), str(path / 'main.swift'), '-o', str(path / 'regressions')], check=True)
    subprocess.run([str(path / 'regressions'), str(path / 'data')], check=True)

spec = importlib.util.spec_from_file_location('wifi_diagnostic', root / 'Scripts/diagnose_wifi.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
for record, service, expected in [
    ({'WiFiMACAddress': 'AA:BB:CC:DD:EE:FF'}, 'aa:bb:cc:dd:ee:ff@device', 'match'),
    ({'WiFiMACAddress': 'AA:BB:CC:DD:EE:FF'}, '11:22:33:44:55:66@device', 'mismatch'),
    ({}, 'missing', 'unknown'),
    ({'WiFiMACAddress': 'invalid'}, 'aa:bb:cc:dd:ee:ff@device', 'unknown'),
]:
    assert module.compare_addresses(record, service) == expected
print('PASS: read-only Wi-Fi diagnosis handles matching, mismatching and invalid addresses')
