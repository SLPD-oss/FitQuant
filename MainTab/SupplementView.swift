import SwiftUI

//【合规红线：仅提醒不锁输入】
//【合规红线：仅健身维度描述，剔除医疗功效】
//【设计规范：进度条薄玻璃、图标超薄玻璃】

/// Tab1 量化补充 — 补剂追踪页面
/// 四个健身补剂卡片（蛋白粉/肌酸/维生素D3/鱼油）+ 身体量化参考模块
struct SupplementView: View {

    @Binding var bodyData: BodyDataModel
    @StateObject private var identityVM = GlobalViewManager.shared
    // 【修复肌酸饮水单次同步BUG｜改动业务：注入全局响应式肌酸单例，替代页面本地肌酸变量】
    @EnvironmentObject var creatineManager: GlobalCreatineManager

    // 当日补剂摄入量（蛋白粉/VD3/鱼油仍为本地记录，肌酸已迁移至全局单例）
    @State private var proteinPowderG: Double = 0
    @State private var vitaminD3Mcg: Double = 0
    @State private var fishOilMg: Double = 0

    // 侧边抽屉状态
    @State private var showDrawer = false

    // 【保守减脂热量计算逻辑】总热量缺口状态
    @State private var totalDeficitToday: Double = 0
    // 【本次修复｜热量缺口健康语义】实际净缺口状态（建议总缺口 − 当日饮食摄入，扣摄入）
    @State private var actualNetDeficitToday: Double = 0
    // 【本次修复｜热量缺口健康语义】当日饮食摄入热量（来自饮食页共享 key）
    @State private var todayKcalIntake: Double = 0
    @State private var showDeficitWarning: Bool = false

    // 【补剂页新增肌酸饮水量进度条】饮水追踪状态（肌酸数据已迁移至全局单例）
    @State private var waterIntakeTodayL: Double = 0

    // 【网络层对接】plan 从本地 MockDataSource 改为异步 SupplementPlanService
    // 页面加载时自动请求后端 API，不可用时降级到本地计算
    @State private var plan: SupplementPlanMock = SupplementPlanMock()

    // 【网络层对接】补剂摄入持久化 Key
    // 【方案A】按当前账号生成作用域 key（{baseKey}_{userId}），未登录回退原始 key
    private var supplementIntakeStorageKey: String {
        AccountScopedStore.scopedKey("saved_supplementIntake_v1")
    }
    // 【本次修复｜热量缺口健康语义】当日摄入热量共享 Key（账号作用域，与饮食页共用）
    private var dailyKcalIntakeKey: String {
        AccountScopedStore.scopedKey("dailyKcalIntake_v1")
    }

    private var moduleCount: Int {
        identityVM.currentIdentity.supplementModuleCount
    }

    // MARK: - 补剂目标值（自动从身体数据计算，可手动覆盖）

    /// 蛋白粉每日目标 (g) — 按体重 1.6g/kg 扣除预估天然食物蛋白后缺口
    private var proteinPowderTarget: Double {
        let total = bodyData.weightKg * 1.6
        let natural = bodyData.weightKg * 0.8  // 预估天然食物提供 0.8g/kg
        return max(total - natural, 20)
    }

    /// 肌酸每日推荐 (g) — 维持期 5g
    private var creatineTarget: Double { 5.0 }

    /// 维生素D3每日目标 (μg) — 20μg ≈ 800 IU
    private var vitaminD3Target: Double { 20.0 }

    /// 鱼油EPA+DHA每日目标 (mg) — min(体重*30, 2000)
    private var fishOilTarget: Double {
        min(bodyData.weightKg * 30, 2000)
    }

