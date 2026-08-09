import Foundation

// MARK: - TrainingRecordRepository
// 【Repository 层｜封装训练记录的本地持久化访问】
// 职责：统一管理 TrainingRecordModel 列表的序列化/反序列化（当前基于 UserDefaults）
// 设计逻辑：原先 TrainingRecordStorage 是 PhysiologyCalcTool.swift 文件末尾定义的内部类，
// 职责割裂（计算工具类却管理持久化），现独立为 Repository，遵循单一职责原则。
// key 与旧版保持一致（"trainingLog_v1"），确保升级不丢失已有的训练记录。
struct TrainingRecordRepository {

    /// UserDefaults 存储 key，与旧版保持一致；
    /// 【方案A】按当前账号生成作用域 key（{baseKey}_{userId}），未登录回退原始 key
    private static var storageKey: String {
        AccountScopedStore.scopedKey("trainingLog_v1")
    }

    /// 【删除同步修复】待删除墓碑的存储 key（账号作用域），与 records 分key存储
    private static var pendingDeletesKey: String {
        AccountScopedStore.scopedKey("saved_trainingPendingDeletes_v1")
    }

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

    // MARK: - 墓碑（待删除记录，删除传播用）

    /// 【删除同步修复】删除记录：本地移除 + 移入墓碑并落盘。
    /// 墓碑随下次同步上传 deleted_training_records 到后端删除，同步成功后清空。
    static func delete(_ record: TrainingRecordModel) {
        var records = loadAll()
        records.removeAll { $0.id == record.id }
        saveAll(records)
        var pending = loadPendingDeletes()
        pending.append(record)
        savePendingDeletes(pending)
    }

    /// 读取待删除墓碑记录（同步失败时保留，App 重启后继续重试删除）
    static func loadPendingDeletes() -> [TrainingRecordModel] {
        guard let data = UserDefaults.standard.data(forKey: pendingDeletesKey),
              let saved = try? JSONDecoder().decode([TrainingRecordModel].self, from: data) else {
            return []
        }
        return saved
    }

    /// 持久化待删除墓碑记录
    static func savePendingDeletes(_ records: [TrainingRecordModel]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: pendingDeletesKey)
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
