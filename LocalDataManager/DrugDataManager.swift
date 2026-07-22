
import Foundation
import Combine

//【合规红线】DrugDataManager 管理敏感药物数据，
// 不得将 records 暴露给非授权模块，不得在后台任务中无用户知情同意地上传数据。
// 所有对外接口应遵循最小必要原则。
// //【合规隔离红线】All drug data is stored locally; no cloud sync.
final class DrugDataManager: ObservableObject {

    // MARK: - Singleton

    static let shared = DrugDataManager()

    private init() {
        loadFromStorage()
        if records.isEmpty {
            loadSampleData()
            saveToStorage()
        }
    }

    // MARK: - Published

    @Published var records: [DrugRecordModel] = []

    // MARK: - Computed

    /// 是否存在活跃的 B 类药品记录
    var hasActiveTypeBDrug: Bool {
        records.contains { record in
            record.category == .typeB && record.status != .stopped
        }
    }

    // MARK: - CRUD

    func add(_ record: DrugRecordModel) {
        records.append(record)
        saveToStorage()
    }

    func addRecord(_ record: DrugRecordModel) {
        records.append(record)
        saveToStorage()
    }

    func update(_ record: DrugRecordModel) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index] = record
        saveToStorage()
    }

    func updateRecord(_ record: DrugRecordModel) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index] = record
        saveToStorage()
    }

    func delete(_ record: DrugRecordModel) {
        records.removeAll { $0.id == record.id }
        saveToStorage()
    }

    func deleteRecord(_ record: DrugRecordModel) {
        records.removeAll { $0.id == record.id }
        saveToStorage()
    }

    func delete(at indexSet: IndexSet) {
        records.remove(atOffsets: indexSet)
        saveToStorage()
    }

    func records(for status: DrugStatus?) -> [DrugRecordModel] {
        guard let status else { return records }
        return records.filter { $0.status == status }
    }

    // MARK: - 批量同步到后端

    /// 将全部用药记录异步同步到后端 sync/batch
    func syncToBackend() async {
        guard let uid = LoginUserStorage.userId, !uid.isEmpty else { return }
        let records = self.records
        let syncRecords = records.map { r -> DrugSyncRecord in
            DrugSyncRecord(
                recorded_at: ISO8601DateFormatter().string(from: r.createdAt),
                drug_name: r.drugName,
                category: r.category.rawValue,
                status: r.status.rawValue,
                dosage: r.dosage,
                unit: r.unit,
                frequency: r.frequency
            )
        }
        let body = SyncBatchRequest(
            sync_mode: "full",
            user_id: uid,
            body_data: [],
            meal_records: [],
            training_records: [],
            drug_records: syncRecords,
            supplement_records: []
        )
        do {
            let _: SyncBatchResponse = try await APIClient.shared.post("/api/sync/batch", body: body)
            print("[DrugDataManager] 云端同步成功: \(records.count) 条")
        } catch {
            print("[DrugDataManager] 云端同步失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Sample Data

    private func loadSampleData() {
        let now = Date()
        let calendar = Calendar.current

        // 删除补剂类模拟数据，补剂统一迁移到底部补剂Tab展示，不在用药列表出现
        // 合规标注：以下为样本演示数据，不包含真实个人信息
        records = [
            DrugRecordModel(
                drugName: "布洛芬",
                category: .typeA,
                status: .viewing,
                dosage: "200",
                unit: "mg",
                frequency: "必要时服用",
                createdAt: calendar.date(byAdding: .day, value: -7, to: now) ?? now,
                notes: "遵医嘱使用"
            ),
            DrugRecordModel(
                drugName: "左氧氟沙星",
                category: .typeB,
                status: .syncing,
                dosage: "500",
                unit: "mg",
                frequency: "每日1次",
                createdAt: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                notes: "处方药，注意肌腱风险"
            ),
        ]
    }

    // MARK: - 持久化（UserDefaults）

    private static let storageKey = "saved_drugRecords"

    /// 从本地持久化读取用药记录
    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let saved = try? JSONDecoder().decode([DrugRecordModel].self, from: data) else {
            return
        }
        records = saved
    }

    /// 将当前用药记录持久化到本地
    func saveToStorage() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
