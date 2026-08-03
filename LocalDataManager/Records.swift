import SwiftUI

// MARK: - MealType

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast = "早餐"
    case lunch = "午餐"
    case dinner = "晚餐"
    case snack = "加餐"
    case supplement = "补剂"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var systemImage: String {
        switch self {
        case .breakfast:  return "sunrise.fill"
        case .lunch:      return "sun.max.fill"
        case .dinner:     return "moon.stars.fill"
        case .snack:      return "takeoutbag.and.cup.and.straw.fill"
        case .supplement: return "pills.fill"
        }
    }

    var colorName: String {
        switch self {
        case .breakfast:  return "orange"
        case .lunch:      return "yellow"
        case .dinner:     return "indigo"
        case .snack:      return "pink"
        case .supplement: return "mint"
        }
    }

    var color: Color {
        switch self {
        case .breakfast:  return .orange
        case .lunch:      return .yellow
        case .dinner:     return .indigo
        case .snack:      return .pink
        case .supplement: return .mint
        }
    }
}

// MARK: - MealRecordModel & DietRecord (DietView用)

struct MealRecordModel: Identifiable, Codable {
    let id: UUID
    var foodName: String
    var mealType: MealType
    var proteinGrams: Double
    var fatGrams: Double
    var carbsGrams: Double
    // 新增：补充膳食纤维营养字段，完整覆盖基础膳食营养素指标
    var dietaryFiber: Double?
    var kcal: Double
    var servingAmount: Double
    var servingUnit: String
    // 新增：食物热量识别来源标记，nil=手动录入，"camera"=相机AI识别
    var recognitionSource: String?
    var createdAt: Date

    init(id: UUID = UUID(), foodName: String = "", mealType: MealType = .breakfast,
         proteinGrams: Double = 0, fatGrams: Double = 0, carbsGrams: Double = 0,
         dietaryFiber: Double? = nil, kcal: Double = 0,
         servingAmount: Double = 1, servingUnit: String = "份",
         recognitionSource: String? = nil, createdAt: Date = Date()) {
        self.id = id; self.foodName = foodName; self.mealType = mealType
        self.proteinGrams = proteinGrams; self.fatGrams = fatGrams; self.carbsGrams = carbsGrams
        self.dietaryFiber = dietaryFiber; self.kcal = kcal
        self.servingAmount = servingAmount; self.servingUnit = servingUnit
        self.recognitionSource = recognitionSource; self.createdAt = createdAt
    }
}

/// Alias used by DietView
typealias DietRecord = MealRecordModel

struct MacroSummary {
    let totalProtein: Double
    let totalFat: Double
    let totalCarbs: Double
    let totalFiber: Double   // 新增：膳食纤维汇总
    let totalKcal: Double

    static func from(_ records: [MealRecordModel]) -> MacroSummary {
        MacroSummary(
            totalProtein: records.reduce(0) { $0 + $1.proteinGrams },
            totalFat: records.reduce(0) { $0 + $1.fatGrams },
            totalCarbs: records.reduce(0) { $0 + $1.carbsGrams },
            totalFiber: records.reduce(0) { $0 + ($1.dietaryFiber ?? 0) },
            totalKcal: records.reduce(0) { $0 + $1.kcal }
        )
    }
}

// MARK: - TrainCategory

enum TrainCategory: String, Codable, CaseIterable {
    case strength
    case cardio
}

// MARK: - MuscleGroup

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest = "胸"
    case back = "背"
    case legs = "腿"
    case shoulders = "肩"
    case arms = "手臂"
    case core = "核心"
    case fullBody = "全身"
    var id: String { rawValue }
    var displayName: String { rawValue }
    var iconName: String {
        switch self {
        case .chest: return "figure.strengthtraining.traditional"
        case .back: return "figure.rower"
        case .legs: return "figure.walk"
        case .shoulders: return "figure.arms.above.head"
        case .arms: return "figure.strengthtraining.functional"
        case .core: return "figure.core.training"
        case .fullBody: return "figure.mixed.cardio"
        }
    }
    var color: Color { Color(.systemBlue) }
}

