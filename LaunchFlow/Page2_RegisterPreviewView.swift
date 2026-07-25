import SwiftUI

// MARK: - Page2_RegisterPreviewView (注册方式预览)

/// 【设计规范】展示三种注册方式（Apple ID / 微信 / 手机号），注册已对接后端 MySQL。
struct Page2_RegisterPreviewView: View {

    // MARK: - Callbacks

    var onContinue: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            Spacer()

            // MARK: Title

            VStack(spacing: AppleGlassStyle.spacingSM) {
                Text("选择注册方式")
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppleGlassStyle.textPrimary)

                Text("请选择一种方式创建您的 FitQuant 账户")
                    .font(.subheadline)
                    .foregroundStyle(AppleGlassStyle.textSecondary)
            }
            .padding(.bottom, AppleGlassStyle.spacingLG)

            // MARK: Registration Buttons (thinMaterial card)

            VStack(spacing: AppleGlassStyle.spacingSM) {

                // Apple ID
                registerButton(
                    icon: "apple.logo",
                    title: "通过 Apple ID 注册",
                    subtitle: "安全登录，无需额外密码"
                )

                HDivider()

                // 微信
                registerButton(
                    iconName: "weixin_icon", // 自定义资产图标
                    title: "通过微信注册",
                    subtitle: "一键授权，快速登录"
                )

                HDivider()

                // 手机号
                registerButton(
                    icon: "phone.fill",
                    title: "通过手机号注册",
                    subtitle: "中国大陆 +86 号码注册"
                )
            }
            .padding(AppleGlassStyle.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium)
                    .fill(.thinMaterial)
            )
            .padding(.horizontal, AppleGlassStyle.spacingLG)

            Spacer()

            // MARK: Bottom Notice Bar (ultraThin)

            VStack(spacing: 4) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.caption)
                    .foregroundStyle(AppleGlassStyle.textTertiary)
                Text("登录注册已对接后端数据库 · 数据加密同步至服务器")
                    .font(.caption2)
                    .foregroundStyle(AppleGlassStyle.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppleGlassStyle.spacingLG)
            .padding(.vertical, AppleGlassStyle.spacingSM)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, AppleGlassStyle.spacingLG)
            .padding(.bottom, AppleGlassStyle.spacingMD)

            // MARK: Skip & Continue

            Button {
                onContinue()
            } label: {
                Text("暂不注册，直接体验")
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppleGlassStyle.accent)
            }
            .padding(.bottom, AppleGlassStyle.spacingLG)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppleGlassStyle.groupedBackground)
        .navigationBarBackButtonHidden()
    }

    // MARK: - View Components

    @ViewBuilder
    private func registerButton(icon: String, title: String, subtitle: String) -> some View {
        Button {
            // 预留：后续接入真实登录流程
            onContinue()
        } label: {
            HStack(spacing: AppleGlassStyle.spacingMD) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(AppleGlassStyle.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppleGlassStyle.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppleGlassStyle.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppleGlassStyle.textTertiary)
            }
            .padding(.vertical, AppleGlassStyle.spacingSM)
            .padding(.horizontal, AppleGlassStyle.spacingSM)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func registerButton(iconName: String, title: String, subtitle: String) -> some View {
        Button {
            onContinue()
        } label: {
            HStack(spacing: AppleGlassStyle.spacingMD) {
                Image(iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(AppleGlassStyle.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppleGlassStyle.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppleGlassStyle.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppleGlassStyle.textTertiary)
            }
            .padding(.vertical, AppleGlassStyle.spacingSM)
            .padding(.horizontal, AppleGlassStyle.spacingSM)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - HDivider (辅助组件)

/// 【设计规范】薄材料水平分割线，用于卡片内选项之间的分隔。
struct HDivider: View {
    var body: some View {
        Divider()
            .background(AppleGlassStyle.textTertiary.opacity(0.15))
            .padding(.horizontal, AppleGlassStyle.spacingSM)
    }
}
