import Foundation

// MARK: - SupplementPlanService
// 【网络层 | 补剂方案服务】
// 职责：优先从后端 POST /api/supplement-plan 获取补剂方案，
// 后端不可用时自动降级到本地 MockDataSource 计算。
// 设计逻辑：SupplementView 原先直接调用 MockDataSource.generateSupplementPlan(for:)，
// 改造后改为调用此 Service 的 fetchPlan(for:) 方法，调用方无需感知数据来源。

final class SupplementPlanService {
    static let shared = SupplementPlanService()
    private init() {}

    /// 从后端获取补剂方案，失败时降级到本地计算
    /// - Parameter body: 用户身体数据
    /// - Returns: SupplementPlanMock（与前端现有模型对齐）
    func fetchPlan(for body: BodyDataModel) async -> SupplementPlanMock {
        do {
            let req = SupplementPlanRequest(
                weight_kg: body.weightKg,
                height_cm: body.heightCm,
                age: body.age,
                sex: body.sex.rawValue,
                body_fat_percent: body.bodyFatPercent,
                activity_level: body.activityLevel.rawValue,
                waist_cm: body.waistCm,
                neck_cm: body.neckCm
            )
            let resp: SupplementPlanResponse = try await APIClient.shared.post(
                "/api/supplement-plan", body: req
            )

            // 将后端返回数据映射到前端现有的 SupplementPlanMock
            return SupplementPlanMock(
                bmi: resp.bmi,
                bmiNote: "BMI \(String(format: "%.1f", resp.bmi)) — 筛查区间：\(resp.bmi_screening_zone)",
                tdeeKcal: resp.tdee_kcal,
                proteinTargetGrams: resp.protein_target_g,
                wheyScoopsReference: resp.whey_scoops_ref,
                creatineMgPerDay: resp.creatine_mg_per_day,
                waterLitersReference: resp.water_liters_ref,
                bodyFat: resp.body_fat_estimate_pct,
                bodyFatNote: resp.body_fat_note
            )
        } catch {
            // 后端不可用 → 降级到本地计算
            print("[SupplementPlanService] 后端不可用，降级到本地模拟: \(error.localizedDescription)")
            return MockDataSource.generateSupplementPlan(for: body)
        }
    }
}
