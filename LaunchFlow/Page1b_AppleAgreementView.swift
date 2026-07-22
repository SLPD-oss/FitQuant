import SwiftUI

// MARK: - Page1b_AppleAgreementView (Apple 平台合规及隐私协议)

/// 【合规红线：苹果政策协议勾选】
/// 全屏展示 Apple 平台合规文件，用户必须勾选复选框后方可继续。
struct Page1b_AppleAgreementView: View {

    // MARK: - State

    @State private var isChecked: Bool = false

    /// 持久化存储 Apple 政策协议已读状态
    @AppStorage("agreedApplePolicy") private var agreedApplePolicy: Bool = false

    // MARK: - Callbacks

    var onContinue: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: AppleGlassStyle.spacingLG) {

            // MARK: Header

            VStack(spacing: AppleGlassStyle.spacingSM) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 48))
                    .foregroundStyle(AppleGlassStyle.textPrimary)

                Text("Apple 平台合规及隐私协议")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppleGlassStyle.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, AppleGlassStyle.spacingLG)

            // MARK: Scrollable Content

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: AppleGlassStyle.spacingLG) {

                    // MARK: App Store 1.4.1

                    sectionCard(title: "App Store 审核准则 1.4.1") {
                        Text("根据 App Store 审核准则第 1.4.1 条，所有提供医疗或健康相关建议的应用程序必须包含免责声明，明确告知用户该应用不能替代专业医疗诊断、治疗或处方。本应用严格遵守此规定。")
                            .font(.footnote)
                            .foregroundStyle(AppleGlassStyle.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // MARK: Privacy Policy

                    sectionCard(title: "隐私政策与数据保护") {
                        VStack(alignment: .leading, spacing: 8) {
                            privacyBullet("用户健康数据（包括但不限于心率、步数、体重、体脂率等）将严格遵循 Apple 隐私保护框架进行处理。")
                            privacyBullet("所有敏感健康数据默认存储在设备本地安全区，应用不会在未经用户明确授权的情况下将健康数据上传至任何第三方服务器。")
                            privacyBullet("本应用的隐私实践符合 App Store 隐私标签 (Privacy Nutrition Label) 的披露要求。")
                        }
                    }

                    // MARK: HealthKit

                    sectionCard(title: "HealthKit 声明") {
                        VStack(alignment: .leading, spacing: 8) {
                            privacyBullet("本应用可能请求访问 Apple HealthKit 数据，以提供个性化的运动与健康分析服务。")
                            privacyBullet("您可以在「设置 > 隐私与安全性 > 健康」中随时管理 HealthKit 数据访问权限。")
                            privacyBullet("未经用户主动授权，本应用不会读取或写入任何 HealthKit 数据。")
                        }
                    }

                    // MARK: User Rights

                    sectionCard(title: "用户权利") {
                        VStack(alignment: .leading, spacing: 8) {
                            privacyBullet("知情权：您有权知晓应用收集、使用和存储您个人数据的方式和目的。")
                            privacyBullet("访问权：您可以随时通过应用设置页面查看和管理已存储的个人数据。")
                            privacyBullet("删除权：您可以随时请求删除存储在应用中的所有个人数据，删除操作将立即生效。")
                            privacyBullet("撤回同意权：您有权在任何时候撤回对数据处理和隐私条款的同意。")
                        }
                    }
                }
                .padding(.horizontal, AppleGlassStyle.spacingLG)
            }

            // MARK: Bottom – Checkbox + Continue

            VStack(spacing: AppleGlassStyle.spacingMD) {

                // 勾选框
                Button {
                    isChecked.toggle()
                } label: {
                    HStack(spacing: AppleGlassStyle.spacingSM) {
                        Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                            .font(.title3)
                            .foregroundStyle(isChecked ? AppleGlassStyle.accent : AppleGlassStyle.textTertiary)

                        Text("我已仔细阅读并同意以上全部条款")
                            .font(.subheadline)
                            .foregroundStyle(AppleGlassStyle.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                // 继续按钮
                Button {
                    agreedApplePolicy = true
                    onContinue()
                } label: {
                    Text("同意并继续")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppleGlassStyle.spacingMD)
                        .background(
                            RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium)
                                .fill(isChecked ? AppleGlassStyle.accent : AppleGlassStyle.accent.opacity(0.4))
                        )
                }
                .disabled(!isChecked)
                .padding(.horizontal, AppleGlassStyle.spacingLG)
            }
            .padding(.bottom, AppleGlassStyle.spacingLG)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppleGlassStyle.groupedBackground)
        .interactiveDismissDisabled()
        .navigationBarBackButtonHidden()
    }

    // MARK: - View Components

    @ViewBuilder
    private func sectionCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: AppleGlassStyle.spacingSM) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppleGlassStyle.textPrimary)

            content()
        }
        .padding(AppleGlassStyle.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium)
                .fill(.thinMaterial)
        )
    }

    @ViewBuilder
    private func privacyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: AppleGlassStyle.spacingXS) {
            Text("•")
                .foregroundStyle(AppleGlassStyle.accent)
            Text(text)
                .font(.footnote)
                .foregroundStyle(AppleGlassStyle.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
