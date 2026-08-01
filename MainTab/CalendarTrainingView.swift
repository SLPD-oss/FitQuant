import SwiftUI

// MARK: - CalendarTrainingView
// 月度日历视图，读取本地全部历史训练记录，按日期分组渲染训练汇总
// 复用项目AppleGlassStyle液态玻璃UI规范；预留后端RAG训练数据接口替换注释

struct CalendarTrainingView: View {
    @Environment(\.dismiss) private var dismiss
    let trainingRecords: [TrainingRecordModel]
    @State private var currentMonth: Date = Date()
    // 【本次修复】原 selectedDateRecords 变量因时序竞态导致弹窗空白，已移除；
    // 改为直接存储「已构建好的当日详情内容视图」与「点击日期字符串」，点击时同步写入，无竞态。
    @State private var detailContent: AnyView? = nil
    @State private var selectedDateTitleText: String = ""
    @State private var selectedDateRecordCount: Int = 0
    @State private var showDayDetail: Bool = false

    /// 当前展示月份的完整日期数组（空白补齐星期头尾）
    private var daysInMonth: [Date?] {
        calendarDays(for: currentMonth)
    }

    /// 按日期分组的训练记录字典 [日期字符串: [记录]]
    private var recordsByDate: [String: [TrainingRecordModel]] {
        groupRecordsByDate()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 月份切换栏
                monthHeader
                // 星期标题行
                weekdayHeader
                // 日期网格
                dateGrid
                Spacer()
            }
            .background(AppleGlassStyle.groupedBackground)
            .navigationTitle("训练日历")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showDayDetail) {
                dayDetailView
            }
        }
    }

    // MARK: - 月份切换栏
    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation { currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.medium))
                    .foregroundColor(AppleGlassStyle.accent)
                    .frame(width: 36, height: 36)
            }

            Spacer()
            Text(monthYearString)
                .font(.headline.weight(.semibold))
                .foregroundColor(AppleGlassStyle.textPrimary)
            Spacer()

            Button {
                withAnimation { currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.medium))
                    .foregroundColor(AppleGlassStyle.accent)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, AppleGlassStyle.spacingSM)
        .padding(.vertical, AppleGlassStyle.spacingSM)
        .background(AppleGlassStyle.standard)
    }

    // MARK: - 星期标题行
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(["日","一","二","三","四","五","六"], id: \.self) { day in
                Text(day)
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppleGlassStyle.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, AppleGlassStyle.spacingSM)
        .padding(.vertical, AppleGlassStyle.spacingXS)
    }

    // MARK: - 日期网格
    private var dateGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(daysInMonth.indices, id: \.self) { idx in
                if let date = daysInMonth[idx] {
                    let key = dateKey(date)
                    let dayRecords = recordsByDate[key] ?? []
                    dateCell(date: date, records: dayRecords)
                } else {
                    Color.clear.frame(height: 72)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 单个日期格子
    private func dateCell(date: Date, records: [TrainingRecordModel]) -> some View {
        let dayNum = calendar.component(.day, from: date)
        let isToday = calendar.isDateInToday(date)
        let hasRecords = !records.isEmpty

        return VStack(spacing: 2) {
            // 日期数字
            Text("\(dayNum)")
                .font(.caption.weight(isToday ? .bold : .regular))
                .foregroundColor(isToday ? .white : AppleGlassStyle.textPrimary)
                .frame(width: 22, height: 22)
                .background(
                    isToday ? AppleGlassStyle.accent : Color.clear,
                    in: Circle()
                )

            // 训练汇总小字（最多2行）
            if hasRecords {
                VStack(spacing: 1) {
                    ForEach(summaryLines(for: records, maxLines: 2), id: \.self) { line in
                        Text(line)
                            .font(.system(size: 7))
                            .foregroundColor(AppleGlassStyle.accent)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(height: 64)
        .background(
            hasRecords ? AppleGlassStyle.accent.opacity(0.06) : Color.clear,
            in: RoundedRectangle(cornerRadius: 4)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // 【本次修复】修复"点击日期后弹窗空白"问题：
            // 原实现先给 selectedDateRecords 赋值再置 showDayDetail=true，两者间存在数据时序竞态，
            // SwiftUI 可能在 selectedDateRecords 尚未被捕获时就开始渲染 sheet，读到空数组 → 空白页。
            // 现在改为：点击时直接把本日记录作为参数传入 detailContent 构建视图，数据流显式无竞态。
            guard hasRecords else { return }
            // 记录当前点击日期（用于弹窗标题展示）
            selectedDateTitleText = dateKey(date)
            // 记录当日训练记录条数（用于弹窗标题展示"共N条"）
            selectedDateRecordCount = records.count
            // 直接用本地变量 records 构建弹窗内容，不依赖 @State 的异步捕获
            detailContent = dayDetailContent(records: records)
            showDayDetail = true
        }
    }

    // MARK: - 训练汇总文字行生成
    private func summaryLines(for records: [TrainingRecordModel], maxLines: Int) -> [String] {
        var lines: [String] = []
        for record in records.prefix(maxLines) {
            if record.trainingType == .strength {
                let muscles = record.muscleGroups.map { $0.displayName }.joined(separator: "/")
                var line = "力量｜\(muscles)"
                if let subs = record.targetSubMuscleGroups, !subs.isEmpty {
                    line += "(\(subs.prefix(2).joined(separator: "/")))"
                }
                lines.append(line)
            } else {
                let subStr: String
                if let hiitCount = record.hiitGroupCount, hiitCount > 0 {
                    subStr = "HIIT"
                } else {
                    subStr = "匀速"
                }
                lines.append("有氧｜\(subStr)\(record.exerciseName)")
            }
        }
        if records.count > maxLines {
            lines.append("...共\(records.count)条记录")
        }
        return lines
    }

    // MARK: - 日期详情弹窗（展示当日全部训练安排）
    // 【本次修复】原弹窗使用 presentationDetents([.medium,.large]) 半屏呈现，
    // 内容多时被压缩裁剪且依赖 selectedDateRecords 状态（存在竞态空白）；
    // 现在改为：点击日期时直接把当日记录构建成内容视图（dayDetailContent），
    // sheet 内通过 detailContent 直接渲染，弹窗大尺寸展示全部训练内容。
    private var dayDetailView: some View {
        VStack(spacing: 0) {
            // 顶部免责声明条（复用项目统一规范）
            HStack(spacing: AppleGlassStyle.spacingXS) {
                Image(systemName: "info.circle").font(.caption2)
                Text(ComplianceText.alertDisclaimerPrefix).font(.caption2)
                Spacer()
            }
            .foregroundColor(AppleGlassStyle.textTertiary)
            .padding(.horizontal, AppleGlassStyle.spacingSM)
            .padding(.vertical, AppleGlassStyle.spacingXS)
            .background(AppleGlassStyle.ultraThin)

            // 内容区：标题 + 当日全部训练记录（数据在点击时已构建，无竞态）
            VStack(spacing: AppleGlassStyle.spacingSM) {
                // 标题：M月d日 训练记录（共N条）
                Text(dayDetailTitle)
                    .font(.headline).foregroundColor(AppleGlassStyle.textPrimary)

                ScrollView {
                    VStack(spacing: AppleGlassStyle.spacingSM) {
                        // 直接渲染点击时构建好的当日内容视图
                        if let content = detailContent {
                            content
                        } else {
                            // 兜底：正常情况下不会出现（detailContent 在点击时必被赋值）
                            Text("暂无训练记录")
                                .font(.subheadline)
                                .foregroundColor(AppleGlassStyle.textTertiary)
                                .padding(.vertical, AppleGlassStyle.spacingLG)
                        }
                    }
                }

                Divider().padding(.horizontal, -AppleGlassStyle.spacingSM)
                Button { showDayDetail = false } label: {
                    Text("关闭").font(.body.weight(.medium))
                        .foregroundColor(.white).frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
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
        .presentationDetents([.large])  // 【本次修复】仅大尺寸呈现，确保全部训练内容完整可见
    }

    /// 弹窗标题：M月d日 训练记录（共N条）
    private var dayDetailTitle: String {
        guard !selectedDateTitleText.isEmpty else { return "训练记录" }
        // 将 yyyy-MM-dd 转为 M月d日 展示
        let parts = selectedDateTitleText.split(separator: "-")
        guard parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) else { return "训练记录" }
        return "\(m)月\(d)日 训练记录（共\(selectedDateRecordCount)条）"
    }

    // MARK: - 构建当日训练详情内容（点击日期时调用，直接传入当日记录）
    /// 传入当日全部记录，构建完整的训练安排列表视图；
    /// 展示力量/有氧全部字段：动作名、类型、组次、重量、时长、消耗、
    /// 肌群、细分肌群、跑步机时速/坡度、HIIT组数/运动秒/休息秒、备注。
    private func dayDetailContent(records: [TrainingRecordModel]) -> AnyView {
        AnyView(
            VStack(spacing: AppleGlassStyle.spacingSM) {
                ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                    dayRecordCard(record)
                }
            }
        )
    }

    // MARK: - 单条训练记录详情卡（展示训练计划全部内容）
    private func dayRecordCard(_ record: TrainingRecordModel) -> some View {
        VStack(alignment: .leading, spacing: AppleGlassStyle.spacingXS) {
            // 第一行：类型图标 + 动作名称 + 训练类型标签
            HStack {
                Image(systemName: record.trainingType == .strength ? "dumbbell.fill" : "figure.run")
                    .foregroundStyle(record.trainingType == .strength ? .orange : .teal)
                Text(record.exerciseName.isEmpty ? "未命名动作" : record.exerciseName)
                    .font(.body.weight(.medium)).foregroundColor(AppleGlassStyle.textPrimary)
                Spacer()
                Text(record.trainingType == .strength ? "力量训练" : "有氧训练")
                    .font(.caption2).foregroundColor(AppleGlassStyle.textTertiary)
            }

            Divider()

            // 力量训练：组数/次数/重量/肌群/细分肌群
            if record.trainingType == .strength {
                detailRow(icon: "repeat", label: "组数 × 次数", value: "\(record.sets)组 × \(record.reps)次")
                if record.weightKg > 0 {
                    detailRow(icon: "scalemass", label: "重量", value: String(format: "%.0f kg", record.weightKg))
                }
                if !record.muscleGroups.isEmpty {
                    detailRow(icon: "figure.strengthtraining.traditional", label: "目标肌群",
                              value: record.muscleGroups.map { $0.displayName }.joined(separator: " / "))
                }
                if let subs = record.targetSubMuscleGroups, !subs.isEmpty {
                    detailRow(icon: "target", label: "细分肌群", value: subs.joined(separator: " · "))
                }
            }
            // 有氧训练：时长/消耗/跑步机时速/坡度/HIIT参数
            else {
                detailRow(icon: "timer", label: "时长", value: "\(record.durationMinutes) 分钟")
                if record.estimatedKcal > 0 {
                    detailRow(icon: "flame.fill", label: "估算消耗", value: String(format: "%.0f kcal", record.estimatedKcal))
                }
                // HIIT 分类：展示组数/运动秒/休息秒
                if let hiitCount = record.hiitGroupCount, hiitCount > 0 {
                    detailRow(icon: "bolt.fill", label: "HIIT 组数", value: "\(hiitCount) 组")
                    if let work = record.hiitWorkSecond { detailRow(icon: "bolt.fill", label: "每组运动", value: "\(work) 秒") }
                    if let rest = record.hiitRestSecond { detailRow(icon: "pause.fill", label: "每组休息", value: "\(rest) 秒") }
                }
                // 匀速有氧：跑步机时速/坡度
                if let speed = record.treadmillSpeed {
                    detailRow(icon: "speedometer", label: "时速", value: String(format: "%.0f km/h", speed))
                }
                if let slope = record.treadmillSlope {
                    detailRow(icon: "arrow.up.forward", label: "坡度", value: String(format: "%.0f %%", slope))
                }
            }

            // 备注（完整展示，不限行数）
            if !record.notes.isEmpty {
                detailRow(icon: "note.text", label: "备注", value: record.notes)
            }
        }
        .padding(AppleGlassStyle.spacingSM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
    }

    // MARK: - 详情行通用组件（图标 + 标签 + 值）
    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: AppleGlassStyle.spacingSM) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppleGlassStyle.accent)
                .frame(width: 18)
            Text(label)
                .font(.caption)
                .foregroundColor(AppleGlassStyle.textTertiary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundColor(AppleGlassStyle.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - 工具函数
    private var calendar: Calendar { Calendar.current }
    private var monthYearString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy年M月"
        return f.string(from: currentMonth)
    }
    private func dateKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// 生成当月日期数组（空白补齐为7的倍数）
    private func calendarDays(for month: Date) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }
        let daysInMonth = range.count
        let weekday = calendar.component(.weekday, from: firstDay) - 1 // 0=周日
        var result: [Date?] = Array(repeating: nil, count: weekday)
        for day in 1...daysInMonth {
            result.append(calendar.date(byAdding: .day, value: day - 1, to: firstDay))
        }
        let remainder = 7 - (result.count % 7)
        if remainder < 7 { result.append(contentsOf: Array(repeating: nil as Date?, count: remainder)) }
        return result
    }

    /// 读取本地全部训练记录并按日期分组
    /// 当前读取本地训练数据，预留后端RAG训练数据接口替换注释
    private func groupRecordsByDate() -> [String: [TrainingRecordModel]] {
        var dict: [String: [TrainingRecordModel]] = [:]
        // 远期替换：调用后端RAG训练数据API → 获取线上全部历史训练记录 → 替换下方本地读取逻辑
        for record in trainingRecords {
            let key = dateKey(record.createdAt)
            dict[key, default: []].append(record)
        }
        return dict
    }
}

#Preview {
    CalendarTrainingView(trainingRecords: [])
}
