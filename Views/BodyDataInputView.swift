import SwiftUI

// MARK: - BodyDataInputView
// 【全新新增页面代码】新用户专属初始身体数据录入页面
// 仅对新手机号注册用户生效，老用户完全跳过
// 录入必填字段后自动计算体脂率+BMR+营养素目标，一键写入本地存储
// 所有计算本地离线完成，无云端RAG依赖

struct BodyDataInputView: View {
    /// 录入完成后回调 → 跳转欢迎页面
    var onComplete: () -> Void

    // MARK: - 必填字段
    @State private var sex: Sex = .male
    @State private var heightCm: Double = 170
    @State private var weightKg: Double = 70
    // 【本次更新｜年龄输入】注册后身体数据录入页新增年龄（必填），同步写入「我的」板块与 BMR/营养目标计算
    @State private var age: Int = 25

    // MARK: - 选填字段（围度，留空不影响确认）
    @State private var chestCm: Double = 0
    @State private var waistCm: Double = 0
    @State private var hipCm: Double = 0

    // MARK: - 计算展示
    @State private var calculatedBodyFat: Double = 0
    @State private var calculatedBMR: Double = 0
    @State private var hasCalculated: Bool = false

    // 体脂自定义弹窗
    @State private var showCustomFatSheet: Bool = false
    @State private var customFatValue: String = ""