// MARK: - TrainingRecordModel (TrainView用)

struct TrainingRecordModel: Identifiable, Codable {
    let id: UUID
    var exerciseName: String
    var trainingType: TrainingType
    var muscleGroups: Set<MuscleGroup>
    var sets: Int
    var reps: Int
    var weightKg: Double
    var durationMinutes: Int
    var estimatedKcal: Double
    var notes: String
    var createdAt: Date
    // 新增：有氧训练差异化录入字段（可选，兼容历史旧数据）
    var treadmillSpeed: Double?   // 跑步机时速 km/h，nil=未录入
    var treadmillSlope: Double?   // 跑步机坡度 %，nil=未录入
    var hiitGroupCount: Int?      // HIIT循环组数，nil=未录入
    var hiitWorkSecond: Int?      // 每组运动秒数，nil=未录入
    var hiitRestSecond: Int?      // 每组休息秒数，nil=未录入
    // 新增：存储用户选中的二级细分肌群，设为可选向下兼容历史训练数据
    var targetSubMuscleGroups: [String]?

    enum TrainingType: String, Codable, CaseIterable, Identifiable {
        case strength = "力量训练"
        case cardio = "有氧训练"
        var id: String { rawValue }
    }

    init(id: UUID = UUID(), exerciseName: String = "",
         trainingType: TrainingType = .strength,
         muscleGroups: Set<MuscleGroup> = [],
         sets: Int = 0, reps: Int = 0, weightKg: Double = 0,
         durationMinutes: Int = 0, estimatedKcal: Double = 0,
         notes: String = "", createdAt: Date = Date(),
         treadmillSpeed: Double? = nil, treadmillSlope: Double? = nil,
         hiitGroupCount: Int? = nil, hiitWorkSecond: Int? = nil,
         hiitRestSecond: Int? = nil,
         targetSubMuscleGroups: [String]? = nil) {
        self.id = id; self.exerciseName = exerciseName; self.trainingType = trainingType
        self.muscleGroups = muscleGroups; self.sets = sets; self.reps = reps
        self.weightKg = weightKg; self.durationMinutes = durationMinutes
        self.estimatedKcal = estimatedKcal; self.notes = notes; self.createdAt = createdAt
        self.treadmillSpeed = treadmillSpeed; self.treadmillSlope = treadmillSlope
        self.hiitGroupCount = hiitGroupCount; self.hiitWorkSecond = hiitWorkSecond
        self.hiitRestSecond = hiitRestSecond
        self.targetSubMuscleGroups = targetSubMuscleGroups
    }

    static func estimatedKcal(strengthMinutes: Int, cardioMinutes: Int, weightKg: Double) -> Double {
        Double(strengthMinutes) * 0.1 * weightKg + Double(cardioMinutes) * 0.15 * weightKg
    }
}

// MARK: - TrainRecord

struct TrainRecord: Identifiable, Codable {
    let id: UUID
    var exerciseName: String
    var category: TrainCategory
    var muscleGroup: MuscleGroup
    var sets: Int
    var reps: Int
    var weightKg: Double
    var durationMin: Int
    var timestamp: Date

    init(id: UUID = UUID(), exerciseName: String = "",
         category: TrainCategory = .strength, muscleGroup: MuscleGroup = .chest,
         sets: Int = 0, reps: Int = 0, weightKg: Double = 0,
         durationMin: Int = 0, timestamp: Date = Date()) {
        self.id = id; self.exerciseName = exerciseName; self.category = category
        self.muscleGroup = muscleGroup; self.sets = sets; self.reps = reps
        self.weightKg = weightKg; self.durationMin = durationMin; self.timestamp = timestamp
    }
}

// MARK: - SupplementRecord

struct SupplementRecord: Identifiable, Codable {
    let id: UUID
    var date: Date
    var name: String
    var dosage: String
    var unit: String
    var notes: String

