import Foundation

// MARK: - TrainingRecordRepository
// 【Repository 层｜封装训练记录的本地持久化访问】
// 职责：统一管理 TrainingRecordModel 列表的序列化/反序列化（当前基于 UserDefaults）
// 设计逻辑：原先 TrainingRecordStorage 是 PhysiologyCalcTool.swift 文件末尾定义的内部类，
// 职责割裂（计算工具类却管理持久化），现独立为 Repository，遵循单一职责原则。
// key 与旧版保持一致（"trainingLog_v1"），确保升级不丢失已有的训练记录。
struct TrainingRecordRepository {

    /// UserDefaults 存储 key，与旧版保持一致
    private static let storageKey = "trainingLog_v1"

    // MARK: - 读取

    /// 从本地持久化读取全部训练记录，不存在时返回空数组
    static func loadAll() -> [TrainingRecordModel] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([TrainingRecordModel].self, from: data) else {
            return []
        }
        return records
    }

    // MARK: - 写入

    /// 将训练记录列表持久化到本地存储（全量覆盖）
    static func saveAll(_ records: [TrainingRecordModel]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    // MARK: - 便捷查询

    /// 获取当天的全部训练记录
    static func loadTodayRecords() -> [TrainingRecordModel] {
        let allRecords = loadAll()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }

        return allRecords.filter { record in
            record.createdAt >= today && record.createdAt < tomorrow
        }
    }

    /// 计算当天训练总消耗（kcal）
    static func sumTodayTrainingConsume() -> Double {
        let todayRecords = loadTodayRecords()
        return todayRecords.reduce(0.0) { $0 + $1.estimatedKcal }
    }
}
