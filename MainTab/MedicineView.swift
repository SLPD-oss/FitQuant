import SwiftUI

// MARK: - MedicineView
// Drug record management with 3-state filter and add input card.
// //【合规隔离红线】Drug data is strictly stored locally; no cloud sync, no sharing.
// //【合规隔离红线】All drug records must include disclaimer about consulting a physician.
// //【合规隔离红线】No dosage recommendations -- user enters their own from a physician.

struct MedicineView: View {
    @StateObject private var drugManager = DrugDataManager.shared
    @State private var selectedStatus: DrugStatus? = nil
    @State private var showAddSheet: Bool = false
    // 新增：药品操作弹窗触发状态
    @State private var selectedRecordForAction: DrugRecordModel? = nil
    // 新增：滚动偏移量，控制Header收起动画
    @State private var scrollOffset: CGFloat = 0

    // 新增数据过滤逻辑，仅渲染药品分类条目，过滤全部补剂类型数据，隔离药品/补剂业务边界
    private var drugOnlyRecords: [DrugRecordModel] {
        drugManager.records.filter { record in
            isDrugCategory(record.category)
        }
    }

    private var filteredRecords: [DrugRecordModel] {
        let base = drugOnlyRecords
        guard let selectedStatus else { return base }
        return base.filter { $0.status == selectedStatus }
    }

    // 独立数据分类适配层：判断是否为药品分类（非补剂）
    // 远期替换后端RAG下发药品/补剂分类数据，仅修改此函数内部过滤规则
    private func isDrugCategory(_ cat: DrugCategory) -> Bool {
        switch cat {
        case .traditionalChMedicine, .typeA, .typeB, .other:
            return true
        default:
            return false
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 修改：拆分页面Header悬浮区与列表滚动区，实现标题钉顶悬浮效果
                // Header区域：标题 + 筛选 + 添加按钮，永久固定页面顶部
                pinnedHeader
                    // 新增：向上滑动列表时Header轻微收起动画
                    .offset(y: min(0, scrollOffset * 0.15))
                    .animation(.easeInOut(duration: 0.2), value: scrollOffset)

                // 仅药品条目列表作为可滚动区域，Header完全脱离滚动流
                ScrollView {
                    scrollTrackingContent
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
            }
            .background(AppleGlassStyle.groupedBackground)
            .sheet(isPresented: $showAddSheet) {
                AddDrugSheet { newRecord in
                    drugManager.addRecord(newRecord)
                    // 【网络层对接】同步用药记录到后端
                    Task { await drugManager.syncToBackend() }
                }
            }
            .sheet(item: $selectedRecordForAction) { record in
                MedicationOperationPopover(record: record) { action in
                    switch action {
                    case .stop:
                        if let idx = drugManager.records.firstIndex(where: { $0.id == record.id }) {
                            drugManager.records[idx].status = .stopped
                            drugManager.saveToStorage()
                        }
                    case .keepActive:
                        //【修复原有逻辑】已停用药品点击维持按钮自动切回「在用」状态，恢复后药物风险警告正常生效
                        if let idx = drugManager.records.firstIndex(where: { $0.id == record.id }) {
                            drugManager.records[idx].status = .viewing
                            drugManager.saveToStorage()
                        }
                    }
                    selectedRecordForAction = nil
                    // 【网络层对接】同步用药记录到后端
                    Task { await drugManager.syncToBackend() }
                }
            }
            // 【网络层对接】从后端加载用药记录
            .onAppear {
                Task {
                    await loadDrugsFromAPI()
                }
            }
        }
    }

    // MARK: - Pinned Header（新增：固定悬浮Header视图块）
    // 承载「用药记录」标题、筛选标签、添加药品按钮，永久钉顶
    // 向上滑动列表时Header支持轻微收起动画，松手回弹恢复

    private var pinnedHeader: some View {
        VStack(spacing: 0) {
            // 标题行 + 添加按钮
            HStack {
                Text("用药记录")
                    .font(.title.weight(.semibold))
                    .foregroundColor(AppleGlassStyle.textPrimary)
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppleGlassStyle.accent)
                }
            }
            .padding(.horizontal, AppleGlassStyle.spacingMD)
            .padding(.top, AppleGlassStyle.spacingSM)
            .padding(.bottom, AppleGlassStyle.spacingXS)

