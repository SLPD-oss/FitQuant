import Foundation

// MARK: - SupplementPlanService
// 【网络层 | 补剂方案服务】
// 职责：从后端 POST /api/supplement-plan 获取补剂方案。
// 不再包含本地 MockDataSource 降级逻辑。

final class SupplementPlanService {
    static let shared = SupplementPlanService()
    private init() {}

    /// 从后端获取补剂方案，后端不可用时返回默认空方案
    /// - Parameter body: 用户身体数据
    /// - Returns: SupplementPlanMock
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
            return SupplementPlanMock(
                bmi: resp.bmi,
                bmiNote: "BMI \(String(format: "%.1f", resp.bmi)) — 筛查区间：\(resp.bmi_screening_zone)",
                tdeeKcal: resp.tdee_kcal,
                proteinTargetGrams: resp.protein_target_g,
                wheyScoopsReference: resp.whey_scoops_ref,
                creatineMgPerDay: resp.creatine_mg_per_day,
                waterLitersReference: resp.water_liters_ref,
                bodyFat: resp.body_fat_estimate_pct,
                bodyFatNote: resp.body_fat_note,
                nutritionTargets: NutritionTargetsModel(
                    dailyKcal: resp.nutrition_targets.daily_kcal,
                    proteinG: resp.nutrition_targets.protein_g,
                    fatG: resp.nutrition_targets.fat_g,
                    carbsG: resp.nutrition_targets.carbs_g,
                    fiberG: resp.nutrition_targets.fiber_g,
                    baseDeficitKcal: resp.nutrition_targets.base_deficit_kcal
                )
            )
        } catch {
            print("[SupplementPlanService] 后端不可用: \(error.localizedDescription)")
            return SupplementPlanMock() // 返回默认空方案
        }
    }
}
