import Foundation

// MARK: - FoodRecognitionService
// 【Service 层｜食物识别与营养素估算】
// 职责：根据食物名称返回模拟的营养素数据（前端演示阶段）。
// 设计逻辑：原先 DietView 的 performMockRecognition() 方法内嵌了
// 鸡胸肉/牛肉/米饭等食物的硬编码营养素数据，现独立为此 Service。
// View 层只负责调用 getNutritionEstimate() 并接收结果。
// 远期替换：后端食物视觉识别 API 上线后，替换此 Service 内部实现为网络请求，
// 上层 ViewModel/View 无需改动。
final class FoodRecognitionService {

    // MARK: - 公共结构

    /// 食物识别结果，包含全部宏量营养素数值
    struct FoodRecognitionResult {
        let proteinGrams: Double
        let fatGrams: Double
        let carbsGrams: Double
        let fiberGrams: Double
    }

    // MARK: - 识别接口

    /// 根据食物名称，返回模拟的营养素估算值（演示阶段）
    /// - Parameter foodName: 食物名称
    /// - Returns: 模拟的营养素数值
    /// - Note: 后期替换逻辑：① 拍照获取 UIImage → ② 转换为 Data
    ///   → ③ POST 后端 API → ④ 解析返回 JSON → ⑤ 返回 FoodRecognitionResult
    func getNutritionEstimate(for foodName: String) -> FoodRecognitionResult {
        let name = foodName.trimmingCharacters(in: .whitespaces)

        if name.contains("鸡胸") || name.contains("鸡") {
            return FoodRecognitionResult(proteinGrams: 31, fatGrams: 3.6, carbsGrams: 0, fiberGrams: 0)
        } else if name.contains("牛肉") || name.contains("牛") {
            return FoodRecognitionResult(proteinGrams: 26, fatGrams: 15, carbsGrams: 0, fiberGrams: 0)
        } else if name.contains("米饭") {
            return FoodRecognitionResult(proteinGrams: 2.6, fatGrams: 0.3, carbsGrams: 28, fiberGrams: 0.1)
        } else if name.contains("西兰花") || name.contains("花椰") {
            return FoodRecognitionResult(proteinGrams: 2.8, fatGrams: 0.4, carbsGrams: 7, fiberGrams: 2.6)
        } else if name.contains("鸡蛋") {
            return FoodRecognitionResult(proteinGrams: 13, fatGrams: 11, carbsGrams: 1.1, fiberGrams: 0)
        } else if name.contains("牛奶") {
            return FoodRecognitionResult(proteinGrams: 3, fatGrams: 3.2, carbsGrams: 4.8, fiberGrams: 0)
        } else if name.contains("苹果") {
            return FoodRecognitionResult(proteinGrams: 0.3, fatGrams: 0.2, carbsGrams: 14, fiberGrams: 2.4)
        } else if name.contains("全麦面包") || name.contains("面包") {
            return FoodRecognitionResult(proteinGrams: 9, fatGrams: 2.5, carbsGrams: 49, fiberGrams: 6)
        } else {
            // 默认值（未匹配到关键词时的兜底数据）
            return FoodRecognitionResult(proteinGrams: 10, fatGrams: 5, carbsGrams: 20, fiberGrams: 2)
        }
    }
}
