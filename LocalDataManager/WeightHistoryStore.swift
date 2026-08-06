import Foundation

// MARK: - WeightRecord
// 【体重追踪】单条体重记录：记录日期 + 体重数值
// 每次用户「更新体重」时追加一条，用于体重趋势线性图展示
struct WeightRecord: Identifiable, Codable {
    let id: UUID
    var date: Date       // 记录日期
    var weightKg: Double // 体重（kg）

    init(id: UUID = UUID(), date: Date = Date(), weightKg: Double) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
    }
}

// MARK: - WeightHistoryStore
// 【体重追踪】体重历史本地持久化（UserDefaults + JSON）
// 遵循项目 Repository 模式：统一封装序列化细节，后续可平滑切换 CoreData/CloudKit
// key 与项目惯例一致（v1 版本号），保证升级不丢数据
struct WeightHistoryStore {

    /// UserDefaults 存储 key；
    /// 【方案A】按当前账号生成作用域 key（{baseKey}_{userId}），未登录回退原始 key
    private static var storageKey: String {
        AccountScopedStore.scopedKey("weightHistory_v1")
    }

    // MARK: - 读取

    /// 读取全部体重记录（按日期升序返回，图表直接用）
    static func load() -> [WeightRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([WeightRecord].self, from: data) else {
            return []
        }
        return records.sorted { $0.date < $1.date }
    }

    // MARK: - 写入

    /// 保存全部体重记录
    static func save(_ records: [WeightRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// 追加一条体重记录：
    /// 【本次更新】每次更新都新增一个独立数据点，不覆盖任何历史记录，
    /// 保留完整的减脂历程（即使同一天多次更新也各记为一点，由时间戳区分顺序）。
    static func add(weightKg: Double, at date: Date = Date()) {
        var records = load()
        records.append(WeightRecord(date: date, weightKg: weightKg))
        save(records)
    }

    // MARK: - 【本次更新】记录编辑（删除/更改，供减脂历程长按操作使用）

    /// 按 id 删除一条体重记录（不存在则忽略）
    static func delete(id: UUID) {
        var records = load()
        records.removeAll { $0.id == id }
        save(records)
    }

    /// 按 id 更新一条体重记录的体重值与日期（不存在则忽略）
    static func update(id: UUID, weightKg: Double, date: Date) {
        var records = load()
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        records[idx].weightKg = weightKg
        records[idx].date = date
        // 更新后按日期重新排序，保证图表顺序正确
        records.sort { $0.date < $1.date }
        save(records)
    }

    /// 清空全部体重记录（预留：用户重置数据时使用）
    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
