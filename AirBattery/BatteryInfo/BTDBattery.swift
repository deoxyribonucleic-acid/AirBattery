//
//  BTDBattery.swift
//  AirBattery
//
//  Created by apple on 2024/6/23.
//

import SwiftUI
import Foundation
import IOBluetooth

// Pure parser: never associate an ambiguous unkeyed GATT stream with a device.
struct BluetoothLogRecord {
    let time: String
    let vid: String
    let pid: String
    let type: String
    let mac: String
    let name: String
    let level: Int
    let status: String
}

enum BluetoothLogParser {
    private static func match(_ pattern: String, _ text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let result = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(result.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private static func field(_ key: String, _ line: String) -> String {
        match(", " + key + " ([^,]+)", line)?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    static func parse(_ output: String, profilerJSON: String) -> [BluetoothLogRecord] {
        let lines = output.components(separatedBy: .newlines)
        var records: [BluetoothLogRecord] = []
        struct Identity: Hashable { let vid: String; let pid: String }
        struct Event { let line: String; let handle: String; let bytes: [UInt8]; let mac: String }
        var events: [Event] = []
        for line in lines {
            if let value = match(", Battery M [+-]?([0-9]+)%", line), let level = Int(value), (0...100).contains(level) {
                let vid = field("VID", line)
                guard vid.lowercased() != "0x004c" else { continue }
                let name = match(", PrNm '(.+?)'(?=,|$)", line)
                    ?? match(", PrNm ([^,]+)", line)
                    ?? match(", Nm '(.+?)'(?=,|$)", line)
                    ?? match(", Nm ([^,]+)", line) ?? ""
                let mac = field("BDA", line).uppercased()
                guard !mac.isEmpty, !name.isEmpty else { continue }
                records.append(BluetoothLogRecord(time: timestamp(line), vid: vid, pid: field("PID", line), type: field("DvT", line), mac: mac, name: name, level: level, status: match(", Battery M ([+-])", line) ?? "?"))
            }
            if let handle = match("statedump: (0x001[14ADad]) Characteristic Value", line),
               let payload = match("Characteristic Value \\[\\s*([0-9A-Fa-f ]+)\\s*\\]", line) {
                let parts = payload.split(separator: " ")
                let bytes = parts.compactMap { UInt8($0, radix: 16) }
                guard bytes.count == parts.count else { continue }
                let mac = match("([0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5})", line)?.uppercased() ?? ""
                events.append(Event(line: line, handle: handle.uppercased(), bytes: bytes, mac: mac))
            }
        }
        func identity(_ bytes: [UInt8]) -> Identity? {
            guard bytes.count == 7 else { return nil }
            return Identity(vid: String(format: "0x%02x%02x", bytes[2], bytes[1]), pid: String(format: "0x%02x%02x", bytes[4], bytes[3]))
        }
        let allIdentities = Set(events.filter { ["0X0011", "0X001A"].contains($0.handle) }.compactMap { identity($0.bytes) })
        let root = (try? JSONSerialization.jsonObject(with: Data(profilerJSON.utf8))) as? [String: Any]
        let profile = (root?["SPBluetoothDataType"] as? [[String: Any]])?.first
        let connected = profile?["device_connected"] as? [[String: Any]] ?? []
        var byContext: [String: Identity] = [:]
        for event in events {
            if ["0X0011", "0X001A"].contains(event.handle) {
                if let id = identity(event.bytes) { byContext[event.mac] = id }
                else { byContext.removeValue(forKey: event.mac) }
                continue
            }
            guard event.bytes.count == 1, event.bytes[0] <= 100,
                  let id = byContext[event.mac] else { continue }
            // With no address in the log, accept only one identity in the whole
            // batch AND one matching connected device. Never guess by row order.
            guard !event.mac.isEmpty || allIdentities.count == 1 else { continue }
            let candidates: [(String, [String: Any])] = connected.flatMap { entry in
                entry.compactMap { name, value in
                    guard let info = value as? [String: Any],
                          (info["device_productID"] as? String)?.lowercased() == id.pid,
                          (info["device_vendorID"] as? String)?.lowercased() == id.vid else { return nil }
                    let address = (info["device_address"] as? String ?? "").uppercased()
                    guard event.mac.isEmpty || event.mac == address else { return nil }
                    return (name, info)
                }
            }
            guard candidates.count == 1, let (name, info) = candidates.first,
                  let address = info["device_address"] as? String, !address.isEmpty else { continue }
            records.append(BluetoothLogRecord(time: timestamp(event.line), vid: id.vid, pid: id.pid, type: info["device_minorType"] as? String ?? "hid", mac: address.uppercased(), name: name, level: Int(event.bytes[0]), status: "?"))
        }
        return records
    }

    private static func timestamp(_ line: String) -> String {
        let parts = line.split(whereSeparator: { $0.isWhitespace })
        return parts.count >= 2 ? "\(parts[0])T\(parts[1])" : ""
    }
}

class BTDBattery {
    var scanTimer: Timer?
    private static let scanLock = NSLock()
    private static let namesLock = NSLock()
    private static var knownNames = Set<String>()
    static var allDevices: [String] {
        namesLock.lock(); defer { namesLock.unlock() }
        return Array(knownNames)
    }
    @AppStorage("readBTHID") var readBTHID = true
    
    static func remember(_ name: String) {
        namesLock.lock(); defer { namesLock.unlock() }
        knownNames.insert(name)
    }

    func startScan() {
        let interval = TimeInterval(59 * updateInterval)
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: max(1, interval), repeats: true) { [weak self] _ in self?.scanDevices() }
        print("ℹ️ Start scanning Bluetooth HID devices...")
        scanDevices(longScan: true)
    }
    
    @objc func scanDevices(longScan: Bool = false) {
        Thread.detachNewThread {
            if self.readBTHID {
                LogReader.shared.run(longScan ? .bootstrap : .connect)
                let connects = BTDBattery.getConnected()
                let names = BTDBattery.allDevices.filter({ connects.contains($0) })
                for name in names {
                    AirBatteryModel.refreshTimestamp(for: name)
                }
            }
        }
    }
    
    static func getConnected(mac: Bool = false) -> [String]{
        guard var bluetoothDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return [] }
        bluetoothDevices = bluetoothDevices.filter({ $0.isConnected() })
        if mac {
            let devices = bluetoothDevices.map({ ($0.addressString ?? "").uppercased().replacingOccurrences(of: "-", with: ":") })
            return devices.filter({ $0 != "" })
        }
        return bluetoothDevices.map({ $0.name ?? "" }).filter({ $0 != "" })
    }
    
    static func getOtherDevice(last: String = "10m", timeout: Int = 0) {
        guard scanLock.try() else { return }
        defer { scanLock.unlock() }
        let parent = ud.string(forKey: "deviceName") ?? "Mac"
        guard let result = process(path: "/bin/bash", arguments: ["\(Bundle.main.resourcePath!)/logReader.sh", "mac", last], timeout: timeout) else { return }
        let connected = getConnected(mac: true)
        let records = BluetoothLogParser.parse(result, profilerJSON: SPBluetoothDataModel.shared.data)
        for d in records where connected.contains(d.mac) {
            remember(d.name)
            AirBatteryModel.updateDevice(Device(deviceID: d.mac, deviceType: d.type, deviceName: d.name, batteryLevel: d.level, isCharging: d.status == "+" ? 1 : 0, parentName: parent, lastUpdate: Date().timeIntervalSince1970, realUpdate: ISO8601DateFormatter().date(from: d.time)?.timeIntervalSince1970 ?? 0))
        }
    }
}

// Serialized incremental log reader for Enhanced HID scans
class LogReader {
    static let shared = LogReader()

