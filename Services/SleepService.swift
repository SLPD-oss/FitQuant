import Foundation

// MARK: - SleepRecoveryData
// 【睡眠模块｜本地展示数据模型】
// 后端 SleepLatestResponse 的本地映射，字段命名与前端既有 SleepRecoveryMockData 对齐，
// 使 SleepRecoveryView 渲染逻辑无需大改即可接入真实数据。
// status 由后端 recovery_status（good/mild/severe）映射到前端 SleepRecoveryStatus 枚举。
struct SleepRecoveryData: Codable, Identifiable {
    var id: String { sleepDate }
    let sleepDate: String
    let totalSleepHours: Double       // 昨夜睡眠总时长（小时）
    let coreSleepHours: Double        // 核心睡眠时长（小时）
    let deepSleepHours: Double        // 深睡眠时长（小时）
    let remSleepHours: Double         // REM 睡眠时长（小时）
    let awakeHours: Double            // 夜间清醒时长（小时）
    let restingHeartRate: Int         // 晨起静息心率（次/分）
    let avgHRV: Int                   // 夜间平均 HRV（ms）
    let recoveryScore: Int            // 后端自研 0-100 恢复评分
    let consecutiveLowScoreDays: Int  // 后端计算的连续低分天数
    let recoveryStatusRaw: String     // good / mild / severe
    let suggestionTitle: String?      // 后端训练建议标题
    let suggestionMessage: String?    // 后端训练建议正文

    /// 前端三套状态枚举（后端 status 映射；未知值回退 good）
    var status: SleepRecoveryStatus {
        SleepRecoveryStatus.from(score: recoveryScore)
    }

    /// 四个睡眠阶段总时长（用于占比可视化）
    var totalStageHours: Double {
        coreSleepHours + deepSleepHours + remSleepHours + awakeHours
    }
}

// MARK: - SleepService
// 【网络层｜睡眠恢复数据服务】
// 职责：拉取最新一夜睡眠数据（GET /api/sleep/latest）、上报单夜数据（POST /api/sleep/records）。
// 降级链：后端可用 → 后端数据；后端不可用 → 本地缓存；两者皆无 → nil（前端走空状态降级）。
final class SleepService {
    static let shared = SleepService()
    private init() {}

    /// 拉取最新一夜睡眠恢复数据
    func fetchLatest(userId: String) async -> SleepRecoveryData? {
        guard !userId.isEmpty else { return SleepRecordRepository.loadLatest() }
        do {
            let resp: SleepLatestResponse = try await APIClient.shared.get("/api/sleep/latest?user_id=\(userId)")
            let data = SleepRecoveryData(
                sleepDate: resp.sleep_date,
                totalSleepHours: resp.total_sleep_hours,
                coreSleepHours: resp.core_sleep_hours,
                deepSleepHours: resp.deep_sleep_hours,
                remSleepHours: resp.rem_sleep_hours,
                awakeHours: resp.awake_hours,
                restingHeartRate: resp.resting_heart_rate,
                avgHRV: resp.avg_hrv,
                recoveryScore: resp.recovery_score,
                consecutiveLowScoreDays: resp.consecutive_low_score_days,
                recoveryStatusRaw: resp.recovery_status,
                suggestionTitle: resp.suggestion?.title,
                suggestionMessage: resp.suggestion?.message
            )
            SleepRecordRepository.saveLatest(data)
            return data
        } catch {
            // 网络不可用 → 回退本地缓存
            print("[SleepService] 拉取睡眠数据失败，回退本地缓存: \(error.localizedDescription)")
            return SleepRecordRepository.loadLatest()
        }
    }

    /// 上报一夜睡眠数据（静默失败，不影响本地展示）
    func upload(_ record: SleepRecordUploadRequest) async {
        do {
            let _: SleepRecordUploadResponse = try await APIClient.shared.post("/api/sleep/records", body: record)
            print("[SleepService] 睡眠数据上报成功")
        } catch {
            print("[SleepService] 睡眠数据上报失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - SleepRecordRepository
// 【Repository 层｜睡眠数据本地缓存】
// 职责：缓存最近一次拉取的最新一夜数据，供无网络时离线展示。
struct SleepRecordRepository {
    /// 【方案A】按当前账号生成作用域 key（{baseKey}_{userId}），未登录回退原始 key
    private static var storageKey: String {
        AccountScopedStore.scopedKey("sleepLatest_v1")
    }

    static func loadLatest() -> SleepRecoveryData? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let model = try? JSONDecoder().decode(SleepRecoveryData.self, from: data) else {
            return nil
        }
        return model
    }

    static func saveLatest(_ model: SleepRecoveryData) {
        if let data = try? JSONEncoder().encode(model) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
