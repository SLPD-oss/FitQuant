import SwiftUI

// MARK: - SleepRecoveryView
// 「Apple Watch 睡眠恢复监测 + 智能训练适配」前端模块
// 【合规红线】本模块定位为健身恢复参考工具，非医疗诊断工具。
// 【合规红线】全程展示「自研恢复评分」，禁止展示/宣称苹果官方睡眠评分。
// 【数据来源】展示字段来自后端 sleep_records 表（Apple HealthKit 同步）；
// 恢复评分 / 连续低分天数 / 训练建议由后端 sleep_score 算法计算，前端仅渲染。
// 降级链：后端 → 本地缓存 → 演示覆盖场景（见场景切换器）。

// MARK: - 睡眠恢复状态枚举（前端固定三套状态 UI）
/// 三套状态：绿色恢复良好 / 黄色轻度恢复不足 / 红色恢复严重不足；另有无数据降级态。
enum SleepRecoveryStatus {
    case good           // 绿色 80-100 分：恢复良好
    case mildDeficit    // 黄色 60-79 分：轻度恢复不足
    case severeDeficit  // 红色 0-59 分：恢复严重不足
    case noData         // 无数据 / 未授权：优雅降级

    /// 由自研 0-100 分映射到状态（分级逻辑集中在此，视图层只做渲染）
    static func from(score: Int) -> SleepRecoveryStatus {
        if score >= 80 { return .good }
        if score >= 60 { return .mildDeficit }
        return .severeDeficit
    }

    /// 状态主题色（绿 / 黄 / 红）
    var color: Color {
        switch self {
        case .good:          return .green
        case .mildDeficit:   return .orange
        case .severeDeficit: return .red
        case .noData:        return .gray
        }
    }

    /// 状态图标
    var icon: String {
        switch self {
        case .good:          return "checkmark.circle.fill"
        case .mildDeficit:   return "exclamationmark.circle.fill"
        case .severeDeficit: return "xmark.circle.fill"
        case .noData:        return "watch.slash"
        }
    }

    /// 状态标题（演示/页面顶部展示用）
    var title: String {
        switch self {
        case .good:          return "恢复良好"
        case .mildDeficit:   return "轻度恢复不足"
        case .severeDeficit: return "恢复严重不足"
        case .noData:        return "暂无睡眠数据"
        }
    }

    /// 三套状态固定文案（需求原文，一字未改）
    var message: String {
        switch self {
        case .good:
            return "睡眠与身体恢复状态优秀，可正常执行原定力量、有氧训练计划"
        case .mildDeficit:
            return "睡眠结构一般、自主神经活跃度偏低，建议今日适当下调训练重量与组数，降低高强度训练占比"
        case .severeDeficit:
            return "睡眠碎片化偏高、身体应激状态较高（关联皮质醇偏高趋势），不建议进行力量训练、高强度有氧"
        case .noData:
            return "未获取到 Watch 睡眠数据，请授权健康权限并佩戴设备过夜监测"
        }
    }
}

// MARK: - 睡眠恢复数据模型（后端 SleepLatestResponse 映射）
/// 数据来源说明：展示字段来自后端 sleep_records 表（Apple HealthKit 同步），
/// 恢复评分与连续低分天数由后端自研算法计算；本文件仅负责渲染，不生成业务数据。
/// 模型定义见 Services/SleepService.swift（SleepRecoveryData）。

// MARK: - 场景枚举（实时数据 + 概念演示覆盖场景）
/// 默认「实时数据」：展示后端返回的真实睡眠数据；
/// 其余场景为概念演示覆盖（恢复良好 / 轻度不足 / 严重不足 / 无数据），
/// 用于离线环境或演示三套状态与空状态闭环。
enum SleepRecoveryMockScenario: String, CaseIterable, Identifiable {
    case auto     = "实时数据"
    case good     = "恢复良好"
    case mild     = "轻度不足"
    case severe   = "严重不足"
    case noData   = "无数据"

    var id: String { rawValue }

