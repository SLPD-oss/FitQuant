import Foundation

// MARK: - DrugRiskService
// 【Service 层｜药物-训练风险校验】
// 职责：检测当前正在服用的药品中是否包含高风险药物，
// 尤其是喹诺酮类抗生素（肌腱损伤高风险）。
// 设计逻辑：原先 GlobalViewManager 同时管理 UI 身份 + Tab 导航 + 药物风险三项职责，
// 根据单一职责原则，药物风险校验独立为此 Service。
// DrugDataManager 中的 quinoloneBlacklist 也一并迁移至此。
// 远期兼容：后端第一套「药物↔训练 RAG 库」搭建后，
// 可替换此本地黑名单为 RAG 库下发的权威数据，上层调用方无需改动。
final class DrugRiskService {

    // MARK: - 单例

    /// 本 Service 不持有可变状态，因此使用共享实例而非强制单例，
    /// 调用方也可以按需创建新实例。
    static let shared = DrugRiskService()
    private init() {}

    // MARK: - 喹诺酮类抗生素本地黑名单

    /// 肌腱损伤高风险药物列表（喹诺酮类抗生素）
    /// 当用户正在服用列表中任一药物时，训练页应弹出肌腱损伤风险提示
    private let quinoloneBlacklist: Set<String> = [
        "左氧氟沙星",
        "氧氟沙星",
        "环丙沙星",
        "莫西沙星",
        "诺氟沙星",
        "依诺沙星",
        "洛美沙星",
        "氟罗沙星",
        "司帕沙星",
        "加替沙星"
    ]

    // MARK: - 风险判定

    /// 检测当前是否有高风险肌腱损伤药物正在服用
    /// 遍历所有 status != .stopped 的药品，匹配喹诺酮黑名单
    /// - Returns: true 表示存在高风险药物，训练页应触发弹窗警告
    /// - Note: 从 DrugDataManager.shared.records 读取当前用药记录
    func hasHighTendonRiskMedication() -> Bool {
        let activeDrugs = DrugDataManager.shared.records.filter { $0.status != .stopped }
        for drug in activeDrugs {
            for quinolone in quinoloneBlacklist {
                if drug.drugName.contains(quinolone) {
                    return true
                }
            }
        }
        return false
    }
}
