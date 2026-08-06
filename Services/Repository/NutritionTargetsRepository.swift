import Foundation

// MARK: - NutritionTargetsRepository
// 【Repository 层｜封装营养目标的本地持久化访问】
// 职责：统一管理 NutritionTargets 的序列化/反序列化（当前基于 UserDefaults）
// 设计逻辑：原先 NutritionTargets 的 loadFromStorage() 和 saveToStorage()
// 直接定义在模型结构体上（模型同时承担持久化职责），现剥离到此 Repository 中。
// 模型模型仅保留数据结构，持久化细节由 Repository 统一管理。
// key 与旧版保持一致（"nutritionTargets_v2"），确保升级不丢失已保存的目标数据。
struct NutritionTargetsRepository {

    /// UserDefaults 存储 key，与旧版保持一致以保证向后兼容；
    /// 【方案A】按当前账号生成作用域 key（{baseKey}_{userId}），未登录回退原始 key
    private static var storageKey: String {
        AccountScopedStore.scopedKey("nutritionTargets_v2")
    }

    // MARK: - 读取

    /// 从本地持久化读取营养目标，不存在时返回 nil
    static func load() -> NutritionTargets? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(NutritionTargets.self, from: data)
    }

    // MARK: - 写入

    /// 将营养目标持久化到本地存储
    static func save(_ targets: NutritionTargets) {
        if let data = try? JSONEncoder().encode(targets) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - 删除

    /// 清除本地存储的营养目标数据
    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
