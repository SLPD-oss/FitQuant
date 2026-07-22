import SwiftUI

// MARK: - TrainView
// Training log with strength/cardio segmented picker.
// //【合规红线】Exercise data is locally stored only.
// //【合规红线】No real-time health monitoring or ECG-style features.
// //【合规红线】Strength/cardio recommendations are user-driven, not AI-generated.

struct TrainView: View {
    // Training type picker
    @State private var trainingType: TrainingRecordModel.TrainingType = .strength

    // Strength fields
    @State private var strengthExerciseName: String = ""
    @State private var selectedMuscleGroups: Set<MuscleGroup> = []
    @State private var strengthSets: Int = 3
    @State private var strengthReps: Int = 10
    @State private var strengthWeight: Double = 0

    // Cardio fields
    @State private var cardioDurationMinutes: Int = 30

    // Training log
    @State private var trainingLog: [TrainingRecordModel] = []

    // Quick note
    @State private var trainingNote: String = ""

    // User weight for kcal estimation
    @State private var userWeight: Double = 70.0

    // 新增：药物肌腱风险弹窗触发状态
    @State private var showMedicationRiskAlert: Bool = false

    // 新增：有氧训练拆分为匀速有氧/HIIT两大类
    @State private var selectedAerobicSubType: AerobicSubType = .steadyCardio
    // 新增：TFCC腕损伤风险弹窗触发状态
    @State private var showTFCCRiskAlert: Bool = false

    // 删除：废弃旧方案一级肌群点击弹窗整套视图、状态变量、sheet修饰符、点击手势交互
    // 新增：长按滑动液态玻璃泡泡交互状态 — 控制悬浮泡泡显隐/记录当前长按肌群/滑动选中的细分索引/已确认细分
    @State private var showMuscleGlassBubble: Bool = false
    @State private var activeBubbleMuscle: MuscleGroup = .chest
    @State private var bubbleDragIndex: Int = 0
    @State private var confirmedSubMuscles: [String] = []
    // 新增：日历训练视图控制状态
    @State private var showTrainingCalendar: Bool = false

    // 新增：跑步机专属时速、坡度绑定变量，仅匀速有氧下生效
    @State private var treadmillSpeedValue: Double = 8.0
    @State private var treadmillSlopeValue: Double = 0.0
    // 新增：HIIT专用组数、每组运动秒、每组休息秒绑定变量，仅HIIT分类下生效
    @State private var hiitGroupCountValue: Int = 8
    @State private var hiitWorkSecondValue: Int = 30
    @State private var hiitRestSecondValue: Int = 15

    // 新增：拆分有氧为匀速有氧/HIIT高强度间歇两类，预留RAG同步动作分类接口
    enum AerobicSubType: String, CaseIterable {
        case steadyCardio = "匀速有氧"
        case hiit = "HIIT高强度间歇"
    }

    // 演示阶段本地动作识别库，后期替换后端RAG运动动作权威分类数据
    private let localAerobicActionMap: [String: AerobicSubType] = [
        // ── 匀速有氧（低关节/低手腕承压）──
        "跑步机": .steadyCardio, "椭圆机": .steadyCardio,
        "动感单车": .steadyCardio, "划船机": .steadyCardio,
        "慢跑": .steadyCardio, "快走": .steadyCardio,
        "骑行": .steadyCardio, "游泳": .steadyCardio,
        // ── HIIT 高强度间歇（部分动作手腕承压有TFCC风险）──
        "登山跑": .hiit, "平板支撑": .hiit,
        "俯身登山": .hiit, "熊爬": .hiit,
        "波比跳": .hiit, "开合跳": .hiit,
        "高抬腿": .hiit, "深蹲跳": .hiit,
        "箭步蹲跳": .hiit, "徒手箭步蹲": .hiit,
        "战绳": .hiit, "壶铃摆荡": .hiit,
    ]