    init(id: UUID = UUID(), date: Date = Date(), name: String = "",
         dosage: String = "", unit: String = "", notes: String = "") {
        self.id = id; self.date = date; self.name = name
        self.dosage = dosage; self.unit = unit; self.notes = notes
    }
}

// MARK: - DrugCategory

enum DrugCategory: String, Codable, CaseIterable, Identifiable {
    case supplement = "补剂"
    case prescription = "处方药"
    case otc = "非处方药"
    case traditionalChMedicine = "中药"
    case typeA, typeB
    case other = "其他"
    var id: String { rawValue }
    var displayName: String { rawValue }
    var systemImage: String {
        switch self {
        case .supplement: return "pills.fill"; case .prescription: return "cross.case.fill"
        case .otc: return "bandage.fill"; case .traditionalChMedicine: return "leaf.fill"
        case .typeA: return "pill.fill"; case .typeB: return "pills"
        case .other: return "tag.fill"
        }
    }
}

// MARK: - DrugStatus

enum DrugStatus: String, Codable, CaseIterable, Identifiable {
    case viewing = "在用"
    case syncing = "评估中"
    case stopped = "已停用"
    var id: String { rawValue }
}

// MARK: - DrugRecordModel

struct DrugRecordModel: Identifiable, Codable {
    let id: UUID
    var date: Date
    var drugName: String
    var category: DrugCategory
    var status: DrugStatus
    var dosageMg: Double
    var frequencyPerDay: Int
    var dosage: String
    var unit: String
    var frequency: String
    var createdAt: Date
    var notes: String
    /// 【删除同步修复】墓碑标记：本地已删除、待同步到后端删除的记录
    /// 兼容旧数据：解码时缺失该字段默认 false（自定义 Codable 实现）
    var isDeleted: Bool
    var name: String { drugName }

    init(id: UUID = UUID(), date: Date = Date(), drugName: String = "",
         category: DrugCategory = .other, status: DrugStatus = .viewing,
         dosageMg: Double = 0, frequencyPerDay: Int = 0,
         dosage: String = "", unit: String = "", frequency: String = "",
         createdAt: Date = Date(), notes: String = "", isDeleted: Bool = false) {
        self.id = id; self.date = date; self.drugName = drugName
        self.category = category; self.status = status
        self.dosageMg = dosageMg; self.frequencyPerDay = frequencyPerDay
        self.dosage = dosage; self.unit = unit; self.frequency = frequency
        self.createdAt = createdAt; self.notes = notes
        self.isDeleted = isDeleted
    }

    // MARK: - Codable（自定义实现，兼容旧版本无 isDeleted 字段的数据）
    private enum CodingKeys: String, CodingKey {
        case id, date, drugName, category, status, dosageMg, frequencyPerDay
        case dosage, unit, frequency, createdAt, notes, isDeleted
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        drugName = try c.decode(String.self, forKey: .drugName)
        category = try c.decode(DrugCategory.self, forKey: .category)
        status = try c.decode(DrugStatus.self, forKey: .status)
        dosageMg = try c.decodeIfPresent(Double.self, forKey: .dosageMg) ?? 0
        frequencyPerDay = try c.decodeIfPresent(Int.self, forKey: .frequencyPerDay) ?? 0
        dosage = try c.decodeIfPresent(String.self, forKey: .dosage) ?? ""
        unit = try c.decodeIfPresent(String.self, forKey: .unit) ?? ""
        frequency = try c.decodeIfPresent(String.self, forKey: .frequency) ?? ""
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isDeleted = try c.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(drugName, forKey: .drugName)
        try c.encode(category, forKey: .category)
        try c.encode(status, forKey: .status)
        try c.encode(dosageMg, forKey: .dosageMg)
        try c.encode(frequencyPerDay, forKey: .frequencyPerDay)
        try c.encode(dosage, forKey: .dosage)
        try c.encode(unit, forKey: .unit)
        try c.encode(frequency, forKey: .frequency)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(notes, forKey: .notes)
        try c.encode(isDeleted, forKey: .isDeleted)
    }
}