    /// 各演示场景对应的模拟数据；auto / noData 场景返回 nil（auto 走实时数据，noData 触发空状态降级）
    var mockData: SleepRecoveryData? {
        switch self {
        case .auto, .noData:
            return nil
        case .good:
            // 绿色场景：总时长 7.8h，深睡 1.6h，评分 86 分，HRV 正常
            return SleepRecoveryData(
                sleepDate: "",
                totalSleepHours: 7.8,
                coreSleepHours: 4.2,
                deepSleepHours: 1.6,
                remSleepHours: 1.5,
                awakeHours: 0.5,
                restingHeartRate: 52,
                avgHRV: 68,
                recoveryScore: 86,
                consecutiveLowScoreDays: 0,
                recoveryStatusRaw: "good",
                suggestionTitle: nil,
                suggestionMessage: nil
            )
        case .mild:
            // 黄色场景：总时长 6.2h，深睡 0.9h，评分 70 分，HRV 偏低
            return SleepRecoveryData(
                sleepDate: "",
                totalSleepHours: 6.2,
                coreSleepHours: 3.6,
                deepSleepHours: 0.9,
                remSleepHours: 1.1,
                awakeHours: 0.6,
                restingHeartRate: 58,
                avgHRV: 45,
                recoveryScore: 70,
                consecutiveLowScoreDays: 1,
                recoveryStatusRaw: "mild",
                suggestionTitle: nil,
                suggestionMessage: nil
            )
        case .severe:
            // 红色场景：总时长 4.8h，深睡仅 0.5h，评分 45 分，HRV 明显偏低，连续 3 晚低分
            return SleepRecoveryData(
                sleepDate: "",
                totalSleepHours: 4.8,
                coreSleepHours: 3.0,
                deepSleepHours: 0.5,
                remSleepHours: 0.7,
                awakeHours: 0.6,
                restingHeartRate: 64,
                avgHRV: 32,
                recoveryScore: 45,
                consecutiveLowScoreDays: 3,
                recoveryStatusRaw: "severe",
                suggestionTitle: nil,
                suggestionMessage: nil
            )
        }
    }
}

