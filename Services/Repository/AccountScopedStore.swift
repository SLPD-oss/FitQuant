import Foundation

// MARK: - AccountScopedStore
// 【方案A｜本地存储账号维度化】核心工具
// 职责：
//   1. scopedKey(_:) —— 把业务 key 按当前登录账号生成命名空间（{baseKey}_{userId}），
//      未登录时回退到原始 key（保持向后兼容）。
//   2. migrateLegacyToScoped() —— 一次性数据迁移：旧版本全局 key 的数据
//      归属到「首次登录的账号」，全局标记保证幂等，迁移不删除 legacy key（防误删）。
//   3. accountDidChange() —— 登录/登出统一入口：触发迁移 + 重建账号相关内存单例，
//      避免「key 已隔离但单例内存仍是旧账号数据」的残留。
// 设计原则：
//   - 迁移只执行一次，旧数据整体归属首个登录账号（多账号混存无法拆分，取可接受折中）。
//   - 迁移用 object(forKey:) != nil 判存在，避免 JSON 解码失败误判。
//   - 不删除 legacy key，仅靠全局标记防重复迁移。
struct AccountScopedStore {

    // MARK: - Keys

    /// 迁移完成标记（全局，与账号无关）
    private static let migrationDoneKey = "localData_scopedMigration_v1"

    /// 需要账号维度化的业务 key 清单（不含登录态与 token，它们本就随账号清除）
    static let legacyBusinessKeys: [String] = [
        "weightHistory_v1",          // 体重趋势
        "saved_bodyData",            // 身体数据
        "trainingLog_v1",            // 训练记录
        "saved_mealRecords_v2",      // 饮食记录
        "saved_drugRecords",         // 用药记录
        "saved_drugPendingDeletes",  // 用药删除墓碑
        "nutritionTargets_v2",       // 营养目标
        "todayCreatineGrams_v1",     // 肌酸摄入
        "sleepLatest_v1",            // 睡眠缓存
        "saved_supplementIntake_v1", // 补剂摄入
        "deficitOverride_v1"         // 热量缺口覆盖
    ]

    // MARK: - 账号作用域 key

    /// 生成当前账号作用域下的业务 key。
    /// 未登录（userId 为空）时回退原始 key —— 冷启动阶段单例初始化可用，
    /// 进入业务页前必然已登录（RootView 门控），无用户可见影响。
    static func scopedKey(_ baseKey: String) -> String {
        guard let uid = LoginUserStorage.userId, !uid.isEmpty else { return baseKey }
        return "\(baseKey)_\(uid)"
    }

    // MARK: - 一次性迁移

    /// 将旧版本全局 key 的数据迁移到当前账号作用域 key。
    /// 仅在「当前账号作用域 key 为空 且 legacy key 有数据」时拷贝；
    /// 全局标记 migrationDoneKey 置位后不再执行（幂等）。
    static func migrateLegacyToScoped() {
        guard !UserDefaults.standard.bool(forKey: migrationDoneKey) else { return }
        guard let uid = LoginUserStorage.userId, !uid.isEmpty else { return }

        let defaults = UserDefaults.standard
        var changed = false
        for baseKey in legacyBusinessKeys {
            let scoped = "\(baseKey)_\(uid)"
            // 作用域 key 已有数据 → 跳过（防覆盖）；legacy 无数据 → 无可迁移
            guard defaults.object(forKey: scoped) == nil,
                  let legacyData = defaults.object(forKey: baseKey) else { continue }
            defaults.set(legacyData, forKey: scoped)
            changed = true
        }
        defaults.set(true, forKey: migrationDoneKey)
        print("[AccountScopedStore] 本地数据一次性迁移完成: 迁移 \(changed ? "有数据" : "无数据")（归属账号 \(uid)）")
    }

    // MARK: - 账号切换统一入口

    /// 登录成功后 / 登出时调用：
    ///   1. 首次登录触发一次性迁移；
    ///   2. 重建账号相关内存单例（用药、肌酸），确保内存数据与当前账号一致。
    /// 注意：必须在 LoginUserStorage 写入/清除 userId 之后调用。
    static func accountDidChange() {
        migrateLegacyToScoped()
        // 单例内存重建（key 已按账号隔离，内存若不重建仍是旧账号数据）
        DrugDataManager.shared.reloadForCurrentAccount()
        GlobalCreatineManager.shared.reloadForCurrentAccount()
        print("[AccountScopedStore] 账号上下文已切换")
    }

    // MARK: - 注销账号数据清理

    /// 【注销】账号作用域业务 key 完整清单（含删除墓碑 key）。
    /// 注销时按 {baseKey}_{userId} 逐一删除；同时清理未隔离的 legacy key，
    /// 确保该账号的本地数据彻底清除、不可恢复。
    static let accountDataBaseKeys: [String] = legacyBusinessKeys + [
        "saved_trainingPendingDeletes_v1", // 训练删除墓碑
        "saved_mealPendingDeletes_v1",     // 饮食删除墓碑
    ]

    /// 【注销】样例数据初始化标记（全局）：重置后新注册账号可重新回填样例数据
    private static let sampleInitializedKeys: [String] = [
        "saved_drugRecords_initialized",
    ]

    /// 【注销】清除当前账号的全部本地数据。
    /// 仅在云端删除账号成功后调用（本地数据不可恢复）：
    /// 1. 删除当前账号作用域业务 key（{baseKey}_{userId}）
    /// 2. 删除未隔离的 legacy key（兼容历史存储）
    /// 3. 重置全局样例数据初始化标记
    static func removeCurrentAccountData() {
        guard let uid = LoginUserStorage.userId, !uid.isEmpty else { return }
        let defaults = UserDefaults.standard
        for baseKey in accountDataBaseKeys {
            defaults.removeObject(forKey: "\(baseKey)_\(uid)")
        }
        // 兼容历史：旧版本数据曾以全局 key 存储
        for baseKey in legacyBusinessKeys {
            defaults.removeObject(forKey: baseKey)
        }
        for key in sampleInitializedKeys {
            defaults.removeObject(forKey: key)
        }
        print("[AccountScopedStore] 已清理账号 \(uid) 的全部本地数据")
    }
}
