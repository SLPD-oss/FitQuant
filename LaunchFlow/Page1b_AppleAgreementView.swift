import SwiftUI

// MARK: - Page1b_AppleAgreementView (Apple 平台合规及隐私协议)

/// 【合规红线：苹果政策协议勾选】
/// 全屏展示 Apple 平台合规文件，用户必须勾选复选框后方可继续。
struct Page1b_AppleAgreementView: View {

    // MARK: - State

    @State private var isChecked: Bool = false

    /// 持久化存储 Apple 政策协议已读状态
    @AppStorage("agreedApplePolicy") private var agreedApplePolicy: Bool = false
    /// 【合规整改｜协议版本化】记录用户确认的 Apple 协议版本号（与 RootView.agreementVersion 比对）
    @AppStorage("agreedApplePolicyVersion") private var agreedApplePolicyVersion: String = ""

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
                            // 【合规整改｜上传口径统一】原表述"不会上传至任何第三方服务器"与代码实际上传行为不符（sync/batch、/api/body、/api/sleep/records）。
                            // 依据《个人信息保护法》第 17 条"真实、准确、完整告知"，如实披露上传事实并声明不向第三方共享。
                            privacyBullet("您的账号信息（手机号、昵称、身份）与健康记录（身体数据、训练、饮食、用药、睡眠记录）将上传至开发者服务器用于跨设备同步与备份。开发者服务器部署于受控环境，未经您明确授权，不会向任何第三方提供、出售或共享您的个人数据。同步失败时数据保留在设备本地，联网后自动重试。")
                            // 【合规整改｜收集清单】依据个保法第 17 条列明收集种类、处理目的、处理方式
                            privacyBullet("我们收集并处理以下个人信息：① 账号信息：手机号（注册必填）、昵称、训练身份、设备标识；② 身体数据：身高、体重、年龄、腰围、颈围、体脂率等；③ 健康记录：训练记录、饮食记录、用药记录、睡眠数据（时长、HRV、静息心率）；④ 使用数据：当日补剂摄入、热量缺口设置。以上信息用于提供记录、统计与循证参考功能。")
                            // 【合规整改｜敏感信息单独告知】依据个保法第 28-29 条，心率/体脂/睡眠属敏感个人信息
                            privacyBullet("敏感个人信息特别告知：心率、体脂率、睡眠恢复数据属于敏感个人信息。我们仅在您主动录入或授权时处理，用于运动风险提示与恢复状态参考，处理必要性限于实现上述功能。您可随时在应用内删除相应记录或撤回授权。")
                            // 【会话级授权合规】心率权限说明：临时授权、退出即清除、不持久化存储
                            privacyBullet("实时心率采集采用会话级临时授权：授权仅在本次 App 运行期间有效，App 完全退出后授权记忆自动清除，不在设备本地磁盘持久存储用户的授权选择；每次新的运行周期需重新获取用户授权。")
                            privacyBullet("本应用的隐私实践符合 App Store 隐私标签 (Privacy Nutrition Label) 的披露要求。")
                        }
                    }

                    // MARK: HealthKit

                    sectionCard(title: "HealthKit 声明") {
                        VStack(alignment: .leading, spacing: 8) {
                            // 【合规整改｜HealthKit 声明修正】代码核实未集成 HKHealthStore，原"可能请求访问 HealthKit"与实现不符，改为如实声明
                            privacyBullet("本应用当前版本未接入 Apple HealthKit，不读取或写入任何健康数据到 Apple 健康 App。若未来版本接入 HealthKit，将提前更新本政策并取得您的单独授权。")
                        }
                    }

                    // MARK: User Rights

                    sectionCard(title: "用户权利") {
                        VStack(alignment: .leading, spacing: 8) {
                            privacyBullet("知情权：您有权知晓应用收集、使用和存储您个人数据的方式和目的。")
                            privacyBullet("访问权：您可以随时通过应用设置页面查看和管理已存储的个人数据。")
                            // 【合规整改｜删除权落地】补充云端数据删除渠道与时限（个保法第 47 条）
                            privacyBullet("删除权：您可删除应用内记录；请求删除云端数据请通过应用内意见反馈或联系我们，我们将在 15 个工作日内完成删除并停止处理。")
                            // 【合规整改｜撤回同意规则】补充撤回后的处理规则（个保法第 15-16 条）
                            privacyBullet("撤回同意权：您有权在任何时候撤回对数据处理和隐私条款的同意。撤回后我们将停止收集，但撤回前基于同意的处理仍合法有效。")
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
                    // 【合规整改｜协议版本化】写入当前协议版本号，与 RootView.agreementVersion 比对
                    agreedApplePolicyVersion = RootView.agreementVersion
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
