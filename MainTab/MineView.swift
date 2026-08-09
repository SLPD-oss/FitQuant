import SwiftUI

// MARK: - MineView
// User profile with body data editor, identity switcher, quick stats,
// BMI zone bar, iteration plan notes, and logout.
// //【合规红线】Body data is locally stored only; no cloud sync.
// //【合规红线】BMI/BMR calculations are informational only -- not medical diagnostics.
// //【用户整改】Logout resets all @AppStorage flags for re-agreement flow.

struct MineView: View {
    @Binding var bodyData: BodyDataModel

    // Body data editor state
    @State private var isEditingData: Bool = false

    // 【体重追踪】迭代计划板块改造为体重追踪线性图
    // 状态：体重历史记录（本地存储）、更新体重弹窗控制、弹窗内体重输入文本
    @State private var weightHistory: [WeightRecord] = []
    @State private var showWeightUpdate: Bool = false
    @State private var weightInputText: String = ""
    // 【本次更新】减脂历程全屏弹窗控制：点击趋势图打开完整减脂历程
    @State private var showWeightTimeline: Bool = false

    // Iteration plan notes
    @State private var iterationNotes: String = ""

    // @AppStorage for logout reset
    @AppStorage("agreedLocalLaw") private var agreedLocalLaw: Bool = false
    @AppStorage("agreedApplePolicy") private var agreedApplePolicy: Bool = false
    // 【合规整改｜协议版本化】退出时同步清空协议版本号（与 RootView.agreementVersion 配合）
    @AppStorage("agreedLocalLawVersion") private var agreedLocalLawVersion: String = ""
    @AppStorage("agreedApplePolicyVersion") private var agreedApplePolicyVersion: String = ""
    @AppStorage("firstOpenFlag") private var firstOpenFlag: Bool = true
    //【新增代码】引入登录状态标记，确保退出重置后下次启动强制重新登录
    @AppStorage("isUserLogined") private var isUserLogined: Bool = false
    // 【本次更新｜深色模式】全局深浅色开关（与 FitQuantApp 同名 key 联动，默认浅色）
    @AppStorage("darkModeEnabled") private var darkModeEnabled: Bool = false

