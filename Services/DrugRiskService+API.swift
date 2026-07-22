import Foundation

// MARK: - DrugRiskService + API
// 【网络层 | 药物风险校验 API 扩展】
// 新增 async 方法优先请求后端 /api/drug/risk-check，
// 网络不可用时降级到本地喹诺酮黑名单。

extension DrugRiskService {

    /// 从后端校验药物风险，失败时降级到本地黑名单
    func hasHighTendonRiskFromAPI() async -> Bool {
        let activeDrugs = DrugDataManager.shared.records
            .filter { $0.status != .stopped }
            .map { ActiveDrugItem(
                drug_name: $0.drugName,
                dosage: $0.dosage,
                unit: $0.unit,
                frequency: $0.frequency
            )}
        guard !activeDrugs.isEmpty else { return false }

        do {
            let req = DrugRiskCheckRequest(
                active_drugs: activeDrugs,
                training_type: "strength",
                target_muscle_groups: []
            )
            let resp: DrugRiskCheckResponse = try await APIClient.shared.post(
                "/api/drug/risk-check", body: req
            )
            return resp.has_risk
        } catch {
            return hasHighTendonRiskMedication()
        }
    }
}
