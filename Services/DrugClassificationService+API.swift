import Foundation

// MARK: - DrugClassificationService + API
// 【网络层 | 药品分类 API 扩展】
// 新增 async 方法优先请求后端 /api/drug/lookup，
// 网络不可用时降级到本地的药品关键词映射。

extension DrugClassificationService {

    /// 从后端查询药品分类，失败时降级到本地关键词匹配
    func autoDetectFromAPI(drugName: String) async -> DrugCategory? {
        do {
            let req = DrugLookupRequest(drug_name: drugName)
            let resp: DrugLookupResponse = try await APIClient.shared.post(
                "/api/drug/lookup", body: req
            )
            return DrugCategory(rawValue: resp.category)
        } catch {
            return nil
        }
    }
}
