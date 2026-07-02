import SwiftUI

struct SettingsRow: View {
    let sfIcon: String
    let label: String
    var value: String? = nil
    var iconBg: Color = Color(hex: "F5F2EE")
    var iconColor: Color = Color(hex: "7A756E")
    var isDestructive: Bool = false
    var toggle: Binding<Bool>? = nil
    var showChevron: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: sfIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDestructive ? Color(hex: "FF5252") : iconColor)
                    .frame(width: 32, height: 32)
                    .background(isDestructive ? Color(hex: "FFECEC") : iconBg)
                    .cornerRadius(9)

                Text(label)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(isDestructive ? Color(hex: "FF5252") : Color(hex: "1E1C1A"))

                Spacer()

                if let value = value {
                    Text(value)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "7A756E"))
                }

                if let toggle = toggle {
                    Toggle("", isOn: toggle)
                        .labelsHidden()
                        .tint(Color(hex: "FFD93D"))
                } else if showChevron && !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "B8B3AC"))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }
}
