import Foundation

// MARK: - WorkoutClassificationService
// 【Service 层｜训练动作分类与风险评估】
// 数据来源：所有业务数据均从后端 API 获取，不再包含本地硬编码映射。
// 保留 muscleSubGroupMap 用于 UI 下拉配置（非后端模拟数据）。
final class WorkoutClassificationService {

    // MARK: - 细分肌群映射（UI 配置数据，非后端模拟）

    /// 演示本地细分肌群库，供下拉选择器使用
    let muscleSubGroupMap: [MuscleGroup: [String]] = [
        .chest:      ["上胸", "中胸（厚度）", "下胸"],
        .back:       ["背阔肌", "斜方肌中下部", "菱形肌", "竖脊肌"],
        .legs:       ["股四头肌", "腘绳肌", "臀大肌", "小腿腓肠肌"],
        .shoulders:  ["前束", "中束", "后束"],
        .arms:       ["肱二头肌", "肱三头肌", "前臂肌群"],
        .core:       ["上腹", "下腹", "侧腹（腹斜肌）", "下背部核心"],
        .fullBody:   []
    ]

    // MARK: - 有氧子分类枚举

    enum AerobicSubType: String, CaseIterable {
        case steadyCardio = "匀速有氧"
        case hiit = "HIIT高强度间歇"
    }

    // MARK: - 体脂风险判定（依赖 Repository）

    /// 判断用户体脂率是否高于阈值（纯本地判断，不依赖 RAG 后端）
    func isHighBodyFat() -> Bool {
        return BodyDataRepository.isBodyFatAboveThreshold(30)
    }
}