    @State private var showLogoutConfirmation: Bool = false
    // 【注销账号】二次确认弹窗 + 删除中状态 + 删除失败提示
    @State private var showDeleteAccountConfirmation: Bool = false
    @State private var isDeletingAccount: Bool = false
    @State private var deleteAccountError: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppleGlassStyle.spacingMD) {
                    profileHeader
                    bodyDataEditor
                    quickStatsSection
                    bmiZoneBar
                    weightTrackingSection
                    // 【本次更新｜深色模式】外观设置区块（置于合规区上方）
                    appearanceSection
                    complianceSection
                    logoutButton
                    // 【注销账号】置于页面最底部，与登出按钮视觉区分（更醒目）
                    deleteAccountButton
                }
                .padding(AppleGlassStyle.spacingMD)
            }
            .background(AppleGlassStyle.groupedBackground)
            .navigationTitle("我的")
            .sheet(isPresented: $isEditingData) {
                BodyDataEditSheet(bodyData: $bodyData)
            }
            .confirmationDialog(
                "确认退出",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("退出并重置", role: .destructive) { performLogout() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("退出后将清除所有同意协议记录，下次启动需要重新进行合规确认。您的本地数据不会被删除。")
            }
            // 【注销账号】二次确认弹窗：不可恢复操作，红色确认
            .alert("注销账号", isPresented: $showDeleteAccountConfirmation) {
                Button("注销", role: .destructive) { performDeleteAccount() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作不可恢复：账号及其全部记录（训练、饮食、用药、睡眠、身体数据）将被永久删除，云端与本地数据均无法找回。")
            }
            // 【注销账号】删除失败提示
            .alert("注销失败", isPresented: Binding(
                get: { deleteAccountError != nil },
                set: { if !$0 { deleteAccountError = nil } }
            )) {
                Button("知道了", role: .cancel) { deleteAccountError = nil }
            } message: {
                Text(deleteAccountError ?? "未知错误，请稍后重试。本地数据未清除，可重新尝试注销。")
            }
            //【修复数据读取逻辑】每次进入页面从UserDefaults读取最新身体数据，同步绑定状态
            .onAppear {
                loadBodyDataFromStorage()
                // 【体重追踪】进入页面时加载本地体重历史（无历史且当前有体重则自动补基线）
                loadWeightHistory()
            }
            // 【体重追踪】更新体重输入弹窗
            .sheet(isPresented: $showWeightUpdate) {
                weightUpdateSheet
            }
            // 【本次更新】减脂历程全屏弹窗：点击趋势图打开，查看整体减脂历程
            // 传 Binding：历程内长按删除/更改记录后，主界面趋势图实时同步刷新
            .sheet(isPresented: $showWeightTimeline) {
                WeightTimelineSheet(records: $weightHistory)
            }
        }
    }

    // MARK: - Profile Header
    private var profileHeader: some View {
        HStack(spacing: AppleGlassStyle.spacingMD) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppleGlassStyle.accent)
                .frame(width: 60, height: 60)
                .background(AppleGlassStyle.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusLarge))

            VStack(alignment: .leading, spacing: AppleGlassStyle.spacingXS) {
                Text(LoginUserStorage.userNickname)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppleGlassStyle.textPrimary)
                Text("\(bodyData.age)岁  \(bodyData.gender.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(AppleGlassStyle.textSecondary)
                Text("活动水平: \(bodyData.activityLevel.rawValue)")
                    .font(.caption)
                    .foregroundStyle(AppleGlassStyle.textTertiary)
            }
            Spacer()
            Button {
                isEditingData = true
            } label: {
                Text("编辑")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppleGlassStyle.accent)
                    .padding(.horizontal, AppleGlassStyle.spacingMD)
                    .padding(.vertical, AppleGlassStyle.spacingSM)
                    .background(AppleGlassStyle.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
            }
            .buttonStyle(.plain)
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    // MARK: - Body Data Editor (Summary View)
    private var bodyDataEditor: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            HStack {
                Text("身体数据").font(.headline).foregroundStyle(AppleGlassStyle.textPrimary)
                Spacer()
            }
            bodyDataRow(label: "身高", value: String(format: "%.1f cm", bodyData.heightCm), systemImage: "ruler")
            bodyDataRow(label: "体重", value: String(format: "%.1f kg", bodyData.weightKg), systemImage: "scalemass")
            bodyDataRow(label: "体脂率", value: String(format: "%.1f%%", bodyData.bodyFatPercent), systemImage: "figure.arms.open")
            bodyDataRow(label: "腰围", value: String(format: "%.1f cm", bodyData.waistCm), systemImage: "circle.dotted.circle")
            bodyDataRow(label: "臀围", value: String(format: "%.1f cm", bodyData.hipCm), systemImage: "circle.dotted.circle")
            bodyDataRow(label: "颈围", value: String(format: "%.1f cm", bodyData.neckCm), systemImage: "circle.dotted.circle")
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    private func bodyDataRow(label: String, value: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage).font(.caption).foregroundStyle(AppleGlassStyle.accent).frame(width: 20)
            Text(label).font(.subheadline).foregroundStyle(AppleGlassStyle.textSecondary)
            Spacer()
            Text(value).font(.subheadline.weight(.medium)).foregroundStyle(AppleGlassStyle.textPrimary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Quick Stats Section
    private var quickStatsSection: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            HStack {
                Text("快速指标").font(.headline).foregroundStyle(AppleGlassStyle.textPrimary)
                Spacer()
            }
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: AppleGlassStyle.spacingSM), GridItem(.flexible(), spacing: AppleGlassStyle.spacingSM)],
                spacing: AppleGlassStyle.spacingSM
            ) {
                quickStatCard(label: "BMI", value: String(format: "%.1f", bodyData.bmi), detail: bodyData.bmiCategory, color: bmiColor)
                quickStatCard(label: "体脂率 (Navy)", value: String(format: "%.1f%%", bodyData.navyBodyFat), detail: "公式估算", color: .purple)
                quickStatCard(label: "腰臀比", value: String(format: "%.2f", bodyData.waistToHipRatio), detail: whrRisk, color: .orange)
                quickStatCard(label: "基础代谢 BMR", value: String(format: "%.0f kcal", bodyData.bmr), detail: "Mifflin-St Jeor", color: .teal)
            }

            // 【本次更新】一键录入身体数据按钮：点击直接打开身体数据编辑表（BodyDataEditSheet）
            // 设计逻辑：复用页面已有 isEditingData 状态与 sheet 挂接，零新增状态；
            // 录入表含基本信息/围度/体脂，完成时本地保存并同步云端，与顶部「编辑」入口功能一致。
            // 【本次更新】体脂率联动：点击一键录入时，将身体数据中存储的体脂率（bodyFatPercent）
            // 直接替换为快速指标中的公式计算体脂率（navyBodyFat），保证两板块体脂率一致；
            // 仅当公式值有效（>0，即已录身高与腰围）时替换，未录围度时保持原值避免误清零。
            Button {
                if bodyData.navyBodyFat > 0 {
                    bodyData.bodyFatPercent = bodyData.navyBodyFat
                    // 替换后立即保存（本地 + 云端），保证两个板块展示一致
                    let model = bodyData
                    BodyDataRepository.saveAndSync(model)
                }
                isEditingData = true
            } label: {
                Label("一键录入身体数据", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppleGlassStyle.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppleGlassStyle.spacingSM)
                    .background(AppleGlassStyle.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
            }
            .buttonStyle(.plain)
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    private func quickStatCard(label: String, value: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppleGlassStyle.spacingXS) {
            Text(label).font(.caption.weight(.medium)).foregroundStyle(AppleGlassStyle.textTertiary)
            Text(value).font(.title3.weight(.bold)).foregroundStyle(color)
            Text(detail).font(.caption2).foregroundStyle(AppleGlassStyle.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppleGlassStyle.spacingSM)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
    }

    private var bmiColor: Color {
        switch bodyData.bmi {
        case ..<18.5: return .orange
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }

    private var whrRisk: String {
        switch bodyData.gender {
        case .male:   return bodyData.waistToHipRatio > 0.90 ? "偏高" : "正常"
        case .female: return bodyData.waistToHipRatio > 0.85 ? "偏高" : "正常"
        }
    }

    // MARK: - BMI Zone Bar
    private var bmiZoneBar: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            HStack {
                Text("BMI 区间").font(.headline).foregroundStyle(AppleGlassStyle.textPrimary)
                Spacer()
                Text(String(format: "BMI %.1f", bodyData.bmi))
                    .font(.subheadline.weight(.medium)).foregroundStyle(bmiColor)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Rectangle().fill(Color.orange.opacity(0.6)).frame(width: geometry.size.width * 0.185)
                        Rectangle().fill(Color.green.opacity(0.6)).frame(width: geometry.size.width * 0.315)
                        Rectangle().fill(Color.orange.opacity(0.6)).frame(width: geometry.size.width * 0.25)
                        Rectangle().fill(Color.red.opacity(0.6)).frame(width: geometry.size.width * 0.25)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4)).frame(height: 24)
                    let bmiValue = bodyData.bmi
                    let normalized: CGFloat = {
                        if bmiValue <= 18.5 { return CGFloat(bmiValue / 18.5) * 0.185 }
                        else if bmiValue <= 25 { return 0.185 + CGFloat((bmiValue - 18.5) / 6.5) * 0.315 }
                        else if bmiValue <= 30 { return 0.5 + CGFloat((bmiValue - 25) / 5) * 0.25 }
                        else { return min(0.75 + CGFloat((bmiValue - 30) / 10) * 0.25, 1.0) }
                    }()
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 3, height: 32)
                        .offset(x: normalized * geometry.size.width - 1.5)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                }
            }
            .frame(height: 32)
            HStack(spacing: 0) {
                Text("偏瘦").frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                Text("正常").frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                Text("超重").frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                Text("肥胖").frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
            }
            .font(.caption2).foregroundStyle(AppleGlassStyle.textTertiary)
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    // MARK: - Weight Tracking Section（迭代计划 → 体重追踪）
    // 【本次更新】原迭代计划（TextEditor 备注）改造为「体重追踪线性图 + 更新体重按钮」：
    // - 线性图：SwiftUI 原生 Path 绘制折线，数据来自 WeightHistoryStore 本地历史记录
    // - 更新按钮：弹出输入框填写最新体重 → 追加历史 + 同步 bodyData.weightKg（联动 BMI 等指标）
    // - 数据一致性：历史记录按日期升序；同一天多次更新以最后一次为准
    private var weightTrackingSection: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            HStack {
                Text("体重追踪").font(.headline).foregroundStyle(AppleGlassStyle.textPrimary)
                Spacer()
                // 显示当前体重与变化趋势（相比最早一条）
                if let first = weightHistory.first, let last = weightHistory.last {
                    Text(String(format: "%.1f kg", last.weightKg))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(weightChangeColor(first: first.weightKg, last: last.weightKg))
                }
            }

            // 线性图主体：
            // 【本次更新】初始体重即为趋势图第一个数据点（进入页面时自动补基线），
            // 每更新一次体重追加为新数据点，用折线串联整体看减脂趋势；
            // 只要有 ≥1 条记录即显示图表（单点显示，无连线），无需等待两次更新。
            // 【本次更新】点击趋势图可打开完整减脂历程弹窗（全量数据大图 + 记录列表）
            if !weightHistory.isEmpty {
                WeightTrendChart(records: Array(weightHistory.suffix(14)))
                    .frame(height: 180)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showWeightTimeline = true
                    }

                // 点击提示：引导用户点图查看整体减脂历程
                HStack(spacing: 4) {
                    Image(systemName: "hand.tap.fill")
                        .font(.caption2)
                    Text("点击趋势图查看完整减脂历程")
                        .font(.caption2)
                }
                .foregroundStyle(AppleGlassStyle.textTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                // 空状态：从未记录过体重且身体数据中也没有有效体重
                VStack(spacing: AppleGlassStyle.spacingXS) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2)
                        .foregroundStyle(AppleGlassStyle.textTertiary)
                    Text("暂无体重数据")
                        .font(.subheadline)
                        .foregroundStyle(AppleGlassStyle.textPrimary)
                    Text("点击下方按钮记录体重，初始体重将作为趋势图起点")
                        .font(.caption2)
                        .foregroundStyle(AppleGlassStyle.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppleGlassStyle.spacingMD)
            }

            // 最近记录摘要（最近 5 条，便于快速回看）
            if weightHistory.count >= 2 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppleGlassStyle.spacingSM) {
                        ForEach(Array(weightHistory.suffix(5).reversed())) { record in
                            VStack(spacing: 2) {
                                Text(String(format: "%.1f kg", record.weightKg))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppleGlassStyle.textPrimary)
                                Text(weightShortDate(record.date))
                                    .font(.caption2)
                                    .foregroundStyle(AppleGlassStyle.textTertiary)
                            }
                            .padding(.horizontal, AppleGlassStyle.spacingSM)
                            .padding(.vertical, 6)
                            .background(AppleGlassStyle.ultraThin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
                        }
                    }
                }
            }

            // 更新体重按钮：弹出输入框直接填写最新体重
            Button {
                // 预填当前体重，方便微调
                weightInputText = bodyData.weightKg > 0 ? String(format: "%.1f", bodyData.weightKg) : ""
                showWeightUpdate = true
            } label: {
                Label("更新体重", systemImage: "scalemass.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppleGlassStyle.spacingSM)
                    .background(AppleGlassStyle.accent, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
            }
            .buttonStyle(.plain)
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    /// 体重变化颜色：下降=绿（减脂趋势），上升=橙，持平=默认
    private func weightChangeColor(first: Double, last: Double) -> Color {
        let diff = last - first
        if diff < -0.1 { return .green }
        if diff > 0.1 { return .orange }
        return AppleGlassStyle.textSecondary
    }

    /// 体重记录短日期格式化（如 8/2）
    private func weightShortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }

    // MARK: - 更新体重输入弹窗
    // 【本次更新】点击「更新体重」弹出：TextField 填写数值 → 确认写入历史 + 同步身体数据
    private var weightUpdateSheet: some View {
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

            VStack(spacing: AppleGlassStyle.spacingSM) {
                Text("更新体重")
                    .font(.headline)
                    .foregroundColor(AppleGlassStyle.textPrimary)

                // 体重输入框：数字键盘，带单位提示
                HStack(spacing: AppleGlassStyle.spacingXS) {
                    TextField("请输入体重", text: $weightInputText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text("kg")
                        .font(.subheadline)
                        .foregroundColor(AppleGlassStyle.textTertiary)
                }
                .padding(.vertical, AppleGlassStyle.spacingSM)
                .background(Color(.systemFill).opacity(0.25), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
                .padding(.horizontal, AppleGlassStyle.spacingMD)

                Text("记录后将同步更新身体数据中的体重，BMI 等指标随之刷新")
                    .font(.caption2)
                    .foregroundColor(AppleGlassStyle.textTertiary)

                Divider()
                    .padding(.horizontal, -AppleGlassStyle.spacingSM)

                HStack(spacing: 0) {
                    // 取消：关闭弹窗，不写入
                    Button {
                        showWeightUpdate = false
                    } label: {
                        Text("取消")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(AppleGlassStyle.textSecondary)

                    Rectangle()
                        .fill(AppleGlassStyle.textTertiary)
                        .frame(width: 0.5, height: 24)

                    // 确认：解析输入 → 追加历史 + 同步身体数据（含有效性校验）
                    Button {
                        confirmWeightUpdate()
                    } label: {
                        Text("确认")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(AppleGlassStyle.accent)
                }
                .padding(.top, AppleGlassStyle.spacingXS)
            }
            .padding(AppleGlassStyle.spacingSM)
            .background(AppleGlassStyle.standard)
            .clipShape(RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
        }
        .padding(.horizontal, AppleGlassStyle.spacingMD)
        .padding(.vertical, AppleGlassStyle.spacingMD)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppleGlassStyle.groupedBackground)
        .presentationDetents([.height(280)])
    }

    /// 确认更新体重：解析输入 → 范围校验（20-300kg 合理区间）→ 写入历史 + 同步身体数据 → 刷新图表
    private func confirmWeightUpdate() {
        // 解析输入文本为数值，支持中文逗号容错
        guard let parsed = Double(weightInputText.replacingOccurrences(of: "，", with: ".")),
              (20...300).contains(parsed) else {
            // 非法输入：关闭弹窗，保持原值（不阻塞用户）
            showWeightUpdate = false
            return
        }
        // 写入本地体重历史
        WeightHistoryStore.add(weightKg: parsed)
        weightHistory = WeightHistoryStore.load()
        // 同步更新身体数据体重并保存（本地 + 云端），BMI/BMR 等指标联动刷新
        bodyData.weightKg = parsed
        let model = bodyData
        BodyDataRepository.saveAndSync(model)
        // 关闭弹窗
        showWeightUpdate = false
    }

    // MARK: - 加载体重历史（onAppear 调用）
    // 【本次更新】进入页面时读取本地体重历史；
    // 若从未记录过且当前有有效体重，则自动补一条作为基线，保证图表可用
    private func loadWeightHistory() {
        var records = WeightHistoryStore.load()
        if records.isEmpty && bodyData.weightKg > 0 {
            WeightHistoryStore.add(weightKg: bodyData.weightKg)
            records = WeightHistoryStore.load()
        }
        weightHistory = records
    }

    // MARK: - 【本次更新｜深色模式】外观设置区块
    // 深色模式开关：开=深色，关=浅色；默认浅色（FitQuantApp 全局联动）
    private var appearanceSection: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            HStack {
                Text("外观").font(.headline).foregroundStyle(AppleGlassStyle.textPrimary)
                Spacer()
            }
            complianceToggleRow(
                label: "深色模式",
                description: "开启后使用深色外观，关闭后使用浅色外观",
                isOn: $darkModeEnabled,
                systemImage: "moon.fill"
            )
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    // MARK: - Compliance Section
    private var complianceSection: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            HStack {
                Text("合规与隐私").font(.headline).foregroundStyle(AppleGlassStyle.textPrimary)
                Spacer()
            }
            complianceToggleRow(label: "本地法律合规确认", description: "确认已了解并遵守所在地区的相关法律法规", isOn: $agreedLocalLaw, systemImage: "building.columns.fill")
            Divider()
            complianceToggleRow(label: "Apple 政策确认", description: "确认已阅读并同意 Apple 开发者政策相关条款", isOn: $agreedApplePolicy, systemImage: "apple.logo")
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    private func complianceToggleRow(label: String, description: String, isOn: Binding<Bool>, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage).font(.subheadline).foregroundStyle(AppleGlassStyle.accent).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline.weight(.medium)).foregroundStyle(AppleGlassStyle.textPrimary)
                Text(description).font(.caption2).foregroundStyle(AppleGlassStyle.textTertiary)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(AppleGlassStyle.accent)
        }
    }

    // MARK: - Logout Button
    private var logoutButton: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            Button(role: .destructive) {
                showLogoutConfirmation = true
            } label: {
                Label("退出并重置协议", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppleGlassStyle.spacingMD)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
            }
            // //【用户整改】Explain what logout does.
            ComplianceText(text: "【用户整改】退出后所有协议标记将被重置。下次启动应用时将重新展示合规确认页面。您记录的本地数据不会被删除。")
        }
    }

    // MARK: - Logout Action
    private func performLogout() {
        // //【用户整改】Reset all @AppStorage flags to force re-agreement.
        agreedLocalLaw = false
        agreedApplePolicy = false
        // 【合规整改｜协议版本化】同步清空协议版本号，确保下次启动完整重走「合规→登录」新手流程
        agreedLocalLawVersion = ""
        agreedApplePolicyVersion = ""
        firstOpenFlag = true
        //【新增代码】同步清空登录状态，确保下次启动完整走「协议→登录页」流程
        // 远期云端账号兼容：可在此处追加调用云端登出接口，本地重置逻辑无需改动
        isUserLogined = false
        // 【网络层对接】清除后端登录的用户信息
        LoginUserStorage.clear()
        APIClient.shared.clearToken()
        GlobalViewManager.shared.resetToDefaults()
        // 【方案A】登出后切换账号上下文（userId 已清除）：
        // 内存单例回退到未登录状态（读取原始 key），待新账号登录后重建
        AccountScopedStore.accountDidChange()
    }

    // MARK: - 【注销账号】Delete Account Button
    // 置于页面最底部，红色区块比登出更醒目；点击弹二次确认（不可恢复）
    private var deleteAccountButton: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            Button(role: .destructive) {
                showDeleteAccountConfirmation = true
            } label: {
                Label("注销账号", systemImage: "person.crop.circle.badge.xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppleGlassStyle.spacingMD)
                    .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
            }
            .disabled(isDeletingAccount)
            if isDeletingAccount {
                ProgressView("正在注销...")
                    .font(.caption)
                    .foregroundStyle(AppleGlassStyle.textSecondary)
            }
            ComplianceText(text: "【注销】删除账号后将永久清除云端与本地全部记录（训练/饮食/用药/睡眠/身体数据），此操作无法恢复。")
        }
    }

    // MARK: - 【注销账号】Delete Account Action
    // 流程：调 DELETE /api/auth/user/{user_id} → 成功则清理本地账号数据并重置协议/登录态；
    //       失败则提示错误，本地数据保留可重试。
    private func performDeleteAccount() {
        guard let uid = LoginUserStorage.userId, !uid.isEmpty else {
            // 未登录兜底：直接走本地清理（无云端数据可删）
            finishDeleteAccountLocally()
            return
        }
        isDeletingAccount = true
        Task {
            do {
                let _: DeleteAccountResult = try await APIClient.shared.delete("/api/auth/user/\(uid)")
                await MainActor.run {
                    isDeletingAccount = false
                    finishDeleteAccountLocally()
                }
            } catch let error as APIError {
                await MainActor.run {
                    isDeletingAccount = false
                    if case .businessError(let code, _) = error, code == 1002 {
                        // 账号不存在（如 mock 登录用户）：云端无数据可删，视为注销完成，本地清理
                        finishDeleteAccountLocally()
                    } else {
                        deleteAccountError = error.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    isDeletingAccount = false
                    deleteAccountError = error.localizedDescription
                }
            }
        }
    }

    /// 云端删除成功后：清理本地账号数据 + 重置协议与登录态（复用登出清理逻辑）
    private func finishDeleteAccountLocally() {
        // 1. 清理当前账号全部本地数据（业务 key + legacy + 样例标记，不可恢复）
        AccountScopedStore.removeCurrentAccountData()
        // 2. 重置协议标记，强制重走「合规→登录」流程（与登出一致）
        agreedLocalLaw = false
        agreedApplePolicy = false
        agreedLocalLawVersion = ""
        agreedApplePolicyVersion = ""
        firstOpenFlag = true
        isUserLogined = false
        // 3. 清除登录态与 token
        LoginUserStorage.clear()
        APIClient.shared.clearToken()
        GlobalViewManager.shared.resetToDefaults()
        // 4. 切换账号上下文（userId 已清除，单例回退未登录态）
        AccountScopedStore.accountDidChange()
        print("[MineView] 账号已注销，本地数据已清理")
    }

    // MARK: - 【修复数据读取逻辑】从UserDefaults加载身体数据
    // BodyDataInputView写入完整BodyDataModel序列化数据到"saved_bodyData"key
    // 修改前：bodyData由MainTabContentView用默认值初始化，新用户注册录入无法同步
    // 修改后：onAppear读取UserDefaults，存在写入记录则覆盖binding实现数据同步
    // 【方案A】直读 UserDefaults 收敛为经 BodyDataRepository 读取（自动按当前账号隔离）
    private func loadBodyDataFromStorage() {
        guard let saved = BodyDataRepository.loadOptional() else { return }
        bodyData = saved
    }
}

