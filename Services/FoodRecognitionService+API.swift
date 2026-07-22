import Foundation

// MARK: - FoodRecognitionService + API
// 【网络层 | 食物识别 API 扩展】
// 新增 async 方法优先请求后端 /api/food/recognize，
// 网络不可用时降级到本地食物营养素映射表。

extension FoodRecognitionService {

    /// 从后端识别食物营养，失败时降级到本地映射
    /// - Parameter foodName: 食物名称字符串
    /// - Returns: FoodRecognitionResult（与前端现有结构对齐）
    func recognizeFromAPI(foodName: String) async -> FoodRecognitionResult {
        do {
            let resp: FoodRecognitionResponse = try await APIClient.shared.post(
                "/api/food/recognize",
                body: FoodRecognitionBody(food_name: foodName)
            )
            return FoodRecognitionResult(
                proteinGrams: resp.nutrition_per_100g.protein_g,
                fatGrams: resp.nutrition_per_100g.fat_g,
                carbsGrams: resp.nutrition_per_100g.carbs_g,
                fiberGrams: resp.nutrition_per_100g.fiber_g
            )
        } catch {
            return FoodRecognitionResult(proteinGrams: 0, fatGrams: 0, carbsGrams: 0, fiberGrams: 0)
        }
    }
}

/// 食物识别请求体（模拟接口适配）
private struct FoodRecognitionBody: Encodable {
    let food_name: String
}