    // 新增：前端演示本地细分肌群库，预留RAG运动肌群数据库替换注释
    private let muscleSubGroupMap: [MuscleGroup: [String]] = [
        .chest:      ["上胸", "中胸（厚度）", "下胸"],
        .back:       ["背阔肌", "斜方肌中下部", "菱形肌", "竖脊肌"],
        .legs:       ["股四头肌", "腘绳肌", "臀大肌", "小腿腓肠肌"],
        .shoulders:  ["前束", "中束", "后束"],
        .arms:       ["肱二头肌", "肱三头肌", "前臂肌群"],
        .core:       ["上腹", "下腹", "侧腹（腹斜肌）", "下背部核心"],
        .fullBody:   []  // 全身综合训练无细分肌群
    ]

    // 新增识别登山跑、平板支撑类手腕承压动作，标记TFCC高风险动作
    private let highRiskWristHiitActions: Set<String> = [
        "登山跑", "平板支撑", "俯身登山", "熊爬", "侧平板支撑", "俯卧撑"
    ]

    // 独立适配层函数：匹配本地关键词识别有氧子分类
    // 远期替换后端运动RAG数据库动作分类接口请求逻辑
    private func detectAerobicSubType(actionName: String) -> AerobicSubType? {
        let trimmed = actionName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // 精确匹配
        if let matched = localAerobicActionMap[trimmed] { return matched }
        // 模糊匹配
        for (keyword, subType) in localAerobicActionMap {
            if trimmed.contains(keyword) { return subType }
        }
        return nil
    }

    // 判定当前输入动作是否为高危手腕HIIT动作（登山跑、平板支撑等撑地动作）
    private func isHighRiskWristHiitAction(actionName: String) -> Bool {
        let trimmed = actionName.trimmingCharacters(in: .whitespaces)
        for keyword in highRiskWristHiitActions {
            if trimmed.contains(keyword) { return true }
        }
        return false
    }

    // 读取用户本地体重数据判定是否超重
    // 阈值本地演示写死，后期由后端RAG库下发循证医学标准阈值
    private func isUserOverWeight() -> Bool {
        return BodyDataModel().bmi >= 24
    }