// MARK: - BodyDataEditSheet
struct BodyDataEditSheet: View {
    @Binding var bodyData: BodyDataModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    HStack {
                        Text("身高 (cm)")
                        Spacer()
                        TextField("", value: $bodyData.heightCm, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    HStack {
                        Text("体重 (kg)")
                        Spacer()
                        TextField("", value: $bodyData.weightKg, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    HStack {
                        Text("年龄")
                        Spacer()
                        TextField("", value: $bodyData.age, format: .number)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    Picker("性别", selection: $bodyData.sex) {
                        ForEach(Sex.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    Picker("活动水平", selection: $bodyData.activityLevel) {
                        ForEach(ActivityLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }

                Section("围度数据") {
                    HStack {
                        Text("胸围 (cm)")
                        Spacer()
                        TextField("", value: $bodyData.chestCm, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    HStack {
                        Text("腰围 (cm)")
                        Spacer()
                        TextField("", value: $bodyData.waistCm, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    HStack {
                        Text("臀围 (cm)")
                        Spacer()
                        TextField("", value: $bodyData.hipCm, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    HStack {
                        Text("颈围 (cm)")
                        Spacer()
                        TextField("", value: $bodyData.neckCm, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    HStack {
                        Text("体脂率 (%)")
                        Spacer()
                        TextField("", value: $bodyData.bodyFatPercent, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                }

                Section {
                    ComplianceText(
                        text: "【合规红线】身体数据仅用于个人健身参考。BMI、体脂率、BMR 等计算结果不构成医疗诊断。如有健康疑虑请咨询专业医师。",
                        showIcon: false
                    )
                }
            }
            .navigationTitle("编辑身体数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        // 【网络层对接】保存到本地 + 同步云端
                        let model = bodyData
                        BodyDataRepository.saveAndSync(model)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - WeightTimelineSheet
// 【体重追踪】减脂历程全屏视图（点击趋势图打开）
// 展示全部体重记录的大图（不截断）+ 完整记录列表（日期/体重/环比变化）
// 【本次更新】records 改为 @Binding：支持长按记录删除/更改，父视图图表实时同步刷新
struct WeightTimelineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var records: [WeightRecord]

    // 【本次更新】长按操作状态：目标记录、编辑输入文本、删除二次确认
    // 【本次更新｜更改记录】编辑弹窗改用 .sheet(item: $editingRecord) 驱动，不再需要 showEditSheet
    @State private var editingRecord: WeightRecord? = nil
    @State private var editWeightText: String = ""
    // 【本次更新｜更改记录】编辑弹窗可修改日期：当前编辑记录的日期选择状态
    @State private var editDate: Date = Date()
    @State private var pendingDelete: WeightRecord? = nil

    // 【本次更新｜历史补录】减脂历程补录入口状态：表单弹窗控制、补录日期、补录体重输入
    @State private var showBackfillSheet: Bool = false
    @State private var backfillDate: Date = Date()
    @State private var backfillWeightText: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppleGlassStyle.spacingMD) {
                    // 【本次更新｜历史补录】补录历史体重入口卡片（支持早期开始减脂的用户填写往日数据）
                    backfillEntryCard

                    // 全部记录的大趋势图（不截断，一次看完整减脂历程）
                    if records.count >= 1 {
                        WeightTrendChart(records: records)
                            .frame(height: 260)
                            .padding(AppleGlassStyle.spacingSM)
                            .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
                    }

                    // 减脂历程统计摘要
                    if let first = records.first, let last = records.last {
                        HStack(spacing: AppleGlassStyle.spacingMD) {
                            timelineStat(label: "起始体重", value: String(format: "%.1f kg", first.weightKg))
                            timelineStat(label: "当前体重", value: String(format: "%.1f kg", last.weightKg))
                            timelineStat(
                                label: "累计变化",
                                value: String(format: "%@%.1f kg", last.weightKg - first.weightKg > 0 ? "+" : "", last.weightKg - first.weightKg),
                                color: last.weightKg - first.weightKg <= 0 ? .green : .orange
                            )
                        }
                    }

                    // 【本次更新】每周减脂速度分析报告（以循证研究报告为基础）
                    // 计算最近 7 天体重变化换算周减重速度，按健康区间分级提示，
                    // 快/慢/正常三态分别给出文案 + 论文引用 + 合规声明（仅参考，非诊疗建议）
                    weeklyFatLossReport

                    // 完整记录列表（日期/体重/环比变化）
                    VStack(alignment: .leading, spacing: AppleGlassStyle.spacingXS) {
                        Text("全部记录（\(records.count) 条）")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppleGlassStyle.textPrimary)

                        ForEach(Array(records.enumerated()), id: \.offset) { idx, record in
                            HStack {
                                Text(timelineDate(record.date))
                                    .font(.subheadline)
                                    .foregroundStyle(AppleGlassStyle.textSecondary)
                                Spacer()
                                Text(String(format: "%.1f kg", record.weightKg))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppleGlassStyle.textPrimary)
                                // 环比变化（第一条无对比）
                                if idx > 0 {
                                    let prev = records[idx - 1].weightKg
                                    let diff = record.weightKg - prev
                                    Text(diff == 0 ? "持平" : String(format: "%@%.1f", diff > 0 ? "+" : "", diff))
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(diff <= 0 ? .green : .orange)
                                        .frame(width: 60, alignment: .trailing)
                                } else {
                                    Text("起点")
                                        .font(.caption2)
                                        .foregroundStyle(AppleGlassStyle.textTertiary)
                                        .frame(width: 60, alignment: .trailing)
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, AppleGlassStyle.spacingSM)
                            .background(AppleGlassStyle.ultraThin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
                            // 【本次更新】长按记录弹出操作菜单：更改 / 删除（防止录入错误无法修改）
                            .contextMenu {
                                Button {
                                    editingRecord = record
                                    editWeightText = String(format: "%.1f", record.weightKg)
                                    // 【本次更新｜更改记录】初始化编辑日期为原记录日期
                                    editDate = record.date
                                } label: {
                                    Label("更改此记录", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    pendingDelete = record
                                } label: {
                                    Label("删除此记录", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(AppleGlassStyle.spacingMD)
            }
            .background(AppleGlassStyle.groupedBackground)
            .navigationTitle("减脂历程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            // 【本次更新｜更改记录】长按「更改」弹出的记录编辑弹窗
            // 改用 .sheet(item:) 绑定：SwiftUI 保证 editingRecord 非 nil 时才呈现，
            // 彻底避免 .sheet(isPresented:) + if let 在 contextMenu 触发时捕获旧值 nil 导致的空白窗口
            .sheet(item: $editingRecord) { record in
                recordEditSheet(record)
            }
            // 【本次更新】长按「删除」弹出的二次确认弹窗
            .alert("删除这条体重记录？", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )) {
                Button("删除", role: .destructive) { confirmDeleteRecord() }
                Button("取消", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("删除后该数据点将从趋势图与周报中移除，此操作不可撤销。")
            }
        }
    }

    // MARK: - 【本次更新｜历史补录】补录历史体重入口卡片
    // 支持早期开始减脂的用户填写往日体重数据：指定日期 + 体重，
    // 补录后只要有 ≥1 周（7 天）时间跨度的数据即自动生成减脂速度分析报告。
    private var backfillEntryCard: some View {
        Button {
            backfillDate = Date()
            backfillWeightText = ""
            showBackfillSheet = true
        } label: {
            HStack(spacing: AppleGlassStyle.spacingSM) {
                Image(systemName: "calendar.badge.plus")
                    .font(.title3)
                    .foregroundStyle(AppleGlassStyle.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("补录历史体重")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppleGlassStyle.textPrimary)
                    Text("填写往日体重数据（日期 + 体重），已有超过一周的数据即可生成减脂速度分析报告，无需从零开始累积")
                        .font(.caption2)
                        .foregroundStyle(AppleGlassStyle.textTertiary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppleGlassStyle.textTertiary)
            }
            .padding(AppleGlassStyle.spacingMD)
            .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
        }
        .buttonStyle(.plain)
        // 【本次更新｜历史补录】补录表单弹窗：日期选择 + 体重输入
        .sheet(isPresented: $showBackfillSheet) {
            backfillSheet
        }
    }

    // 【本次更新｜历史补录】补录表单弹窗内容
    private var backfillSheet: some View {
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

            VStack(spacing: AppleGlassStyle.spacingSM) {
                Text("补录历史体重")
                    .font(.headline)
                    .foregroundColor(AppleGlassStyle.textPrimary)

                // 日期选择器（年月日）
                DatePicker(
                    "记录日期",
                    selection: $backfillDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .font(.subheadline)
                .foregroundColor(AppleGlassStyle.textPrimary)
                .padding(.horizontal, AppleGlassStyle.spacingMD)

                // 体重输入框
                HStack(spacing: AppleGlassStyle.spacingXS) {
                    TextField("体重", text: $backfillWeightText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text("kg")
                        .font(.subheadline)
                        .foregroundColor(AppleGlassStyle.textTertiary)
                }
                .padding(.vertical, AppleGlassStyle.spacingSM)
                .background(Color(.systemFill).opacity(0.25), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
                .padding(.horizontal, AppleGlassStyle.spacingMD)

                // 提示：同一天多条记录会各自独立保留
                Text("提示：同一日期可补录多条记录，将各自独立保留在趋势图中；补录后可长按记录修改或删除。")
                    .font(.caption2)
                    .foregroundColor(AppleGlassStyle.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppleGlassStyle.spacingMD)

                // 保存 / 取消
                HStack(spacing: AppleGlassStyle.spacingMD) {
                    Button("取消") { showBackfillSheet = false }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppleGlassStyle.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppleGlassStyle.spacingSM)
                        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))

                    Button("保存") { confirmBackfill() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppleGlassStyle.spacingSM)
                        .background(
                            RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium)
                                .fill(validBackfill ? AppleGlassStyle.accent : AppleGlassStyle.accent.opacity(0.4))
                        )
                        .disabled(!validBackfill)
                }
                .padding(.horizontal, AppleGlassStyle.spacingMD)
            }
            .padding(.vertical, AppleGlassStyle.spacingMD)
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(true)
    }

    /// 补录输入合法性：体重为有效正数（与体重更新一致 20-300kg 校验）
    private var validBackfill: Bool {
        guard let w = Double(backfillWeightText.replacingOccurrences(of: "，", with: ".")) else { return false }
        return w >= 20 && w <= 300
    }

    /// 【本次更新｜历史补录】确认补录：写入指定日期体重 → 刷新记录列表 → 关闭表单
    private func confirmBackfill() {
        guard let w = Double(backfillWeightText.replacingOccurrences(of: "，", with: ".")) else { return }
        WeightHistoryStore.add(weightKg: w, at: backfillDate)
        records = WeightHistoryStore.load()
        showBackfillSheet = false
    }

    /// 统计卡片（起始/当前/累计变化）
    private func timelineStat(label: String, value: String, color: Color = AppleGlassStyle.textPrimary) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppleGlassStyle.textTertiary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppleGlassStyle.spacingSM)
        .background(AppleGlassStyle.ultraThin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
    }

    // MARK: - 【本次更新】记录编辑弹窗（长按「更改此记录」打开）
    // 支持修改体重值与日期；确认后调用 WeightHistoryStore.update 持久化并刷新绑定
    private func recordEditSheet(_ record: WeightRecord) -> some View {
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

            VStack(spacing: AppleGlassStyle.spacingSM) {
                Text("更改体重记录")
                    .font(.headline)
                    .foregroundColor(AppleGlassStyle.textPrimary)

                // 体重输入框
                HStack(spacing: AppleGlassStyle.spacingXS) {
                    TextField("体重", text: $editWeightText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text("kg")
                        .font(.subheadline)
                        .foregroundColor(AppleGlassStyle.textTertiary)
                }
                .padding(.vertical, AppleGlassStyle.spacingSM)
                .background(Color(.systemFill).opacity(0.25), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
                .padding(.horizontal, AppleGlassStyle.spacingMD)

                // 【本次更新｜更改记录】可修改记录日期（DatePicker 年月日，不可选未来）
                DatePicker(
                    "记录日期",
                    selection: $editDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .font(.subheadline)
                .foregroundColor(AppleGlassStyle.textPrimary)
                .padding(.horizontal, AppleGlassStyle.spacingMD)

                Divider()
                    .padding(.horizontal, -AppleGlassStyle.spacingSM)

                HStack(spacing: 0) {
                    Button {
                        editingRecord = nil
                    } label: {
                        Text("取消").fontWeight(.medium).frame(maxWidth: .infinity)
                    }
                    .foregroundColor(AppleGlassStyle.textSecondary)

                    Rectangle().fill(AppleGlassStyle.textTertiary).frame(width: 0.5, height: 24)

                    Button {
                        confirmUpdateRecord()
                    } label: {
                        Text("保存").fontWeight(.semibold).frame(maxWidth: .infinity)
                    }
                    .foregroundColor(AppleGlassStyle.accent)
                }
                .padding(.top, AppleGlassStyle.spacingXS)
            }
            .padding(AppleGlassStyle.spacingSM)
            .background(AppleGlassStyle.standard)
            .clipShape(RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
        }
        .padding(.horizontal, AppleGlassStyle.spacingMD)
        .padding(.vertical, AppleGlassStyle.spacingMD)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppleGlassStyle.groupedBackground)
        // 【本次更新｜更改记录】弹窗高度由固定 height(300) 改为 medium，避免内容被裁切显示为空卡片
        .presentationDetents([.medium])
    }

    // MARK: - 【本次更新】删除确认处理
    // 从本地存储删除目标记录，并同步刷新绑定数据（图表/周报实时更新）
    private func confirmDeleteRecord() {
        guard let record = pendingDelete else { return }
        WeightHistoryStore.delete(id: record.id)
        records = WeightHistoryStore.load()
        pendingDelete = nil
    }

    // MARK: - 【本次更新】更新确认处理
    // 解析输入体重（20-300kg 合理区间）→ 更新本地存储（体重 + 日期）→ 刷新绑定数据 → 关闭弹窗
    private func confirmUpdateRecord() {
        guard let record = editingRecord else { return }
        // 解析输入文本，支持中文逗号容错；非法/越界输入忽略并关闭
        guard let parsed = Double(editWeightText.replacingOccurrences(of: "，", with: ".")),
              (20...300).contains(parsed) else {
            editingRecord = nil
            return
        }
        // 【本次更新｜更改记录】日期一并更新（editDate 由 DatePicker 绑定）
        WeightHistoryStore.update(id: record.id, weightKg: parsed, date: editDate)
        records = WeightHistoryStore.load()
        editingRecord = nil
    }

    // MARK: - 【本次更新】减脂速度分析报告
    // 以《健康减脂速度评估研究报告》为基础：健康区间 0.5-1 kg/周，
    // >1.5 kg/周 过快、1-1.5 kg/周 偏快、<0.5 kg/周（含上升）过慢，
    // 数据不足时提示继续记录或补录。所有文案含合规声明，仅作健身参考。
    private var weeklyFatLossReport: some View {
        let assessment = weeklyFatLossAssessment
        return VStack(alignment: .leading, spacing: AppleGlassStyle.spacingSM) {
            // 标题行：报告标题 + 状态徽标
            HStack {
                Text("减脂速度分析")
                    .font(.headline)
                    .foregroundStyle(AppleGlassStyle.textPrimary)
                Spacer()
                Text(assessment.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(assessment.color, in: RoundedRectangle(cornerRadius: 8))
            }

            // 周减重速度数值
            HStack(alignment: .firstTextBaseline) {
                Text(assessment.rateText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(assessment.color)
                Text("kg/周")
                    .font(.subheadline)
                    .foregroundStyle(AppleGlassStyle.textTertiary)
                Spacer()
                Text(assessment.daysCoveredText)
                    .font(.caption2)
                    .foregroundStyle(AppleGlassStyle.textTertiary)
            }

            // 状态分析正文（快/慢/正常三态文案）
            Text(assessment.body)
                .font(.subheadline)
                .foregroundStyle(AppleGlassStyle.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // 论文引用（仅过快要害提示时展示，标注来源）
            if let citation = assessment.citation {
                VStack(alignment: .leading, spacing: 4) {
                    Text("循证依据")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppleGlassStyle.textTertiary)
                    Text(citation)
                        .font(.caption2)
                        .foregroundStyle(AppleGlassStyle.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppleGlassStyle.ultraThin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
            }

            // 合规声明（常驻，任何情况都展示）
            ComplianceText(
                text: "【合规声明】本分析基于公开文献的统计参考，仅作健身记录参考，不构成任何医疗诊疗意见，不能替代执业医师或注册营养师的当面建议。数据受称量时间、水分、设备误差等影响，单次波动请勿过度解读。",
                showIcon: true
            )
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium)
                .fill(assessment.color.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium)
                .stroke(assessment.color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 每周减脂速度评估模型
    // 【本次更新｜历史补录】评估范围由"最近 7 天"改为"首尾记录整体跨度"：
    // 只要有 ≥1 周（7 天）时间跨度即生成分析报告，支持补录往日数据后立即评估整体减脂健康问题。
    // 阈值依据研究报告：健康 0.5-1 kg/周（CDC/中国指南）；>1.5 kg/周 过快（肌肉流失风险）；
    // <0.5 kg/周 或上升 → 过慢（可能训练懈怠或热量缺口不足）
    private var weeklyFatLossAssessment: (title: String, color: Color, rateText: String, daysCoveredText: String, body: String, citation: String?) {
        // 数据不足判定：少于 2 条记录或首尾时间跨度不足 7 天
        guard records.count >= 2,
              let first = records.first, let last = records.last,
              let days = Calendar.current.dateComponents([.day], from: first.date, to: last.date).day,
              days >= 7 else {
            return (
                title: "数据积累中",
                color: AppleGlassStyle.textTertiary,
                rateText: "—",
                daysCoveredText: "暂无足够数据",
                body: "记录或补录体重后将生成减脂速度分析。当前数据点或时间跨度不足，请继续定期更新体重（按天或每周固定一天记录均可），或通过「补录历史体重」填写往日数据；任意两次记录的间隔超过一周即可生成分析报告。",
                citation: nil
            )
        }

        // 周减重速度 = 总变化(kg) / 天数 × 7（负值=减重），基于首尾整体评估
        // 【本次更新｜按周记录】支持"每周固定一天输入一次"场景（如上周六 98kg → 本周六 97.4kg）：
        // 任意两条记录首尾跨度 ≥7 天即按总变化折算周速度，无需逐日记录。
        let weekRate = (last.weightKg - first.weightKg) / Double(days) * 7.0
        let rateText = String(format: "%.2f", abs(weekRate))
        let directionText = weekRate < 0 ? "减重" : (weekRate > 0 ? "增重" : "持平")
        let covered = "覆盖 \(days) 天 · \(directionText)"

        // 分级判定（注意：weekRate 负值代表减重）
        if weekRate <= -1.5 {
            // 过快：>1.5 kg/周
            return (
                title: "速度过快",
                color: .red,
                rateText: rateText,
                daysCoveredText: covered,
                body: "整体减脂速度可能过快（>1.5 kg/周）。研究报告指出，快速减重相较渐进减重会损失更多去脂体重（肌肉）并更难保留静息代谢率，去脂体重损失比例与后续体重反弹风险正相关。建议适度放宽热量缺口、保证蛋白质摄入并坚持力量训练，以保护肌肉。",
                citation: "依据：Ashtary-Larky et al., Br J Nutr 2020（快速 vs 渐进减重 Meta 分析）；Vink et al., Obesity 2016（去脂体重损失与反弹正相关 r=0.325）。"
            )
        } else if weekRate <= -1.0 {
            // 偏快：1-1.5 kg/周
            return (
                title: "略偏快",
                color: .orange,
                rateText: rateText,
                daysCoveredText: covered,
                body: "整体减脂速度接近快速减重区间（1-1.5 kg/周），处于健康上限边缘。建议关注训练与饮食是否过于激进，适当放缓有助于保留肌肉与代谢水平。",
                citation: "依据：Ashtary-Larky et al., Br J Nutr 2020（渐进减重更利于保留 RMR）。"
            )
        } else if weekRate <= -0.5 {
            // 正常：0.5-1 kg/周
            return (
                title: "速度健康",
                color: .green,
                rateText: rateText,
                daysCoveredText: covered,
                body: "整体减脂速度处于健康区间（0.5-1 kg/周），与主流指南推荐一致。研究表明该速度下脂肪供能占比更高、肌肉与代谢保留更好，请继续保持当前的训练与饮食节奏，稳步推进。",
                citation: nil
            )
        } else {
            // 过慢：<0.5 kg/周 或体重上升
            return (
                title: weekRate > 0 ? "体重回升" : "速度偏慢",
                color: .orange,
                rateText: rateText,
                daysCoveredText: covered,
                body: weekRate > 0
                    ? "整体体重较上一记录日有所回升。可能原因：训练强度有所懈怠、热量缺口未实际达成、或水分/进食状态波动。建议回顾近一周饮食记录与训练安排，确认缺口是否真实存在，同时无需因单周波动过度焦虑。"
                    : "整体减脂速度偏慢（<0.5 kg/周）。可能原因：训练强度有所懈怠，或热量缺口创造过低。建议适当提高有氧/力量训练强度，或微调饮食缺口（每日 500-600 kcal 温和区间内），并持续观察 1-2 周趋势。",
                citation: nil
            )
        }
    }

    /// 记录日期格式化（如 2026/8/2）
    private func timelineDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/M/d HH:mm"
        return f.string(from: date)
    }
}

// MARK: - WeightTrendChart
// 【体重追踪】体重趋势线性图（SwiftUI 原生绘制，零第三方依赖）
// 输入：体重记录数组（按日期升序）；图表展示折线 + 数据点 + 首尾数值标签
struct WeightTrendChart: View {
    let records: [WeightRecord]

    var body: some View {
        GeometryReader { geo in
            let points = normalizedPoints(in: geo.size)
            ZStack {
                // 折线
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(AppleGlassStyle.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                // 数据点
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(AppleGlassStyle.accent)
                        .frame(width: 8, height: 8)
                        .position(point)
                }

                // 首尾数值标签（单条记录时仅显示一个居中标签，避免重叠）
                if let first = points.first, let firstRecord = records.first {
                    if records.count > 1, let last = points.last, let lastRecord = records.last {
                        Text(String(format: "%.1f", firstRecord.weightKg))
                            .font(.caption2)
                            .foregroundStyle(AppleGlassStyle.textSecondary)
                            .position(x: first.x, y: max(first.y - 16, 8))
                        Text(String(format: "%.1f", lastRecord.weightKg))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppleGlassStyle.accent)
                            .position(x: last.x, y: max(last.y - 16, 8))
                    } else {
                        Text(String(format: "%.1f kg", firstRecord.weightKg))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppleGlassStyle.accent)
                            .position(x: first.x, y: max(first.y - 16, 8))
                    }
                }
            }
        }
    }

    /// 将记录归一化为图表坐标点（x 按索引均分，y 按体重范围映射）
    /// 【本次更新】坐标语义：
    /// - x 轴：按记录顺序从左到右排列，第一个点在最左，每次更新往右追加新点
    /// - y 轴：体重越低点越靠下、越高点越靠上（体重范围数据驱动）
    /// - 单条记录时：点默认显示在左上角区域（作为趋势起点锚点）
    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard !records.isEmpty else { return [] }
        let weights = records.map { $0.weightKg }
        guard let minW = weights.min(), let maxW = weights.max() else { return [] }
        let range = max(maxW - minW, 1.0) // 防止除零；体重全相同则平铺
        // 上下留白，避免数值贴边
        let topPad: CGFloat = 22
        let bottomPad: CGFloat = 10
        let plotHeight = size.height - topPad - bottomPad
        return records.enumerated().map { idx, record in
            // 单条记录：x 偏左（左上角起点锚点）；多条记录：x 按索引从左到右均分
            let x: CGFloat = records.count == 1 ? 14 : size.width * CGFloat(idx) / CGFloat(records.count - 1)
            // y：体重越小 normalized 越小 → 点越靠下（坐标 y 增大方向向下）
            let normalized = (record.weightKg - minW) / range
            let y = topPad + plotHeight * CGFloat(1 - normalized)
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var bodyData = BodyDataModel()
    MineView(bodyData: $bodyData)
}
