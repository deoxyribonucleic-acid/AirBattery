//
//  SInfoButton.swift
//  AirBattery
//
//  Created by apple on 2024/10/28.
//

import SwiftUI

struct HoverButton<Content: View>: View {
    var color: Color = .primary
    var secondaryColor: Color = .blue
    var action: () -> Void
    @ViewBuilder let label: () -> Content
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: {
            action()
        }, label: {
            label().foregroundColor(isHovered ? secondaryColor : color)
        })
        .buttonStyle(.plain)
        .onHover(perform: { isHovered = $0 })
    }
}

struct SForm<Content: View>: View {
    var spacing: CGFloat = 30
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                content()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

struct SGroupBox<Content: View>: View {
    var label: LocalizedStringKey? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let label = label {
                Text(label).font(.headline).padding(.leading, 4)
            }
            VStack(spacing: 12) { content() }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color.primary.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07)))
        }
    }
}

struct SItem<Content: View>: View {
    var label: LocalizedStringKey? = nil
    var spacing: CGFloat = 8
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        HStack(spacing: spacing) {
            if let label = label { Text(label) }
            Spacer()
            content()
        }.frame(minHeight: 28)
    }
}

struct SDivider: View {
    var body: some View {
        Divider().opacity(0.5)
    }
}

struct SSlider: View {
    var label: LocalizedStringKey? = nil
    @Binding var value: Int
    var range: ClosedRange<Double> = 0...100
    var width: CGFloat = .infinity
    
    var body: some View {
        HStack {
            if let label = label {
                Text(label)
            }
            Spacer()
            Slider(value:
                    Binding(get: { Double(value) },
                            set: { newValue in
                let base: Int = Int(newValue.rounded())
                let modulo: Int = base % 1
                value = base - modulo
            }), in: range).frame(maxWidth: width)
        }.frame(minHeight: 28)
    }
}

struct SInfoButton: View {
    var tips: LocalizedStringKey
    @State private var isPresented: Bool = false
    
    var body: some View {
        Button(action: {
            isPresented = true
        }, label: {
            Image(systemName: "info.circle")
                .font(.system(size: 15, weight: .light))
                .opacity(0.5)
        })
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented) {
            VStack(alignment: .trailing) {
                GroupBox { Text(tips).padding() }
                Button(action: {
                    isPresented = false
                }, label: {
                    Text("OK").frame(width: 30)
                }).keyboardShortcut(.defaultAction)
            }.padding()
        }
    }
}

struct SButton: View {
    var title: LocalizedStringKey
    var buttonTitle: LocalizedStringKey
    var tips: LocalizedStringKey?
    var action: () -> Void
    
    init(_ title: LocalizedStringKey, buttonTitle: LocalizedStringKey, tips: LocalizedStringKey? = nil, action: @escaping () -> Void) {
        self.title = title
        self.buttonTitle = buttonTitle
        self.tips = tips
        self.action = action
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Spacer()
            if let tips = tips { SInfoButton(tips: tips) }
            Button(buttonTitle,
                   action: { action() })
                .airBatteryActionStyle()
        }.frame(minHeight: 28)
    }
}

struct SField: View {
    var title: LocalizedStringKey
    var placeholder: LocalizedStringKey
    var tips: LocalizedStringKey?
    @Binding var text: String
    var width: Double
    
    init(_ title: LocalizedStringKey, placeholder:LocalizedStringKey = "", tips: LocalizedStringKey? = nil, text: Binding<String>, width: Double = .infinity) {
        self.title = title
        self.placeholder = placeholder
        self.tips = tips
        self._text = text
        self.width = width
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Spacer()
            if let tips = tips { SInfoButton(tips: tips) }
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: width)
        }
    }
}

struct SPicker<T: Hashable, Content: View, Style: PickerStyle>: View {
    var title: LocalizedStringKey
    @Binding var selection: T
    var style: Style
    var tips: LocalizedStringKey?
    @ViewBuilder let content: () -> Content
    
    init(_ title: LocalizedStringKey, selection: Binding<T>, style: Style = .menu, tips: LocalizedStringKey? = nil, @ViewBuilder content: @escaping () -> Content) {
            self.title = title
            self._selection = selection
            self.style = style
            self.tips = tips
            self.content = content
        }
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let tips = tips { SInfoButton(tips: tips) }
            Picker(selection: $selection, content: { content() }, label: {})
                .fixedSize()
                .pickerStyle(style)
                .buttonStyle(.borderless)
        }.frame(minHeight: 28)
    }
}

struct SToggle: View {
    var title: LocalizedStringKey
    @Binding var isOn: Bool
    var tips: LocalizedStringKey?
    
    init(_ title: LocalizedStringKey, isOn: Binding<Bool>, tips: LocalizedStringKey? = nil) {
        self.title = title
        self._isOn = isOn
        self.tips = tips
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Spacer()
            if let tips = tips { SInfoButton(tips: tips) }
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .accessibilityLabel(Text(title))
        }.frame(minHeight: 28)
    }
}

struct SSteper: View {
    var title: LocalizedStringKey
    @Binding var value: Int
    var min: Int
    var max: Int
    var width: CGFloat
    var tips: LocalizedStringKey?
    
    init(_ title: LocalizedStringKey, value: Binding<Int>, min: Int = 0, max: Int = 100, width: CGFloat = 45, tips: LocalizedStringKey? = nil) {
        self.title = title
        self._value = value
        self.tips = tips
        self.width = width
        self.min = min
        self.max = max
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Text(title)
            Spacer()
            if let tips = tips {
                SInfoButton(tips: tips)
                    .padding(.trailing, 2)
            }
            TextField("", value: $value, formatter: NumberFormatter())
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: width)
                .onChange(of: value) { newValue in
                    if newValue > max { value = max }
                    if newValue < min { value = min }
                }
            Stepper("", value: $value)
                .padding(.leading, -6)
        }.frame(minHeight: 28)
    }
}

// Shared floating surfaces. System material handles contrast and transparency;
// content cards deliberately use a quieter fill rather than stacked glass.
struct AirBatteryPanelSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(NSColor.windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content.background(BlurView(material: .popover))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

extension View {
    func airBatteryPanel(cornerRadius: CGFloat = 20) -> some View {
        modifier(AirBatteryPanelSurface(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    func airBatteryActionStyle(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent { buttonStyle(.glassProminent) }
            else { buttonStyle(.glass) }
        } else if #available(macOS 12.0, *) {
            if prominent { buttonStyle(.borderedProminent) }
            else { buttonStyle(.bordered) }
        } else {
            buttonStyle(.bordered)
        }
    }
}
