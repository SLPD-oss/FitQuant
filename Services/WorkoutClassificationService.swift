import Foundation

// MARK: - WorkoutClassificationService
// 【Service 层｜训练动作分类与风险评估】
// 职责：封装与训练动作相关的业务规则，包括：
// - 有氧动作分类（匀速有氧 vs HIIT）
// - 高危手腕动作识别（TFCC 风险）
// - 跑步机设备识别
// - 细分肌群映射
// - 体脂率判断（依赖 BodyDataRepository）
// 设计逻辑：所有规则集中原先散落在 TrainView 中的内联属性和方法，
// 现统一由本 Service 管理。TrainView 不再直接持有这些 Key-Value 映射。
// 远期替换：后端 RAG 运动数据库上线后，可替换内部映射为 API 调用，
// 上层 ViewModel/View 的接口签名保持不变。
final class WorkoutClassificationService {

    // MARK: - 有氧动作分类映射（本地关键词 → 匀速有氧 / HIIT）

    /// 演示阶段本地动作识别库，后期可替换后端 RAG 运动动作权威分类数据
    private let localAerobicActionMap: [String: AerobicSubType] = [
        // 匀速有氧（低关节/低手腕承压）
        "跑步机": .steadyCardio, "椭圆机": .steadyCardio,
        "动感单车": .steadyCardio, "划船机": .steadyCardio,
        "慢跑": .steadyCardio, "快走": .steadyCardio,
        "骑行": .steadyCardio, "游泳": .steadyCardio,
        // HIIT 高强度间歇（部分动作手腕承压有 TFCC 风险）
        "登山跑": .hiit, "平板支撑": .hiit,
        "俯身登山": .hiit, "熊爬": .hiit,
        "波比跳": .hiit, "开合跳": .hiit,
        "高抬腿": .hiit, "深蹲跳": .hiit,
        "箭步蹲跳": .hiit, "徒手箭步蹲": .hiit,
        "战绳": .hiit, "壶铃摆荡": .hiit,
    ]

    // MARK: - 高危手腕 HIIT 动作集合（TFCC 风险）

    /// 识别登山跑、平板支撑类手腕承压动作，标记 TFCC 高风险动作
    private let highRiskWristHiitActions: Set<String> = [
        "登山跑", "平板支撑", "俯身登山", "熊爬", "侧平板支撑", "俯卧撑"
    ]

    // MARK: - 跑步机关键词

    private let treadmillKeywords: Set<String> = ["跑步机", "慢跑", "快走"]

    // MARK: - 细分肌群映射

    /// 前端演示本地细分肌群库，预留 RAG 运动肌群数据库替换注释
    let muscleSubGroupMap: [MuscleGroup: [String]] = [
        .chest:      ["上胸", "中胸（厚度）", "下胸"],
        .back:       ["背阔肌", "斜方肌中下部", "菱形肌", "竖脊肌"],
        .legs:       ["股四头肌", "腘绳肌", "臀大肌", "小腿腓肠肌"],
        .shoulders:  ["前束", "中束", "后束"],
        .arms:       ["肱二头肌", "肱三头肌", "前臂肌群"],
        .core:       ["上腹", "下腹", "侧腹（腹斜肌）", "下背部核心"],
        .fullBody:   []  // 全身综合训练无细分肌群
    ]

    // MARK: - 有氧子分类枚举

    enum AerobicSubType: String, CaseIterable {
        case steadyCardio = "匀速有氧"
        case hiit = "HIIT高强度间歇"
    }

    // MARK: - 动作分类识别

    /// 匹配本地关键词识别有氧子分类
    /// - Parameter actionName: 用户输入的动作名称
    /// - Returns: 匹配到的有氧子分类，无法识别时返回 nil
    func detectAerobicSubType(actionName: String) -> AerobicSubType? {
        let trimmed = actionName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // 精确匹配优先
        if let matched = localAerobicActionMap[trimmed] { return matched }
        // 模糊匹配（包含任一关键词即命中）
        for (keyword, subType) in localAerobicActionMap {
            if trimmed.contains(keyword) { return subType }
        }
        return nil
    }

    // MARK: - 高危动作判定

    /// 判定当前输入动作是否为高危手腕 HIIT 动作（登山跑、平板支撑等撑地动作）
    func isHighRiskWristHiitAction(actionName: String) -> Bool {
        let trimmed = actionName.trimmingCharacters(in: .whitespaces)
        for keyword in highRiskWristHiitActions {
            if trimmed.contains(keyword) { return true }
        }
        return false
    }

    // MARK: - 设备识别

    /// 识别动作名称是否涉及跑步机类设备
    func isTreadmillDevice(actionName: String) -> Bool {
        let trimmed = actionName.trimmingCharacters(in: .whitespaces)
        for keyword in treadmillKeywords {
            if trimmed.contains(keyword) { return true }
        }
        return false
    }

    // MARK: - 体脂风险判定（依赖 Repository）

    /// 判断用户体脂率是否高于阈值（纯本地判断，不依赖 RAG 后端）
    /// 阈值本地演示写死，后期由后端 RAG 库下发循证医学标准阈值
    func isHighBodyFat() -> Bool {
        return BodyDataRepository.isBodyFatAboveThreshold(30)
    }
}