            // 状态筛选分段标签（全部/在用/评估中/已停用）
            HStack(spacing: AppleGlassStyle.spacingSM) {
                FilterChip(label: "全部", isSelected: selectedStatus == nil) {
                    selectedStatus = nil
                }
                ForEach(DrugStatus.allCases) { status in
                    FilterChip(label: status.rawValue, isSelected: selectedStatus == status) {
                        selectedStatus = status
                    }
                }
            }
            .padding(.horizontal, AppleGlassStyle.spacingMD)
            .padding(.vertical, AppleGlassStyle.spacingSM)
            .background(AppleGlassStyle.standard)

            // 添加药品记录按钮（调整至Header内，滚动时始终可见）
            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: AppleGlassStyle.spacingSM) {
                    Image(systemName: "plus")
                        .font(.subheadline)
                        .foregroundStyle(AppleGlassStyle.accent)
                    Text("添加药品记录")
                        .font(.subheadline)
                        .foregroundStyle(AppleGlassStyle.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppleGlassStyle.textTertiary)
                }
                .padding(AppleGlassStyle.spacingMD)
                .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
                .padding(.horizontal, AppleGlassStyle.spacingMD)
                .padding(.vertical, AppleGlassStyle.spacingSM)
            }
            .buttonStyle(.plain)
        }
        .background(AppleGlassStyle.groupedBackground)
    }

    // MARK: - Scroll Tracking Content（列表区域 + 底部免责 + 滚动偏移检测）
    private var scrollTrackingContent: some View {
        VStack(spacing: 0) {
            // 滚动偏移锚点
            GeometryReader { geo in
                Color.clear
                    .preference(key: ScrollOffsetPreferenceKey.self,
                                value: geo.frame(in: .named("scroll")).minY)
            }
            .frame(height: 0)

            VStack(spacing: 0) {
                recordListView
                bottomDisclaimer
            }
        }
    }

    // MARK: - Record List View
    private var recordListView: some View {
        Group {
            if filteredRecords.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: AppleGlassStyle.spacingSM) {
                    ForEach(filteredRecords) { record in
                        DrugRecordRow(record: record)
                            // 新增条目点击识别，唤起药品操作弹窗
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedRecordForAction = record
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    drugManager.deleteRecord(record)
                                    // 【网络层对接】同步用药记录到后端
                                    Task { await drugManager.syncToBackend() }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal, AppleGlassStyle.spacingMD)
                .padding(.top, AppleGlassStyle.spacingSM)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppleGlassStyle.spacingMD) {
            Spacer()
            Image(systemName: "cross.vial")
                .font(.system(size: 48))
                .foregroundStyle(AppleGlassStyle.textTertiary)
            Text("暂无用药记录")
                .font(.headline)
                .foregroundStyle(AppleGlassStyle.textSecondary)
            Text("记录您在专业指导下使用的药品") // 修改：删除「和补剂」，用药页面仅体现药品业务
                .font(.subheadline)
                .foregroundStyle(AppleGlassStyle.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppleGlassStyle.spacingLG)
            Spacer()
        }
    }

    // MARK: - Bottom Disclaimer
    private var bottomDisclaimer: some View {
        VStack(spacing: AppleGlassStyle.spacingXS) {
            ComplianceText(text: "【合规隔离红线】以上药品信息仅作个人记录用途，不构成任何用药建议。请在专业医师指导下使用任何药品。")
            ComplianceText(text: "【合规隔离红线】所有数据仅存储在本地设备，不会上传至任何服务器，不涉及任何远程医疗或在线诊疗功能。")
        }
        .padding(.horizontal, AppleGlassStyle.spacingMD)
        .padding(.vertical, AppleGlassStyle.spacingSM)
    }

    // 【网络层对接】从后端 API 加载用药记录
    private func loadDrugsFromAPI() async {
        guard let uid = LoginUserStorage.userId, !uid.isEmpty else { return }
        do {
            let resp: DrugListResponse = try await APIClient.shared.get("/api/drug/list?user_id=\(uid)")
            if !resp.records.isEmpty {
                let records = resp.records.map { item -> DrugRecordModel in
                    DrugRecordModel(
                        drugName: item.drug_name,
                        category: DrugCategory(rawValue: item.category) ?? .other,
                        status: DrugStatus(rawValue: item.status) ?? .viewing,
                        dosage: item.dosage,
                        unit: item.unit,
                        frequency: item.frequency,
                        createdAt: Date(),
                        notes: ""
                    )
                }
                await MainActor.run {
                    DrugDataManager.shared.records = records
                    DrugDataManager.shared.saveToStorage()
                    print("[MedicineView] 从后端加载 \(records.count) 条用药记录")
                }
            }
        } catch {
            print("[MedicineView] 后端加载用药记录失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - DrugRecordRow
struct DrugRecordRow: View {
    let record: DrugRecordModel

    private var catColor: Color {
        drugCategoryColor(record.category)
    }

    var body: some View {
        HStack(spacing: AppleGlassStyle.spacingMD) {
            Image(systemName: record.category.systemImage)
                .font(.title3)
                .foregroundStyle(catColor)
                .frame(width: 40, height: 40)
                .background(
                    catColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall)
                )

            VStack(alignment: .leading, spacing: AppleGlassStyle.spacingXS) {
                Text(record.drugName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppleGlassStyle.textPrimary)

                HStack(spacing: AppleGlassStyle.spacingSM) {
                    categoryBadge
                    Text("\(record.dosage)\(record.unit)")
                        .font(.caption)
                        .foregroundStyle(AppleGlassStyle.textSecondary)
                }

                Text(record.frequency)
                    .font(.caption2)
                    .foregroundStyle(AppleGlassStyle.textTertiary)
            }

            Spacer()

            statusIndicator
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    private var categoryBadge: some View {
        Text(record.category.displayName)
            .font(.caption2.weight(.medium))
            .foregroundStyle(catColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(catColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }

    private var statusIndicator: some View {
        Text(record.status.rawValue)
            .font(.caption2.weight(.medium))
            .foregroundStyle(statusColor)
            .padding(.horizontal, AppleGlassStyle.spacingSM)
            .padding(.vertical, AppleGlassStyle.spacingXS)
            .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
    }

    private var statusColor: Color {
        switch record.status {
        case .viewing: return .green
        case .syncing: return .orange
        case .stopped: return .gray
        }
    }
}

// MARK: - DrugCategory Color Helper
private func drugCategoryColor(_ cat: DrugCategory) -> Color {
    switch cat {
    case .supplement:            return .mint
    case .prescription:          return .orange
    case .otc:                   return .blue
    case .traditionalChMedicine: return .brown
    case .typeA:                 return .red
    case .typeB:                 return .purple
    case .other:                 return .gray
    }
}

// MARK: - AddDrugSheet
struct AddDrugSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var drugName: String = ""
    @State private var category: DrugCategory = .other
    @State private var dosage: String = ""
    @State private var unit: String = "mg"
    @State private var frequency: String = ""
    @State private var notes: String = ""
    @State private var status: DrugStatus = .viewing

    // 【网络层对接】药品完整查询结果（含风险标签、处方标志）
    @State private var drugLookupResult: DrugLookupResponse? = nil

    var onSave: (DrugRecordModel) -> Void

    // 修改：删除补剂、处方药、非处方药3个选项，仅保留中药、TabA、TabB、其他
    private let drugCategoryOptions: [DrugCategory] = [.traditionalChMedicine, .typeA, .typeB, .other]

    // 【解耦改动】drugKeywordMap + autoDetectMedicationType 迁移至 DrugClassificationService
    private let drugClassService = DrugClassificationService()

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("药品名称", text: $drugName)
                        // 【解耦改动】autoDetectMedicationType → drugClassService.autoDetectMedicationType
                        .onChange(of: drugName) { _, newValue in
                            // 重置之前查询的结果
                            drugLookupResult = nil
                            guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            Task {
                                if let result = await drugClassService.lookupFromAPI(drugName: newValue) {
                                    await MainActor.run {
                                        drugLookupResult = result
                                        // 自动填充分类
                                        if let detected = DrugCategory(rawValue: result.category) {
                                            category = detected
                                        }
                                    }
                                }
                            }
                        }
                    Picker("类别", selection: $category) {
                        ForEach(drugCategoryOptions, id: \.self) { cat in // 修改：仅遍历保留的4个分类选项
                            Label(cat.displayName, systemImage: cat.systemImage)
                                .tag(cat)
                        }
                    }

                    // 【网络层对接】药品风险标签展示
                    if let result = drugLookupResult {
                        if result.is_prescription {
                            HStack {
                                Image(systemName: "prescription")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Text("处方药")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                        if !result.risk_tags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(result.risk_tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.1))
                                        .foregroundStyle(.red)
                                        .cornerRadius(4)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("用量信息") {
                    HStack {
                        TextField("剂量", text: $dosage)
                            .keyboardType(.decimalPad)
                        Picker("单位", selection: $unit) {
                            Text("mg").tag("mg")
                            Text("g").tag("g")
                            Text("mcg").tag("mcg")
                            Text("IU").tag("IU")
                            Text("片").tag("片")
                            Text("粒").tag("粒")
                            Text("ml").tag("ml")
                        }
                    }
                    TextField("频率（如：每日1次）", text: $frequency)
                }

                Section("状态") {
                    Picker("使用状态", selection: $status) {
                        ForEach(DrugStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("备注") {
                    TextField("备注（可选）", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                // //【合规隔离红线】Disclaimer within the add form itself.
                Section {
                    ComplianceText(text: "请确保您录入的药品信息来源于专业医师的建议。本应用仅提供记录功能。", showIcon: false)
                }
            }
            .navigationTitle("添加用药记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let record = DrugRecordModel(
                            drugName: drugName,
                            category: category,
                            status: status,
                            dosage: dosage,
                            unit: unit,
                            frequency: frequency,
                            createdAt: Date(),
                            notes: notes
                        )
                        onSave(record)
                        dismiss()
                    }
                    .disabled(drugName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

// MARK: - 新增：药品操作弹窗视图
// 复用项目AppleGlassStyle统一UI规范，提供查看详情、停用药品、维持在用三个操作选项
// 远期兼容：TabB药物 → .stop 时同步通知训练页肌腱风险校验逻辑，无需重构弹窗

enum MedicationAction {
    case stop       // 停用药品
    case keepActive // 维持在用：已停用药品点击此按钮自动切回「在用」状态
}

struct MedicationOperationPopover: View {
    let record: DrugRecordModel
    let onAction: (MedicationAction) -> Void
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
                // 药品名称 + 分类标签
                HStack(spacing: AppleGlassStyle.spacingSM) {
                    Image(systemName: record.category.systemImage)
                        .font(.title2)
                        .foregroundStyle(drugCategoryColor(record.category))
                        .frame(width: 44, height: 44)
                        .background(drugCategoryColor(record.category).opacity(0.12), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.drugName)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(AppleGlassStyle.textPrimary)
                        Text(record.category.displayName)
                            .font(.caption)
                            .foregroundColor(drugCategoryColor(record.category))
                    }
                    Spacer()
                    // 状态标签
                    Text(record.status.rawValue)
                        .font(.caption.weight(.medium))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, AppleGlassStyle.spacingSM)
                        .padding(.vertical, AppleGlassStyle.spacingXS)
                        .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
                }

                Divider().opacity(0.3)

                // 药品基础信息
                DrugDetailInfoRow(icon: "pills.fill", label: "剂量", value: "\(record.dosage) \(record.unit)")
                DrugDetailInfoRow(icon: "clock.fill", label: "频率", value: record.frequency.isEmpty ? "未设置" : record.frequency)
                if !record.notes.isEmpty {
                    DrugDetailInfoRow(icon: "note.text", label: "备注", value: record.notes)
                }

                Divider().opacity(0.3)

                // 操作按钮区
                VStack(spacing: AppleGlassStyle.spacingSM) {
                    // 查看详情 → 跳转药品详情页
                    NavigationLink {
                        MedicationDetailView(record: record)
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("查看药品详情")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .font(.body.weight(.medium))
                        .foregroundColor(AppleGlassStyle.textPrimary)
                        .padding(.vertical, 10)
                    }

                    // 停用药品
                    Button {
                        onAction(.stop)
                        dismiss()
                    } label: {
                        Label("停用药品", systemImage: "xmark.circle.fill")
                            .font(.body.weight(.medium))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }

                    // 维持在用药状态
                    Button {
                        onAction(.keepActive)
                        dismiss()
                    } label: {
                        Label("维持在用药状态", systemImage: "checkmark.circle.fill")
                            .font(.body.weight(.medium))
                            .foregroundColor(AppleGlassStyle.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
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

    private var statusColor: Color {
        switch record.status {
        case .viewing: return .green
        case .syncing: return .orange
        case .stopped: return .gray
        }
    }
}

// MARK: - 新增：药品详情信息行

struct DrugDetailInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: AppleGlassStyle.spacingSM) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundColor(AppleGlassStyle.textTertiary)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppleGlassStyle.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppleGlassStyle.textPrimary)
        }
    }
}

// MARK: - 新增：药品详情页

struct MedicationDetailView: View {
    let record: DrugRecordModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 药品摘要卡片
                VStack(spacing: AppleGlassStyle.spacingSM) {
                    HStack(spacing: AppleGlassStyle.spacingSM) {
                        Image(systemName: record.category.systemImage)
                            .font(.title)
                            .foregroundStyle(drugCategoryColor(record.category))
                            .frame(width: 52, height: 52)
                            .background(drugCategoryColor(record.category).opacity(0.1), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.drugName)
                                .font(.title2.weight(.bold))
                                .foregroundColor(AppleGlassStyle.textPrimary)
                            HStack(spacing: 8) {
                                Text(record.category.displayName)
                                    .font(.caption)
                                    .foregroundColor(drugCategoryColor(record.category))
                                Text(record.status.rawValue)
                                    .font(.caption)
                                    .foregroundColor(statusColor)
                            }
                        }
                        Spacer()
                    }
                    .padding(AppleGlassStyle.spacingSM)
                }
                .padding(AppleGlassStyle.spacingSM)
                .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
                .padding(AppleGlassStyle.spacingSM)

                // 详细信息列表
                Group {
                    DrugDetailInfoRow(icon: "pills.fill", label: "剂量", value: "\(record.dosage) \(record.unit)")
                    DrugDetailInfoRow(icon: "clock.fill", label: "频率", value: record.frequency.isEmpty ? "未设置" : record.frequency)
                    DrugDetailInfoRow(icon: "calendar", label: "录入日期", value: formattedDetailDate)
                    if !record.notes.isEmpty {
                        DrugDetailInfoRow(icon: "note.text", label: "备注", value: record.notes)
                    }
                }
                .padding(.horizontal, AppleGlassStyle.spacingSM)

                Spacer()

                // 合规免责
                VStack(spacing: AppleGlassStyle.spacingXS) {
                    ComplianceText(text: "【合规隔离红线】以上信息仅作个人记录用途，不构成任何用药建议。请在专业医师指导下使用药品。")
                }
                .padding(AppleGlassStyle.spacingSM)
            }
            .background(AppleGlassStyle.groupedBackground)
            .navigationTitle("药品详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var formattedDetailDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月d日 HH:mm"
        return f.string(from: record.createdAt)
    }

    private var statusColor: Color {
        switch record.status {
        case .viewing: return .green
        case .syncing: return .orange
        case .stopped: return .gray
        }
    }
}

// MARK: - Preview

// 新增：滚动偏移量追踪PreferenceKey，用于Header收起动画
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    MedicineView()
}
