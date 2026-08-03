import SwiftUI

// MARK: - ComplianceText (View)
// A dedicated view that renders legal/compliance disclaimers
// with ultraThin glass background and subdued styling.
// Used throughout the app to meet regulatory annotation requirements.

struct ComplianceText: View {
    let text: String
    var showIcon: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: AppleGlassStyle.spacingSM) {
            if showIcon {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppleGlassStyle.textTertiary)
            }
            Text(text)
                .font(.caption2)
                .foregroundStyle(AppleGlassStyle.textTertiary)
                .multilineTextAlignment(.leading)
        }
        .padding(AppleGlassStyle.spacingSM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppleGlassStyle.ultraThin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
    }
}

// MARK: - ComplianceText.Strings (static disclaimers)
// Pre-existing static string constants for backwards compatibility.

extension ComplianceText {
    static let alertDisclaimerPrefix = "本内容为公开循证文献健身参考，不构成任何医疗诊疗、用药、膳食医嘱建议"
    static let footerDisclaimer = "本应用所提供之健身、营养及健康管理内容均基于公开发表的循证文献，仅供具备相应资质的从业者及理性消费者参阅。任何训练方案、膳食建议、体成分评估均不构成医疗诊疗行为，亦不可替代执业医师、注册营养师或其他法定健康专业人士的当面诊断与治疗。使用者应自行评估自身健康状况，必要时于启动任何训练或饮食调整前咨询合格医疗服务提供者。本应用开发者不承担因使用本内容所引发的任何直接或间接损失或伤害。"
    static let bodyFatDisclaimer = "体脂率估算基于生物电阻抗分析（BIA）或其他公开算法，结果受水合状态、进食时间、皮肤温度及测量姿态等多因素影响。该数值仅供趋势追踪参考，不应作为临床诊断依据。"
    static let foodScanDisclaimer = "食物识别与营养成分估算依赖图像识别算法与公开食品数据库交叉比对，可能存在误差。对于有严格宏量营养素控制需求的使用者，建议结合食品包装标示值或实验室检测数据进行校准。"
    static let supplementDisclaimer = "运动营养补剂信息源于公开发表的科学文献综述，不构成产品推荐或处方。补剂使用应遵循属地法规，并优先咨询注册营养师或运动医学医师。"
    static let trainingDisclaimer = "训练方案基于运动科学通用原则编制，未考虑个体解剖变异、陈旧性损伤或潜在心血管风险。使用者在执行任何训练动作前应确保技术准确并评估自身承受能力。"
    static let legalRegulations = "本应用内容遵守中华人民共和国相关法律法规。用户生成内容由发布者自行承担法律责任。如发现侵权或违规内容，请联系开发者进行处理。"
    static let ageRestriction = "本应用面向年满18周岁的成年使用者。未成年人应在监护人知情并同意的前提下使用，且训练方案须经专业教练现场指导评估后执行。"

    static let drugDisclaimer = "【合规隔离红线】药品/补剂信息仅作个人记录用途，不构成任何用药建议。请在专业医师指导下使用任何药品或补剂。"
    /// 注：用药模块现支持云端备份同步，文案已与真实行为对齐（不再承诺「仅本地存储」）
    static let localOnlyDisclaimer = "【合规隔离红线】用药记录将同步至您绑定的云端服务器用于数据备份，不涉及任何远程医疗或在线诊疗功能。"
    static let dietDisclaimer = "【合规隔离红线】饮食数据仅作个人记录，不构成营养建议。"
    static let trainDisclaimer = "【合规红线】训练数据仅作个人记录用途。本应用不提供个性化训练计划或健康指导。"
}

// MARK: - Preview
#Preview {
    VStack(spacing: 12) {
        ComplianceText(text: "以上内容仅供参考，不构成医疗建议。使用前请咨询专业医师。")
        ComplianceText(text: "数据仅存储在本地设备，不会上传至任何服务器。", showIcon: false)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
