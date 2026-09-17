//
//  SettingsView.swift
//  AirBattery
//
//  Created by apple on 2023/9/7.
//

import AppKit
import SwiftUI
import ServiceManagement
import WidgetKit
import Combine

// Native split-window structure adapted to AirBattery from native-via's UI.
final class AirBatteryNavigation: ObservableObject {
    @Published var selectedItem: String? = "Devices"
    static let settingsPages = ["General", "Display", "Nearbility", "Nearcast", "Widget", "Blocklist"]
    static func title(_ page: String) -> String {
        page == "Display" ? "Menu Bar & Dock" : page
    }
    static func symbol(_ page: String) -> String {
        switch page {
        case "Devices": return "battery.100"
        case "General": return "gearshape"
        case "Display": return "menubar.dock.rectangle"
        case "Nearbility": return "antenna.radiowaves.left.and.right"
        case "Nearcast": return "network"
        case "Widget": return "square.grid.2x2"
        case "Blocklist": return "line.3.horizontal.decrease.circle"
        default: return "ladybug"
        }
    }
}

struct SettingsView: NSViewControllerRepresentable {
    func makeNSViewController(context: Context) -> AirBatteryMainController { AirBatteryMainController() }
    func updateNSViewController(_ controller: AirBatteryMainController, context: Context) {}
}

final class AirBatteryMainController: NSSplitViewController, NSToolbarDelegate {
    private let navigation = AirBatteryNavigation()
    private var titleSubscription: AnyCancellable?
    private let separatorID = NSToolbarItem.Identifier("AirBatterySidebarDivider")
    private let titleID = NSToolbarItem.Identifier("AirBatteryPageTitle")
    private let pageTitle = NSTextField(labelWithString: "")

    init() {
        super.init(nibName: nil, bundle: nil)
        // Install items before AppKit loads and wires the split view.
        let sidebar = NSSplitViewItem(sidebarWithViewController:
            NSHostingController(rootView: AirBatterySidebar(navigation: navigation)))
        sidebar.minimumThickness = 190
        sidebar.maximumThickness = 260
        sidebar.canCollapse = true
        sidebar.allowsFullHeightLayout = true
        addSplitViewItem(sidebar)
        let detail = NSSplitViewItem(viewController:
            NSHostingController(rootView: AirBatteryDetail(navigation: navigation)))
        detail.minimumThickness = 500
        detail.allowsFullHeightLayout = false
        addSplitViewItem(detail)
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        DispatchQueue.main.async { [weak self] in self?.splitView.setPosition(220, ofDividerAt: 0) }
    }
    override func viewDidAppear() {
        super.viewDidAppear()
        guard let window = view.window else { return }
        // Extend the native sidebar material behind the traffic lights while
        // letting AppKit retain the detail toolbar background and safe area.
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = false
        if window.toolbar == nil {
            let toolbar = NSToolbar(identifier: "AirBatteryMainToolbar")
            toolbar.delegate = self
            toolbar.displayMode = .iconOnly
            window.toolbarStyle = .unified
            // Keep the native window title for accessibility, but place its visible
            // label after the split divider so it cannot crowd the sidebar controls.
            window.titleVisibility = .hidden
            window.subtitle = ""
            window.titlebarSeparatorStyle = .none
            window.toolbar = toolbar
        }
        if titleSubscription == nil {
            titleSubscription = navigation.$selectedItem.sink { [weak self, weak window] page in
                let title = AirBatteryNavigation.title(page ?? "Devices").local
                window?.title = title + " — AirBattery"
                self?.pageTitle.stringValue = title
            }
        }
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, separatorID, titleID, .flexibleSpace]
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if identifier == separatorID {
            return NSTrackingSeparatorToolbarItem(identifier: identifier, splitView: splitView, dividerIndex: 0)
        }
        if identifier == .toggleSidebar {
            let item = NSToolbarItem(itemIdentifier: .toggleSidebar)
            item.label = "Toggle Sidebar".local
            item.toolTip = item.label
            item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: item.label)
            item.target = self
            item.action = #selector(NSSplitViewController.toggleSidebar(_:))
            item.isNavigational = true
            return item
        }
        guard identifier == titleID else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = "AirBattery"
        item.isBordered = false
        pageTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        pageTitle.lineBreakMode = .byTruncatingTail
        pageTitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        item.view = pageTitle
        return item
    }
}

