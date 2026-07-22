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
    // 【网络层对接】训练记录持久化 Key
    private let trainingLogStorageKey = "trainingLog_v1"

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

    // 【解耦改动】内联业务规则迁移至 WorkoutClassificationService
    private let workoutClassService = WorkoutClassificationService()
    // 【解耦改动】药物风险校验迁移至 DrugRiskService（取代 GlobalViewManager 中的方法）
    private let drugRiskService = DrugRiskService.shared

    // 新增：跑步机专属时速、坡度绑定变量，仅匀速有氧下生效
    @State private var treadmillSpeedValue: Double = 8.0
    @State private var treadmillSlopeValue: Double = 0.0
    // 新增：HIIT专用组数、每组运动秒、每组休息秒绑定变量，仅HIIT分类下生效
    @State private var hiitGroupCountValue: Int = 8
    @State private var hiitWorkSecondValue: Int = 30
    @State private var hiitRestSecondValue: Int = 15

    // 【网络层对接】异步从后端识别是否跑步机设备
    @State private var isTreadmillDevice: Bool = false
    // 【网络层对接】存储完整动作分类结果用于展示
    @State private var classifyResult: WorkoutClassifyResponse? = nil

    // 【解耦改动】AerobicSubType 已迁移至 WorkoutClassificationService，此处起别名保持 View 内调用兼容
    typealias AerobicSubType = WorkoutClassificationService.AerobicSubType

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
        // 【解耦改动】药物风险校验从 GlobalViewManager 迁移至 DrugRiskService
        .onAppear {
            Task {
                if await drugRiskService.hasHighTendonRiskFromAPI() {
                    await MainActor.run { showMedicationRiskAlert = true }
                }
            }
            // 【网络层对接】从本地持久化加载训练记录
            let saved = TrainingRecordRepository.loadAll()
            if !saved.isEmpty {
                trainingLog = saved
            }
            // 【网络层对接】从后端加载训练记录
            Task {
                await loadTrainingFromAPI()
            }
        }
        // 新增：喹诺酮药物训练风险提示弹窗
        .sheet(isPresented: $showMedicationRiskAlert) {
            MedicationTendonRiskAlertView()
        }
        // 【网络层对接】异步从后端识别是否跑步机设备
        .task(id: strengthExerciseName) {
            isTreadmillDevice = await workoutClassService.isTreadmillDeviceFromAPI(actionName: strengthExerciseName)
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
                    // 【解耦改动】workoutClassService 替代 isHighRiskWristHiitAction / isHighBodyFat
                    .onChange(of: selectedAerobicSubType) {
                        Task {
                            let isHighRisk = await workoutClassService.isHighRiskWristHiitActionFromAPI(actionName: strengthExerciseName)
                            if isHighRisk && workoutClassService.isHighBodyFat() && selectedAerobicSubType == .hiit {
                                await MainActor.run { showTFCCRiskAlert = true }
                            }
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
                    classifyResult = nil
                    guard trainingType == .cardio else { return }
                    // 【解耦改动】detectAerobicSubType → workoutClassService.detectAerobicSubTypeFromAPI（异步）
                    Task {
                        if let detected = await workoutClassService.detectAerobicSubTypeFromAPI(actionName: newValue) {
                            await MainActor.run { selectedAerobicSubType = detected }
                        }
                    }
                    // 纯本地TFCC双重条件判定：高危手腕动作 + 体脂>30% → 唤起风险弹窗
                    // 【本次修复｜业务：TFCC风险弹窗缺少双条件组合调用逻辑，体脂＞30%+高危HIIT动作无弹窗】
                    // 追加第三条件：当前选中有氧子分类必须为HIIT，三条件AND同时满足才弹窗
                    // 【解耦改动】isHighRiskWristHiitAction → isHighRiskWristHiitActionFromAPI（异步）
                    Task {
                        let isHighRisk = await workoutClassService.isHighRiskWristHiitActionFromAPI(actionName: newValue)
                        if isHighRisk && workoutClassService.isHighBodyFat() && selectedAerobicSubType == .hiit {
                            await MainActor.run { showTFCCRiskAlert = true }
                        }
                    }
                    // 【网络层对接】获取完整动作分类信息（额外展示数据）
                    guard trainingType == .strength, !newValue.isEmpty else {
                        classifyResult = nil
                        return
                    }
                    Task {
                        let result = await workoutClassService.classifyFromAPI(actionName: newValue)
                        await MainActor.run { classifyResult = result }
                    }
                }
            }

            // 【网络层对接】展示动作分类完整信息
            if let result = classifyResult, !strengthExerciseName.isEmpty {
                HStack(spacing: 10) {
                    if !result.primary_muscle_group.isEmpty {
                        Label(result.primary_muscle_group, systemImage: "figure.strengthtraining.traditional")
                            .font(.caption2)
                            .foregroundStyle(AppleGlassStyle.textSecondary)
                    }
                    if result.estimated_kcal_per_min > 0 {
                        Label("\(String(format: "%.1f", result.estimated_kcal_per_min)) kcal/分", systemImage: "flame")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    if !result.difficulty.isEmpty {
                        Label(result.difficulty, systemImage: "chart.bar")
                            .font(.caption2)
                            .foregroundStyle(result.difficulty == "beginner" ? .green : result.difficulty == "intermediate" ? .orange : .red)
                    }
                    Spacer()
                }
                .padding(.top, 2)
                .padding(.horizontal, 4)
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
                                    // 【解耦改动】muscleSubGroupMap → workoutClassService.muscleSubGroupMap
                                    let subs = workoutClassService.muscleSubGroupMap[group] ?? []
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
                if isTreadmillDevice {
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
            let isTreadmill = trainingType == .cardio && selectedAerobicSubType == .steadyCardio && isTreadmillDevice
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
            // 【解耦改动】TrainingRecordStorage → TrainingRecordRepository
            TrainingRecordRepository.saveAll(trainingLog)
            // 【网络层对接】云端同步训练记录
            Task {
                let syncBody = SyncBatchRequest(
                    sync_mode: "incremental",
                    user_id: LoginUserStorage.userId ?? "",
                    body_data: [],
                    meal_records: [],
                    training_records: [TrainingSyncRecord(
                        recorded_at: ISO8601DateFormatter().string(from: Date()),
                        exercise_name: record.exerciseName,
                        training_type: record.trainingType.rawValue,
                        sets: record.sets,
                        reps: record.reps,
                        weight_kg: record.weightKg,
                        duration_minutes: record.durationMinutes,
                        estimated_kcal: record.estimatedKcal
                    )],
                    drug_records: [],
                    supplement_records: []
                )
                do {
                    let _: SyncBatchResponse = try await APIClient.shared.post("/api/sync/batch", body: syncBody)
                    print("[TrainView] 训练记录云端同步成功")
                } catch {
                    print("[TrainView] 训练记录云端同步失败: \(error.localizedDescription)")
                }
            }
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
    // 【网络层对接】从后端 API 加载训练记录
    private func loadTrainingFromAPI() async {
        guard let uid = LoginUserStorage.userId, !uid.isEmpty else { return }
        do {
            let resp: TrainingHistoryResponse = try await APIClient.shared.get("/api/training/history?user_id=\(uid)")
            if !resp.records.isEmpty {
                let records = resp.records.map { item -> TrainingRecordModel in
                    let formatter = ISO8601DateFormatter()
                    let date = formatter.date(from: item.recorded_at) ?? Date()
                    return TrainingRecordModel(
                        exerciseName: item.exercise_name,
                        trainingType: TrainingRecordModel.TrainingType(rawValue: item.training_type) ?? .strength,
                        sets: item.sets,
                        reps: item.reps,
                        weightKg: item.weight_kg,
                        durationMinutes: item.duration_minutes,
                        estimatedKcal: item.estimated_kcal,
                        createdAt: date
                    )
                }
                await MainActor.run {
                    trainingLog = records
                    TrainingRecordRepository.saveAll(records)
                    print("[TrainView] 从后端加载 \(records.count) 条训练记录")
                }
            }
        } catch {
            print("[TrainView] 后端加载训练记录失败: \(error.localizedDescription)")
        }
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
        // 【解耦改动】muscleSubGroupMap → workoutClassService.muscleSubGroupMap
        let subs = workoutClassService.muscleSubGroupMap[activeBubbleMuscle] ?? []
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
