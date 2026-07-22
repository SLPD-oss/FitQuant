import Foundation

// MARK: - DrugClassificationService
// 【Service 层｜药品分类识别】
// 数据来源：所有药品分类数据均从后端 POST /api/drug/lookup 获取。
// 不再包含本地硬编码关键词映射。
final class DrugClassificationService {

    /// 共享实例
    static let shared = DrugClassificationService()
    init() {}

    /// 注：autoDetectMedicationType 已移除，请使用 extension 中的 autoDetectFromAPI(drugName:) async 方法
}
