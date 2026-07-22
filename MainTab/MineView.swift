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

    // Iteration plan notes
    @State private var iterationNotes: String = ""

    // @AppStorage for logout reset
    @AppStorage("agreedLocalLaw") private var agreedLocalLaw: Bool = false
    @AppStorage("agreedApplePolicy") private var agreedApplePolicy: Bool = false
    @AppStorage("firstOpenFlag") private var firstOpenFlag: Bool = true
    //【新增代码】引入登录状态标记，确保退出重置后下次启动强制重新登录
    @AppStorage("isUserLogined") private var isUserLogined: Bool = false

    @State private var showLogoutConfirmation: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppleGlassStyle.spacingMD) {
                    profileHeader
                    bodyDataEditor
                    quickStatsSection
                    bmiZoneBar
                    iterationPlanSection
                    complianceSection
                    logoutButton
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
            //【修复数据读取逻辑】每次进入页面从UserDefaults读取最新身体数据，同步绑定状态
            .onAppear { loadBodyDataFromStorage() }
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

    // MARK: - Iteration Plan Section
    private var iterationPlanSection: some View {
        VStack(alignment: .leading, spacing: AppleGlassStyle.spacingSM) {
            HStack {
                Text("迭代计划").font(.headline).foregroundStyle(AppleGlassStyle.textPrimary)
                Spacer()
            }
            TextEditor(text: $iterationNotes)
                .font(.subheadline)
                .foregroundStyle(AppleGlassStyle.textPrimary)
                .frame(minHeight: 100)
                .padding(AppleGlassStyle.spacingSM)
                .background(Color(.systemFill).opacity(0.15), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
                .scrollContentBackground(.hidden)
            Text("记录您的训练目标、饮食调整计划和个人迭代方向。")
                .font(.caption2).foregroundStyle(AppleGlassStyle.textTertiary)
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
        firstOpenFlag = true
        //【新增代码】同步清空登录状态，确保下次启动完整走「协议→登录页」流程
        // 远期云端账号兼容：可在此处追加调用云端登出接口，本地重置逻辑无需改动
        isUserLogined = false
        // 【网络层对接】清除后端登录的用户信息
        LoginUserStorage.clear()
        APIClient.shared.clearToken()
        GlobalViewManager.shared.resetToDefaults()
    }

    // MARK: - 【修复数据读取逻辑】从UserDefaults加载身体数据
    // BodyDataInputView写入完整BodyDataModel序列化数据到"saved_bodyData"key
    // 修改前：bodyData由MainTabContentView用默认值初始化，新用户注册录入无法同步
    // 修改后：onAppear读取UserDefaults，存在写入记录则覆盖binding实现数据同步
    private func loadBodyDataFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: "saved_bodyData"),
              let saved = try? JSONDecoder().decode(BodyDataModel.self, from: data) else {
            return
        }
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

// MARK: - Preview
#Preview {
    @Previewable @State var bodyData = BodyDataModel()
    MineView(bodyData: $bodyData)
}
