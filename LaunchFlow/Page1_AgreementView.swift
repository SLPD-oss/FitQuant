import SwiftUI

// MARK: - Page1_AgreementView (中国大陆用户法律及免责协议)

/// 【合规红线：中国大陆法定协议强制勾选】
/// 全屏展示中国大陆地区法律合规文件，用户必须勾选复选框后方可继续。
struct Page1_AgreementView: View {

    // MARK: - State

    @State private var isChecked: Bool = false

    /// 持久化存储协议已读状态
    @AppStorage("agreedLocalLaw") private var agreedLocalLaw: Bool = false
    /// 【合规整改｜协议版本化】记录用户确认的大陆协议版本号（与 RootView.agreementVersion 比对）
    @AppStorage("agreedLocalLawVersion") private var agreedLocalLawVersion: String = ""

    // MARK: - Callbacks

    var onContinue: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: AppleGlassStyle.spacingLG) {

            // MARK: Header

            VStack(spacing: AppleGlassStyle.spacingSM) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppleGlassStyle.accent)

                Text("中国大陆地区用户法律及免责协议")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppleGlassStyle.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, AppleGlassStyle.spacingLG)

            // MARK: Scrollable Content

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: AppleGlassStyle.spacingLG) {

                    // MARK: Section A – 法律法规依据

                    sectionCard(title: "A. 适用法律法规") {
                        lawItem("《中华人民共和国网络安全法》—— 网络运营者应当采取技术措施和其他必要措施，保障网络免受干扰、破坏或者未经授权的访问，防止网络数据泄露或者被窃取、篡改。")
                        lawItem("《中华人民共和国个人信息保护法》—— 处理个人信息应当遵循合法、正当、必要和诚信原则，不得通过误导、欺诈、胁迫等方式处理个人信息。")
                        lawItem("《中华人民共和国数据安全法》—— 数据处理活动应当遵守法律法规，建立健全全流程数据安全管理制度，采取相应技术措施保障数据安全。") // 【合规整改】补充《数据安全法》引用
                        lawItem("《中华人民共和国消费者权益保护法》—— 消费者享有知悉其购买、使用的商品或者接受的服务的真实情况的权利。")
                        lawItem("《互联网信息服务管理办法》—— 互联网信息服务提供者不得制作、复制、发布、传播含有法律、行政法规禁止的内容。")
                        // 【合规整改｜协议一致性】两协议交叉引用，避免用户只细读其一导致告知不完整
                        lawItem("本协议与《Apple 平台合规及隐私协议》共同构成完整合规文件；关于个人信息的收集、使用、存储与共享规则，以《Apple 平台合规及隐私协议》为准。")
                    }

                    // MARK: Section B – 免责声明

                    sectionCard(title: "B. 免责声明") {
                        disclaimerItem(
                            "ACSM / 公开循证文献免责声明",
                            "本应用所提供的运动建议与健康数据参考，均基于美国运动医学会 (ACSM) 及其他公开循证文献发表的指导性文件。相关内容仅供教育及参考用途，不构成医疗诊断、处方或治疗方案。在开始任何新的运动计划或饮食方案之前，您应当咨询持有执照的医师或注册营养师。"
                        )
                        disclaimerItem(
                            "AI 误差声明",
                            "\(ComplianceText.alertDisclaimerPrefix) 本应用中由人工智能模块生成的分析结果、训练建议及营养方案可能存在误差或偏差。AI 输出不应替代专业教练、营养师或医疗人员的个性化判断。用户应当结合自身实际情况审慎采纳。"
                        )
                        disclaimerItem(
                            "药物关联声明",
                            "若您正在服用处方药物、非处方药物或膳食补充剂，其代谢与运动方案之间可能存在相互作用。请务必在调整训练或饮食计划前咨询您的处方医师，切勿自行更改用药方案。"
                        )
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
                    agreedLocalLaw = true
                    // 【合规整改｜协议版本化】写入当前协议版本号，与 RootView.agreementVersion 比对
                    agreedLocalLawVersion = RootView.agreementVersion
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
    private func lawItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: AppleGlassStyle.spacingXS) {
            Text("•")
                .foregroundStyle(AppleGlassStyle.accent)
            Text(text)
                .font(.footnote)
                .foregroundStyle(AppleGlassStyle.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func disclaimerItem(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppleGlassStyle.textPrimary)
            Text(body)
                .font(.footnote)
                .foregroundStyle(AppleGlassStyle.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}
