import SwiftUI

//【合规强制红线：弹窗必加医疗免责前缀，禁止删除】

/// 全局通用弹窗组件 — 超薄液态玻璃外壳 + 强制免责前缀
struct CommonAlert: View {
    let title: String
    let message: String
    var confirmTitle: String = "确认"
    var showCancel: Bool = true
    var onConfirm: () -> Void
    var onCancel: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            disclaimerBar
            contentCard
        }
        .padding(.horizontal, AppleGlassStyle.spacingMD)
    }

    private var disclaimerBar: some View {
        HStack(spacing: AppleGlassStyle.spacingXS) {                                           //【已修复】AppleGlassStyle.Spacing.xs → spacingXS
            Image(systemName: "info.circle")
                .font(.caption2)
            Text(ComplianceText.alertDisclaimerPrefix)
                .font(.caption2)
            Spacer()
        }
        .foregroundColor(AppleGlassStyle.textTertiary)                                          //【已修复】AppleGlassStyle.Colors.textTertiary → textTertiary
        .padding(.horizontal, AppleGlassStyle.spacingSM)                                        //【已修复】AppleGlassStyle.Spacing.sm → spacingSM
        .padding(.vertical, AppleGlassStyle.spacingXS)                                          //【已修复】AppleGlassStyle.Spacing.xs → spacingXS
        .background(AppleGlassStyle.ultraThin)                                                  //【已修复】AppleGlassStyle.Material.ultraThin → ultraThin
    }

    private var contentCard: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {                                            //【已修复】AppleGlassStyle.Spacing.sm → spacingSM
            Text(title)
                .font(.headline)
                .foregroundColor(AppleGlassStyle.textPrimary)                                   //【已修复】AppleGlassStyle.Colors.textPrimary → textPrimary

            Text(message)
                .font(.body)
                .foregroundColor(AppleGlassStyle.textSecondary)                                 //【已修复】AppleGlassStyle.Colors.textSecondary → textSecondary
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.horizontal, -AppleGlassStyle.spacingSM)                               //【已修复】AppleGlassStyle.Spacing.sm → spacingSM

            HStack(spacing: 0) {
                if showCancel {
                    Button(action: { onCancel?() }) {
                        Text("取消")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(AppleGlassStyle.textSecondary)                             //【已修复】AppleGlassStyle.Colors.textSecondary → textSecondary
                }

                if showCancel {
                    Rectangle()
                        .fill(AppleGlassStyle.textTertiary)                                     //【已修复】AppleGlassStyle.Colors.textTertiary → textTertiary
                        .frame(width: 0.5, height: 24)
                }

                Button(action: onConfirm) {
                    Text(confirmTitle)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .foregroundColor(AppleGlassStyle.accent)                                        //【已修复】AppleGlassStyle.Colors.accent → accent
            }
            .padding(.top, AppleGlassStyle.spacingXS)                                           //【已修复】AppleGlassStyle.Spacing.xs → spacingXS
        }
        .padding(AppleGlassStyle.spacingSM)                                                     //【已修复】AppleGlassStyle.Spacing.sm → spacingSM
        .background(AppleGlassStyle.standard)                                                   //【已修复】AppleGlassStyle.Material.standard → standard
        .clipShape(RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))          //【已修复】AppleGlassStyle.CornerRadius.medium → cornerRadiusMedium
    }
}

// MARK: - View Extension

extension View {
    func commonAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String = "确认",
        showCancel: Bool = true,
        onConfirm: @escaping () -> Void = {},
        onCancel: (() -> Void)? = nil
    ) -> some View {
        ZStack {
            self
            if isPresented.wrappedValue {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { /* 阻止点击穿透 */ }
                    .transition(.opacity)

                CommonAlert(
                    title: title,
                    message: message,
                    confirmTitle: confirmTitle,
                    showCancel: showCancel,
                    onConfirm: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isPresented.wrappedValue = false
                        }
                        onConfirm()
                    },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isPresented.wrappedValue = false
                        }
                        onCancel?()
                    }
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented.wrappedValue)
    }
}

#Preview {
    CommonAlert(
        title: "参考提示",
        message: "根据您输入的身体数据，您的 BMI 处于超重筛查区间。这只是群体统计学意义上的参考数值，不构成健康评估。",
        confirmTitle: "我知道了",
        showCancel: true,
        onConfirm: {},
        onCancel: {}
    )
}