    @AppStorage("readBTHID") var readBTHID = true
    @AppStorage("logReaderLastTS") var lastTS: String = ""   // e.g. "2025-07-01 12:34:56 +0000"

    private var isRunning = false
    private var queued = false
    private let lock = NSLock()
    private let fmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
        return f
    }()

    enum Trigger { case bootstrap, wake, connect }

    func run(_ trigger: Trigger) {
        guard readBTHID else { return }
        lock.lock()
        if isRunning { queued = true; lock.unlock(); return }
        isRunning = true
        lock.unlock()

        let args: [String]
        if let start = computeStart(trigger) {
            args = ["\(Bundle.main.resourcePath!)/logReader.sh", "mac", "10m", start]
        } else {
            let win = (trigger == .bootstrap) ? "20m" : (trigger == .wake ? "3m" : "2m")
            args = ["\(Bundle.main.resourcePath!)/logReader.sh", "mac", win]
        }

        let scanStarted = Date()
        let out = process(path: "/bin/bash", arguments: args, timeout: 5)
        parseAndUpdate(output: out)
        if out != nil { lastTS = fmt.string(from: scanStarted.addingTimeInterval(-2)) }

        lock.lock()
        isRunning = false
        let again = queued
        queued = false
        lock.unlock()

        if again {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.8) { self.run(.wake) }
        }
    }

    private func computeStart(_ trigger: Trigger) -> String? {
        if lastTS.isEmpty {
            let t = Date(timeIntervalSinceNow: -20*60)
            return fmt.string(from: t)
        }
        if let prev = fmt.date(from: lastTS) {
            return fmt.string(from: max(prev.addingTimeInterval(-2), Date(timeIntervalSinceNow: -20 * 60)))
        }
        return nil
    }

    private func parseAndUpdate(output: String?) {
        guard let output = output else { return }
        let parent = ud.string(forKey: "deviceName") ?? "Mac"
        let connected = Set(BTDBattery.getConnected(mac: true))
        for d in BluetoothLogParser.parse(output, profilerJSON: SPBluetoothDataModel.shared.data) where connected.contains(d.mac) {
            BTDBattery.remember(d.name)
            AirBatteryModel.updateDevice(Device(deviceID: d.mac, deviceType: d.type, deviceName: d.name, batteryLevel: d.level, isCharging: d.status == "+" ? 1 : 0, parentName: parent, lastUpdate: Date().timeIntervalSince1970, realUpdate: ISO8601DateFormatter().date(from: d.time)?.timeIntervalSince1970 ?? 0))
        }
    }
}
