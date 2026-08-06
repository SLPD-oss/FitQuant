import SwiftUI
import Foundation

// MARK: - DietView
// //【合规隔离红线】Diet data is stored locally only.
// //【合规隔离红线】No medical nutrition therapy or prescribed diet plans.

struct DietView: View {
    @Binding var bodyData: BodyDataModel
    // 【修复肌酸饮水单次同步BUG｜改动业务：注入全局响应式肌酸单例，替代页面本地肌酸变量+onAppear刷新】
    @EnvironmentObject var creatineManager: GlobalCreatineManager
    @State private var mealRecords: [MealRecordModel] = []
    // 【网络层对接】饮食记录持久化 Key
    // 【方案A】按当前账号生成作用域 key（{baseKey}_{userId}），未登录回退原始 key
    private var mealRecordsStorageKey: String {
        AccountScopedStore.scopedKey("saved_mealRecords_v2")
    }
    @State private var selectedMealType: MealType? = nil

    // Food entry fields
    @State private var foodName: String = ""
    @State private var entryMealType: MealType = .breakfast
    // 【拆分四餐独立数据｜修复多餐共用同一录入变量BUG｜改动：拆分各餐营养素状态变量】
    /// 四餐独立营养素数据存储字典，键为餐次类型，值为该餐全部8项营养素
    @State private var allMealsData: [MealType: MealNutrients] = [:]
    /// 当前编辑面板的8项营养素变量（绑定UI控件，切换餐次时自动保存/加载）
    @State private var editingProtein: Double = 0
    @State private var editingFat: Double = 0
    @State private var editingCarbs: Double = 0
    // 新增：膳食纤维独立数值变量
    @State private var editingFiber: Double = 0
    // 【录入面板新增钠(mg)调节控件】录入面板钠毫克输入变量
    @State private var editingSodium: Double = 0
    // 【录入面板新增咖啡因(mg)调节控件】录入面板咖啡因毫克输入变量
    @State private var editingCaffeine: Double = 0
    @State private var editingWater: Double = 0
    @State private var editingSugar: Double = 0
    /// 记录上一次餐次类型，防止首次onAppear误触发onChange保存空数据
    @State private var lastMealType: MealType? = nil
    @State private var kcal: Double = 0
    @State private var servingAmount: Double = 1
    @State private var servingUnit: String = "份"

    // 新增：相机识别相关状态
    @State private var showCameraSheet: Bool = false
    @State private var showRecognitionComplianceAlert: Bool = false
    @State private var recognitionFoodName: String = ""

    // 【饮食页面新增钠摄入指标】钠摄入追踪
    @State private var sodiumTotalMg: Double = 0
    // 【饮食页面新增咖啡因摄入指标】咖啡因摄入追踪 + 咖啡ml输入
    @State private var caffeineTotalMg: Double = 0
    @State private var coffeeMlInput: Double = 0
    // 【录入面板新增饮水量调节控件 + 顶部卡片】饮水L总摄入追踪（录入变量已拆分至editingWater）
    @State private var waterTotalL: Double = 0
    // 【录入面板新增添加糖(g)调节控件 + 顶部卡片】添加糖g总摄入追踪（录入变量已拆分至editingSugar）
    @State private var addedSugarTotalG: Double = 0
    // WHO循证标准：每日添加糖上限25g（约6茶匙）
    private let addedSugarDailyMaxG: Double = 25

    private var filteredRecords: [MealRecordModel] {
        guard let selectedMealType else { return mealRecords }
        return mealRecords.filter { $0.mealType == selectedMealType }
    }

    private var macroSummary: MacroSummary {
        MacroSummary.from(filteredRecords)
    }