private struct AirBatterySidebar: View {
    @ObservedObject var navigation: AirBatteryNavigation
    @AppStorage("showDebug") private var showDebug = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "battery.100")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundColor(.accentColor)
                Text("AirBattery").font(.system(size: 22, weight: .semibold, design: .rounded))
            }
            .padding(20)
            .accessibilityAddTraits(.isHeader)
            List(selection: $navigation.selectedItem) {
                navigationRow("Devices")
                Section(header: Text("Settings")) {
                    ForEach(AirBatteryNavigation.settingsPages, id: \.self) { navigationRow($0) }
                }
                if showDebug { navigationRow("Debug") }
            }
            .listStyle(.sidebar)

        }
        .onChange(of: showDebug) { visible in
            if !visible && navigation.selectedItem == "Debug" { navigation.selectedItem = "General" }
        }
    }
    private func navigationRow(_ page: String) -> some View {
        Label(LocalizedStringKey(AirBatteryNavigation.title(page)), systemImage: AirBatteryNavigation.symbol(page))
            .padding(.vertical, 6)
            .tag(page)
    }
}

private struct AirBatteryDetail: View {
    @ObservedObject var navigation: AirBatteryNavigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Group {
            switch navigation.selectedItem ?? "Devices" {
            case "General": GeneralView()
            case "Display": DisplayView()
            case "Nearbility": NearbilityView()
            case "Nearcast": NearcastView()
            case "Widget": WidgetView()
            case "Blocklist": BlacklistView()
            case "Debug": DebugView(selectedItem: $navigation.selectedItem)
            default: AirBatteryOverview()
            }
        }
        .id(navigation.selectedItem)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: navigation.selectedItem)
    }
}

private struct AirBatteryOverview: View {
    @State private var devices: [Device] = []
    private func refresh() {
        var snapshot = AirBatteryModel.getAll()
        let internalBattery = InternalBattery.status
        if internalBattery.hasBattery { snapshot.insert(ib2ab(internalBattery), at: 0) }
        devices = snapshot
    }
    var body: some View {
        SForm {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Batteries").font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Battery levels at a glance.").foregroundColor(.secondary)
            }
            if devices.isEmpty {
                SGroupBox {
                    VStack(spacing: 12) {
                        Image(systemName: "battery.0").font(.system(size: 36)).foregroundColor(.secondary)
                        Text("No Battery Data").font(.headline)
                        Text("Connect a device or check discovery settings.")
                            .foregroundColor(.secondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(.vertical, 40)
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 18)], spacing: 18) {
                    ForEach(devices, id: \.deviceName) { device in
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                Image(getDeviceIcon(device)).resizable().scaledToFit()
                                    .frame(width: 36, height: 36)
                                Spacer()
                                if device.acPowered || device.isCharging != 0 {
                                    Image(systemName: "bolt.fill").foregroundColor(.secondary)
                                        .accessibilityLabel(Text("External Power"))
                                }
                            }
                            Text(device.deviceName).font(.headline).lineLimit(2)
                                .frame(height: 38, alignment: .topLeading)
                            HStack(alignment: .firstTextBaseline) {
                                Text(device.hasBattery ? "\(device.batteryLevel)%" : "—")
                                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                Spacer()
                                if device.lastUpdate > 0 {
                                    Text(Date(timeIntervalSince1970: device.lastUpdate), style: .relative)
                                        .font(.caption).foregroundColor(.secondary).lineLimit(1)
                                        .help("Last Updated")
                                }
                            }
                            ProgressView(value: Double(min(100, max(0, device.batteryLevel))), total: 100)
                                .accentColor(Color(getPowerColor(device)))
                                .accessibilityLabel(Text("Battery Level"))
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .airBatteryPanel(cornerRadius: 18)
                    }
                }
            }
        }
        .onAppear(perform: refresh)
        .onReceive(mainTimer) { _ in refresh() }
    }
}