    // 【新增逻辑】纯本地体脂判断工具函数，不依赖RAG后端，无需网络
    // 本地演示专用：体脂率>30% + 平板支撑/登山跑 → 自动唤起TFCC腕损伤风险弹窗
    // 硬编码阈值30%，仅读取本地用户身体数据中的体脂率数值即可稳定触发
    // 【本次修复｜业务：加体脂阈值后逻辑异常，历史HIIT高危动作弹窗失效，排查两处onChange判定+Alert绑定】
    // 根因：原BodyDataModel()创建空实例，bodyFatPercent默认20.0永远<30%，导致isHighBodyFat()永远返回false
    // 修复：从UserDefaults读取用户实际保存的体脂数据进行判断，判断阈值(>30%)保持不变
    private func isHighBodyFat() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: "saved_bodyData"),
              let bodyData = try? JSONDecoder().decode(BodyDataModel.self, from: data) else {
            return false
        }
        return bodyData.bodyFatPercent > 30
    }

    // 新增：识别动作名称是否为跑步机，用于控制时速、坡度输入框显隐
    // 预留RAG动作识别接口替换注释
    private let treadmillKeywords: Set<String> = ["跑步机", "慢跑", "快走"]
    private func isTreadmillDevice(actionName: String) -> Bool {
        let trimmed = actionName.trimmingCharacters(in: .whitespaces)
        for keyword in treadmillKeywords {
            if trimmed.contains(keyword) { return true }
        }
        return false
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: AppleGlassStyle.spacingMD) {
                        trainingTypePicker
                        trainingInputCard
                        quickLogButton
                        trainingLogSection
                        bottomDisclaimer
                    }
                    .padding(AppleGlassStyle.spacingMD)
                }
                .background(AppleGlassStyle.groupedBackground)
                .navigationTitle("训练")
                // 新增：日历视图唤起入口，点击弹出完整训练日历sheet视图
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showTrainingCalendar = true
                        } label: {
                            Image(systemName: "calendar")
                                .font(.body)
                                .foregroundColor(AppleGlassStyle.accent)
                        }
                    }
                }
            }

            // 新增：液态玻璃悬浮泡泡面板，覆盖在长按肌群按钮右侧
            if showMuscleGlassBubble {
                muscleGlassBubbleOverlay
            }
        }
        // 新增：页面加载校验在用药物，存在肌腱风险药品则弹出提示
        .onAppear {
            if GlobalViewManager.shared.hasHighTendonRiskMedication() {
                showMedicationRiskAlert = true
            }
        }
        // 新增：喹诺酮药物训练风险提示弹窗
        .sheet(isPresented: $showMedicationRiskAlert) {
            MedicationTendonRiskAlertView()
        }
        // 【修复原有Bug】体脂>30% + 手部承重HIIT动作 → TFCC腕损伤风险提示弹窗（纯本地，不依赖RAG）
        .sheet(isPresented: $showTFCCRiskAlert) {
            TFCCWristRiskAlertView()
        }
        // 新增：月度训练日历视图，读取本地全部历史训练记录按日期分组渲染
        .sheet(isPresented: $showTrainingCalendar) {
            CalendarTrainingView(trainingRecords: trainingLog)
        }
    }

    // MARK: - Training Type Picker
    private var trainingTypePicker: some View {
        Picker("训练类型", selection: $trainingType) {
            ForEach(TrainingRecordModel.TrainingType.allCases, id: \.self) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .padding(AppleGlassStyle.spacingSM)
        .background(AppleGlassStyle.standard, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    // MARK: - Training Input Card
    private var trainingInputCard: some View {
        VStack(spacing: AppleGlassStyle.spacingMD) {
            // Exercise name
            VStack(alignment: .leading, spacing: AppleGlassStyle.spacingXS) {
                Text("动作名称")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppleGlassStyle.textSecondary)

                // 新增有氧子分类切换控件，区分匀速有氧、HIIT间歇训练
                if trainingType == .cardio {
                    Picker("有氧类型", selection: $selectedAerobicSubType) {
                        ForEach(AerobicSubType.allCases, id: \.self) { subType in
                            Text(subType.rawValue).tag(subType)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, AppleGlassStyle.spacingXS)
                    // 【本次修复｜业务：TFCC风险弹窗缺少双条件组合调用逻辑，体脂＞30%+高危HIIT动作无弹窗】
                    // 手动切换有氧子分类时也触发TFCC组合校验，确保切HIIT时已输入的高危动作+高体脂能立即弹窗
                    .onChange(of: selectedAerobicSubType) {
                        if isHighRiskWristHiitAction(actionName: strengthExerciseName) && isHighBodyFat() && selectedAerobicSubType == .hiit {
                            showTFCCRiskAlert = true
                        }
                    }
                }

                TextField(
                    trainingType == .strength ? "如：杠铃卧推" : "如：跑步机",
                    text: $strengthExerciseName
                )
                .textFieldStyle(.plain)
                .padding(AppleGlassStyle.spacingSM)
                .background(
                    Color(.systemFill).opacity(0.2),
                    in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall)
                )
                // 监听输入动作名称，自动匹配关键词库识别有氧分类，识别错误用户可手动切换分类
                .onChange(of: strengthExerciseName) { _, newValue in
                    guard trainingType == .cardio else { return }
                    // 自动识别有氧子分类
                    if let detected = detectAerobicSubType(actionName: newValue) {
                        selectedAerobicSubType = detected
                    }
                    // 【修复原有Bug】纯本地TFCC双重条件判定：高危手腕动作 + 体脂>30% → 唤起风险弹窗
                    // 无网络、无RAG后端也能稳定触发，不再依赖外部接口下发阈值
                    // 【本次修复｜业务：TFCC风险弹窗缺少双条件组合调用逻辑，体脂＞30%+高危HIIT动作无弹窗】
                    // 追加第三条件：当前选中有氧子分类必须为HIIT，三条件AND同时满足才弹窗
                    if isHighRiskWristHiitAction(actionName: newValue) && isHighBodyFat() && selectedAerobicSubType == .hiit {
                        showTFCCRiskAlert = true
                    }
                }
            }

            // Muscle group chips (strength only)
            if trainingType == .strength {
                muscleGroupChips
            }

            // Strength-specific fields
            if trainingType == .strength {
                strengthFields
            } else {
                cardioFields
            }

            // Notes field
            VStack(alignment: .leading, spacing: AppleGlassStyle.spacingXS) {
                Text("备注")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppleGlassStyle.textSecondary)
                TextField("训练感受、要点记录...", text: $trainingNote)
                    .textFieldStyle(.plain)
                    .padding(AppleGlassStyle.spacingSM)
                    .background(
                        Color(.systemFill).opacity(0.2),
                        in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall)
                    )
            }
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    // MARK: - Muscle Group Chips（长按滑动液态玻璃泡泡选取二级细分）
    private var muscleGroupChips: some View {
        VStack(alignment: .leading, spacing: AppleGlassStyle.spacingSM) {
            Text("目标肌群（可多选）")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppleGlassStyle.textSecondary)

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 60), spacing: AppleGlassStyle.spacingSM)
                ],
                spacing: AppleGlassStyle.spacingSM
            ) {
                ForEach(MuscleGroup.allCases) { group in
                    muscleChip(group)
                        // 新增：长按识别手势，长按唤起液态玻璃悬浮泡泡细分面板；原有一级肌群单击选中逻辑完整保留
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    let subs = muscleSubGroupMap[group] ?? []
                                    activeBubbleMuscle = group
                                    bubbleDragIndex = 0
                                    if !subs.isEmpty || group == .fullBody {
                                        showMuscleGlassBubble = true
                                    }
                                }
                        )
                }
            }

            // 新增：展示已确认的二级细分肌群清单，松开手指后自动同步
            if !confirmedSubMuscles.isEmpty {
                HStack(spacing: AppleGlassStyle.spacingSM) {
                    Text("已选细分：\(confirmedSubMuscles.joined(separator: " · "))")
                        .font(.caption2)
                        .foregroundColor(AppleGlassStyle.accent)

                    // 新增：一键清空全部已选中一级肌群、二级细分肌群，重置肌群选择状态
                    Button {
                        selectedMuscleGroups = []
                        confirmedSubMuscles = []
                    } label: {
                        Text("一键清除")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func muscleChip(_ group: MuscleGroup) -> some View {
        let isSelected = selectedMuscleGroups.contains(group)
        return Button {
            if isSelected {
                selectedMuscleGroups.remove(group)
            } else {
                selectedMuscleGroups.insert(group)
            }
        } label: {
            Text(group.rawValue)
                .font(.caption.weight(.medium))
                .foregroundStyle(isSelected ? .white : group.color)
                .padding(.horizontal, AppleGlassStyle.spacingMD)
                .padding(.vertical, AppleGlassStyle.spacingSM)
                .background(
                    isSelected ? group.color : group.color.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Strength Fields (sets/reps/weight steppers)
    private var strengthFields: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            stepperRow(icon: "repeat", label: "组数", value: $strengthSets, range: 0...20, color: .orange)
            Divider()
            stepperRow(icon: "arrow.triangle.merge", label: "次数", value: $strengthReps, range: 0...50, color: .green)
            Divider()
            stepperRow(
                icon: "scalemass",
                label: "重量 (kg)",
                value: Binding(get: { Int(strengthWeight) }, set: { strengthWeight = Double($0) }),
                range: 0...500,
                color: .blue
            )
        }
        .padding(AppleGlassStyle.spacingSM)
        .background(Color(.systemFill).opacity(0.08), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
    }

    // MARK: - Cardio Fields（根据有氧分类动态切换展示对应录入字段）
    private var cardioFields: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            // 固定保留：总时长输入
            stepperRow(icon: "timer", label: "时长 (分钟)", value: $cardioDurationMinutes, range: 0...300, color: .teal)

            // 匀速有氧：跑步机额外展示时速+坡度；椭圆机/单车隐藏
            if selectedAerobicSubType == .steadyCardio {
                if isTreadmillDevice(actionName: strengthExerciseName) {
                    Divider()
                    stepperRow(icon: "speedometer", label: "时速 (km/h)", value: treadmillSpeedBinding, range: 0...20, color: .blue)
                    Divider()
                    stepperRow(icon: "arrow.up.forward", label: "坡度 (%)", value: treadmillSlopeBinding, range: 0...15, color: .orange)
                }
            }

            // HIIT高强度间歇：新增组数、运动秒、休息秒三组输入控件
            if selectedAerobicSubType == .hiit {
                Divider()
                stepperRow(icon: "repeat.circle.fill", label: "组数", value: $hiitGroupCountValue, range: 1...30, color: .purple)
                Divider()
                stepperRow(icon: "bolt.fill", label: "每组运动 (秒)", value: $hiitWorkSecondValue, range: 5...180, color: .red)
                Divider()
                stepperRow(icon: "pause.circle.fill", label: "每组休息 (秒)", value: $hiitRestSecondValue, range: 5...120, color: .mint)
            }

            Divider()
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("估算消耗")
                    .font(.subheadline)
                    .foregroundStyle(AppleGlassStyle.textSecondary)
                Spacer()
                Text(String(format: "%.0f kcal", Double(cardioDurationMinutes) * 0.15 * userWeight))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppleGlassStyle.textPrimary)
            }
        }
        .padding(AppleGlassStyle.spacingSM)
        .background(Color(.systemFill).opacity(0.08), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
    }

    // 新增：Double值绑定适配器，将时速/坡度Double转为stepperRow需要的Int
    private var treadmillSpeedBinding: Binding<Int> {
        Binding(get: { Int(treadmillSpeedValue) }, set: { treadmillSpeedValue = Double($0) })
    }
    private var treadmillSlopeBinding: Binding<Int> {
        Binding(get: { Int(treadmillSlopeValue) }, set: { treadmillSlopeValue = Double($0) })
    }

    // MARK: - Stepper Row Helper
    private func stepperRow(
        icon: String, label: String, value: Binding<Int>,
        range: ClosedRange<Int>, color: Color
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppleGlassStyle.textSecondary)
            Spacer()
            Button {
                if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(color.opacity(0.7))
            }
            .buttonStyle(.plain)
            Text("\(value.wrappedValue)")
                .font(.headline)
                .foregroundStyle(AppleGlassStyle.textPrimary)
                .frame(minWidth: 40)
                .multilineTextAlignment(.center)
            Button {
                if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(color.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Quick Log Button
    private var quickLogButton: some View {
        Button {
            // 根据分类自动判断写入对应差异化字段
            let isTreadmill = trainingType == .cardio && selectedAerobicSubType == .steadyCardio && isTreadmillDevice(actionName: strengthExerciseName)
            let isHiit = trainingType == .cardio && selectedAerobicSubType == .hiit

            let record = TrainingRecordModel(
                exerciseName: strengthExerciseName,
                trainingType: trainingType,
                muscleGroups: selectedMuscleGroups,
                sets: strengthSets,
                reps: strengthReps,
                weightKg: strengthWeight,
                durationMinutes: cardioDurationMinutes,
                estimatedKcal: TrainingRecordModel.estimatedKcal(
                    strengthMinutes: trainingType == .strength ? strengthSets * 2 : 0,
                    cardioMinutes: trainingType == .cardio ? cardioDurationMinutes : 0,
                    weightKg: userWeight
                ),
                notes: trainingNote,
                createdAt: Date(),
                // 新增：根据分类写入差异化参数
                treadmillSpeed: isTreadmill ? treadmillSpeedValue : nil,
                treadmillSlope: isTreadmill ? treadmillSlopeValue : nil,
                hiitGroupCount: isHiit ? hiitGroupCountValue : nil,
                hiitWorkSecond: isHiit ? hiitWorkSecondValue : nil,
                hiitRestSecond: isHiit ? hiitRestSecondValue : nil,
                targetSubMuscleGroups: trainingType == .strength && !confirmedSubMuscles.isEmpty ? confirmedSubMuscles : nil
            )
            trainingLog.insert(record, at: 0)
            // 【保守减脂热量计算逻辑】写入持久化以便PhysiologyCalcTool.sumTodayTrainingConsume读取
            TrainingRecordStorage.shared.saveAll(trainingLog)
            resetInputFields()
        } label: {
            Label("记录本次训练", systemImage: "checkmark")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppleGlassStyle.spacingMD)
                .background(AppleGlassStyle.accent, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
        }
        .disabled(strengthExerciseName.isEmpty)
        .opacity(strengthExerciseName.isEmpty ? 0.5 : 1.0)
    }

    // MARK: - Training Log Section
    private var trainingLogSection: some View {
        VStack(alignment: .leading, spacing: AppleGlassStyle.spacingSM) {
            if !trainingLog.isEmpty {
                Text("训练记录")
                    .font(.headline)
                    .foregroundStyle(AppleGlassStyle.textPrimary)
            }
            ForEach(trainingLog) { record in
                TrainingLogRow(record: record)
            }
        }
    }

    // MARK: - Bottom Disclaimer
    private var bottomDisclaimer: some View {
        VStack(spacing: AppleGlassStyle.spacingXS) {
            ComplianceText(text: "【合规红线】训练数据仅作个人记录用途。本应用不提供个性化训练计划或健康指导。")
            ComplianceText(text: "【合规红线】所有训练数据保存在本地，不会传输至任何远程服务器。")
        }
    }

    // MARK: - Helpers
    private func resetInputFields() {
        strengthExerciseName = ""
        selectedMuscleGroups = []
        strengthSets = 3
        strengthReps = 10
        strengthWeight = 0
        cardioDurationMinutes = 30
        trainingNote = ""
        // 新增：重置有氧差异化字段为默认值
        treadmillSpeedValue = 8.0
        treadmillSlopeValue = 0.0
        hiitGroupCountValue = 8
        hiitWorkSecondValue = 30
        hiitRestSecondValue = 15
        // 新增：重置二级细分肌群选择
        confirmedSubMuscles = []
    }
}

// MARK: - TrainingLogRow
struct TrainingLogRow: View {
    let record: TrainingRecordModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppleGlassStyle.spacingSM) {
            HStack {
                Image(systemName: record.trainingType == .strength ? "dumbbell.fill" : "figure.run")
                    .foregroundStyle(record.trainingType == .strength ? .orange : .teal)
                Text(record.exerciseName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppleGlassStyle.textPrimary)
                Spacer()
                Text(formattedDate)
                    .font(.caption2)
                    .foregroundStyle(AppleGlassStyle.textTertiary)
            }

            HStack(spacing: AppleGlassStyle.spacingSM) {
                if record.trainingType == .strength {
                    Text("\(record.sets)组 x \(record.reps)次").font(.caption)
                    if record.weightKg > 0 {
                        Text(String(format: "%.0fkg", record.weightKg)).font(.caption)
                    }
                } else {
                    Text("\(record.durationMinutes)分钟").font(.caption)
                }
                if record.estimatedKcal > 0 {
                    Text(String(format: "%.0f kcal", record.estimatedKcal))
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            .foregroundStyle(AppleGlassStyle.textSecondary)

            if !record.muscleGroups.isEmpty {
                muscleGroupTags
            }
            // 新增：展示已选二级细分肌群
            if let subs = record.targetSubMuscleGroups, !subs.isEmpty {
                Text("细分：\(subs.joined(separator: " · "))")
                    .font(.caption2)
                    .foregroundStyle(AppleGlassStyle.accent)
                    .padding(.top, 2)
            }
            if !record.notes.isEmpty {
                Text(record.notes)
                    .font(.caption2)
                    .foregroundStyle(AppleGlassStyle.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    private var muscleGroupTags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppleGlassStyle.spacingXS) {
                ForEach(Array(record.muscleGroups)) { group in
                    Text(group.rawValue)
                        .font(.caption2)
                        .foregroundStyle(group.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(group.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: record.createdAt)
    }
}

// MARK: - Preview

// MARK: - 新增：喹诺酮药物训练肌腱风险提示弹窗
// 复用项目统一AppleGlassStyle样式规范，仅做风险告知，不拦截训练操作
// 远期兼容：后端第一套「药物↔训练RAG库」上线后可直接替换文案内容，视图结构保持不变

struct MedicationTendonRiskAlertView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 顶部免责声明条（复用CommonAlert.h 统一规范）
            HStack(spacing: AppleGlassStyle.spacingXS) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                Text(ComplianceText.alertDisclaimerPrefix)
                    .font(.caption2)
                Spacer()
            }
            .foregroundColor(AppleGlassStyle.textTertiary)
            .padding(.horizontal, AppleGlassStyle.spacingSM)
            .padding(.vertical, AppleGlassStyle.spacingXS)
            .background(AppleGlassStyle.ultraThin)

            // 主体内容卡片
            VStack(spacing: AppleGlassStyle.spacingSM) {
                // 图标
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }

                // 标题
                Text("肌腱损伤风险提示")
                    .font(.headline)
                    .foregroundColor(AppleGlassStyle.textPrimary)

                // 风险说明正文
                VStack(alignment: .leading, spacing: AppleGlassStyle.spacingXS) {
                    Text("系统检测到您当前正在服用喹诺酮类抗生素（如左氧氟沙星、莫西沙星等）。")
                        .font(.subheadline)
                        .foregroundColor(AppleGlassStyle.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("该类药物会显著升高肌腱炎、肌腱撕裂的运动损伤风险，高强度抗阻训练可能加重此类风险。")
                        .font(.subheadline)
                        .foregroundColor(AppleGlassStyle.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("建议：暂时降低大重量推拉抗阻训练负荷，减少高强度负重动作，待药物停用后逐步恢复原有训练强度。")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppleGlassStyle.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AppleGlassStyle.spacingSM)
                .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))

                Divider()
                    .padding(.horizontal, -AppleGlassStyle.spacingSM)

                // 关闭按钮（仅做告知，不拦截训练操作）
                Button {
                    dismiss()
                } label: {
                    Text("我已知晓")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppleGlassStyle.spacingSM)
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
}

// MARK: - TFCC腕关节损伤风险提示弹窗（纯本地判断，不依赖RAG）
// 触发条件：体脂率>30% + 平板支撑/登山跑手部承重HIIT动作
// 弹窗仅作风险告知，不拦截训练保存
// 复用AppleGlassStyle统一UI规范

struct TFCCWristRiskAlertView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 顶部免责声明条
            HStack(spacing: AppleGlassStyle.spacingXS) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                Text(ComplianceText.alertDisclaimerPrefix)
                    .font(.caption2)
                Spacer()
            }
            .foregroundColor(AppleGlassStyle.textTertiary)
            .padding(.horizontal, AppleGlassStyle.spacingSM)
            .padding(.vertical, AppleGlassStyle.spacingXS)
            .background(AppleGlassStyle.ultraThin)

            // 主体内容卡片
            VStack(spacing: AppleGlassStyle.spacingSM) {
                // 橙色三角警告图标
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "hand.raised.slash.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }

                // 标题
                Text("TFCC 腕关节损伤风险提示")
                    .font(.headline)
                    .foregroundColor(AppleGlassStyle.textPrimary)

                // 循证医学风险说明
                VStack(alignment: .leading, spacing: AppleGlassStyle.spacingXS) {
                    Text("系统检测到您正在录入需要手腕撑地的高强度间歇训练动作（如登山跑、平板支撑等）。")
                        .font(.subheadline)
                        .foregroundColor(AppleGlassStyle.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // 【修改原有逻辑】循证医学风险说明：由"超重"改为"体脂偏高"作为核心判别依据
                    Text("循证医学研究表明：体脂偏高人群在执行该类型动作时，自身腕部肌肉支撑能力不足以缓冲体重压迫，腕关节三角纤维软骨复合体（TFCC）受力成倍提升，撕裂与软骨损伤风险大幅上涨。")
                        .font(.subheadline)
                        .foregroundColor(AppleGlassStyle.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("建议替代方案：优先选择跑步机快走、椭圆机、动感单车等匀速有氧项目，这些运动全程低手腕承压，同样能达成高效燃脂。")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppleGlassStyle.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AppleGlassStyle.spacingSM)
                .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))

                Divider()
                    .padding(.horizontal, -AppleGlassStyle.spacingSM)

                // 关闭按钮（仅告知，不拦截训练记录保存）
                Button {
                    dismiss()
                } label: {
                    Text("我已知晓")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppleGlassStyle.spacingSM)
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
}

// MARK: - TrainView Extension：液态玻璃泡泡overlay

extension TrainView {

    // 新增：液态玻璃悬浮泡泡覆盖层 — 全屏透明遮罩+泡泡面板
    var muscleGlassBubbleOverlay: some View {
        let subs = muscleSubGroupMap[activeBubbleMuscle] ?? []
        return ZStack {
            // 半透明遮罩，点击关闭泡泡
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .onTapGesture {
                    // 手指松开确认当前高亮细分
                    confirmCurrentDrag(subs)
                }

            // 泡泡面板主体
            VStack {
                Spacer().frame(height: 300)
                MuscleSubLiquidGlassBubble(
                    mainMuscle: activeBubbleMuscle,
                    subGroups: subs,
                    dragIndex: $bubbleDragIndex,
                    onRelease: { confirmCurrentDrag(subs) }
                )
                Spacer()
            }
            .padding(.horizontal, AppleGlassStyle.spacingLG)
        }
    }

    /// 手指松开后确认选中当前滑动高亮的细分肌群
    private func confirmCurrentDrag(_ subs: [String]) {
        guard showMuscleGlassBubble else { return }
        if !subs.isEmpty {
            let idx = min(bubbleDragIndex, subs.count - 1)
            let picked = subs[idx]
            if !confirmedSubMuscles.contains(picked) {
                confirmedSubMuscles.append(picked)
            }
        }
        showMuscleGlassBubble = false
    }
}

// MARK: - 新增：液态玻璃悬浮泡泡视图
// 适配项目统一液态玻璃视觉规范的悬浮泡泡面板，承载当前肌群二级细分选项，支持手指滑动选区
// 复用现有muscleSubGroupMap映射适配层，预留RAG运动肌群数据库替换注释

struct MuscleSubLiquidGlassBubble: View {
    let mainMuscle: MuscleGroup
    let subGroups: [String]
    @Binding var dragIndex: Int
    var onRelease: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if subGroups.isEmpty {
                // 全身综合训练无细分肌群
                Text("全身综合训练无细分肌群")
                    .font(.subheadline)
                    .foregroundColor(AppleGlassStyle.textSecondary)
                    .padding(AppleGlassStyle.spacingMD)
            } else {
                // 一级肌群名称提示
                Text("\(mainMuscle.displayName) 细分")
                    .font(.caption2)
                    .foregroundColor(AppleGlassStyle.textTertiary)
                    .padding(.horizontal, AppleGlassStyle.spacingSM)
                    .padding(.top, AppleGlassStyle.spacingXS)

                // 横向滚动细分选项列表，支持滑动跟踪
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppleGlassStyle.spacingSM) {
                        ForEach(subGroups.indices, id: \.self) { idx in
                            Text(subGroups[idx])
                                .font(.caption.weight(dragIndex == idx ? .bold : .regular))
                                .foregroundColor(dragIndex == idx ? .white : AppleGlassStyle.textPrimary)
                                .padding(.horizontal, AppleGlassStyle.spacingSM)
                                .padding(.vertical, AppleGlassStyle.spacingXS)
                                .background(
                                    dragIndex == idx ? AppleGlassStyle.accent : AppleGlassStyle.accent.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall)
                                )
                                .id(idx)
                        }
                    }
                    .padding(.horizontal, AppleGlassStyle.spacingSM)
                    .padding(.vertical, AppleGlassStyle.spacingSM)
                }
                .frame(height: 50)

                // 操作提示
                Text("👆 横向滑动选择 · 松手确认")
                    .font(.caption2)
                    .foregroundColor(AppleGlassStyle.textTertiary)
                    .padding(.bottom, AppleGlassStyle.spacingXS)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium)
                .stroke(AppleGlassStyle.accent.opacity(0.15), lineWidth: 0.5)
        )
        // 拖拽手势：手指横向滑动实时更新高亮索引，松开确认
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !subGroups.isEmpty else { return }
                    let stepWidth: CGFloat = 90
                    let rawIdx = Int((value.location.x + stepWidth / 2) / stepWidth)
                    let clamped = max(0, min(rawIdx, subGroups.count - 1))
                    dragIndex = clamped
                }
                .onEnded { _ in
                    onRelease()
                }
        )
    }
}

#Preview {
    TrainView()
}
