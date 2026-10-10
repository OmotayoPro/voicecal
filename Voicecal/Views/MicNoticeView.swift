import SwiftUI

/// Inline explanation shown when voice input cannot start. Never a modal.
struct MicNoticeView: View {
    let notice: MicNotice
    let onDismiss: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.section) {
            Text(notice.message)
                .font(DesignTokens.Typography.notice)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if notice.canOpenSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") {
                    openURL(url)
                }
                .font(DesignTokens.Typography.notice.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.primaryDefault)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(DesignTokens.Typography.notice.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary.opacity(DesignTokens.Opacity.secondaryText))
                    .frame(width: DesignTokens.Size.minTapTarget, height: DesignTokens.Size.minTapTarget)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, DesignTokens.Spacing.screenHorizontal)
        .frame(minHeight: DesignTokens.Size.minTapTarget)
        .background(
            DesignTokens.Colors.tertiaryDefault,
            in: RoundedRectangle(cornerRadius: DesignTokens.Size.chipRadius)
        )
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    VStack {
        MicNoticeView(notice: .microphoneDenied, onDismiss: {})
        MicNoticeView(notice: .unavailable, onDismiss: {})
    }
    .padding()
    .background(DesignTokens.Colors.surface)
}
