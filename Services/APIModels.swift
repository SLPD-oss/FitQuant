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

/// 注册请求体 — 对应后端 POST /api/auth/register
struct RegisterRequest: Encodable {
    let phone: String
    let password: String
    let nickname: String?
    let identity: String?
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

// MARK: - 身体数据最新一条
struct BodyLatestResponse: Decodable {
    let record_id: String?
    let height_cm: Double?
    let weight_kg: Double?
    let age: Int?
    let sex: String?
    let chest_cm: Double?
    let waist_cm: Double?
    let neck_cm: Double?
    let hip_cm: Double?
    let body_fat_percent: Double?
    let activity_level: String?
    let recorded_at: String?
}

// MARK: - 饮食记录
struct MealTodayResponse: Decodable {
    let date: String
    let meals: [MealItemResponse]
    let totals: MealTotalsResponse
}

struct MealItemResponse: Decodable {
    let record_id: String
    let food_name: String
    let meal_type: String
    let protein_g: Double
    let fat_g: Double
    let carbs_g: Double
    let fiber_g: Double
    let kcal: Double
    let recorded_at: String
}

struct MealTotalsResponse: Decodable {
    let protein_g: Double
    let fat_g: Double
    let carbs_g: Double
    let fiber_g: Double
    let kcal: Double
}

// MARK: - 训练记录
struct TrainingHistoryResponse: Decodable {
    let records: [TrainingItemResponse]
    let total: Int
}

struct TrainingItemResponse: Decodable {
    let record_id: String
    let exercise_name: String
    let training_type: String
    let sets: Int
    let reps: Int
    let weight_kg: Double
    let duration_minutes: Int
    let estimated_kcal: Double
    let recorded_at: String
}

// MARK: - 用药记录
struct DrugListResponse: Decodable {
    let records: [DrugItemResponse]
    let total: Int
}

struct DrugItemResponse: Decodable {
    let record_id: String
    let drug_name: String
    let category: String
    let status: String
    let dosage: String
    let unit: String
    let frequency: String
    let recorded_at: String
}

// MARK: - 睡眠恢复
struct SleepRecordUploadRequest: Encodable {
    let user_id: String
    let sleep_date: String
    let total_sleep_hours: Double
    let core_sleep_hours: Double
    let deep_sleep_hours: Double
    let rem_sleep_hours: Double
    let awake_hours: Double
    let resting_heart_rate: Int
    let avg_hrv: Int
    let source: String
}

struct SleepRecordUploadResponse: Decodable {
    let record_id: String
    let sleep_date: String
    let updated: Bool
}

/// GET /api/sleep/latest 响应 data 结构（含后端派生指标与训练建议）
struct SleepLatestResponse: Decodable {
    let record_id: String
    let sleep_date: String
    let total_sleep_hours: Double
    let core_sleep_hours: Double
    let deep_sleep_hours: Double
    let rem_sleep_hours: Double
    let awake_hours: Double
    let resting_heart_rate: Int
    let avg_hrv: Int
    let source: String
    let recovery_score: Int
    let recovery_status: String
    let consecutive_low_score_days: Int
    let suggestion: SleepSuggestionResponse?
}

/// GET /api/sleep/history 响应 data 结构
struct SleepHistoryResponse: Decodable {
    let records: [SleepItemResponse]
    let total: Int
}

struct SleepItemResponse: Decodable {
    let record_id: String
    let sleep_date: String
    let total_sleep_hours: Double
    let core_sleep_hours: Double
    let deep_sleep_hours: Double
    let rem_sleep_hours: Double
    let awake_hours: Double
    let resting_heart_rate: Int
    let avg_hrv: Int
    let source: String
    let recovery_score: Int
    let recovery_status: String
    let consecutive_low_score_days: Int
}

struct SleepSuggestionResponse: Decodable {
    let title: String
    let message: String
}

// MARK: - 身体数据上传（补充 user_id）
struct BodyDataUploadRequestWithUser: Encodable {
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
    let user_id: String
}

// MARK: - 通用响应（无 data 业务字段的接口使用）
/// DELETE /api/auth/user/{user_id} 响应 data：{ deleted: true }
struct DeleteAccountResult: Decodable {
    let deleted: Bool?
}

/// DELETE /api/users/{user_id}/data 响应 data：{ cleared: true }
struct ClearUserDataResult: Decodable {
    let cleared: Bool?
}

// MARK: - 同步
struct SyncBatchRequest: Encodable {
    let sync_mode: String
    let user_id: String
    let body_data: [BodyDataSyncRecord]
    let meal_records: [MealSyncRecord]
    let training_records: [TrainingSyncRecord]
    let drug_records: [DrugSyncRecord]
    let deleted_drug_records: [DeletedDrugSyncRecord]
    /// 【删除同步修复】待删除的饮食/训练记录墓碑：后端按 record_id / 幂等键删除对应行
    let deleted_meal_records: [DeletedMealSyncRecord]
    let deleted_training_records: [DeletedTrainingSyncRecord]
    /// 【删除同步修复】一键删除所有药物时传 true，后端无条件清空该用户全部用药记录
    let clear_all_drugs: Bool
    let supplement_records: [SupplementSyncRecord]
    let sleep_records: [SleepSyncRecord]
}

struct BodyDataSyncRecord: Encodable {
    let recorded_at: String
    let weight_kg: Double
    let body_fat_percent: Double
    let waist_cm: Double
    let height_cm: Double
    let age: Int
    let sex: String
    let activity_level: String
}

struct MealSyncRecord: Encodable {
    /// 【删除同步修复】客户端本地 id：后端优先按 (user_id, id) upsert，
    /// 保证前后端 id 一致，删除按 id 传播（与药物分支同一机制）
    let record_id: String
    let recorded_at: String
    let meal_type: String
    let food_name: String
    let protein_g: Double
    let fat_g: Double
    let carbs_g: Double
    let fiber_g: Double
    let kcal: Double
}

struct TrainingSyncRecord: Encodable {
    /// 【删除同步修复】客户端本地 id：后端优先按 (user_id, id) upsert，
    /// 保证前后端 id 一致，删除按 id 传播（与药物分支同一机制）
    let record_id: String
    let recorded_at: String
    let exercise_name: String
    let training_type: String
    let sets: Int
    let reps: Int
    let weight_kg: Double
    let duration_minutes: Int
    let estimated_kcal: Double
}

struct DrugSyncRecord: Encodable {
    /// 【重复记录修复】客户端本地 id：后端优先按 (user_id, id) upsert，
    /// 保证前后端 id 一致，合并按 id 命中，避免切页返回出现两条相同记录
    let record_id: String
    let recorded_at: String
    let drug_name: String
    let category: String
    let status: String
    let dosage: String
    let unit: String
    let frequency: String
}

/// 待删除用药记录（删除传播）：优先按 record_id（后端行 ID）删除，缺失时按幂等键兜底
struct DeletedDrugSyncRecord: Encodable {
    let record_id: String
    let drug_name: String
    let recorded_at: String
}

/// 待删除饮食记录（删除传播）：优先按 record_id（后端行 ID）删除，缺失时按幂等键兜底
struct DeletedMealSyncRecord: Encodable {
    let record_id: String
    let meal_type: String
    let food_name: String
    let recorded_at: String
}

/// 待删除训练记录（删除传播）：优先按 record_id（后端行 ID）删除，缺失时按幂等键兜底
struct DeletedTrainingSyncRecord: Encodable {
    let record_id: String
    let exercise_name: String
    let recorded_at: String
}

struct SupplementSyncRecord: Encodable {
    let recorded_at: String
    let name: String
    let dosage: String
    let unit: String
}

struct SleepSyncRecord: Encodable {
    let sleep_date: String
    let total_sleep_hours: Double
    let core_sleep_hours: Double
    let deep_sleep_hours: Double
    let rem_sleep_hours: Double
    let awake_hours: Double
    let resting_heart_rate: Int
    let avg_hrv: Int
    let source: String
    let recorded_at: String
}

// MARK: - 同步响应
struct SyncBatchResponse: Decodable {
    let sync_id: String
    let synced_at: String
    let stats: SyncBatchStats
}

struct SyncBatchStats: Decodable {
    let body_records_uploaded: Int
    let meal_records_uploaded: Int
    let training_records_uploaded: Int
    let drug_records_uploaded: Int
    let drug_records_deleted: Int?
    let supplement_records_uploaded: Int
    let sleep_records_uploaded: Int?
}
