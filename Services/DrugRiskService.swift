import Foundation

// MARK: - DrugRiskService
// 【Service 层｜药物-训练风险校验】
// 数据来源：所有药物风险数据均从后端 POST /api/drug/risk-check 获取。
// 不再包含本地喹诺酮黑名单。
final class DrugRiskService {

    static let shared = DrugRiskService()
    private init() {}

    /// 注：hasHighTendonRiskMedication() 已移除，请使用 extension 中的 hasHighTendonRiskFromAPI() async 方法
}
