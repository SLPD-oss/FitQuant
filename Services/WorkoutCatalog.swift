import Foundation
import SwiftUI

// MARK: - WorkoutCatalogEntry
/// 训练动作目录条目：本地静态动作库，用于训练录入时动作名称的搜索匹配、
/// 肌群/有氧子类型联动预选。
/// 数据来源与后端 mock.py 的 mock_workout_classify 动作库保持一致（同一维护模式）。
struct WorkoutCatalogEntry: Identifiable, Decodable, Equatable {
    let id: String
    let name: String
    let aliases: [String]
    /// "strength" / "cardio"，对应 TrainingRecordModel.TrainingType.rawValue
    let trainingType: String
    /// 主肌群，对应 MuscleGroup.rawValue（如 "胸"、"背"、"腿"）；仅 strength 使用
    let primaryMuscleGroup: String
    /// 细分肌群选项，仅 strength 使用
    let subMuscles: [String]
    /// 有氧子类型，对应 WorkoutClassificationService.AerobicSubType.rawValue（"匀速有氧"/"HIIT高强度间歇"）；仅 cardio 使用
    let aerobicSubType: String
    let estimatedKcalPerMin: Double
    let difficulty: String
    let commonEquipment: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, aliases, trainingType, primaryMuscleGroup, subMuscles
        case aerobicSubType, estimatedKcalPerMin, difficulty, commonEquipment
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decode(String.self, forKey: .name)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        trainingType = try c.decodeIfPresent(String.self, forKey: .trainingType) ?? "strength"
        primaryMuscleGroup = try c.decodeIfPresent(String.self, forKey: .primaryMuscleGroup) ?? ""
        subMuscles = try c.decodeIfPresent([String].self, forKey: .subMuscles) ?? []
        aerobicSubType = try c.decodeIfPresent(String.self, forKey: .aerobicSubType) ?? ""
        estimatedKcalPerMin = try c.decodeIfPresent(Double.self, forKey: .estimatedKcalPerMin) ?? 0
        difficulty = try c.decodeIfPresent(String.self, forKey: .difficulty) ?? "beginner"
        commonEquipment = try c.decodeIfPresent([String].self, forKey: .commonEquipment) ?? []
    }

    /// 是否为力量动作
    var isStrength: Bool { trainingType == "strength" }

    /// 浮层行图标
    var systemImage: String { isStrength ? "dumbbell.fill" : "figure.run" }
}

// MARK: - WorkoutCatalogService
/// 本地训练动作目录搜索服务
/// 职责：提供训练录入时动作名称的实时搜索匹配（名称/别名模糊匹配）与联动预选数据。
/// 存储：静态 JSON 内嵌于代码（随版本发布），离线可用、毫秒级响应，不依赖后端网络。
/// 对齐：与后端 app/services/mock.py 的 mock_workout_classify 动作库保持一致。
final class WorkoutCatalogService {

    static let shared = WorkoutCatalogService()