// MARK: - 主视图：睡眠恢复监测 + 智能训练适配
struct SleepRecoveryView: View {
    // 数据源场景：默认「实时数据」从后端拉取；其余为概念演示覆盖场景
    @State private var selectedScenario: SleepRecoveryMockScenario = .auto
    // 【后端接入】从后端拉取的最新一夜睡眠数据（网络失败时回退本地缓存）
    @State private var loadedData: SleepRecoveryData? = nil
    // 智能建议弹窗控制
    @State private var showSuggestion: Bool = false
    // 「采纳建议」后的反馈提示控制
    @State private var showAdoptedTip: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppleGlassStyle.spacingMD) {
                    // 无数据 / 未授权：优雅降级空状态（无报错、无崩溃）
                    if currentData == nil {
                        noDataPlaceholder
                    } else {
                        scoreOverviewCard        // 恢复评分总览卡（分数 + 星级 + 状态）
                        sleepDataCard            // 睡眠时长数据卡（总时长 + 四阶段）
                        sleepStageRatioCard      // 睡眠结构占比可视化（分段比例条 + 图例）
                        heartVitalCard           // 晨起静息心率 + 夜间平均 HRV 卡
                        suggestionButton         // 智能建议入口按钮
                    }
                    scenarioPicker              // 数据源场景切换（实时数据 + 概念演示覆盖）
                    fixedDisclaimerSection      // 常驻免责声明模块（固定五条文案，一字不变）
                }
                .padding(AppleGlassStyle.spacingMD)
            }
            .background(AppleGlassStyle.groupedBackground)
            .navigationTitle("睡眠恢复")
            .navigationBarTitleDisplayMode(.inline)
            // 【后端接入】进入页面时拉取最新一夜睡眠数据
            .task {
                await loadFromAPI()
            }
            // 智能建议弹窗：双按钮常驻，不锁死用户训练
            .sheet(isPresented: $showSuggestion) {
                if let data = currentData {
                    SleepRecoverySuggestionSheet(
                        data: data,
                        status: SleepRecoveryStatus.from(score: data.recoveryScore),
                        onAdopt: {
                            // 【采纳建议，调整今日训练】点击后关闭弹窗并展示调整反馈
                            showAdoptedTip = true
                        },
                        onIgnore: { /* 【忽略建议，执行原定计划】仅关闭弹窗，不拦截训练 */ }
                    )
                }
            }
            // 采纳建议后的轻量反馈（概念 Demo：提示今日训练已按恢复建议调整）
            .alert("今日训练已按恢复建议调整", isPresented: $showAdoptedTip) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text("您可随时在训练页继续按原计划执行，本建议仅为健身辅助参考。")
            }
        }
    }

    // MARK: - 当前场景数据
    /// 「实时数据」场景返回后端数据；其余场景返回演示覆盖数据；无数据场景返回 nil 触发降级
    private var currentData: SleepRecoveryData? {
        if selectedScenario == .auto { return loadedData }
        return selectedScenario.mockData
    }

    // MARK: - 从后端拉取最新一夜睡眠数据
    /// 降级链：后端 → 本地缓存 → nil（前端空状态）
    private func loadFromAPI() async {
        let data = await SleepService.shared.fetchLatest(userId: LoginUserStorage.userId ?? "")
        await MainActor.run {
            loadedData = data
            if data == nil { selectedScenario = .noData }
        }
    }

    // MARK: - 无数据 / 未授权空状态（优雅降级）
    private var noDataPlaceholder: some View {
        VStack(spacing: AppleGlassStyle.spacingMD) {
            // 空状态图标：手表 + 斜杠，表达「未获取到 Watch 数据」
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 88, height: 88)
                Image(systemName: "watch.slash")
                    .font(.system(size: 36))
                    .foregroundStyle(AppleGlassStyle.textTertiary)
            }
            .padding(.top, AppleGlassStyle.spacingLG)

            Text("未获取到 Watch 睡眠数据")
                .font(.headline)
                .foregroundStyle(AppleGlassStyle.textPrimary)

            Text("请授权健康权限并佩戴设备过夜监测")
                .font(.subheadline)
                .foregroundStyle(AppleGlassStyle.textSecondary)

            // 空状态下的参考引导文案（仅作展示说明，不构成诊断）
            ComplianceText(text: "睡眠监测数据依赖 Apple Watch 传感器采集，未授权或未佩戴时无法生成恢复评分。")
        }
        .padding(.vertical, AppleGlassStyle.spacingLG)
    }

    // MARK: - 恢复评分总览卡（分数 + 星级 + 状态文案）
    private var scoreOverviewCard: some View {
        let data = currentData ?? SleepRecoveryMockScenario.good.mockData!
        let status = SleepRecoveryStatus.from(score: data.recoveryScore)
        return VStack(spacing: AppleGlassStyle.spacingSM) {
            // 状态图标 + 状态标题
            HStack(spacing: AppleGlassStyle.spacingXS) {
                Image(systemName: status.icon)
                    .foregroundStyle(status.color)
                Text(status.title)
                    .font(.headline)
                    .foregroundStyle(status.color)
                Spacer()
                // 自研评分标签：明确「自研」，禁止宣称苹果官方评分
                Text("自研恢复评分")
                    .font(.caption2)
                    .foregroundStyle(AppleGlassStyle.textTertiary)
                    .padding(.horizontal, AppleGlassStyle.spacingXS)
                    .padding(.vertical, 3)
                    .background(AppleGlassStyle.ultraThin, in: RoundedRectangle(cornerRadius: 6))
            }

            // 恢复评分大数字
            Text("\(data.recoveryScore)")
                .font(.system(size: 68, weight: .heavy, design: .rounded))
                .foregroundStyle(status.color)
                .fontWidth(.compressed)
                .monospacedDigit()

            // 星级展示：0-100 分映射到 0-5 星（每 20 分一星）
            HStack(spacing: 5) {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= starCount(for: data.recoveryScore) ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(index <= starCount(for: data.recoveryScore) ? status.color : AppleGlassStyle.textTertiary)
                }
            }

            // 三套状态固定文案（需求原文）
            Text(status.message)
                .font(.subheadline)
                .foregroundStyle(AppleGlassStyle.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppleGlassStyle.spacingXS)

            // 连续低分提示：仅「连续低分」才提示重度休息建议（前端文案逻辑体现）
            if status == .severeDeficit && data.consecutiveLowScoreDays >= 2 {
                Text("已连续 \(data.consecutiveLowScoreDays) 晚恢复评分偏低，今日建议以低强度活动与休息为主。")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppleGlassStyle.spacingSM)
                    .padding(.vertical, AppleGlassStyle.spacingXS)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
            }
        }
        .padding(AppleGlassStyle.spacingMD)
        .frame(maxWidth: .infinity)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    /// 评分 → 星级换算（0-100 分 / 20 = 0-5 星，四舍五入）
    private func starCount(for score: Int) -> Int {
        min(5, max(0, Int((Double(score) / 20.0).rounded())))
    }

    // MARK: - 睡眠时长数据卡（昨夜总时长 + 四个阶段）
    private var sleepDataCard: some View {
        let data = currentData ?? SleepRecoveryMockScenario.good.mockData!
        return VStack(alignment: .leading, spacing: AppleGlassStyle.spacingSM) {
            sectionHeader(icon: "moon.stars.fill", title: "昨夜睡眠", tint: .indigo)

            // 昨夜睡眠总时长（大字展示）
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.1f", data.totalSleepHours))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(AppleGlassStyle.textPrimary)
                Text("小时")
                    .font(.subheadline)
                    .foregroundStyle(AppleGlassStyle.textSecondary)
                Spacer()
                Text("目标 ≥ 7.5 小时")
                    .font(.caption2)
                    .foregroundStyle(AppleGlassStyle.textTertiary)
            }

            Divider()

            // 四个睡眠阶段：核心 / 深睡 / REM / 夜间清醒
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppleGlassStyle.spacingSM) {
                stageItem(icon: "bed.double.fill", label: "核心睡眠", hours: data.coreSleepHours, color: .blue)
                stageItem(icon: "zzz", label: "深睡", hours: data.deepSleepHours, color: .purple)
                stageItem(icon: "sparkles", label: "REM 睡眠", hours: data.remSleepHours, color: .teal)
                stageItem(icon: "eye", label: "夜间清醒", hours: data.awakeHours, color: .gray)
            }
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    /// 阶段条目：图标 + 名称 + 时长
    private func stageItem(icon: String, label: String, hours: Double, color: Color) -> some View {
        HStack(spacing: AppleGlassStyle.spacingSM) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(AppleGlassStyle.textTertiary)
                Text(String(format: "%.1f 小时", hours))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppleGlassStyle.textPrimary)
            }
            Spacer()
        }
    }

    // MARK: - 睡眠结构占比可视化（简易分段比例条 + 图例）
    private var sleepStageRatioCard: some View {
        let data = currentData ?? SleepRecoveryMockScenario.good.mockData!
        let total = data.totalStageHours
        // 各阶段占比（占比为 0 时给最小可见宽度占位，避免除零）
        let coreRatio  = total > 0 ? data.coreSleepHours / total : 0
        let deepRatio  = total > 0 ? data.deepSleepHours / total : 0
        let remRatio   = total > 0 ? data.remSleepHours / total : 0
        let awakeRatio = total > 0 ? data.awakeHours / total : 0

        return VStack(alignment: .leading, spacing: AppleGlassStyle.spacingSM) {
            sectionHeader(icon: "chart.bar.fill", title: "睡眠结构占比", tint: .mint)

            // 分段比例条：核心(蓝) / 深睡(紫) / REM(青) / 清醒(灰)
            GeometryReader { geo in
                HStack(spacing: 3) {
                    ratioSegment(ratio: coreRatio, width: geo.size.width, color: .blue)
                    ratioSegment(ratio: deepRatio, width: geo.size.width, color: .purple)
                    ratioSegment(ratio: remRatio, width: geo.size.width, color: .teal)
                    ratioSegment(ratio: awakeRatio, width: geo.size.width, color: .gray)
                }
            }
            .frame(height: 16)

            // 图例
            HStack(spacing: AppleGlassStyle.spacingSM) {
                legendItem(color: .blue, label: "核心 \(String(format: "%.0f%%", coreRatio * 100))")
                legendItem(color: .purple, label: "深睡 \(String(format: "%.0f%%", deepRatio * 100))")
                legendItem(color: .teal, label: "REM \(String(format: "%.0f%%", remRatio * 100))")
                legendItem(color: .gray, label: "清醒 \(String(format: "%.0f%%", awakeRatio * 100))")
            }
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    /// 单个比例段（占比 0 时隐藏；占比小但非 0 时保留最小可见宽度）
    @ViewBuilder
    private func ratioSegment(ratio: Double, width: CGFloat, color: Color) -> some View {
        if ratio > 0 {
            RoundedRectangle(cornerRadius: 5)
                .fill(color)
                .frame(width: max(6, width * ratio - 3))
        }
    }

    /// 图例条目
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppleGlassStyle.textSecondary)
        }
    }

    // MARK: - 晨起静息心率 + 夜间平均 HRV 卡
    private var heartVitalCard: some View {
        let data = currentData ?? SleepRecoveryMockScenario.good.mockData!
        return VStack(alignment: .leading, spacing: AppleGlassStyle.spacingSM) {
            sectionHeader(icon: "heart.text.square.fill", title: "自主神经恢复指标", tint: .pink)

            HStack(spacing: AppleGlassStyle.spacingMD) {
                // 晨起静息心率
                VStack(alignment: .leading, spacing: 4) {
                    Text("晨起静息心率")
                        .font(.caption)
                        .foregroundStyle(AppleGlassStyle.textTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(data.restingHeartRate)")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(AppleGlassStyle.textPrimary)
                        Text("bpm")
                            .font(.caption2)
                            .foregroundStyle(AppleGlassStyle.textSecondary)
                    }
                }
                Spacer()
                // 夜间平均 HRV
                VStack(alignment: .trailing, spacing: 4) {
                    Text("夜间平均 HRV")
                        .font(.caption)
                        .foregroundStyle(AppleGlassStyle.textTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(data.avgHRV)")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(AppleGlassStyle.textPrimary)
                        Text("ms")
                            .font(.caption2)
                            .foregroundStyle(AppleGlassStyle.textSecondary)
                    }
                }
            }

            // 指标参考说明（仅作趋势参考，不做诊断）
            ComplianceText(text: "静息心率与 HRV 仅作恢复趋势参考，单次数值波动受多种因素影响，不构成健康评估。")
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    // MARK: - 智能建议入口按钮
    private var suggestionButton: some View {
        Button {
            showSuggestion = true
        } label: {
            Label("查看今日训练建议", systemImage: "lightbulb.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppleGlassStyle.spacingMD)
                .background(
                    SleepRecoveryStatus.from(score: currentData?.recoveryScore ?? 0).color,
                    in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium)
                )
        }
    }

    // MARK: - 数据源场景切换器（实时数据 + 概念演示覆盖）
    private var scenarioPicker: some View {
        VStack(spacing: AppleGlassStyle.spacingXS) {
            Picker("数据源", selection: $selectedScenario) {
                ForEach(SleepRecoveryMockScenario.allCases) { scenario in
                    Text(scenario.rawValue).tag(scenario)
                }
            }
            .pickerStyle(.segmented)

            ComplianceText(text: "【实时数据】默认展示后端同步的睡眠数据；其余为概念演示覆盖场景，用于展示三套状态与空状态闭环。")
        }
    }

    // MARK: - 常驻免责声明模块（固定文案，一字不变）
    /// 需求指定的完整免责与局限性说明，页面常驻展示。
    private var fixedDisclaimerSection: some View {
        VStack(alignment: .leading, spacing: AppleGlassStyle.spacingXS) {
            Text("免责与局限性说明")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppleGlassStyle.textSecondary)
                .padding(.bottom, 2)

            ComplianceText(text: "本模块所有数据来源于 Apple Watch HealthKit 可穿戴传感器采集，仅为健身恢复参考数据，无法等同于医院 PSG 多导睡眠临床诊断标准。")
            ComplianceText(text: "本系统睡眠恢复评分为前端自研加权启发式算法，仅参考运动生理学公开文献设计；受个体体质差异、设备佩戴状态、环境因素影响，不具备医学诊断效力，准确度存在局限性。")
            ComplianceText(text: "本功能无法直接检测皮质醇数值，仅通过睡眠结构、HRV、静息心率变化，推断身体应激恢复趋势。")
            ComplianceText(text: "所有训练、饮食调整建议仅作健身辅助参考，不强制干预用户行为；长期失眠、身体不适请及时就医。")
            ComplianceText(text: "本项目为概念 Demo，未接入大规模用户数据集训练，算法仅用于产品理念演示，商用高精度迭代需企业级长期数据积累。")
        }
    }

    // MARK: - 小节标题通用组件
    private func sectionHeader(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: AppleGlassStyle.spacingXS) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(tint)
            Text(title)
                .font(.headline)
                .foregroundStyle(AppleGlassStyle.textPrimary)
            Spacer()
        }
    }
}

