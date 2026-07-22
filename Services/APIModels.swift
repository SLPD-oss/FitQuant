import Foundation

// MARK: - APIModels
// 【网络层 | API 请求/响应数据模型】
// 职责：所有后端 API 的请求体（Encodable）和响应体（Decodable）定义在此。
// 每个模型与 backend 端 Pydantic schema 完全对齐，字段使用 snake_case 命名。
// 所有 API 响应外层统一为 { code, message, data }，由 APIClient 解析，
// 这里只定义 data 字段内部的类型。

// MARK: - 用户认证
struct LoginRequest: Encodable {
    let phone: String
    let password: String
    let device_id: String
}

struct LoginResponse: Decodable {
    let token: String
    let refresh_token: String
    let expires_in: Int
    let user: UserInfo
}

struct UserInfo: Decodable {
    let user_id: String
    let phone: String
    let nickname: String
    let avatar_url: String
    let identity: String
}

// MARK: - 补剂方案
struct SupplementPlanRequest: Encodable {
    let weight_kg: Double
    let height_cm: Double
    let age: Int
    let sex: String
    let body_fat_percent: Double
    let activity_level: String
    let waist_cm: Double
    let neck_cm: Double
}

struct SupplementPlanResponse: Decodable {
    let bmi: Double
    let bmi_screening_zone: String
    let tdee_kcal: Double
    let bmr_kcal: Double
    let protein_target_g: Double
    let protein_note: String
    let whey_scoops_ref: Double
    let creatine_mg_per_day: Double
    let creatine_note: String
    let vitamin_d3_iu_per_day: Double
    let fish_oil_mg_per_day: Double
    let water_liters_ref: Double
    let body_fat_estimate_pct: Double
    let body_fat_note: String
    let nutrition_targets: NutritionTargetsResponse
}

struct NutritionTargetsResponse: Decodable {
    let daily_kcal: Double
    let protein_g: Double
    let fat_g: Double
    let carbs_g: Double
    let fiber_g: Double
    let base_deficit_kcal: Double
}

// MARK: - 训练动作分类
struct WorkoutClassifyRequest: Encodable {
    let action_name: String
}

struct WorkoutClassifyResponse: Decodable {
    let action_name: String
    let training_type: String
    let aerobic_sub_type: String?
    let primary_muscle_group: String
    let secondary_muscle_groups: [String]
    let sub_muscle_options: [String]
    let is_high_risk_wrist: Bool
    let estimated_kcal_per_min: Double
    let common_equipment: [String]
    let difficulty: String
}

// MARK: - 药品查询
struct DrugLookupRequest: Encodable {
    let drug_name: String
}

struct DrugLookupResponse: Decodable {
    let drug_name: String
    let category: String
    let category_display: String
    let aliases: [String]
    let is_prescription: Bool
    let risk_tags: [String]
}

// MARK: - 药物风险校验
struct DrugRiskCheckRequest: Encodable {
    let active_drugs: [ActiveDrugItem]
    let training_type: String
    let target_muscle_groups: [String]
}

struct ActiveDrugItem: Encodable {
    let drug_name: String
    let dosage: String
    let unit: String
    let frequency: String
}

struct DrugRiskCheckResponse: Decodable {
    let has_risk: Bool
    let risks: [DrugRiskDetail]
}

struct DrugRiskDetail: Decodable {
    let drug_name: String
    let risk_level: String
    let risk_description: String
    let affected_body_parts: [String]
    let suggestion: String
}

// MARK: - 食物识别
struct FoodRecognitionResponse: Decodable {
    let food_name: String
    let confidence: Double
    let serving_size_g: Double
    let nutrition_per_100g: NutritionPer100g
}

struct NutritionPer100g: Decodable {
    let protein_g: Double
    let fat_g: Double
    let carbs_g: Double
    let fiber_g: Double
    let kcal: Double
    let sodium_mg: Double
    let sugar_g: Double
}

// MARK: - 身体数据上传
struct BodyDataUploadRequest: Encodable {
    let height_cm: Double
    let weight_kg: Double
    let age: Int
    let sex: String
    let chest_cm: Double
    let waist_cm: Double
    let neck_cm: Double
    let hip_cm: Double
    let body_fat_percent: Double
    let activity_level: String
    let recorded_at: String
}

struct BodyDataUploadResponse: Decodable {
    let record_id: String
    let created_at: String
}
