//
//  widgetBundle.swift
//  widget
//
//  Created by apple on 2024/2/18.
//

import WidgetKit
import SwiftUI

extension View {
    @ViewBuilder
    func widgetBackground(_ backgroundView: some View, usesBackground: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            // Do not paint an opaque card in full-color mode on Tahoe.
            // The widget host owns the glass/tinted container presentation.
            containerBackground(for: .widget) {
                if usesBackground { backgroundView } else { Color.clear }
            }
        } else if #available(macOS 14.0, *) {
            containerBackground(for: .widget) { backgroundView }
        } else {
            background(backgroundView)
        }
    }
}

// Keep the background in the container slot: WidgetKit replaces it with the
// system glass/tint in accented appearances. Never add a glass overlay here.
@available(macOS 13.0, *)
private struct WidgetForeground: ViewModifier {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let color: Color
    let accented: Bool

    func body(content: Content) -> some View {
        content
            .foregroundColor(renderingMode == .fullColor ? color : .primary)
            .widgetAccentable(accented)
    }
}

extension View {
    @ViewBuilder
    func widgetForeground(_ color: Color, accented: Bool = false) -> some View {
        if #available(macOS 13.0, *) {
            modifier(WidgetForeground(color: color, accented: accented))
        } else {
            foregroundColor(color)
        }
    }
}

extension Image {
    // Device assets are glyphs, so preserve their alpha silhouettes when the
    // system recolors them; do not force full-color images into glass widgets.
    @ViewBuilder
    func widgetDeviceImage() -> some View {
        if #available(macOS 15.0, *) {
            renderingMode(.template)
                .resizable()
                .widgetAccentedRenderingMode(.desaturated)
        } else {
            renderingMode(.template).resizable()
        }
    }
}

extension WidgetConfiguration {
    // Container backgrounds remain removable (WidgetKit's default), so the
    // host can supply the user's clear or tinted appearance.
    func disableContentMarginsIfNeeded() -> some WidgetConfiguration {
        if #available(macOS 12.0, *) {
            return self.contentMarginsDisabled()
        } else {
            return self
        }
    }

    func supportFamily() -> some WidgetConfiguration {
        if #available(macOS 14, *) {
            return self.supportedFamilies([.systemLarge, .systemMedium])
        } else {
            return self.supportedFamilies([.systemLarge, .systemMedium, .systemSmall])
        }
    }
}

@main
struct widgetBundle: WidgetBundle {
    var body: some Widget {
        widgets(usesBackground: false)
        widgets(usesBackground: true)
    }
    
    func widgets(usesBackground: Bool) -> some Widget {
        if #available(macOS 14, *) {
            return WidgetBundleBuilder.buildBlock(batteryWidget(usesBackground: usesBackground), batteryWidget2New(usesBackground: usesBackground), batteryWidget2(usesBackground: usesBackground), batteryWidget3(usesBackground: usesBackground))
        } else {
            return WidgetBundleBuilder.buildBlock(batteryWidget(usesBackground: usesBackground), batteryWidget2(usesBackground: usesBackground), batteryWidget3(usesBackground: usesBackground))
        }
    }
}

#if DEBUG
@available(macOS 14.0, *)
struct BatteryAppearancePreviews: PreviewProvider {
    private static let devices: [Device] = [
        Device(deviceID: "preview-mac", deviceType: "macbook", deviceName: "MacBook Pro", batteryLevel: 76, isCharging: 1, lastUpdate: Date().timeIntervalSince1970),
        Device(deviceID: "preview-phone", deviceType: "iphone", deviceName: "iPhone", batteryLevel: 42, isCharging: 0, lastUpdate: Date().timeIntervalSince1970),
        Device(deviceID: "preview-low", deviceType: "mouse", deviceName: "Mouse", batteryLevel: 8, isCharging: 0, lastUpdate: Date().timeIntervalSince1970),
        Device(deviceID: "preview-full", deviceType: "keyboard", deviceName: "Keyboard", batteryLevel: 100, isCharging: 1, lastUpdate: Date().timeIntervalSince1970)
    ]

    private static func entry(_ family: WidgetFamily) -> SimpleEntry {
        SimpleEntry(date: Date(), data: devices + devices, family: family, mainApp: true, deviceName: "")
    }

    static var previews: some View {
        Group {
            batteryWidgetEntryView(entry: entry(.systemSmall))
                .widgetBackground(Color("WidgetBackground"))
                .environment(\.widgetRenderingMode, .fullColor)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small • Full Color")
            batteryWidgetEntryView(entry: entry(.systemMedium))
                .widgetBackground(Color("WidgetBackground"))
                .environment(\.widgetRenderingMode, .accented)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium • Accented")
            batteryWidgetEntryView3(entry: entry(.systemSmall))
                .widgetBackground(Color("WidgetBackground"))
                .environment(\.widgetRenderingMode, .vibrant)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("No Percentage • Vibrant")
            batteryWidgetEntryView2(entry: entry(.systemLarge))
                .widgetBackground(Color("WidgetBackground"))
                .environment(\.colorScheme, .dark)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("List • Dark")
        }
    }
}
#endif