    // 【本次修复｜饮水联动】全天饮水量共享 Key（账号作用域）：
    // 与饮食页共用，补剂页录入/读取与饮食页保持一致
    private var dailyWaterIntakeKey: String {
        AccountScopedStore.scopedKey("dailyWaterIntake_v1")
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            ScrollView {
                VStack(spacing: AppleGlassStyle.spacingMD) {
                    identityBadge
                    bodySummaryCard
                    // 【补剂页总缺口红色进度条】独立VStack区域，紧接身体数据摘要下方
                    calorieDeficitCard

                    // MARK: - 四大补剂追踪卡片（替换原营养素卡片）
                    //【用户需求整改：四补剂卡片独立追踪蛋白粉/肌酸/VD3/鱼油】
                    supplementTrackingSection

                    // 【补剂页新增肌酸饮水量进度条】独立VStack区域，紧接补剂追踪下方
                    waterIntakeCard

                    // MARK: - 补剂量化模块（BMI/TDEE等保留）
                    supplementModules
                }
                .padding(AppleGlassStyle.spacingSM)
                .padding(.bottom, 60)
            }

            // 侧边补剂拖拽抽屉入口
            if showDrawer {
                supplementDrawer
            }
        }
        .background(AppleGlassStyle.groupedBackground)
        .navigationTitle("量化补充")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            disclaimerBar
        }
        //【修复数据读取逻辑】每次进入页面从UserDefaults读取最新身体数据，与BodyDataInputView/MineView联动
        //【修复肌酸饮水单次同步BUG｜改动业务：肌酸数据已由全局单例自动管理，无需手动加载】
        .onAppear {
            loadBodyDataFromStorage()
            // 【网络层对接】从本地持久化加载补剂摄入量
            if let data = UserDefaults.standard.data(forKey: supplementIntakeStorageKey),
               let saved = try? JSONDecoder().decode(SupplementIntakeData.self, from: data) {
                proteinPowderG = saved.proteinPowderG
                vitaminD3Mcg = saved.vitaminD3Mcg
                fishOilMg = saved.fishOilMg
                waterIntakeTodayL = saved.waterIntakeTodayL
            }
            // 【本次修复｜饮水联动】以共享 key 为准覆盖本地值（饮食页录入的饮水量在此生效）
            waterIntakeTodayL = UserDefaults.standard.double(forKey: dailyWaterIntakeKey)
            refreshCalorieDeficit()
            // 【网络层对接】异步加载补剂方案（后端优先，本地降级）
            Task {
                let fetchedPlan = await SupplementPlanService.shared.fetchPlan(for: bodyData)
                // 保存 nutrition_targets 到 UserDefaults 供 DietView 使用
                if let nt = fetchedPlan.nutritionTargets {
                    let targets = NutritionTargets(
                        dailyKcal: nt.dailyKcal,
                        proteinG: nt.proteinG,
                        fatG: nt.fatG,
                        carbsG: nt.carbsG,
                        fiberG: nt.fiberG,
                        bmr: 0,
                        baseDeficit: nt.baseDeficitKcal
                    )
                    targets.saveToStorage()
                    // 【方案A】saveToStorage 兼容壳写入原始 key，这里统一走 Repository 按当前账号隔离落盘
                    NutritionTargetsRepository.save(targets)
                }
                plan = fetchedPlan
            }
        }
        .sheet(isPresented: $showDeficitWarning) {
            deficitWarningSheet
        }
    }

    // MARK: - 身份标签

    private var identityBadge: some View {
        HStack(spacing: AppleGlassStyle.spacingXS) {
            Image(systemName: "person.text.rectangle")
                .font(.caption).foregroundColor(AppleGlassStyle.textSecondary)
            Text("\(identityVM.currentIdentity.rawValue)\(identityVM.currentIdentity.labelSuffix) · 可见 \(moduleCount) 模块")
                .font(.caption).foregroundColor(AppleGlassStyle.textSecondary)
            Spacer()
        }
        .padding(.horizontal, AppleGlassStyle.spacingSM)
        .padding(.vertical, AppleGlassStyle.spacingXS)
        .background(AppleGlassStyle.ultraThin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
    }

    // MARK: - 身体数据摘要

    private var bodySummaryCard: some View {
        VStack(alignment: .leading, spacing: AppleGlassStyle.spacingSM) {
            headerRow(title: "身体数据摘要", icon: "figure.arms.open")
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: AppleGlassStyle.spacingSM
            ) {
                summaryItem("身高", "\(String(format: "%.0f", bodyData.heightCm)) cm")
                summaryItem("体重", "\(String(format: "%.1f", bodyData.weightKg)) kg")
                summaryItem("年龄", "\(bodyData.age) 岁")
                summaryItem("性别", bodyData.sex.rawValue)
                summaryItem("BMI", String(format: "%.1f", bodyData.bmi))
                summaryItem("腰围", "\(String(format: "%.0f", bodyData.waistCm)) cm")
            }
            Divider().opacity(0.3)
            HStack(spacing: 4) {
                Image(systemName: "info.circle").font(.caption2).foregroundColor(AppleGlassStyle.textTertiary)
                Text(bodyData.waistToHeightNote).font(.caption).foregroundColor(AppleGlassStyle.textSecondary)
            }
        }
        .padding(AppleGlassStyle.spacingSM)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusLarge))
    }

    // MARK: - 四大补剂追踪卡片区

    //【用户需求整改：四补剂卡片替换原营养素数据栏，蛋白粉/肌酸/VD3/鱼油独立追踪】
    private var supplementTrackingSection: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            headerRow(title: "补剂摄入追踪", icon: "pills.fill")

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: AppleGlassStyle.spacingSM
            ) {
                // 1. 蛋白粉卡片
                supplementTrackingCard(
                    icon: "shippingbox.fill",
                    title: "蛋白粉",
                    current: proteinPowderG,
                    target: proteinPowderTarget,
                    unit: "g",
                    color: Color(.systemBlue),
                    format: "%.0f",
                    note: "仅统计补剂蛋白粉 · 天然食物蛋白在饮食Tab"
                )

                // 2. 肌酸卡片
                supplementTrackingCard(
                    icon: "bolt.shield.fill",
                    title: "肌酸",
                    current: creatineManager.todayCreatineGrams,  // 【修复肌酸饮水单次同步BUG｜改动业务：绑定全局单例，自动刷新】
                    target: creatineTarget,
                    unit: "g",
                    color: Color(.systemOrange),
                    format: "%.1f",
                    note: "维持期推荐 5g/日 · 冲击期建议 20g/日"
                )

                // 3. 维生素D3卡片
                supplementTrackingCard(
                    icon: "capsule.fill",
                    title: "维生素D3",
                    current: vitaminD3Mcg,
                    target: vitaminD3Target,
                    unit: "μg",
                    color: Color(.systemYellow),
                    format: "%.0f",
                    note: "20μg (800 IU)/日 · 骨骼肌状态参考"
                )

                // 4. 鱼油卡片
                supplementTrackingCard(
                    icon: "drop.circle.fill",
                    title: "鱼油",
                    current: fishOilMg,
                    target: fishOilTarget,
                    unit: "mg",
                    color: Color(.systemTeal),
                    format: "%.0f",
                    note: "核心统计EPA+DHA含量 · 非胶囊总重量"
                )
            }
        }
        .padding(AppleGlassStyle.spacingSM)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusLarge))
    }

    /// 单个补剂追踪卡片
    private func supplementTrackingCard(
        icon: String, title: String,
        current: Double, target: Double,
        unit: String, color: Color, format: String, note: String
    ) -> some View {
        let fraction = target > 0 ? min(current / target, 1.0) : 0
        let isComplete = current >= target && target > 0

        return VStack(alignment: .leading, spacing: 6) {
            // 图标 + 标题
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2).foregroundColor(color)
                Text(title)
                    .font(.caption).foregroundColor(AppleGlassStyle.textSecondary)
            }

            // 数值行
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: format, current))
                    .font(.title3.weight(.semibold))
                    .foregroundColor(isComplete ? color : AppleGlassStyle.textPrimary)
                Text("/ \(String(format: format, target))")
                    .font(.caption2).foregroundColor(AppleGlassStyle.textTertiary)
                Text(unit)
                    .font(.caption2).foregroundColor(AppleGlassStyle.textTertiary)
            }

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppleGlassStyle.thin).frame(height: 4)
                    Capsule()
                        .fill(isComplete ? color : color.opacity(0.5))
                        .frame(width: max(geo.size.width * CGFloat(fraction), 3), height: 4)
                }
            }
            .frame(height: 4)

            // 完成度百分比 + 备注
            HStack {
                Text("\(String(format: "%.0f", fraction * 100))%")
                    .font(.caption2).foregroundColor(isComplete ? color : AppleGlassStyle.textTertiary)
                Spacer()
            }

            Text(note)
                .font(.caption2).foregroundColor(AppleGlassStyle.textTertiary).lineLimit(2)
        }
        .padding(10)
        .background(AppleGlassStyle.ultraThin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
        .overlay(alignment: .topTrailing) {
            // 快速录入 ± 按钮
            HStack(spacing: 2) {
                Button { decrementSupp(for: title) } label: {
                    Image(systemName: "minus.circle.fill").font(.caption2).foregroundColor(AppleGlassStyle.textTertiary)
                }
                Button { incrementSupp(for: title) } label: {
                    Image(systemName: "plus.circle.fill").font(.caption2).foregroundColor(color)
                }
            }
            .padding(4)
        }
    }

    // MARK: - 补剂快速录入

    private func incrementSupp(for title: String) {
        switch title {
        case "蛋白粉":
            proteinPowderG += 5
            // 【网络层对接】持久化补剂摄入量
            saveSupplementIntake()
        case "肌酸":
            creatineManager.incrementCreatine(by: 1)  // 【修复肌酸饮水单次同步BUG｜改动业务：调用全局单例方法，自动广播通知饮食页】
        case "维生素D3":
            vitaminD3Mcg += 5
            // 【网络层对接】持久化补剂摄入量
            saveSupplementIntake()
        case "鱼油":
            fishOilMg += 250
            // 【网络层对接】持久化补剂摄入量
            saveSupplementIntake()
        default: break
        }
    }

    private func decrementSupp(for title: String) {
        switch title {
        case "蛋白粉":
            proteinPowderG = max(0, proteinPowderG - 5)
            // 【网络层对接】持久化补剂摄入量
            saveSupplementIntake()
        case "肌酸":
            creatineManager.decrementCreatine(by: 1)  // 【修复肌酸饮水单次同步BUG｜改动业务：调用全局单例方法，自动广播通知饮食页】
        case "维生素D3":
            vitaminD3Mcg = max(0, vitaminD3Mcg - 5)
            // 【网络层对接】持久化补剂摄入量
            saveSupplementIntake()
        case "鱼油":
            fishOilMg = max(0, fishOilMg - 250)
            // 【网络层对接】持久化补剂摄入量
            saveSupplementIntake()
        default: break
        }
    }

    // MARK: - 侧边补剂拖拽抽屉

    // 【修复编译报错｜故障根源：抽屉肌酸按钮残留已删除变量creatineG｜改动业务：替换为全局单例方法调用】
    private var supplementDrawer: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            Spacer().frame(height: AppleGlassStyle.spacingLG)
            Text("快速录入").font(.caption).foregroundColor(AppleGlassStyle.textSecondary)
            drawerPill(icon: "shippingbox.fill", label: "蛋白粉", color: Color(.systemBlue)) {
                proteinPowderG += 5
                saveSupplementIntake()
            }
            drawerPill(icon: "bolt.shield.fill", label: "肌酸", color: Color(.systemOrange)) { creatineManager.incrementCreatine(by: 1) }
            drawerPill(icon: "capsule.fill", label: "VD3", color: Color(.systemYellow)) {
                vitaminD3Mcg += 5
                saveSupplementIntake()
            }
            drawerPill(icon: "drop.circle.fill", label: "鱼油", color: Color(.systemTeal)) {
                fishOilMg += 250
                saveSupplementIntake()
            }
            Spacer()
        }
        .frame(width: 64)
        .padding(.vertical, AppleGlassStyle.spacingSM)
        .background(AppleGlassStyle.standard)
        .transition(.move(edge: .trailing))
    }

    private func drawerPill(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.body).foregroundColor(color)
                    .frame(width: 36, height: 36)
                    .background(AppleGlassStyle.ultraThin, in: Circle())
                Text(label).font(.caption2).foregroundColor(AppleGlassStyle.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 补剂量化模块区域

    private var supplementModules: some View {
        ForEach(Array(buildModules().prefix(moduleCount).enumerated()), id: \.offset) { _, module in
            supplementModuleCard(module)
        }
    }

    private struct SupplementModule {
        let id: String; let icon: String; let title: String
        let value: String; let unit: String; let note: String?
        let progressFraction: CGFloat; let hasLiterature: Bool
    }

    private func buildModules() -> [SupplementModule] {
        let p = plan
        let fOil = fishOilTarget
        return [
            SupplementModule(id: "bmi", icon: "flame.fill", title: "BMI 筛查区间",
                value: String(format: "%.1f", p.bmi), unit: "kg/m²",
                note: "区间：\(bodyData.bmiScreeningZone)", progressFraction: min(p.bmi / 40.0, 1.0), hasLiterature: false),
            SupplementModule(id: "tdee", icon: "bolt.fill", title: "TDEE 能量参考",
                value: String(format: "%.0f", p.tdeeKcal), unit: "kcal/日",
                note: "活动系数 1.55 × BMR", progressFraction: min(p.tdeeKcal / 4000.0, 1.0), hasLiterature: false),
            SupplementModule(id: "protein", icon: "fish.fill", title: "全天总蛋白目标",
                value: String(format: "%.1f", p.proteinTargetGrams), unit: "g/日",
                note: "1.8g/kg·含饮食+补剂",
                progressFraction: min(p.proteinTargetGrams / 300.0, 1.0), hasLiterature: true),
            SupplementModule(id: "whey", icon: "cup.and.saucer.fill", title: "乳清蛋白参考",
                value: String(format: "%.1f", p.wheyScoopsReference), unit: "勺/日",
                note: "30g/勺折算 · 饮食蛋白不足时补充",
                progressFraction: min(p.wheyScoopsReference / 10.0, 1.0), hasLiterature: true),
            SupplementModule(id: "fishOil", icon: "waveform.path.ecg", title: "鱼油参考",
                value: String(format: "%.0f", fOil), unit: "mg EPA+DHA/日",
                note: "循证文献健身安全摄入区间",
                progressFraction: min(fOil / 2000.0, 1.0), hasLiterature: true),
            SupplementModule(id: "vd3", icon: "sun.max.fill", title: "维生素D3参考",
                value: "2000", unit: "IU/日",
                note: "循证运动生理文献参考摄入量",
                progressFraction: 0.8, hasLiterature: true),
            SupplementModule(id: "creatine", icon: "bolt.shield.fill", title: "肌酸参考",
                value: "5", unit: "g/日",
                note: "单水肌酸维持用量", progressFraction: 0.7, hasLiterature: true),
            SupplementModule(id: "water", icon: "drop.fill", title: "水分参考",
                value: String(format: "%.2f", p.waterLitersReference), unit: "L/日",
                note: "33 mL/kg·体重", progressFraction: min(p.waterLitersReference / 5.0, 1.0), hasLiterature: false),
            SupplementModule(id: "bodyFat", icon: "scalemass.fill", title: "体脂率参考",
                value: String(format: "%.1f", p.bodyFat), unit: "%",
                note: "U.S. Navy 公式估算", progressFraction: min(p.bodyFat / 40.0, 1.0), hasLiterature: false),
        ]
    }

    private func supplementModuleCard(_ module: SupplementModule) -> some View {
        VStack(alignment: .leading, spacing: AppleGlassStyle.spacingSM) {
            headerRow(title: module.title, icon: module.icon)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(module.value).font(.title).fontWeight(.semibold).foregroundColor(AppleGlassStyle.textPrimary)
                Text(module.unit).font(.callout).foregroundColor(AppleGlassStyle.textSecondary)
                Spacer()
                if module.hasLiterature {
                    Image(systemName: "book.closed.fill").font(.system(size: 12)).foregroundColor(AppleGlassStyle.textTertiary)
                        .frame(width: 24, height: 24).background(AppleGlassStyle.ultraThin, in: Circle())
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppleGlassStyle.thin).frame(height: 6)
                    Capsule().fill(AppleGlassStyle.accent.opacity(0.6))
                        .frame(width: max(geo.size.width * module.progressFraction, 4), height: 6)
                }
            }.frame(height: 6)
            if let note = module.note {
                Text(note).font(.footnote).foregroundColor(AppleGlassStyle.textTertiary)
            }
        }
        .padding(AppleGlassStyle.spacingSM)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusLarge))
    }

    // MARK: - 底部免责

    private var disclaimerBar: some View {
        HStack(spacing: AppleGlassStyle.spacingXS) {
            Image(systemName: "exclamationmark.shield").font(.caption2).foregroundColor(AppleGlassStyle.textTertiary)
            Text(ComplianceText.supplementDisclaimer).font(.caption2).foregroundColor(AppleGlassStyle.textTertiary).lineLimit(3)
        }
        .padding(.horizontal, AppleGlassStyle.spacingSM).padding(.vertical, AppleGlassStyle.spacingXS)
        .frame(maxWidth: .infinity).background(AppleGlassStyle.ultraThin)
    }

    // MARK: - 通用组件

    private func headerRow(title: String, icon: String) -> some View {
        HStack(spacing: AppleGlassStyle.spacingXS) {
            Image(systemName: icon).font(.callout).foregroundColor(AppleGlassStyle.accent)
                .padding(6).background(AppleGlassStyle.ultraThin, in: RoundedRectangle(cornerRadius: 6))
            Text(title).font(.headline).foregroundColor(AppleGlassStyle.textPrimary)
            Spacer()
        }
    }

    private func summaryItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(AppleGlassStyle.textTertiary)
            Text(value).font(.body).foregroundColor(AppleGlassStyle.textPrimary)
        }
    }

    // MARK: - 【解耦改动】从 UserDefaults 直接读取迁移至 BodyDataRepository
    // 与 MineView、BodyDataInputView 共用同一 Repository 层
    private func loadBodyDataFromStorage() {
        let saved = BodyDataRepository.load()
        bodyData = saved
    }

    // MARK: - 【补剂页总缺口红色进度条】实时计算并刷新总热量缺口
    // 【解耦改动】NutritionTargets.loadFromStorage() → NutritionTargetsRepository.load()
    // 【本次修复｜热量缺口健康语义】拆分「建议总缺口（目标）」与「实际净缺口（扣摄入）」：
    // 警示基于实际净缺口（max(建议总缺口 − 当日摄入, 0)），消除"正常训练+正常饮食被误报"的问题
    private func refreshCalorieDeficit() {
        let nutritionTargets = NutritionTargetsRepository.load()
        let baseDeficit = nutritionTargets?.baseDeficit ?? 0
        let todayExercise = PhysiologyCalcTool.sumTodayTrainingConsume()
        totalDeficitToday = PhysiologyCalcTool.calcTotalCalorieDeficit(
            baseDeficit: baseDeficit, exerciseConsume: todayExercise
        )
        // 【本次修复｜热量缺口健康语义】读取当日饮食摄入（饮食页共享 key），计算实际净缺口
        todayKcalIntake = UserDefaults.standard.double(forKey: dailyKcalIntakeKey)
        actualNetDeficitToday = max(totalDeficitToday - todayKcalIntake, 0)
        // 【本次修复｜删除手动录入】警示始终基于公式计算的实际净缺口（扣摄入）
        if PhysiologyCalcTool.isDeficitOverWarningThreshold(actualNetDeficitToday) {
            showDeficitWarning = true
        }
    }

    // MARK: - 【补剂页总缺口红色进度条】UI组件

    /// 【本次修复｜热量缺口健康语义 + 删除手动录入】热量缺口卡片：
    /// 大数值为「实际净缺口（扣摄入）」，由公式实时计算，不支持手动覆盖
    private var calorieDeficitCard: some View {
        VStack(alignment: .leading, spacing: AppleGlassStyle.spacingSM) {
            headerRow(title: "当日建议创造的总热量缺口", icon: "flame.fill")

            VStack(spacing: 6) {
                // 数值居中展示（纯公式计算结果，不可编辑）
                VStack(spacing: 2) {
                    Text(String(format: "%.0f kcal", actualNetDeficitToday))
                        .font(.title2.weight(.bold))
                        .foregroundColor(.red)
                    Text("实际净缺口（扣除当日饮食摄入）")
                        .font(.system(size: 9))
                        .foregroundColor(AppleGlassStyle.textTertiary)
                }

                // 红色填充进度条（基于实际净缺口）
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red.opacity(0.1))
                            .frame(height: 10)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red)
                            .frame(width: min(CGFloat(actualNetDeficitToday / 1500) * geometry.size.width, geometry.size.width), height: 10)
                    }
                }
                .frame(height: 10)

                // 【本次修复｜热量缺口健康语义】明细：建议总缺口 vs 当日摄入 → 实际净缺口
                VStack(alignment: .leading, spacing: 2) {
                    Text("建议总缺口：基础缺口 \(String(format: "%.0f", NutritionTargetsRepository.load()?.baseDeficit ?? 0)) kcal + 运动消耗 \(String(format: "%.0f", PhysiologyCalcTool.sumTodayTrainingConsume())) kcal")
                        .font(.system(size: 9))
                        .foregroundColor(AppleGlassStyle.textTertiary)
                    Text("已摄入 \(String(format: "%.0f", todayKcalIntake)) kcal · 实际净缺口 \(String(format: "%.0f", actualNetDeficitToday)) kcal")
                        .font(.system(size: 9))
                        .foregroundColor(AppleGlassStyle.textTertiary)
                }
            }
        }
        .padding(AppleGlassStyle.spacingSM)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusLarge))
    }

    // MARK: - 【总热量缺口超标循证医学警示弹窗】800大卡警戒线
    private var deficitWarningSheet: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppleGlassStyle.spacingXS) {
                Image(systemName: "exclamationmark.triangle.fill").font(.caption2).foregroundColor(.red)
                Text("循证医学风险提示").font(.caption2).foregroundColor(.red)
                Spacer()
            }
            .padding(.horizontal, AppleGlassStyle.spacingSM)
            .padding(.vertical, AppleGlassStyle.spacingXS)
            .background(Color.red.opacity(0.06))

            VStack(spacing: AppleGlassStyle.spacingSM) {
                ZStack {
                    Circle().fill(Color.red.opacity(0.1)).frame(width: 56, height: 56)
                    Image(systemName: "exclamationmark.triangle.fill").font(.title2).foregroundStyle(.red)
                }

                Text("总热量缺口过大").font(.headline).foregroundColor(AppleGlassStyle.textPrimary)

                VStack(alignment: .leading, spacing: AppleGlassStyle.spacingXS) {
                    // 【本次修复｜热量缺口健康语义】警示基于「实际净缺口」（扣除当日饮食摄入）
                    Text("您当前实际净热量缺口（建议总缺口扣除当日饮食摄入）已超过800大卡，依据《中国超重/肥胖医学营养治疗指南》及多篇减脂循证医学研究：")
                        .font(.subheadline).foregroundColor(AppleGlassStyle.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    bulletText("长期维持过大热量缺口会降低基础代谢率（BMR），进入代谢适应期后减脂效率大幅下降")
                    bulletText("热量缺口过度会升高皮质醇水平、扰乱瘦素/饥饿素内分泌调控机制，引发平台期与体重反弹")
                    bulletText("过于激进的热量缺口容易造成肌肉流失，进一步降低代谢水平，形成恶性循环")
                    bulletText("女性过大热量缺口还可能引起月经周期紊乱、雌激素水平下降等内分泌问题")

                    Text("建议方案：「适当降低运动时长」或「小幅提高每日饮食摄入热量」，将实际净缺口控制在800大卡以内，维持长期、可持续的健康减脂节奏。")
                        .font(.subheadline.weight(.medium)).foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AppleGlassStyle.spacingSM)
                .background(Color.red.opacity(0.04), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))

                Divider().padding(.horizontal, -AppleGlassStyle.spacingSM)

                Button {
                    showDeficitWarning = false
                } label: {
                    Text("我知道了").font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(AppleGlassStyle.accent, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
                }
            }
            .padding(AppleGlassStyle.spacingSM)
            .background(AppleGlassStyle.standard)
            .clipShape(RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
        }
        .padding(.horizontal, AppleGlassStyle.spacingMD)
        .padding(.vertical, AppleGlassStyle.spacingMD)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppleGlassStyle.groupedBackground)
        .presentationDetents([.medium, .large])
    }

    private func bulletText(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").font(.subheadline).foregroundColor(.red)
            Text(text).font(.subheadline).foregroundColor(AppleGlassStyle.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 【补剂页新增肌酸饮水量进度条】UI组件（绑定全局肌酸单例，实时响应数据变更）
    // 【修复肌酸饮水单次同步BUG｜改动业务：标题/目标全部绑定creatineManager，@Published自动触发重绘】
    private var waterIntakeCard: some View {
        let targetL = creatineManager.waterTargetLiters
        let ratio = targetL > 0 ? min(waterIntakeTodayL / targetL, 1.0) : 0
        let remaining = max(targetL - waterIntakeTodayL, 0)

        return VStack(alignment: .leading, spacing: AppleGlassStyle.spacingSM) {
            headerRow(title: creatineManager.waterTitle, icon: "drop.fill")

            VStack(spacing: 6) {
                Text("已摄入 \(String(format: "%.1f", waterIntakeTodayL))L / 目标 \(String(format: "%.1f", targetL))L")
                    .font(.title3.weight(.medium))
                    .foregroundColor(AppleGlassStyle.textPrimary)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.1))
                            .frame(height: 10)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue)
                            .frame(width: CGFloat(ratio) * geometry.size.width, height: 10)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text("剩余可饮水: \(String(format: "%.1f", remaining))L")
                        .font(.system(size: 9))
                        .foregroundColor(AppleGlassStyle.textTertiary)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("录入饮水(L)").font(.system(size: 9)).foregroundColor(AppleGlassStyle.textTertiary)
                        TextField("0.0", value: $waterIntakeTodayL, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 40)
                    }
                }
            }
        }
        .padding(AppleGlassStyle.spacingSM)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusLarge))
        .onChange(of: waterIntakeTodayL) { _ in
            saveSupplementIntake()
        }
    }

    // MARK: - 【网络层对接】持久化补剂摄入量

    private func saveSupplementIntake() {
        let data = SupplementIntakeData(
            proteinPowderG: proteinPowderG,
            vitaminD3Mcg: vitaminD3Mcg,
            fishOilMg: fishOilMg,
            waterIntakeTodayL: waterIntakeTodayL
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: supplementIntakeStorageKey)
        }
        // 【本次修复｜饮水联动】补剂页手动录入饮水量时同步写回共享 key（饮食页读取保持一致）
        UserDefaults.standard.set(waterIntakeTodayL, forKey: dailyWaterIntakeKey)
    }
}

// MARK: - 补剂摄入持久化模型
struct SupplementIntakeData: Codable {
    let proteinPowderG: Double
    let vitaminD3Mcg: Double
    let fishOilMg: Double
    let waterIntakeTodayL: Double
}

#Preview {
    NavigationStack {
        SupplementView(bodyData: .constant(BodyDataModel()))
            .environmentObject(GlobalCreatineManager.shared)
    }
}
