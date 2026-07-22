import Foundation

// MARK: - BodyDataRepository
// 【Repository 层｜封装身体数据的本地持久化访问】
// 职责：统一管理 BodyDataModel 的序列化/反序列化（当前基于 UserDefaults）
// 设计逻辑：View 层不再直接调用 UserDefaults + JSONDecoder/Encoder，
// 改为调用此 Repository 的方法。后续切换到 CoreData 或 CloudKit 时，
// 只需修改此文件内部实现，所有调用方无需改动。
// key 与旧版保持一致（"saved_bodyData"），确保升级不丢失用户已有数据。
struct BodyDataRepository {

    /// UserDefaults 存储 key，与旧版保持一致以保证向后兼容
    private static let storageKey = "saved_bodyData"

    // MARK: - 读取

    /// 从本地持久化读取身体数据，不存在时返回默认 BodyDataModel 实例
    static func load() -> BodyDataModel {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let model = try? JSONDecoder().decode(BodyDataModel.self, from: data) else {
            return BodyDataModel()
        }
        return model
    }

    /// 读取身体数据并返回可选值（nil 表示从未保存过）
    static func loadOptional() -> BodyDataModel? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let model = try? JSONDecoder().decode(BodyDataModel.self, from: data) else {
            return nil
        }
        return model
    }

    // MARK: - 写入

    /// 将身体数据持久化到本地存储
    static func save(_ model: BodyDataModel) {
        if let data = try? JSONEncoder().encode(model) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    // MARK: - 便捷查询

    /// 判断用户体脂率是否高于阈值（用于训练页 TFCC 腕损伤风险判断）
    /// - Parameter threshold: 体脂率阈值，默认 30%
    /// - Returns: true 表示体脂率高于阈值
    static func isBodyFatAboveThreshold(_ threshold: Double = 30) -> Bool {
        guard let bodyData = loadOptional() else { return false }
        return bodyData.bodyFatPercent > threshold
    }
}