    // 【解耦改动】NutritionTargets.loadFromStorage() → NutritionTargetsRepository.load()
    private var nutritionTargets: NutritionTargets? {
        NutritionTargetsRepository.load()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppleGlassStyle.spacingMD) {
                    macroProgressCards
                    mealTypeFilter
                    foodEntryCard
                    mealLogList
                    bottomDisclaimer
                }
                .padding(AppleGlassStyle.spacingMD)
            }
            .background(AppleGlassStyle.groupedBackground)
            .navigationTitle("饮食")
            // 【本次修复｜业务：首屏默认早餐初始化未存数据，早→午餐首次切换数据错乱BUG】
            // 页面首次载入时，默认选中早餐的初始数据存入早餐专属存储区，确保后续onChange切换可正确保存/加载
            .onAppear {
                saveEditingNutrients(to: .breakfast)
                // 【网络层对接】从本地持久化加载饮食记录
                if let data = UserDefaults.standard.data(forKey: mealRecordsStorageKey),
                   let saved = try? JSONDecoder().decode([MealRecordModel].self, from: data) {
                    mealRecords = saved
                }
                // 【网络层对接】从后端加载今日饮食记录
                Task {
                    await loadMealsFromAPI()
                }
            }
            // 相机拍照sheet
            .sheet(isPresented: $showCameraSheet) {
                cameraPlaceholderView
            }
            // AI识别完成合规弹窗
            .sheet(isPresented: $showRecognitionComplianceAlert) {
                recognitionCompliancePopover
            }
        }
    }

    // MARK: - 【饮食营养素可视化渲染】Macro Progress Cards（膳食纤维+热量独立进度条）
    // 【修复红色阻断报错】补return关键字 + VStack包裹LazyVGrid和热量独立卡片解决opaque类型推断
    private var macroProgressCards: some View {
        // 优先读取身体录入页营养目标，无存储时回退体重估算
        let proteinTarget = nutritionTargets?.proteinG ?? bodyData.weightKg * 2.0
        let fatTarget = nutritionTargets?.fatG ?? bodyData.weightKg * 1.0
        let carbsTarget = nutritionTargets?.carbsG ?? bodyData.weightKg * 4.0
        let fiberTarget = nutritionTargets?.fiberG ?? 25.0
        let kcalTarget = nutritionTargets?.dailyKcal ?? bodyData.bmr * 1.55
        let sodiumTarget = PhysiologyCalcTool.sodiumDailyMaxMg
        // 咖啡因 = 食物自带 + 咖啡换算
        let caffeineTarget = PhysiologyCalcTool.caffeineDailyMaxMg
        let coffeeCaffeine = PhysiologyCalcTool.convertCoffeeMlToCaffeine(ml: coffeeMlInput)
        let totalCaffeine = caffeineTotalMg + coffeeCaffeine
        // 【修复肌酸饮水单次同步BUG｜改动业务：饮水目标、文案全绑定全局肌酸单例，@Published自动广播刷新】
        let waterTarget = creatineManager.waterTargetLiters
        let waterHintText = creatineManager.waterDescText

        return VStack(spacing: AppleGlassStyle.spacingSM) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AppleGlassStyle.spacingSM),
                    GridItem(.flexible(), spacing: AppleGlassStyle.spacingSM)
                ],
                spacing: AppleGlassStyle.spacingSM
            ) {
                enhancedMacroCard(title: "蛋白质", consumed: macroSummary.totalProtein, target: proteinTarget, unit: "g", color: .blue, icon: "fish.fill")
                enhancedMacroCard(title: "脂肪", consumed: macroSummary.totalFat, target: fatTarget, unit: "g", color: .orange, icon: "drop.fill")
                enhancedMacroCard(title: "碳水", consumed: macroSummary.totalCarbs, target: carbsTarget, unit: "g", color: .green, icon: "leaf.fill")
                enhancedMacroCard(title: "膳食纤维", consumed: macroSummary.totalFiber, target: fiberTarget, unit: "g", color: .brown, icon: "chart.bar.doc.horizontal.fill")
                // 【改造钠摄入卡片为小方框布局】并入主营养素Grid，和蛋白/碳水同款样式
                enhancedMacroCard(title: "钠(盐分)", consumed: sodiumTotalMg, target: sodiumTarget, unit: "mg", color: .purple, icon: "bolt.heart.fill")
                // 【改造咖啡因摄入卡片为小方框布局】并入主营养素Grid，和其余卡片统一
                enhancedMacroCard(title: "咖啡因", consumed: totalCaffeine, target: caffeineTarget, unit: "mg", color: .brown, icon: "cup.and.saucer.fill")
                // 【DietView饮水量卡片动态更新推荐值+提示小字】自定义卡片含动态备注
                waterHintCard(title: "饮水量", consumed: waterTotalL, target: waterTarget, unit: "L", color: .cyan, icon: "drop.fill", hintText: waterHintText)
                // 【录入面板新增添加糖(g)调节控件】添加糖小方框卡片，WHO上限25g
                enhancedMacroCard(title: "添加糖", consumed: addedSugarTotalG, target: addedSugarDailyMaxG, unit: "g", color: .pink, icon: "birthday.cake.fill")
            }
            // 热量独立进度条（单行全宽）
            enhancedMacroCard(title: "热量", consumed: macroSummary.totalKcal, target: kcalTarget, unit: "kcal", color: .red, icon: "flame.fill")
            // 咖啡毫升录入行（小字，紧跟咖啡因卡片下方）
            coffeeMlInputRow
        }
    }

    // 【改造咖啡因摄入卡片为小方框布局】咖啡ml手动录入行，紧跟Grid下方
    private var coffeeMlInputRow: some View {
        HStack(spacing: 4) {
            Text("咖啡毫升录入:").font(.system(size: 9)).foregroundColor(AppleGlassStyle.textTertiary)
            TextField("0", value: $coffeeMlInput, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 10, weight: .medium))
                .frame(width: 50)
            Text("ml").font(.system(size: 9)).foregroundColor(AppleGlassStyle.textTertiary)
            Spacer()
            Text("≈ \(String(format: "%.0f", PhysiologyCalcTool.convertCoffeeMlToCaffeine(ml: coffeeMlInput)))mg咖啡因")
                .font(.system(size: 8)).foregroundColor(AppleGlassStyle.accent)
        }
        .padding(.horizontal, 4)
    }

    // 【DietView饮水量卡片动态更新推荐值+提示小字】带动态备注文案的饮水卡片（复用enhancedMacroCard布局+底部提示）
    private func waterHintCard(title: String, consumed: Double, target: Double, unit: String, color: Color, icon: String, hintText: String) -> some View {
        let consumedVal = String(format: "%.1f", consumed)
        let targetVal = String(format: "%.1f", target)
        let remaining = max(target - consumed, 0)
        let ratio = target > 0 ? min(consumed / target, 1.0) : 0.0

        return VStack(alignment: .leading, spacing: AppleGlassStyle.spacingXS) {
            HStack {
                Image(systemName: icon).font(.caption).foregroundStyle(color)
                Text(title).font(.caption.weight(.medium)).foregroundStyle(AppleGlassStyle.textSecondary)
                Spacer()
                Text("每日推荐: \(targetVal)\(unit)")
                    .font(.system(size: 8)).foregroundStyle(AppleGlassStyle.textTertiary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(consumedVal).font(.title2.weight(.bold)).foregroundStyle(ratio > 1.0 ? Color.red : AppleGlassStyle.textPrimary)
                Text("/ \(targetVal) \(unit)")
                    .font(.caption2).foregroundStyle(AppleGlassStyle.textTertiary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.12)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ratio > 1.0 ? Color.red : color)
                        .frame(width: CGFloat(ratio) * geometry.size.width, height: 6)
                }
            }
            .frame(height: 6)
            Text("剩余: \(String(format: "%.1f", remaining))\(unit)")
                .font(.system(size: 8)).foregroundStyle(AppleGlassStyle.textTertiary)
            // 【DietView饮水量卡片动态更新推荐值+提示小字】动态备注文案
            Text(hintText)
                .font(.system(size: 7)).foregroundStyle(color.opacity(0.7))
        }
        .padding(AppleGlassStyle.spacingSM)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
    }

    /// 【饮食营养素可视化渲染】增强版营养素卡片：每日推荐标签 + 进度条 + 剩余额度
    private func enhancedMacroCard(title: String, consumed: Double, target: Double, unit: String, color: Color, icon: String) -> some View {
        let consumedVal = String(format: "%.0f", consumed)
        let targetVal = String(format: "%.0f", target)
        let remaining = max(target - consumed, 0)
        let ratio = target > 0 ? min(consumed / target, 1.0) : 0.0

        return VStack(alignment: .leading, spacing: AppleGlassStyle.spacingXS) {
            HStack {
                Image(systemName: icon).font(.caption).foregroundStyle(color)
                Text(title).font(.caption.weight(.medium)).foregroundStyle(AppleGlassStyle.textSecondary)
                Spacer()
                // 每日推荐小字标签
                Text("每日推荐: \(targetVal)\(unit)")
                    .font(.system(size: 8)).foregroundStyle(AppleGlassStyle.textTertiary)
            }

            // 双数值行：已摄入 / 推荐
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(consumedVal).font(.title2.weight(.bold)).foregroundStyle(ratio > 1.0 ? Color.red : AppleGlassStyle.textPrimary)
                Text("/ \(targetVal) \(unit)")
                    .font(.caption2).foregroundStyle(AppleGlassStyle.textTertiary)
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.12)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ratio > 1.0 ? Color.red : color)
                        .frame(width: CGFloat(ratio) * geometry.size.width, height: 6)
                }
            }
            .frame(height: 6)

            // 剩余可摄入额度
            Text("剩余可摄入: \(String(format: "%.0f", remaining))\(unit)")
                .font(.system(size: 8)).foregroundStyle(remaining > 0 ? AppleGlassStyle.textTertiary : Color.red)
        }
        .padding(AppleGlassStyle.spacingSM)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
    }

    // MARK: - Meal Type Filter（中文标签）—【删除餐次栏补剂Tab标签】仅保留4餐次
    private var mealTypeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppleGlassStyle.spacingSM) {
                FilterChip(label: "全部餐次", isSelected: selectedMealType == nil) { selectedMealType = nil }
                ForEach(MealType.allCases.filter { $0 != .supplement }) { type in
                    FilterChip(label: type.displayName, isSelected: selectedMealType == type) { selectedMealType = type }
                }
            }
            .padding(.horizontal, AppleGlassStyle.spacingXS)
        }
    }

    // MARK: - Food Entry Card（相机识别 + 营养素微调 + 热量自动计算）
    private var foodEntryCard: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            Text("记录食物")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppleGlassStyle.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 食物名称 + 相机按钮
            HStack(spacing: AppleGlassStyle.spacingSM) {
                TextField("食物名称", text: $foodName)
                    .textFieldStyle(.plain)
                    .padding(AppleGlassStyle.spacingSM)
                    .background(Color(.systemFill).opacity(0.2), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))

                // 新增相机拍照识别食物控件，内置后端食物识别算法接口适配层
                Button {
                    showCameraSheet = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.body)
                        .foregroundColor(AppleGlassStyle.accent)
                        .frame(width: 40, height: 40)
                        .background(AppleGlassStyle.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
                }
            }

            // 餐次分段选择（中文标签）—【删除餐次栏补剂Tab标签】移除补剂选项
            Picker("餐次", selection: $entryMealType) {
                ForEach(MealType.allCases.filter { $0 != .supplement }) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            // 【修复首餐切换数据清零BUG｜故障根源：lastMealType初始nil分支跳过首次存数据逻辑】
            .onChange(of: entryMealType) {
                if lastMealType == nil {
                    // 首次切换：先保存当前初始餐的录入数据，再赋值标记，再加载新餐
                    // 【本次修复｜业务：nil分支save入参存餐目标错误，早午首次切换数据错乱清零BUG】
                    // entryMealType在onChange触发时已变为新餐(午餐)，传入save导致早餐数据错存入午餐存储区；固定传入.breakfast(页面默认初始餐)精准存入早餐专属存储
                    saveEditingNutrients(to: .breakfast)
                    lastMealType = entryMealType
                    loadEditingNutrients()
                } else {
                    // 后续切换：①先存旧餐→②更新标记→③再加载新餐
                    saveEditingNutrients(to: lastMealType!)
                    lastMealType = entryMealType
                    loadEditingNutrients()
                }
            }

            // AI识别合规声明（常驻提示）
            Text("AI识别营养数值为模型估算，无法保证100%精准，仅供日常饮食记录参考")
                .font(.caption2)
                .foregroundColor(AppleGlassStyle.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 【拆分四餐独立数据｜改动：四大营养素录入控件绑定当前餐次editing变量】四大营养素录入行：蛋白质 + 脂肪
            HStack(spacing: AppleGlassStyle.spacingSM) {
                nutrientStepperRow(icon: "fish.fill", label: "蛋白质", value: $editingProtein, unit: "g", step: 5, color: .blue)
                nutrientStepperRow(icon: "drop.fill", label: "脂肪", value: $editingFat, unit: "g", step: 5, color: .orange)
            }
            // 碳水 + 膳食纤维
            HStack(spacing: AppleGlassStyle.spacingSM) {
                nutrientStepperRow(icon: "leaf.fill", label: "碳水", value: $editingCarbs, unit: "g", step: 10, color: .green)
                nutrientStepperRow(icon: "chart.bar.doc.horizontal.fill", label: "膳食纤维", value: $editingFiber, unit: "g", step: 2, color: .brown)
            }
            // 【拆分四餐独立数据｜改动：钠/咖啡因录入控件绑定当前餐次editing变量】【录入面板新增钠(mg)调节控件】钠±调节，步长10mg，不参与热量换算
            HStack(spacing: AppleGlassStyle.spacingSM) {
                nutrientStepperRow(icon: "bolt.heart.fill", label: "钠（盐分）", value: $editingSodium, unit: "mg", step: 10, color: .purple)
                // 【录入面板新增咖啡因(mg)调节控件】咖啡因±调节，步长10mg，不参与热量换算
                nutrientStepperRow(icon: "cup.and.saucer.fill", label: "咖啡因", value: $editingCaffeine, unit: "mg", step: 10, color: .brown)
            }
            // 【录入面板新增饮水量调节控件】饮水±调节，步长0.1L，不参与热量换算
            // 【录入面板新增添加糖(g)调节控件】添加糖±调节，步长1g，不参与热量换算
            HStack(spacing: AppleGlassStyle.spacingSM) {
                // 【拆分四餐独立数据｜改动：录入控件绑定当前餐次editing变量】
                nutrientStepperRow(icon: "drop.fill", label: "饮水量", value: $editingWater, unit: "L", step: 0.1, color: .cyan)
                nutrientStepperRow(icon: "birthday.cake.fill", label: "糖", value: $editingSugar, unit: "g", step: 1, color: .pink)
            }

            // 热量只读展示（自动计算，禁止手动编辑）
            // 热量经典换算公式：蛋白质×4 + 脂肪×9 + 碳水×4 + 膳食纤维×2 + 糖×4
            // 【拆分四餐独立数据｜改动：热量计算使用当前餐次editing变量，仅展示当前选中餐的即时热量】
            let autoKcal = editingProtein * 4 + editingFat * 9 + editingCarbs * 4 + editingFiber * 2 + editingSugar * 4
            HStack {
                Image(systemName: "flame.fill").font(.caption).foregroundColor(.red)
                Text("热量（自动计算）")
                    .font(.caption).foregroundColor(AppleGlassStyle.textTertiary)
                Spacer()
                Text(String(format: "%.0f", autoKcal))
                    .font(.title3.weight(.bold)).foregroundColor(.red)
                Text("kcal").font(.caption2).foregroundColor(AppleGlassStyle.textTertiary)
            }
            .padding(AppleGlassStyle.spacingSM)
            .background(Color.red.opacity(0.05), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))

            // 【新增一键录入全天总摄入按钮与逻辑】无需选定餐次，直接叠加至全天总摄入
            Button {
                quickAddToDailyTotal()
            } label: {
                Label("一键录入至全天总摄入", systemImage: "square.and.arrow.down.on.square.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppleGlassStyle.spacingSM)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
            }

            // 【拆分四餐独立数据｜改动：添加食物仅保存当前选中餐次的录入数据，不影响其余三餐】添加食物按钮
            Button {
                let finalKcal = editingProtein * 4 + editingFat * 9 + editingCarbs * 4 + editingFiber * 2 + editingSugar * 4
                let record = MealRecordModel(
                    foodName: foodName, mealType: entryMealType,
                    proteinGrams: editingProtein, fatGrams: editingFat, carbsGrams: editingCarbs,
                    dietaryFiber: editingFiber > 0 ? editingFiber : nil,
                    kcal: finalKcal, servingAmount: servingAmount, servingUnit: servingUnit,
                    recognitionSource: nil, createdAt: Date()
                )
                mealRecords.insert(record, at: 0)
                // 【拆分四餐独立数据｜改动：叠加当前餐次的钠、咖啡因至全天总摄入】【录入面板新增钠(mg)调节控件】录入的钠、咖啡因同步叠加至全天总摄入
                sodiumTotalMg += editingSodium
                caffeineTotalMg += editingCaffeine
                // 【拆分四餐独立数据｜改动：叠加当前餐次的饮水量、糖至全天总摄入】【录入面板新增饮水量/添加糖调节控件】叠加至全天总摄入
                waterTotalL += editingWater
                addedSugarTotalG += editingSugar
                // 【网络层对接】持久化到本地
                if let data = try? JSONEncoder().encode(mealRecords) {
                    UserDefaults.standard.set(data, forKey: mealRecordsStorageKey)
                }
                // 【网络层对接】云端同步（静默）
                Task {
                    let syncBody = SyncBatchRequest(
                        sync_mode: "incremental",
                        user_id: LoginUserStorage.userId ?? "",
                        body_data: [],
                        meal_records: [MealSyncRecord(
                            recorded_at: ISO8601DateFormatter().string(from: Date()),
                            meal_type: record.mealType.rawValue,
                            food_name: record.foodName,
                            protein_g: record.proteinGrams,
                            fat_g: record.fatGrams,
                            carbs_g: record.carbsGrams,
                            fiber_g: record.dietaryFiber ?? 0,
                            kcal: record.kcal
                        )],
                        training_records: [],
                        drug_records: [],
                        deleted_drug_records: [],
                        clear_all_drugs: false,
                        supplement_records: [],
                        sleep_records: []
                    )
                    do {
                        let _: SyncBatchResponse = try await APIClient.shared.post("/api/sync/batch", body: syncBody)
                        print("[DietView] 饮食记录云端同步成功")
                    } catch {
                        print("[DietView] 饮食记录云端同步失败: \(error.localizedDescription)")
                    }
                }
                resetFoodFields()
            } label: {
                Label("添加食物", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppleGlassStyle.spacingSM)
                    .background(AppleGlassStyle.accent, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
            }
            .disabled(foodName.isEmpty)
            .opacity(foodName.isEmpty ? 0.5 : 1.0)
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    // 新增独立营养素加减微调控件，替代原macroEntryField
    private func nutrientStepperRow(icon: String, label: String, value: Binding<Double>, unit: String, step: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppleGlassStyle.spacingXS) {
            HStack(spacing: 2) {
                Image(systemName: icon).font(.caption2).foregroundStyle(color)
                Text(label).font(.caption2).foregroundStyle(AppleGlassStyle.textTertiary)
            }
            HStack(spacing: 2) {
                Button {
                    value.wrappedValue = max(0, value.wrappedValue - step)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.caption).foregroundStyle(color.opacity(0.6))
                }
                .buttonStyle(.plain)
                TextField("0", value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppleGlassStyle.textPrimary)
                    .frame(width: 44)
                Button {
                    value.wrappedValue += step
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption).foregroundStyle(color)
                }
                .buttonStyle(.plain)
                Text(unit).font(.caption2).foregroundStyle(AppleGlassStyle.textTertiary)
            }
        }
        .padding(AppleGlassStyle.spacingSM)
        .background(Color(.systemFill).opacity(0.06), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
    }

    // MARK: - Camera Placeholder（预留后端食物热量识别算法对接接口）
    private var cameraPlaceholderView: some View {
        VStack(spacing: AppleGlassStyle.spacingMD) {
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(AppleGlassStyle.textTertiary)
            Text("拍照识别食物（演示）")
                .font(.headline).foregroundColor(AppleGlassStyle.textPrimary)
            Text("此处为系统相机占位区域，拍照后将图像传输至后端食物热量识别算法，返回该食物全套营养素数据。\n当前演示阶段内置模拟识别数据用于效果预览。")
                .font(.subheadline).foregroundColor(AppleGlassStyle.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, AppleGlassStyle.spacingLG)
            // 模拟识别按钮
            Button {
                performRecognition()
            } label: {
                Label("模拟拍照识别", systemImage: "camera.shutter.button.fill")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppleGlassStyle.spacingLG)
                    .padding(.vertical, AppleGlassStyle.spacingSM)
                    .background(AppleGlassStyle.accent, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
            }
            Spacer()
            Button("关闭") { showCameraSheet = false }
                .font(.subheadline).foregroundColor(AppleGlassStyle.textTertiary)
        }
        .padding()
        .background(AppleGlassStyle.groupedBackground)
    }

    // 【解耦改动】内联食物映射逻辑迁移至 FoodRecognitionService
    // 后端识别接口适配层：拍照后图像通过接口传输至后端食物热量识别算法
    // 当前前端演示阶段使用 FoodRecognitionService 模拟识别数据
    private let foodRecognitionService = FoodRecognitionService()

    private func performRecognition() {
        Task {
            let result = await self.foodRecognitionService.recognizeFromAPI(foodName: self.foodName)
            await MainActor.run {
                self.editingProtein = result.proteinGrams
                self.editingFat = result.fatGrams
                self.editingCarbs = result.carbsGrams
                self.editingFiber = result.fiberGrams
                self.editingSodium = result.sodiumMg
                self.editingSugar = result.sugarG
                self.kcal = result.kcal
                self.closeCameraAndShowCompliance()
            }
        }
    }

    private func closeCameraAndShowCompliance() {
        showCameraSheet = false
        recognitionFoodName = foodName
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showRecognitionComplianceAlert = true
        }
    }

    // 新增食物识别合规声明弹窗：AI模型估算结果无法保证100%精准，仅作饮食参考
    private var recognitionCompliancePopover: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppleGlassStyle.spacingXS) {
                Image(systemName: "info.circle").font(.caption2)
                Text(ComplianceText.alertDisclaimerPrefix).font(.caption2)
                Spacer()
            }
            .foregroundColor(AppleGlassStyle.textTertiary)
            .padding(.horizontal, AppleGlassStyle.spacingSM)
            .padding(.vertical, AppleGlassStyle.spacingXS)
            .background(AppleGlassStyle.ultraThin)

            VStack(spacing: AppleGlassStyle.spacingSM) {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.1)).frame(width: 56, height: 56)
                    Image(systemName: "camera.metering.matrix").font(.title2).foregroundStyle(.blue)
                }
                Text("食物识别完成").font(.headline).foregroundColor(AppleGlassStyle.textPrimary)
                VStack(alignment: .leading, spacing: AppleGlassStyle.spacingXS) {
                    Text("\"\(recognitionFoodName)\"的营养数值已由AI视觉模型估算并自动填充。")
                        .font(.subheadline).foregroundColor(AppleGlassStyle.textSecondary)
                    Text("该结果为模型估算值，无法保证100%精准。蛋白质/脂肪/碳水/膳食纤维四项数值均可手动微调，热量将根据调整后的数值自动重算。")
                        .font(.subheadline).foregroundColor(AppleGlassStyle.textSecondary)
                    Text("AI识别数值仅供日常饮食记录参考，不可作为专业医疗、减脂诊疗依据。")
                        .font(.subheadline.weight(.medium)).foregroundColor(AppleGlassStyle.textTertiary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(AppleGlassStyle.spacingSM)
                .background(Color.blue.opacity(0.04), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))

                Divider().padding(.horizontal, -AppleGlassStyle.spacingSM)

                Button {
                    showRecognitionComplianceAlert = false
                } label: {
                    Text("我已知晓，开始微调")
                        .font(.headline.weight(.semibold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, AppleGlassStyle.spacingSM)
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
        .presentationDetents([.medium])
    }

    // MARK: - Meal Log List
    private var mealLogList: some View {
        VStack(alignment: .leading, spacing: AppleGlassStyle.spacingSM) {
            if !filteredRecords.isEmpty {
                Text("饮食记录").font(.headline).foregroundStyle(AppleGlassStyle.textPrimary)
            }
            ForEach(filteredRecords) { record in
                MealLogRow(record: record)
            }
            if mealRecords.isEmpty {
                VStack(spacing: AppleGlassStyle.spacingMD) {
                    Image(systemName: "takeoutbag.and.cup.and.straw")
                        .font(.system(size: 40)).foregroundStyle(AppleGlassStyle.textTertiary)
                    Text("暂无饮食记录").font(.subheadline).foregroundStyle(AppleGlassStyle.textSecondary)
                    Text("记录您的每一餐，追踪宏量营养素摄入").font(.caption).foregroundStyle(AppleGlassStyle.textTertiary)
                }
                .padding(.vertical, AppleGlassStyle.spacingLG).frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Bottom Disclaimer
    private var bottomDisclaimer: some View {
        VStack(spacing: AppleGlassStyle.spacingXS) {
            ComplianceText(text: "【合规隔离红线】饮食数据仅作个人记录，不构成营养建议。如有特殊饮食需求请咨询注册营养师。")
            ComplianceText(text: "【合规隔离红线】所有饮食数据保存在本地设备，不会被用于广告推荐或健康评估报告。")
        }
    }

    private func resetFoodFields() {
        foodName = ""
        editingProtein = 0; editingFat = 0; editingCarbs = 0
        editingFiber = 0; kcal = 0
        editingSodium = 0; editingCaffeine = 0   // 【录入面板新增钠/咖啡因调节控件】重置录入变量
        editingWater = 0; editingSugar = 0  // 【录入面板新增饮水量/添加糖调节控件】重置录入变量
        servingAmount = 1
        // 【修复四餐存储BUG｜改动：重置后自动回写当前餐次的allMealsData，防止切换餐次时旧数据回弹】
        saveEditingNutrients(to: entryMealType)
    }

    // 【拆分四餐独立数据｜改动：新增四餐独立营养素数据结构 + 存取辅助函数】
    /// 单餐营养素存储结构体，包含全部8项营养素
    private struct MealNutrients {
        var protein: Double = 0
        var fat: Double = 0
        var carbs: Double = 0
        var fiber: Double = 0
        var sodium: Double = 0
        var caffeine: Double = 0
        var water: Double = 0
        var sugar: Double = 0
    }

    /// 获取指定餐次的已保存营养素数据，不存在时返回全零默认值
    private func getMealNutrients(_ mealType: MealType) -> MealNutrients {
        return allMealsData[mealType] ?? MealNutrients()
    }

    /// 【修复四餐存储BUG｜1.修正save/load存取逻辑 2.录入控件绑定分餐独立数据源 3.调整onChange存加载执行顺序】
    /// 将当前编辑面板的营养素数值保存至 allMealsData 中指定餐次，杜绝存入错位
    private func saveEditingNutrients(to targetMealType: MealType) {
        allMealsData[targetMealType] = MealNutrients(
            protein: editingProtein, fat: editingFat, carbs: editingCarbs,
            fiber: editingFiber, sodium: editingSodium, caffeine: editingCaffeine,
            water: editingWater, sugar: editingSugar
        )
    }

    /// 【修复四餐存储BUG｜1.修正save/load存取逻辑 2.录入控件绑定分餐独立数据源 3.调整onChange存加载执行顺序】
    /// 从 allMealsData 加载指定餐次的营养素数据至编辑面板变量，无历史数据时自动归零
    private func loadEditingNutrients() {
        let data = getMealNutrients(entryMealType)
        editingProtein = data.protein
        editingFat = data.fat
        editingCarbs = data.carbs
        editingFiber = data.fiber
        editingSodium = data.sodium
        editingCaffeine = data.caffeine
        editingWater = data.water
        editingSugar = data.sugar
    }

    // 【拆分四餐独立数据｜修复多餐共用同一录入变量BUG｜改动：一键录入汇总四餐全部营养素总和】【新增一键录入全天总摄入按钮与逻辑】无需选择餐次，直接叠加当前录入的全部营养素至全天总摄入
    private func quickAddToDailyTotal() {
        // 【修复四餐存储BUG｜改动：一键录入前先将当前餐次编辑数据存入对应存储区，确保四餐数据完整】
        saveEditingNutrients(to: entryMealType)
        // 汇总早+午+晚+加餐四餐全部营养素总和
        let breakfastData = getMealNutrients(.breakfast)
        let lunchData = getMealNutrients(.lunch)
        let dinnerData = getMealNutrients(.dinner)
        let snackData = getMealNutrients(.snack)
        let totalProtein = breakfastData.protein + lunchData.protein + dinnerData.protein + snackData.protein
        let totalFat = breakfastData.fat + lunchData.fat + dinnerData.fat + snackData.fat
        let totalCarbs = breakfastData.carbs + lunchData.carbs + dinnerData.carbs + snackData.carbs
        let totalFiber = breakfastData.fiber + lunchData.fiber + dinnerData.fiber + snackData.fiber
        let totalSugar = breakfastData.sugar + lunchData.sugar + dinnerData.sugar + snackData.sugar
        let totalSodium = breakfastData.sodium + lunchData.sodium + dinnerData.sodium + snackData.sodium
        let totalCaffeine = breakfastData.caffeine + lunchData.caffeine + dinnerData.caffeine + snackData.caffeine
        let totalWater = breakfastData.water + lunchData.water + dinnerData.water + snackData.water
        // 四餐总热量汇总
        let totalKcal = totalProtein * 4 + totalFat * 9 + totalCarbs * 4 + totalFiber * 2 + totalSugar * 4
        // 构建汇总记录（标记为加餐类型兜底）
        let record = MealRecordModel(
            foodName: "四餐汇总录入",
            mealType: .snack,
            proteinGrams: totalProtein, fatGrams: totalFat, carbsGrams: totalCarbs,
            dietaryFiber: totalFiber > 0 ? totalFiber : nil,
            kcal: totalKcal, servingAmount: servingAmount, servingUnit: servingUnit,
            recognitionSource: nil, createdAt: Date()
        )
        mealRecords.insert(record, at: 0)
        // 叠加四餐汇总的钠、咖啡因、饮水量、糖至全天总摄入【录入面板新增钠(mg)调节控件】叠加钠、咖啡因至全天总摄入
        sodiumTotalMg += totalSodium
        caffeineTotalMg += totalCaffeine
        // 【录入面板新增饮水量/添加糖调节控件】叠加至全天总摄入
        waterTotalL += totalWater
        addedSugarTotalG += totalSugar
        // 【网络层对接】持久化到本地
        if let data = try? JSONEncoder().encode(mealRecords) {
            UserDefaults.standard.set(data, forKey: mealRecordsStorageKey)
        }
        // 【网络层对接】云端同步（静默）
        Task {
            let syncBody = SyncBatchRequest(
                sync_mode: "incremental",
                user_id: LoginUserStorage.userId ?? "",
                body_data: [],
                meal_records: [MealSyncRecord(
                    recorded_at: ISO8601DateFormatter().string(from: Date()),
                    meal_type: record.mealType.rawValue,
                    food_name: record.foodName,
                    protein_g: record.proteinGrams,
                    fat_g: record.fatGrams,
                    carbs_g: record.carbsGrams,
                    fiber_g: record.dietaryFiber ?? 0,
                    kcal: record.kcal
                )],
                training_records: [],
                drug_records: [],
                deleted_drug_records: [],
                clear_all_drugs: false,
                supplement_records: [],
                sleep_records: []
            )
            do {
                let _: SyncBatchResponse = try await APIClient.shared.post("/api/sync/batch", body: syncBody)
                print("[DietView] 饮食记录云端同步成功")
            } catch {
                print("[DietView] 饮食记录云端同步失败: \(error.localizedDescription)")
            }
        }
        // 一键录入完成后保留四餐已录入数据，不清空各餐
    }

    // 【网络层对接】从后端 API 加载今日饮食记录
    private func loadMealsFromAPI() async {
        guard let uid = LoginUserStorage.userId, !uid.isEmpty else { return }
        do {
            let resp: MealTodayResponse = try await APIClient.shared.get("/api/meal/today?user_id=\(uid)")
            if !resp.meals.isEmpty {
                let records = resp.meals.map { item -> MealRecordModel in
                    MealRecordModel(
                        foodName: item.food_name,
                        mealType: MealType(rawValue: item.meal_type) ?? .breakfast,
                        proteinGrams: item.protein_g,
                        fatGrams: item.fat_g,
                        carbsGrams: item.carbs_g,
                        dietaryFiber: item.fiber_g,
                        kcal: item.kcal
                    )
                }
                await MainActor.run {
                    mealRecords = records
                    // 缓存到本地
                    if let data = try? JSONEncoder().encode(records) {
                        UserDefaults.standard.set(data, forKey: mealRecordsStorageKey)
                    }
                    print("[DietView] 从后端加载 \(records.count) 条饮食记录")
                }
            }
        } catch {
            print("[DietView] 后端加载饮食记录失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - MealLogRow（新增膳食纤维展示）
struct MealLogRow: View {
    let record: MealRecordModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppleGlassStyle.spacingSM) {
            HStack {
                Image(systemName: record.mealType.systemImage)
                    .foregroundStyle(record.mealType.color)
                Text(record.foodName)
                    .font(.body.weight(.medium)).foregroundStyle(AppleGlassStyle.textPrimary)
                Spacer()
                Text(record.mealType.displayName)
                    .font(.caption2.weight(.medium)).foregroundStyle(record.mealType.color)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(record.mealType.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            }
            // 营养素标签行
            HStack(spacing: AppleGlassStyle.spacingMD) {
                macroTag(label: "蛋白质", value: String(format: "%.0fg", record.proteinGrams), color: .blue)
                macroTag(label: "脂肪", value: String(format: "%.0fg", record.fatGrams), color: .orange)
                macroTag(label: "碳水", value: String(format: "%.0fg", record.carbsGrams), color: .green)
                if let fiber = record.dietaryFiber, fiber > 0 {
                    macroTag(label: "纤维", value: String(format: "%.0fg", fiber), color: .brown)
                }
                macroTag(label: "热量", value: String(format: "%.0f", record.kcal), color: .red)
            }
            // 识别来源标记
            if let source = record.recognitionSource {
                Text(source == "camera" ? "🤖 AI相机识别" : "")
                    .font(.caption2).foregroundColor(AppleGlassStyle.textTertiary)
            }
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    private func macroTag(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(AppleGlassStyle.textTertiary)
            Text(value).font(.caption.weight(.medium)).foregroundStyle(color)
        }
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var bodyData = BodyDataModel()
    DietView(bodyData: $bodyData)
        .environmentObject(GlobalCreatineManager.shared)
}
