import Foundation

// MARK: - DrugClassificationService
// 【Service 层｜药品关键词识别与自动分类】
// 职责：根据输入的药品名称，自动匹配本地关键词库识别药品分类。
// 设计逻辑：原先 AddDrugSheet 视图内嵌了 30+ 条药品关键词和自动分类方法，
// 现独立为 Service。输入药品名 → 返回 DrugCategory 枚举。
// 远期替换：后端 RAG 药物识别 API 上线后，可替换本地映射为网络请求。
final class DrugClassificationService {

    // MARK: - 本地药物识别关键词库

    /// 演示阶段本地药物识别关键词库，后期可替换为后端 RAG 识别接口返回数据
    /// TabA = 非处方药、无/轻微运动损伤风险
    /// TabB = 处方药、循证医学确认显著提升肌腱撕裂等运动损伤风险
    private let drugKeywordMap: [String: DrugCategory] = [
        // 中药（traditionalChMedicine）
        "六味地黄丸": .traditionalChMedicine, "逍遥丸": .traditionalChMedicine,
        "丹参": .traditionalChMedicine, "黄芪": .traditionalChMedicine,
        "板蓝根": .traditionalChMedicine, "金银花": .traditionalChMedicine,
        "连花清瘟": .traditionalChMedicine, "藿香正气": .traditionalChMedicine,
        "牛黄": .traditionalChMedicine, "川贝": .traditionalChMedicine,
        "三七": .traditionalChMedicine, "当归": .traditionalChMedicine,
        // TabA 非处方药（低/无运动损伤风险）
        "布洛芬": .typeA, "对乙酰氨基酚": .typeA,
        "扑热息痛": .typeA, "蒙脱石散": .typeA,
        "氯雷他定": .typeA, "西替利嗪": .typeA,
        "碳酸钙": .typeA, "维生素C": .typeA,
        "维生素B": .typeA, "复合维生素": .typeA,
        "益生菌": .typeA, "葡糖胺": .typeA,
        // TabB 处方药（循证医学证实高肌腱损伤风险）
        "左氧氟沙星": .typeB, "氧氟沙星": .typeB,
        "环丙沙星": .typeB, "莫西沙星": .typeB,
        "诺氟沙星": .typeB, "依诺沙星": .typeB,
        "洛美沙星": .typeB, "氟罗沙星": .typeB,
        "司帕沙星": .typeB, "加替沙星": .typeB,
        "阿托伐他汀": .typeB, "辛伐他汀": .typeB,
        "泼尼松": .typeB, "地塞米松": .typeB,
    ]

    // MARK: - 自动分类

    /// 根据药品名称自动识别药品分类
    /// - Parameter drugName: 用户输入的药品名称
    /// - Returns: 匹配到的 DrugCategory，无匹配时返回 nil
    /// - Note: 预留 RAG 接口适配层，上层视图无需感知数据源为本地还是后端
    func autoDetectMedicationType(drugName: String) -> DrugCategory? {
        let trimmed = drugName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // 本地关键词精确匹配
        if let matched = drugKeywordMap[trimmed] {
            return matched
        }
        // 本地关键词模糊匹配（包含任一关键词即命中）
        for (keyword, cat) in drugKeywordMap {
            if trimmed.contains(keyword) {
                return cat
            }
        }
        // 无匹配 → 返回 nil，由调用方保持当前分类不变
        // 远期替换流程：① 调用后端 RAG 药物识别 API → ② 获取返回分类枚举 → ③ return 分类
        return nil
    }
}
