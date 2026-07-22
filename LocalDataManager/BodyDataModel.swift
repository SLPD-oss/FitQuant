import Foundation

// MARK: - Sex

enum Sex: String, Codable, CaseIterable {
    case male
    case female

    var displayName: String {
        switch self {
        case .male: return "男性"
        case .female: return "女性"
        }
    }
}

// MARK: - ActivityLevel

enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary = "久坐"
    case light = "轻度活动"
    case moderate = "中等活动"
    case active = "活跃"
    case veryActive = "高强度"
}

// MARK: - BodyDataModel

struct BodyDataModel: Codable {

    // MARK: Stored Properties

    var heightCm: Double = 170
    var weightKg: Double = 70
    var age: Int = 25
    var chestCm: Double = 92
    var waistCm: Double = 78
    var neckCm: Double = 38
    var sex: Sex = .male
    var hipCm: Double = 90
    var bodyFatPercent: Double = 20.0
    var activityLevel: ActivityLevel = .moderate

    // MARK: Computed - Gender alias (for view compatibility)
    var gender: Sex { sex }

    // MARK: Computed - BMI

    /// 身高（米）
    var heightM: Double {
        heightCm / 100.0
    }

    /// BMI = 体重(kg) / 身高(m)^2
    var bmi: Double {
        guard heightM > 0 else { return 0 }
        return weightKg / (heightM * heightM)
    }

    /// BMI 筛查区间（中国标准中文标签）
    var bmiScreeningZone: String {
        switch bmi {
        case ..<18.5: return "偏瘦"
        case 18.5..<24:  return "正常"
        case 24..<28:   return "偏胖"
        default:        return "肥胖"
        }
    }

    /// Alias for bmiScreeningZone
    var bmiCategory: String { bmiScreeningZone }

    // MARK: Body Fat Estimate (Navy Formula)

    /// 体脂率估算（美国海军公式）
    var bodyFatEstimate: Double {
        guard heightCm > 0, waistCm > neckCm else { return 0 }
        switch sex {
        case .male:
            let value = 86.010 * log10(waistCm - neckCm)
                       - 70.041 * log10(heightCm)
                       + 36.76
            return max(0, min(value, 60))
        case .female:
            let hipProxy = hipCm > 0 ? hipCm : chestCm
            let value = 163.205 * log10(waistCm + hipProxy - neckCm)
                       - 97.684 * log10(heightCm)
                       - 78.387
            return max(0, min(value, 60))
        }
    }

    /// Alias for bodyFatEstimate
    var navyBodyFat: Double { bodyFatEstimate }

    // MARK: Waist-to-Height Ratio

    var waistToHeightRatio: Double {
        guard heightCm > 0 else { return 0 }
        return waistCm / heightCm
    }

    var waistToHeightNote: String {
        if waistToHeightRatio < 0.5 { return "腰围身高比正常" }
        else { return "腰围身高比偏高，建议关注" }
    }

    // MARK: Waist-to-Hip Ratio

    var waistToHipRatio: Double {
        guard hipCm > 0 else { return 0 }
        return waistCm / hipCm
    }

    // MARK: BMR Estimate (Mifflin-St Jeor)

    var bmrEstimate: Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        switch sex {
        case .male:   return base + 5
        case .female: return base - 161
        }
    }

    /// Alias for bmrEstimate
    var bmr: Double { bmrEstimate }
}
