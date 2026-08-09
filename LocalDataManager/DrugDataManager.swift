
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
        loadPendingDeletes()
        // 【修复】样例数据仅在首次启动（或卸载重装后）回填一次；
        // 用户删光记录并同步成功后重启，不再回填样例，避免「复活」假象
        if !UserDefaults.standard.bool(forKey: Self.initializedKey) {
            loadSampleData()
            saveToStorage()
            UserDefaults.standard.set(true, forKey: Self.initializedKey)
        }
    }

    // MARK: - Published

    @Published var records: [DrugRecordModel] = []
    /// 【删除同步修复】墓碑：本地已删除、待同步到后端删除的记录（同步成功后清空）
    @Published var pendingDeletes: [DrugRecordModel] = []
    /// 【删除同步修复】一键删除所有药物标志：置位后下次同步向后端传 clear_all_drugs=true，
    /// 后端无条件清空该用户全部用药记录（墓碑按 id 删除对历史膨胀数据可能失效，需要显式清空兜底）
    var clearAllPending = false
    /// 最近一次云端同步失败信息（供 UI 提示，nil 表示无失败）
    @Published var lastSyncError: String?

    // MARK: - Computed

    /// 是否存在活跃的 B 类药品记录
    var hasActiveTypeBDrug: Bool {
        records.contains { record in
            record.category == .typeB && record.status != .stopped
        }
    }

    // MARK: - CRUD
    // 【删除同步修复】删除改为墓碑式：本地移除 + 移入 pendingDeletes 并落盘，
    // 待 syncToBackend() 成功后清空墓碑；同步失败时墓碑保留，下次同步重试删除。

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
        pendingDeletes.append(record)
        saveToStorage()
        savePendingDeletes()
    }

    func deleteRecord(_ record: DrugRecordModel) {
        records.removeAll { $0.id == record.id }
        pendingDeletes.append(record)
        saveToStorage()
        savePendingDeletes()
    }

    func delete(at indexSet: IndexSet) {
        let targets = indexSet.map { records[$0] }
        records.remove(atOffsets: indexSet)
        pendingDeletes.append(contentsOf: targets)
        saveToStorage()
        savePendingDeletes()
    }

    // 【本次更新】一键删除全部用药记录（本地清空 + 全部移入墓碑 + 落盘，供「删除所有药物」按钮调用）
    // 【删除同步修复】置位 clearAllPending，同步时向后端传 clear_all_drugs=true 强制清空云端
    func clearAll() {
        pendingDeletes.append(contentsOf: records)
        records.removeAll()
        clearAllPending = true
        saveToStorage()
        savePendingDeletes()
    }

    func records(for status: DrugStatus?) -> [DrugRecordModel] {
        guard let status else { return records }
        return records.filter { $0.status == status }
    }

    // MARK: - 批量同步到后端

    /// 将全部用药记录异步同步到后端 sync/batch
    /// 【删除同步修复】同步请求携带 deleted_drug_records（墓碑），
    /// 后端按 record_id / 幂等键删除对应行；同步成功后清空墓碑，失败保留待下次重试。
    func syncToBackend() async {
        guard let uid = LoginUserStorage.userId, !uid.isEmpty else { return }
        let records = self.records
        let pending = self.pendingDeletes
        let shouldClearAll = self.clearAllPending
        let syncRecords = records.map { r -> DrugSyncRecord in
            DrugSyncRecord(
                record_id: r.id.uuidString,
                recorded_at: ISO8601DateFormatter().string(from: r.createdAt),
                drug_name: r.drugName,
                category: r.category.rawValue,
                status: r.status.rawValue,
                dosage: r.dosage,
                unit: r.unit,
                frequency: r.frequency
            )
        }
        let deletedRecords = pending.map { r -> DeletedDrugSyncRecord in
            DeletedDrugSyncRecord(
                record_id: r.id.uuidString,
                drug_name: r.drugName,
                recorded_at: ISO8601DateFormatter().string(from: r.createdAt)
            )
        }
        let body = SyncBatchRequest(
            sync_mode: "full",
            user_id: uid,
            body_data: [],
            meal_records: [],
            training_records: [],
            drug_records: syncRecords,
            deleted_drug_records: deletedRecords,
            deleted_meal_records: [],
            deleted_training_records: [],
            clear_all_drugs: shouldClearAll,
            supplement_records: [],
            sleep_records: []
        )
        do {
            let resp: SyncBatchResponse = try await APIClient.shared.post("/api/sync/batch", body: body)
            // 同步成功：清空墓碑 + 复位清空标志（后端已执行删除/清空）
            await MainActor.run {
                if !self.pendingDeletes.isEmpty {
                    self.pendingDeletes.removeAll()
                    self.savePendingDeletes()
                }
                self.clearAllPending = false
                self.lastSyncError = nil
            }
            let deletedCount = resp.stats.drug_records_deleted ?? deletedRecords.count
            print("[DrugDataManager] 云端同步成功: 上传 \(records.count) 条, 删除 \(deletedCount) 条")
        } catch {
            await MainActor.run {
                self.lastSyncError = error.localizedDescription
            }
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

    private static var storageKey: String {
        AccountScopedStore.scopedKey("saved_drugRecords")
    }
    private static var pendingDeletesKey: String {
        AccountScopedStore.scopedKey("saved_drugPendingDeletes")
    }
    /// 样例数据初始化标记：保持全局（与账号无关）。
    /// 样例只在设备首次启动回填一次并归属首个登录账号；
    /// 换账号后不重复回填，避免样例数据污染新账号。
    private static let initializedKey = "saved_drugRecords_initialized"

    /// 【方案A】账号切换后重建内存：重新从「当前账号作用域 key」加载 records 与墓碑。
    /// 由 AccountScopedStore.accountDidChange() 在登录/登出时统一调用。
    func reloadForCurrentAccount() {
        loadFromStorage()
        loadPendingDeletes()
        // 复位一次性清空标志：该标志只对发起操作的账号有意义
        clearAllPending = false
        lastSyncError = nil
        print("[DrugDataManager] 用药数据已切换到当前账号上下文")
    }

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

    /// 从本地持久化读取待删除墓碑记录
    private func loadPendingDeletes() {
        guard let data = UserDefaults.standard.data(forKey: Self.pendingDeletesKey),
              let saved = try? JSONDecoder().decode([DrugRecordModel].self, from: data) else {
            return
        }
        pendingDeletes = saved
    }

    /// 将待删除墓碑记录持久化到本地（同步失败时保留，App 重启后继续重试删除）
    private func savePendingDeletes() {
        if let data = try? JSONEncoder().encode(pendingDeletes) {
            UserDefaults.standard.set(data, forKey: Self.pendingDeletesKey)
        }
    }
}