struct GeneralView: View {
    @AppStorage("showOn") var showOn = "sbar"
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("showDebug") var showDebug: Bool = false
    @State private var debugCount: Int = 0
    @State private var cltInstalled: Bool = false
    
    var body: some View {
        SForm {
            SGroupBox(label: "Startup") {
                SToggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { enabled in
                        if ensureLoginItem(enabled: enabled) {
                            launchAtLogin = enabled
                        } else {
                            let alert = NSAlert()
                            alert.messageText = "Launch at Login".local
                            alert.informativeText = "Could not update login item. Please check System Settings > General > Login Items."
                            alert.runModal()
                        }
                    }
                ))
                Divider().opacity(0.5)
                SPicker("Show AirBattery", selection: $showOn) {
                    Text("Dock").tag("dock")
                    Text("Menu Bar").tag("sbar")
                    Text("Both").tag("both")
                    Text("None").tag("none")
                }.onChange(of: showOn) { newValue in
                    switch newValue {
                    case "sbar":
                        statusBarItem.isVisible = true
                        for i in pinnedItems { i.isVisible = true }
                        NSApp.setActivationPolicy(.accessory)
                    case "both":
                        statusBarItem.isVisible = true
                        for i in pinnedItems { i.isVisible = true }
                        NSApp.setActivationPolicy(.regular)
                    case "dock":
                        statusBarItem.isVisible = false
                        for i in pinnedItems { i.isVisible = false }
                        NSApp.setActivationPolicy(.regular)
                    default:
                        statusBarItem.isVisible = false
                        for i in pinnedItems { i.isVisible = false }
                        NSApp.setActivationPolicy(.accessory)
                    }
                    if newValue == "dock" || newValue == "both" {
                        _ = createAlert(title: "AirBattery Tips".local, message: "Displaying AirBattery on the Dock will consume more power, it is better to use Menu Bar mode or Widgets.".local, button1: "OK").runModal()
                    }
                }
            }
            SGroupBox {
                SButton("Command Line Tool", buttonTitle: cltInstalled ? "Uninstall" : "Install",
                        tips: "After installation, you can run \"airbattery\" in yor terminal to list all devices.") {
                    if cltInstalled {
                        CommandLineTool.uninstall { updateCTL() }
                    } else {
                        CommandLineTool.install { updateCTL() }
                    }
                }.onAppear { cltInstalled = CommandLineTool.isInstalled() }
            }
            SGroupBox(label: "Update") { UpdaterSettingsView(updater: updaterController.updater) }
            SGroupBox(label: "About") {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AirBattery").font(.title2.weight(.semibold))
                        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                            Text("Version \(appVersion)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .onTapGesture {
                                    debugCount += 1
                                    if debugCount > 9 {
                                        debugCount = 0
                                        showDebug.toggle()
                                    }
                                }
                        }
                    }
                    Spacer()
                }
                Divider().opacity(0.5)
                VStack(alignment: .leading, spacing: 8) {
                    Link(destination: URL(string: "https://github.com/deoxyribonucleic-acid/AirBattery")!) {
                        Label("Forked version by deoxyribonucleic-acid", systemImage: "arrow.triangle.branch")
                            .font(.subheadline.weight(.medium))
                    }
                    .help("Fork Repository")
                    Link("Based on lihaoyun6/AirBattery", destination: URL(string: "https://github.com/lihaoyun6/AirBattery")!)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    func updateCTL() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            cltInstalled = CommandLineTool.isInstalled()
        }
    }
}

struct NearbilityView: View {
    @AppStorage("ideviceOverBLE") var ideviceOverBLE = false
    @AppStorage("readBTDevice") var readBTDevice = true
    @AppStorage("readBLEDevice") var readBLEDevice = false
    @AppStorage("readPencil") var readPencil = false
    @AppStorage("readIDevice") var readIDevice = true
    @AppStorage("readBTHID") var readBTHID = true
    @AppStorage("updateInterval") var updateInterval = 1
    @AppStorage("twsMerge") var twsMerge = 5
    