    /// 必填项是否全部填写（年龄需为有效正整数）
    private var requiredFieldsFilled: Bool {
        heightCm > 0 && weightKg > 0 && age > 0 && age <= 120
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppleGlassStyle.spacingMD) {
                // 页面标题
                headerSection

                // 必填区域：性别/身高/体重
                requiredFieldsSection

                // 选填区域：围度
                optionalFieldsSection

                // 体脂率计算展示 + 操作按钮
                if hasCalculated {
                    bodyFatResultSection
                }

                // 确认按钮
                confirmButton
            }
            .padding(AppleGlassStyle.spacingMD)
        }
        .background(AppleGlassStyle.groupedBackground)
        .onChange(of: heightCm) { _, _ in recalculate() }
        .onChange(of: weightKg) { _, _ in recalculate() }
        .onChange(of: age) { _, _ in recalculate() }
        .onChange(of: waistCm) { _, _ in recalculate() }
        .onChange(of: hipCm) { _, _ in recalculate() }
        .onChange(of: sex) { _, _ in recalculate() }
        .sheet(isPresented: $showCustomFatSheet) {
            customFatSheet
        }
    }

    // MARK: - 页面标题
    private var headerSection: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            Image(systemName: "figure.arms.open")
                .font(.system(size: 40))
                .foregroundStyle(AppleGlassStyle.accent)

            Text("完善身体数据")
                .font(.title2.weight(.bold))
                .foregroundColor(AppleGlassStyle.textPrimary)

            Text("填写基本信息后，系统将自动计算您的体脂率与每日营养摄入目标")
                .font(.caption)
                .foregroundColor(AppleGlassStyle.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppleGlassStyle.spacingMD)
        }
        .padding(.top, AppleGlassStyle.spacingSM)
    }

    // MARK: - 必填字段
    private var requiredFieldsSection: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            sectionHeader("必填信息", icon: "exclamationmark.circle.fill", color: .orange)

            // 性别选择器
            Picker("性别", selection: $sex) {
                ForEach(Sex.allCases, id: \.self) { s in
                    Text(s.displayName).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 4)

            // 身高
            numberFieldRow(icon: "ruler", label: "身高 (cm)", value: $heightCm, suffix: "cm", color: .blue)

            // 【本次更新｜年龄输入】必填年龄输入行（整数）
            HStack(spacing: AppleGlassStyle.spacingSM) {
                Image(systemName: "calendar").foregroundColor(.orange).frame(width: 24)
                Text("年龄").font(.subheadline).foregroundColor(AppleGlassStyle.textSecondary)
                Spacer()
                HStack(spacing: 2) {
                    TextField("0", value: $age, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.body.weight(.medium))
                        .foregroundColor(AppleGlassStyle.textPrimary)
                        .frame(width: 60)
                    Text("岁").font(.caption2).foregroundColor(AppleGlassStyle.textTertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemFill).opacity(0.15), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
            }

            // 体重
            numberFieldRow(icon: "scalemass", label: "体重 (kg)", value: $weightKg, suffix: "kg", color: .green)
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    // MARK: - 选填字段
    private var optionalFieldsSection: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            sectionHeader("选填 · 围度数据（更精准的计算体脂）", icon: "questionmark.circle.fill", color: AppleGlassStyle.textTertiary)

            numberFieldRow(icon: "figure.stand", label: "胸围 (cm)", value: $chestCm, suffix: "cm", color: .cyan)
            numberFieldRow(icon: "figure.stand.line.dotted.figure.stand", label: "腰围 (cm)", value: $waistCm, suffix: "cm", color: .purple)
            numberFieldRow(icon: "figure.walk", label: "臀围 (cm)", value: $hipCm, suffix: "cm", color: .pink)

            Text("填写腰围/臀围后，系统使用海军体脂公式计算，比纯BMI估算更精准")
                .font(.caption2)
                .foregroundColor(AppleGlassStyle.textTertiary)
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    // MARK: - 体脂率计算结果区
    private var bodyFatResultSection: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            sectionHeader("身体数据计算结果", icon: "function", color: .orange)

            HStack(spacing: AppleGlassStyle.spacingMD) {
                // 体脂率卡片
                resultCard(
                    title: "体脂率",
                    value: String(format: "%.1f%%", calculatedBodyFat),
                    color: calculatedBodyFat > 30 ? .orange : .green,
                    icon: "chart.pie.fill"
                )

                // BMR卡片
                resultCard(
                    title: "基础代谢",
                    value: String(format: "%.0f kcal", calculatedBMR),
                    color: .blue,
                    icon: "flame.fill"
                )
            }

            // 操作按钮
            HStack(spacing: AppleGlassStyle.spacingSM) {
                // 一键导入按钮
                Button {
                    importBodyFatToStorage()
                } label: {
                    Label("一键导入体脂", systemImage: "square.and.arrow.down.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppleGlassStyle.spacingSM)
                        .background(AppleGlassStyle.accent, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
                }

                // 自定义修改按钮
                Button {
                    customFatValue = String(format: "%.1f", calculatedBodyFat)
                    showCustomFatSheet = true
                } label: {
                    Label("自定义修改", systemImage: "pencil")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppleGlassStyle.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppleGlassStyle.spacingSM)
                        .background(AppleGlassStyle.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
                }
            }
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
    }

    // MARK: - 确认按钮
    private var confirmButton: some View {
        Button {
            // 写入身体数据 + 生成营养目标 → 跳转欢迎页
            saveAllDataAndProceed()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("确认，继续")
                    .fontWeight(.semibold)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppleGlassStyle.spacingMD)
            .background(requiredFieldsFilled ? AppleGlassStyle.accent : Color.gray, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
        }
        .disabled(!requiredFieldsFilled)
        .opacity(requiredFieldsFilled ? 1.0 : 0.5)
        .padding(.bottom, AppleGlassStyle.spacingLG)
    }

    // MARK: - 自定义体脂弹窗
    private var customFatSheet: some View {
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
                Text("自定义体脂率").font(.headline).foregroundColor(AppleGlassStyle.textPrimary)

                HStack(spacing: 4) {
                    TextField("", text: $customFatValue)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(AppleGlassStyle.accent)
                        .frame(width: 120)
                    Text("%").font(.title2).foregroundColor(AppleGlassStyle.textSecondary)
                }
                .padding(.vertical, AppleGlassStyle.spacingSM)

                Text("手动输入您自定义的体脂率数值，将覆盖系统自动计算结果")
                    .font(.caption).foregroundColor(AppleGlassStyle.textTertiary)

                Divider().padding(.horizontal, -AppleGlassStyle.spacingSM)

                HStack(spacing: AppleGlassStyle.spacingSM) {
                    Button { showCustomFatSheet = false } label: {
                        Text("取消").font(.body.weight(.medium))
                            .foregroundColor(AppleGlassStyle.textSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(AppleGlassStyle.ultraThin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
                    }
                    Button {
                        if let val = Double(customFatValue), val > 0 {
                            calculatedBodyFat = val
                        }
                        showCustomFatSheet = false
                    } label: {
                        Text("确认修改").font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(AppleGlassStyle.accent, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
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
        .presentationDetents([.medium])
    }

    // MARK: - 辅助UI

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption).foregroundColor(color)
            Text(title).font(.caption.weight(.medium)).foregroundColor(AppleGlassStyle.textSecondary)
            Spacer()
        }
    }

    private func resultCard(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2).foregroundColor(color)
                Text(title).font(.caption2).foregroundColor(AppleGlassStyle.textTertiary)
            }
            Text(value).font(.title2.weight(.bold)).foregroundColor(color)
        }
        .padding(AppleGlassStyle.spacingSM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
    }

    private func numberFieldRow(icon: String, label: String, value: Binding<Double>, suffix: String, color: Color) -> some View {
        HStack(spacing: AppleGlassStyle.spacingSM) {
            Image(systemName: icon).foregroundColor(color).frame(width: 24)
            Text(label).font(.subheadline).foregroundColor(AppleGlassStyle.textSecondary)
            Spacer()
            HStack(spacing: 2) {
                TextField("0", value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.body.weight(.medium))
                    .foregroundColor(AppleGlassStyle.textPrimary)
                    .frame(width: 60)
                Text(suffix).font(.caption2).foregroundColor(AppleGlassStyle.textTertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemFill).opacity(0.15), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))
        }
    }

    // MARK: - 计算逻辑

    private func recalculate() {
        guard requiredFieldsFilled else { return }
        calculatedBodyFat = PhysiologyCalcTool.calculateBodyFat(
            sex: sex,
            heightCm: heightCm,
            weightKg: weightKg,
            waistCm: waistCm > 0 ? waistCm : nil,
            hipCm: hipCm > 0 ? hipCm : nil
        )
        calculatedBMR = PhysiologyCalcTool.calculateBMR(
            sex: sex, weightKg: weightKg, heightCm: heightCm, age: age
        )
        hasCalculated = true
    }

    /// 【修复数据读取逻辑】一键导入：将全套身体数据完整序列化为BodyDataModel写入UserDefaults
    /// 修复前只写了4个零散key，MineView和SupplementView读不到 → 现在写完整Model
    private func importBodyFatToStorage() {
        recalculate()
        var model = BodyDataModel()
        model.sex = sex
        model.heightCm = heightCm
        model.weightKg = weightKg
        // 【本次更新｜年龄输入】年龄同步写入 BodyDataModel（「我的」板块读取显示）
        model.age = age
        model.bodyFatPercent = calculatedBodyFat
        model.waistCm = waistCm > 0 ? waistCm : 0
        model.hipCm = hipCm > 0 ? hipCm : 0
        model.chestCm = chestCm > 0 ? chestCm : 0
        // 【网络层对接】保存到本地 + 同步云端（后端不可用时静默失败）
        BodyDataRepository.saveAndSync(model)
    }

    /// 保存全部数据并跳转：身体数据 + 营养目标
    private func saveAllDataAndProceed() {
        recalculate()
        importBodyFatToStorage()

        // 生成营养素目标并本地持久化（【本次更新｜年龄输入】BMR 计算传入年龄）
        let targets = PhysiologyCalcTool.calculateNutritionTargets(
            sex: sex, weightKg: weightKg, heightCm: heightCm, age: age
        )
        targets.saveToStorage()

        onComplete()
    }
}

#Preview {
    BodyDataInputView(onComplete: {})
}
