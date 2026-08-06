import SwiftUI

// MARK: - GlobalCreatineManager
// 【修复肌酸饮水单次同步BUG｜改动业务：全局响应式肌酸状态单例，实现补剂页与饮食页实时联动】
// 遵循 ObservableObject 协议，使用 @Published 修饰肌酸总量属性，数据变更自动广播通知所有监听页面
// 严禁页面本地独立维护肌酸数值，全部肌酸读写操作统一经由此单例

final class GlobalCreatineManager: ObservableObject {
    static let shared = GlobalCreatineManager()

    /// 当日肌酸总摄入克数 — 唯一全局数据源，补剂页、饮食页统一读取
    @Published var todayCreatineGrams: Double = 0

    /// 【方案A】按当前账号生成作用域 key（{baseKey}_{userId}），未登录回退原始 key
    private var storageKey: String {
        AccountScopedStore.scopedKey("todayCreatineGrams_v1")
    }

    private init() {
        // 启动时从本地持久化恢复肌酸历史值
        todayCreatineGrams = UserDefaults.standard.double(forKey: storageKey)
    }

    /// 【方案A】账号切换后重建内存：重读当前账号作用域 key 的肌酸值并广播刷新。
    /// 由 AccountScopedStore.accountDidChange() 在登录/登出时统一调用。
    func reloadForCurrentAccount() {
        todayCreatineGrams = UserDefaults.standard.double(forKey: storageKey)
        objectWillChange.send()
        print("[GlobalCreatineManager] 肌酸数据已切换到当前账号上下文")
    }

    // MARK: - 肌酸操作方法（补剂页 ± 按钮唯一调用入口）

    /// 增加肌酸克数，自动持久化并广播通知
    func incrementCreatine(by grams: Double) {
        todayCreatineGrams += grams
        persistAndNotify()
    }

    /// 减少肌酸克数（不低于0），自动持久化并广播通知
    func decrementCreatine(by grams: Double) {
        todayCreatineGrams = max(0, todayCreatineGrams - grams)
        persistAndNotify()
    }

    /// 完全重置当日肌酸总量为0
    func resetCreatine() {
        todayCreatineGrams = 0
        persistAndNotify()
    }

    // MARK: - 内部持久化

    /// 持久化写入 UserDefaults，并触发 @Published 广播通知所有监听页面重绘
    private func persistAndNotify() {
        UserDefaults.standard.set(todayCreatineGrams, forKey: storageKey)
    }

    // MARK: - 饮水标题动态文字

    /// 补剂页饮水模块标题：根据当日肌酸是否>0决定是否展示"（肌酸适配）"后缀
    var waterTitle: String {
        todayCreatineGrams > 0
            ? "每日推荐饮水量（肌酸适配）"
            : "每日推荐饮水量"
    }

    /// 饮水目标升数（复用全局统一计算函数，三档分档）
    var waterTargetLiters: Double {
        PhysiologyCalcTool.calcCreatineWaterTarget(dailyCreatineGrams: todayCreatineGrams)
    }

    /// 饮食页饮水量卡片底部说明小字（复用全局统一文案函数）
    var waterDescText: String {
        PhysiologyCalcTool.getWaterDescText(creatineGram: todayCreatineGrams)
    }
}