    var body: some View {
        SForm {
            SGroupBox(label: "Scanner") {
                SToggle("Discover iOS devices via Network", isOn: $readIDevice, tips: "Scan your iPhone / iPad / Apple Watch / VisionPro and other iDevices in your local network.")
                Divider().opacity(0.5)
                SToggle("Discover iOS devices via Bluetooth", isOn: $ideviceOverBLE, tips: "Scan your iPhone and iPad (Cellular) via Bluetooth.")
                Divider().opacity(0.5)
                SToggle("Discover BT and BLE devices", isOn: $readBTDevice, tips: "Get the battery usage of some Bluetooth peripherals like mouse, keyboard, headphone or etc.\n\nIf some of your device is not shown, try enabling \"Discover more BT devices\" or \"Discover more BLE devices\"")
                Divider().opacity(0.5)
                SToggle("Discover more BT devices", isOn: $readBTHID, tips: "Get the battery usage of more third-party Bluetooth devices\n\nBattery data will be updated when devices are reconnected to the Mac or the Mac wakes up.")
                Divider().opacity(0.5)
                SToggle("Discover more BLE devices", isOn: $readBLEDevice, tips: "Try to get the battery usage of any Bluetooth device that AirBattery can find\n\nWARNING: This is a BETA feature and may cause unexpected errors!")
                    .foregroundColor(.orange)
                    .onChange(of: readBLEDevice) { newValue in
                        if newValue {
                            _ = createAlert(title: "AirBattery Tips".local, message: "If you see a bluetooth pairing request from any device that isn't yours, add it to your blocklist!".local, button1: "OK").runModal()
                        }
                    }
                Divider().opacity(0.5)
                SToggle("Apple Pencil from your iPad", isOn: $readPencil, tips: "Read the battery status of the connected Apple Pencil through your iPad\n(It may take 10 minutes or longer to discover the Pencil for the first time)\n\nWARNING: This is a BETA feature and may drain your iPad's battery faster!")
                    .foregroundColor(.orange)
            }
            SGroupBox(label: "Others") {
                VStack(spacing: 2) {
                    SSteper("Refresh Interval (min)", value: $updateInterval, min: 1, max: 99)
                    if updateDelay != updateInterval {
                        HStack {
                            Text("Relaunch AirBattery to apply this change")
                                .font(.footnote)
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
                Divider().opacity(0.5)
                SSteper("Earbud Merging Threshold", value: $twsMerge, min: 1, max: 99, tips: "If the difference in battery usage between the left and right earbuds is less than this value, AirBattery will show them as one device.")
            }
        }
    }
}

struct NearcastView: View {
    @AppStorage("nearCast") var nearCast = false
    @AppStorage("ncGroupID") var ncGroupID = ""
    @State var debug: Bool = false
    
    var body: some View {
        SForm {
            SGroupBox(label: "Nearcast") {
                SToggle("Enable Nearcast", isOn: $nearCast)
                    .onChange(of: nearCast) { newValue in
                        if newValue {
                            if ncGroupID != "" && isGroudIDValid(id: ncGroupID) {
                                netcastService.resume()
                            } else {
                                DispatchQueue.main.async { nearCast = false; ncGroupID = "" }
                                _ = createAlert(
                                    title: "Invalid group ID".local,
                                    message: "Please create or enter a valid Group ID before use!",
                                    button1: "OK".local
                                ).runModal()
                            }
                        } else {
                            netcastService.stop()
                        }
                    }
                Divider().opacity(0.5)
                HStack(spacing: 4) {
                    SField("Group ID", text: $ncGroupID).disabled(nearCast)
                    Button(action: {
                        ncGroupID = "nc-" + randomString(length: 20)
                    }, label: {
                        if ncGroupID != "" {
                            Image(systemName: "arrow.clockwise.circle")
                                .font(.system(size: 15, weight: .light))
                        } else {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 15, weight: .light))
                        }
                    })
                    .buttonStyle(.plain)
                    .disabled(nearCast)
                    Button(action: {
                        if ncGroupID != "" && isGroudIDValid(id: ncGroupID) {
                            copyToClipboard(ncGroupID)
                            _ = createAlert(title: "Group ID Copied".local,
                                            message: String(format: "Group ID has been copied to the clipboard.".local, ncGroupID),
                                            button1: "OK".local).runModal()
                        } else {
                            DispatchQueue.main.async { ncGroupID = "" }
                            _ = createAlert(
                                title: "Invalid group ID".local,
                                message: "Please create or enter a valid Group ID before use!",
                                button1: "OK".local
                            ).runModal()
                        }
                    }, label: {
                        Image("list.clipboard.fill.circle")
                            .resizable().scaledToFit()
                            .frame(width: 15, height: 15)
                    }).buttonStyle(.plain)
                }.frame(minHeight: 28)
                Divider().opacity(0.5)
                VStack(spacing: 2) {
                    Text("Nearcast will broadcast your battery data within the local network.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Your data has been encrypted using the group id, don't share it with others.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            SGroupBox(label: "Peer Info") {
                HStack {
                    Text("Local ID")
                    Spacer()
                    Text(netcastService.transceiver.localPeerId ?? "")
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct DisplayView: View {
    @AppStorage("appearance") var appearance = "auto"
    @AppStorage("showThisMac") var showThisMac = "icon"
    @AppStorage("carouselMode") var carouselMode = true
    @AppStorage("colorfulBattery") var colorfulBattery = false
    @AppStorage("iosBatteryStyle") var iosBatteryStyle = false
    @AppStorage("intBattOnStatusBar") var intBattOnStatusBar = true
    @AppStorage("batteryPercent") var batteryPercent = "outside"
    @AppStorage("hideLevel") var hideLevel = 90
    @AppStorage("disappearTime") var disappearTime = 20
    @State private var levelList = [95, 90, 80, 70, 60, 50, 40, 30, 20, 10]
    
    var body: some View {
        SForm {
            SGroupBox(label: "Menu Bar") {
                SToggle("Dynamic Battery Icon", isOn: $intBattOnStatusBar)
                Divider().opacity(0.5)
                SToggle("Colorful Battery Icon", isOn: $colorfulBattery)
                    .disabled(!intBattOnStatusBar)
                Divider().opacity(0.5)
                SPicker("Battery Icon Style", selection: $iosBatteryStyle) {
                    Text("Classic macOS").tag(false)
                    Text("Modern macOS / iOS").tag(true)
                }.disabled(!intBattOnStatusBar)
                Divider().opacity(0.5)
                SPicker("Show Percentage", selection: $batteryPercent) {
                    Text("Hidden").tag("hide")
                    Text("Inside").tag("inside")
                    Text("Outside").tag("outside")
                }.disabled(!intBattOnStatusBar)
                Divider().opacity(0.5)
                SPicker("Remove Offline Device", selection: $disappearTime) {
                    Text("Never").tag(UInt32.max)
                    Text("after 20min").tag(20)
                    Text("after 40min").tag(40)
                    Text("after 60min").tag(60)
                }
                Divider().opacity(0.5)
                SPicker("Hide percentage when above", selection: $hideLevel) {
                    Text("Always").tag(-1)
                    Text("Never").tag(100)
                    ForEach(levelList, id: \.self) { number in
                        Text("\(number)%").tag(number)
                    }
                    if !levelList.contains(hideLevel) && hideLevel != 100 && hideLevel != -1 {
                        Text("\(hideLevel)%").tag(hideLevel)
                    }
                }.disabled(!intBattOnStatusBar || (batteryPercent == "hide"))
            }
            SGroupBox(label: "Dock") {
                    SPicker("Appearance", selection: $appearance) {
                        Text("Automatic").tag("auto")
                        Text("Light").tag("false")
                        Text("Dark").tag("true")
                    }.pickerStyle(.segmented)
                    Divider().opacity(0.5)
                    SPicker("Built-in Battery Style", selection: $showThisMac, tips: "Show or hide this Mac's built-in battery in the Dock icon") {
                        Text("Hidden").tag("hidden")
                        Text("Device Icon").tag("icon")
                        Text("Percent").tag("percent")
                    }
                    Divider().opacity(0.5)
                    SToggle("Carousel Mode", isOn: $carouselMode, tips: "Cycle through all found devices in the Dock icon")
            }
        }
    }
}

struct WidgetView: View {
    //@AppStorage("showMacOnWidget") var showMacOnWidget = true
    @AppStorage("revListOnWidget") var revListOnWidget = false
    @AppStorage("deviceOnWidget") var deviceOnWidget = ""
    @AppStorage("widgetInterval") var widgetInterval = 0
    @AppStorage("deviceName") var deviceName = "Mac"
    
    @State var ib = getMacDeviceType().lowercased().contains("book")
    @State var devices = [String]()

    var body: some View {
        SForm {
            SGroupBox(label: "Widget") {
                SToggle("Reverse Device List", isOn: $revListOnWidget)
                Divider().opacity(0.5)
                SPicker("Refresh Interval", selection: $widgetInterval) {
                    Text("System Default").tag(-1)
                    Text("Same as Nearbility").tag(0)
                }
                if #unavailable(macOS 14) {
                    Divider().opacity(0.5)
                    SPicker("Single Device Widget", selection: $deviceOnWidget) {
                        Text("Not Set").tag("")
                        if ib { Text(deviceName).tag(deviceName) }
                        ForEach(devices, id: \.self) { device in
                            Text(device).tag(device)
                        }
                        if !devices.contains(deviceOnWidget) && deviceOnWidget != deviceName && deviceOnWidget != "" {
                            Text(deviceOnWidget).tag(deviceOnWidget)
                        }
                    }.onChange(of: deviceOnWidget) { _ in _ = AirBatteryModel.singleDeviceName() }
                }
                Divider().opacity(0.5)
                SButton("Reload All Widgets", buttonTitle: "Reload") {
                    AirBatteryModel.writeData()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
        .onAppear { devices = AirBatteryModel.getAll(noFilter: true).filter({ $0.hasBattery }).map({ $0.deviceName }) }
        .onReceive(dockTimer) { _ in
            if #unavailable(macOS 14) {
                devices = AirBatteryModel.getAll(noFilter: true).filter({ $0.hasBattery }).map({ $0.deviceName })
            }
        }
    }
}

struct BlacklistView: View {
    @AppStorage("whitelistMode") var whitelistMode = false
    @State private var blockedItems = [String]()
    @State private var temp = ""
    @State private var showSheet = false
    @State private var editingIndex: Int?
    
    var body: some View {
        SForm {
            SGroupBox(label: "Blocklist") {
                    SToggle("Allowlist Mode", isOn: $whitelistMode)
                    Divider().opacity(0.5)
                    HStack {
                        Spacer()
                        Text(whitelistMode ? "Only the following devices will be showed" : "The following devices will be ignored")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                        List {
                            ForEach(0..<blockedItems.count, id: \.self) { index in
                                HStack {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.red)
                                        .onTapGesture { if editingIndex == nil { blockedItems.remove(at: index) } }
                                    Text(blockedItems[index])
                                }
                            }
                        }
                        .frame(minHeight: 220)
                        Button(action: {
                            showSheet = true
                        }) {
                            Image(systemName: "plus.square.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showSheet){
                            VStack {
                                TextField("Enter Device Name".local, text: $temp).frame(width: 300)
                                HStack(spacing: 20) {
                                    Button {
                                        if temp == "" { return }
                                        if !blockedItems.contains(temp) { blockedItems.append(temp) }
                                        temp = ""
                                        showSheet = false
                                    } label: {
                                        Text("Add to List").frame(width: 80)
                                    }.keyboardShortcut(.defaultAction)
                                    Button {
                                        showSheet = false
                                    } label: {
                                        Text("Cancel").frame(width: 80)
                                    }
                                }.padding(.top, 10)
                            }.padding()
                        }
                    }
            }
            .onAppear { blockedItems = (ud.object(forKey: "blockedDevices") as? [String]) ?? [String]() }
            .onChange(of: blockedItems) { b in ud.setValue(b, forKey: "blockedDevices") }
        }
    }
}

struct DebugView: View {
    @AppStorage("test_debug") var test_debug = false
    @AppStorage("test_hasib") var test_hasib = false
    @AppStorage("test_acpower") var test_ac = false
    @AppStorage("test_full") var test_full = false
    @AppStorage("test_iblevel") var test_iblevel = 100
    @AppStorage("showDebug") var showDebug: Bool = false
    
    @State private var deviceID: String = ""
    @State private var deviceType: String = ""
    @State private var deviceName: String = ""
    @State private var deviceModel: String = ""
    @State private var parentName: String = ""
    @State private var batteryLevel: Int = 0
    @State private var lowPower: Bool = false
    @State private var isCharging: Bool = false
    @State private var fullCharged: Bool = false
    @State private var isPresented: Bool = false
    
    @Binding var selectedItem: String?
    
    var body: some View {
        SForm {
            SGroupBox {
                SToggle("Debug Mode", isOn: $test_debug)
                Divider().opacity(0.5)
                SButton("Data Folder", buttonTitle: "Open") {
                    NSWorkspace.shared.open(ncFolder.deletingLastPathComponent())
                }
            }
            SGroupBox(label: "Built-in Battery") {
                SToggle("Built-in Battery", isOn: $test_hasib)
                Divider().opacity(0.5)
                SToggle("AC Powered", isOn: $test_ac)
                Divider().opacity(0.5)
                SToggle("Paused", isOn: $test_full)
                Divider().opacity(0.5)
                SSteper("Level", value: $test_iblevel, min: 1)
            }
            SGroupBox(label: "Remote Battery") {
                HStack {
                    Text("Create Item")
                    Spacer()
                    Button(action: {
                        isPresented = true
                    }, label: {
                        Image(systemName: "plus.circle.fill")
                    })
                    .buttonStyle(.plain)
                    .sheet(isPresented: $isPresented) {
                        VStack {
                            SGroupBox(label: "Remote Battery") {
                                SField("Device ID", text: $deviceID)
                                Divider().opacity(0.5)
                                SField("Device Name", text: $deviceName)
                                Divider().opacity(0.5)
                                SField("Device Type", text: $deviceType)
                                Divider().opacity(0.5)
                                SField("Device Model", text: $deviceModel)
                                Divider().opacity(0.5)
                                HStack {
                                    SField("Parent Name", text: $parentName)
                                    Button(action: {
                                        parentName = getMacDeviceName()
                                    }, label: {
                                        let ib = ib2ab(InternalBattery.status)
                                        Image(getDeviceIcon(ib))
                                            .resizable().scaledToFit()
                                            .frame(width: 16, height: 16)
                                    }).buttonStyle(.plain)
                                }
                                Divider().opacity(0.5)
                                SSteper("Level", value: $batteryLevel)
                                Divider().opacity(0.5)
                                SToggle("Charging", isOn: $isCharging)
                                Divider().opacity(0.5)
                                SToggle("Paused", isOn: $fullCharged)
                                Divider().opacity(0.5)
                                SToggle("Low Power", isOn: $lowPower)
                            }
                            HStack {
                                Spacer()
                                Button(action: {
                                    isPresented = false
                                }, label: {
                                    Text("Cancle").frame(width: 50)
                                })
                                Button(action: {
                                    let device = Device(deviceID: deviceID, deviceType: deviceType, deviceName: deviceName, batteryLevel: batteryLevel, isCharging: isCharging ? 1 : (fullCharged ? 5 : 0), lowPower: lowPower, parentName: parentName,lastUpdate: Date().timeIntervalSince1970)
                                    AirBatteryModel.updateDevice(device)
                                    isPresented = false
                                }, label: {
                                    Text("Add").frame(width: 50)
                                }).keyboardShortcut(.defaultAction)
                            }
                        }
                        .padding()
                        .onAppear {
                            deviceID = randomString(length: 10)
                            deviceType = "virtual"
                            deviceName = "Virtual Device"
                            deviceModel = ""
                            parentName = ""
                            batteryLevel = 100
                            lowPower = false
                            isCharging = false
                            fullCharged = false
                        }
                    }
                }
            }
            Button("Hide Debug Menu", action: {
                test_debug = false
                showDebug = false
                selectedItem = "General"
            })
            .padding(.top, -6)
        }
    }
}