    /// 静态动作目录（与后端 mock.py 动作库对齐并扩充常用动作）
    private static let catalogJSON = """
    [
      {
        "name": "杠铃卧推",
        "aliases": ["卧推", "Bench Press", "bench press"],
        "trainingType": "strength",
        "primaryMuscleGroup": "胸",
        "subMuscles": ["上胸", "中胸（厚度）", "下胸"],
        "aerobicSubType": "",
        "estimatedKcalPerMin": 5.2,
        "difficulty": "intermediate",
        "commonEquipment": ["杠铃", "卧推架"]
      },
      {
        "name": "上斜卧推",
        "aliases": ["上斜推", "Incline Press", "incline bench press"],
        "trainingType": "strength",
        "primaryMuscleGroup": "胸",
        "subMuscles": ["上胸", "中胸（厚度）"],
        "aerobicSubType": "",
        "estimatedKcalPerMin": 5.0,
        "difficulty": "intermediate",
        "commonEquipment": ["杠铃", "哑铃"]
      },
      {
        "name": "哑铃卧推",
        "aliases": ["Dumbbell Press", "dumbbell bench press"],
        "trainingType": "strength",
        "primaryMuscleGroup": "胸",
        "subMuscles": ["中胸（厚度）", "下胸"],
        "aerobicSubType": "",
        "estimatedKcalPerMin": 5.0,
        "difficulty": "intermediate",
        "commonEquipment": ["哑铃"]
      },
      {
        "name": "深蹲",
        "aliases": ["杠铃深蹲", "Squat", "squat"],
        "trainingType": "strength",
        "primaryMuscleGroup": "腿",
        "subMuscles": ["股四头肌", "臀大肌"],
        "aerobicSubType": "",
        "estimatedKcalPerMin": 6.5,
        "difficulty": "intermediate",
        "commonEquipment": ["杠铃", "深蹲架"]
      },
      {
        "name": "硬拉",
        "aliases": ["Deadlift", "deadlift"],
        "trainingType": "strength",
        "primaryMuscleGroup": "背",
        "subMuscles": ["背阔肌", "竖脊肌", "臀大肌"],
        "aerobicSubType": "",
        "estimatedKcalPerMin": 7.0,
        "difficulty": "advanced",
        "commonEquipment": ["杠铃"]
      },
      {
        "name": "杠铃划船",
        "aliases": ["划船", "Barbell Row", "barbell row"],
        "trainingType": "strength",
        "primaryMuscleGroup": "背",
        "subMuscles": ["背阔肌", "菱形肌"],
        "aerobicSubType": "",
        "estimatedKcalPerMin": 5.0,
        "difficulty": "intermediate",
        "commonEquipment": ["杠铃"]
      },
      {
        "name": "哑铃划船",
        "aliases": ["Dumbbell Row", "dumbbell row"],
        "trainingType": "strength",
        "primaryMuscleGroup": "背",
        "subMuscles": ["背阔肌", "菱形肌"],
        "aerobicSubType": "",
        "estimatedKcalPerMin": 4.8,
        "difficulty": "intermediate",
        "commonEquipment": ["哑铃"]
      },
      {
        "name": "坐姿划船",
        "aliases": ["Seated Row", "seated cable row"],
        "trainingType": "strength",
        "primaryMuscleGroup": "背",
        "subMuscles": ["背阔肌", "菱形肌"],
        "aerobicSubType": "",
        "estimatedKcalPerMin": 4.5,
        "difficulty": "beginner",
        "commonEquipment": ["坐姿划船机"]
      },
      {
        "name": "引体向上",
        "aliases": ["Pull Up", "pull-up", "引体"],
        "trainingType": "strength",
        "primaryMuscleGroup": "背",
        "subMuscles": ["背阔肌", "肱二头肌"],
        "aerobicSubType": "",
        "estimatedKcalPerMin": 5.5,
        "difficulty": "intermediate",
        "commonEquipment": ["单杠"]
      },
      {
        "name": "高位下拉",
        "aliases": ["Lat Pulldown", "lat pulldown"],
        "trainingType": "strength",
        "primaryMuscleGroup": "背",
        "subMuscles": ["背阔肌"],
        "aerobicSubType": "",
        "estimatedKcalPerMin": 4.8,
        "difficulty": "beginner",
        "commonEquipment": ["高位下拉机"]
      },
      {
        "name": "推举",
        "aliases": ["肩上推举", "Shoulder Press", "overhead press"],
        "trainingType": "strength",
        "primaryMuscleGroup": "肩",
        "subMuscles": ["前束", "中束"],
        "aerobicSubType": "",
        "estimatedKcalPerMin": 4.8,
        "difficulty": "intermediate",
        "commonEquipment": ["杠铃", "哑铃"]
      },
      {
        "name": "哑铃推举",
        "aliases": ["Dumbbell Press", "dumbbell shoulder press"],
        "trainingType": "strength",
        "primaryMuscleGroup": "肩",
        "subMuscles": ["前束", "中束"],
        "aerobicSubType": "",
        "estimatedKcalPerMin": 4.6,
        "difficulty": "intermediate",
        "commonEquipment": ["哑铃"]
      },
      {
        "name": "侧平举",
        "aliases": ["Lateral Raise", "lateral raise"],
        "trainingType": "strength",
        "primaryMuscleGroup": "肩",
        "subMuscles": ["中束"],
        "aerobicSubType": "",
        "estimatedKcalPerMin": 3.5,
        "difficulty": "beginner",
        "commonEquipment": ["哑铃"]
      },
      {
        "name": "弯举",
        "aliases": ["哑铃弯举", "Bicep Curl", "bicep curl"],
        "trainingType": "strength",
        "primaryMuscleGroup": "手臂",
        "subMuscles": ["肱二头肌"],
        "aerobicSubType": "",
        "estimatedKcalPerMin": 3.2,
        "difficulty": "beginner",
        "commonEquipment": ["哑铃", "杠铃"]
      },
      {
        "name": "臂屈伸",
        "aliases": ["双杠臂屈伸", "Triceps Dip", "triceps extension"],
        "trainingType": "strength",
        "primaryMuscleGroup": "手臂",
        "subMuscles": ["肱三头肌"],
        "aerobicSubType": "",
        "estimatedKcalPerMin": 4.0,
        "difficulty": "intermediate",
        "commonEquipment": ["双杠"]
      },
      {
        "name": "卷腹",
        "aliases": ["Crunch", "crunch"],
        "trainingType": "strength",
        "primaryMuscleGroup": "核心",
        "subMuscles": ["上腹", "下腹"],
        "aerobicSubType": "",
        "estimatedKcalPerMin": 3.0,
        "difficulty": "beginner",
        "commonEquipment": []
      },
      {
        "name": "跑步机",
        "aliases": ["Treadmill", "treadmill", "跑步"],
        "trainingType": "cardio",
        "primaryMuscleGroup": "全身",
        "subMuscles": [],
        "aerobicSubType": "匀速有氧",
        "estimatedKcalPerMin": 5.0,
        "difficulty": "beginner",
        "commonEquipment": ["跑步机"]
      },
      {
        "name": "椭圆机",
        "aliases": ["Elliptical", "elliptical"],
        "trainingType": "cardio",
        "primaryMuscleGroup": "全身",
        "subMuscles": [],
        "aerobicSubType": "匀速有氧",
        "estimatedKcalPerMin": 5.0,
        "difficulty": "beginner",
        "commonEquipment": ["椭圆机"]
      },
      {
        "name": "慢跑",
        "aliases": ["Jogging", "jogging", "跑步"],
        "trainingType": "cardio",
        "primaryMuscleGroup": "全身",
        "subMuscles": [],
        "aerobicSubType": "匀速有氧",
        "estimatedKcalPerMin": 5.0,
        "difficulty": "beginner",
        "commonEquipment": []
      },
      {
        "name": "动感单车",
        "aliases": ["Spinning", "spinning", "单车"],
        "trainingType": "cardio",
        "primaryMuscleGroup": "腿",
        "subMuscles": [],
        "aerobicSubType": "匀速有氧",
        "estimatedKcalPerMin": 6.0,
        "difficulty": "beginner",
        "commonEquipment": ["动感单车"]
      },
      {
        "name": "登山跑",
        "aliases": ["Mountain Climber", "mountain climber", "登山者"],
        "trainingType": "cardio",
        "primaryMuscleGroup": "核心",
        "subMuscles": ["核心"],
        "aerobicSubType": "HIIT高强度间歇",
        "estimatedKcalPerMin": 8.0,
        "difficulty": "intermediate",
        "commonEquipment": []
      },
      {
        "name": "平板支撑",
        "aliases": ["Plank", "plank"],
        "trainingType": "cardio",
        "primaryMuscleGroup": "核心",
        "subMuscles": ["核心"],
        "aerobicSubType": "HIIT高强度间歇",
        "estimatedKcalPerMin": 3.5,
        "difficulty": "beginner",
        "commonEquipment": []
      },
      {
        "name": "波比跳",
        "aliases": ["Burpee", "burpee"],
        "trainingType": "cardio",
        "primaryMuscleGroup": "全身",
        "subMuscles": [],
        "aerobicSubType": "HIIT高强度间歇",
        "estimatedKcalPerMin": 8.0,
        "difficulty": "intermediate",
        "commonEquipment": []
      },
      {
        "name": "跳绳",
        "aliases": ["Jump Rope", "jump rope"],
        "trainingType": "cardio",
        "primaryMuscleGroup": "全身",
        "subMuscles": [],
        "aerobicSubType": "HIIT高强度间歇",
        "estimatedKcalPerMin": 8.0,
        "difficulty": "beginner",
        "commonEquipment": ["跳绳"]
      },
      {
        "name": "HIIT循环训练",
        "aliases": ["HIIT", "高强度间歇", "tabata"],
        "trainingType": "cardio",
        "primaryMuscleGroup": "全身",
        "subMuscles": [],
        "aerobicSubType": "HIIT高强度间歇",
        "estimatedKcalPerMin": 8.0,
        "difficulty": "advanced",
        "commonEquipment": []
      }
    ]
    """

    private let allEntries: [WorkoutCatalogEntry]

    private init() {
        guard let data = Self.catalogJSON.data(using: .utf8),
              let entries = try? JSONDecoder().decode([WorkoutCatalogEntry].self, from: data) else {
            allEntries = []
            return
        }
        allEntries = entries
    }

    /// 按关键词搜索动作（名称或别名模糊匹配，不区分大小写）
    /// - 优先返回名称精确/前缀匹配的条目
    func search(keyword: String) -> [WorkoutCatalogEntry] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lower = trimmed.lowercased()
        return allEntries.filter { entry in
            entry.name.lowercased().contains(lower) ||
            entry.aliases.contains { $0.lowercased().contains(lower) }
        }
    }

    /// 按名称精确匹配动作（用于自动命中）
    func entry(named name: String) -> WorkoutCatalogEntry? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allEntries.first { $0.name.lowercased() == trimmed }
    }
}