// MARK: - 智能建议弹窗（双按钮常驻，不锁死用户训练）
/// 依据当前状态展示对应建议文案；优先使用后端返回的 suggestion 文案，
/// 无后端文案（演示覆盖场景）时回退前端三套状态固定文案。
/// 弹窗底部常驻两个操作按钮。
struct SleepRecoverySuggestionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let data: SleepRecoveryData      // 当前睡眠恢复数据
    let status: SleepRecoveryStatus      // 当前恢复状态
    var onAdopt: () -> Void = {}         // 采纳建议回调
    var onIgnore: () -> Void = {}        // 忽略建议回调

    var body: some View {
        VStack(spacing: 0) {
            // 顶部免责声明条（复用项目统一规范）
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

            // 主体内容
            VStack(spacing: AppleGlassStyle.spacingSM) {
                // 状态图标
                ZStack {
                    Circle()
                        .fill(status.color.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: status.icon)
                        .font(.title2)
                        .foregroundStyle(status.color)
                }
                .padding(.top, AppleGlassStyle.spacingSM)

                // 弹窗标题（优先后端建议标题，无则按状态区分）
                Text(sheetTitle)
                    .font(.headline)
                    .foregroundColor(AppleGlassStyle.textPrimary)

                // 建议正文区
                VStack(alignment: .leading, spacing: AppleGlassStyle.spacingXS) {
                    // 优先展示后端返回的建议文案（已含替代方案与连续低分提示）
                    if let sug = data.suggestionMessage, !sug.isEmpty {
                        Text(sug)
                            .font(.subheadline)
                            .foregroundColor(AppleGlassStyle.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        // 无后端文案（演示覆盖场景）：回退前端三套状态固定文案
                        Text(status.message)
                            .font(.subheadline)
                            .foregroundColor(AppleGlassStyle.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        // 红色状态附加：推荐替代方案（需求原文）
                        if status == .severeDeficit {
                            Text("推荐替代方案：轻度散步、低强度活动，饮食清淡、维持蛋白、不加大热量缺口")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.red)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                        }

                        // 连续低分重度休息提示：仅连续低分状态才提示（单晚差仅触发黄色提醒级别）
                        if status == .severeDeficit && data.consecutiveLowScoreDays >= 2 {
                            Text("您已连续 \(data.consecutiveLowScoreDays) 晚评分偏低，今日建议以休息与低强度活动为主。")
                                .font(.caption)
                                .foregroundColor(.red)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                        }
                    }
                }
                .padding(AppleGlassStyle.spacingSM)
                .background(status.color.opacity(0.06), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))

                Divider()
                    .padding(.horizontal, -AppleGlassStyle.spacingSM)

                // 双操作按钮：不锁死用户训练，仅作参考
                // 【采纳建议，调整今日训练】
                Button {
                    dismiss()
                    onAdopt()
                } label: {
                    Text("采纳建议，调整今日训练")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppleGlassStyle.spacingSM)
                        .background(status.color, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
                }

                // 【忽略建议，执行原定计划】
                Button {
                    dismiss()
                    onIgnore()
                } label: {
                    Text("忽略建议，执行原定计划")
                        .font(.headline.weight(.medium))
                        .foregroundColor(AppleGlassStyle.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppleGlassStyle.spacingSM)
                        .background(AppleGlassStyle.ultraThin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
                }
                .padding(.bottom, AppleGlassStyle.spacingSM)
            }
            .padding(.horizontal, AppleGlassStyle.spacingSM)
            .background(AppleGlassStyle.standard)
        }
        .padding(.horizontal, AppleGlassStyle.spacingMD)
        .padding(.vertical, AppleGlassStyle.spacingMD)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppleGlassStyle.groupedBackground)
        .presentationDetents([.medium, .large])
    }

    /// 弹窗标题：优先后端建议标题；无后端标题时按状态区分文案（红色连续低分时提示重度休息建议）
    private var sheetTitle: String {
        if let title = data.suggestionTitle, !title.isEmpty {
            return title
        }
        switch status {
        case .good:
            return "今日恢复状态良好"
        case .mildDeficit:
            return "轻度恢复不足提醒"
        case .severeDeficit:
            return data.consecutiveLowScoreDays >= 2 ? "重度休息建议" : "恢复不足提醒"
        case .noData:
            return "暂无睡眠数据"
        }
    }
}

// MARK: - Preview
#Preview {
    SleepRecoveryView()
}
