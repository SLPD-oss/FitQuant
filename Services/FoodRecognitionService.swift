import Foundation

// MARK: - FoodRecognitionService
// 【Service 层｜食物识别与营养素估算】
// 数据来源：所有食物营养数据均从后端 POST /api/food/recognize 获取。
// 不再包含本地硬编码营养素映射表。
final class FoodRecognitionService {

    // MARK: - 公共结构

    /// 食物识别结果，包含全部宏量营养素数值
    struct FoodRecognitionResult {
        let proteinGrams: Double
        let fatGrams: Double
        let carbsGrams: Double
        let fiberGrams: Double
        let kcal: Double
        let sodiumMg: Double
        let sugarG: Double
    }

    // MARK: - 注：getNutritionEstimate() 已移除
    // 请使用 extension 中的 recognizeFromAPI(foodName:) async 方法从后端获取
}
