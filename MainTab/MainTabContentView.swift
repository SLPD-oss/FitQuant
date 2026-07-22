import SwiftUI

// MARK: - MainTabContentView
// Root TabView with 5 tabs and standard Material dock design.

struct MainTabContentView: View {
    @State private var bodyData = BodyDataModel()
    @State private var selectedTab: Int = 0
    // 【网络层对接】是否已从后端加载身体数据
    @State private var didLoadBodyFromAPI = false

    var body: some View {
        TabView(selection: $selectedTab) {
            SupplementView(bodyData: $bodyData)
                .tabItem {
                    Image(systemName: "pills.fill")
                    Text("补剂")
                }
                .tag(0)

            MedicineView()
                .tabItem {
                    Image(systemName: "cross.case.fill")
                    Text("用药")
                }
                .tag(1)

            TrainView()
                .tabItem {
                    Image(systemName: "figure.strengthtraining.traditional")
                    Text("训练")
                }
                .tag(2)

            DietView(bodyData: $bodyData)
                .tabItem {
                    Image(systemName: "fork.knife")
                    Text("饮食")
                }
                .tag(3)

            MineView(bodyData: $bodyData)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("我的")
                }
                .tag(4)
        }
        .tint(AppleGlassStyle.accent)
        // 【网络层对接】页面出现时从后端加载最新身体数据
        .task {
            guard !didLoadBodyFromAPI, let uid = LoginUserStorage.userId, !uid.isEmpty else { return }
            do {
                let resp: BodyLatestResponse = try await APIClient.shared.get("/api/body/latest?user_id=\(uid)")
                if let h = resp.height_cm, let w = resp.weight_kg, h > 0 {
                    var model = BodyDataModel()
                    model.heightCm = h
                    model.weightKg = w
                    model.age = resp.age ?? 0
                    if let s = resp.sex { model.sex = Sex(rawValue: s) ?? .male }
                    model.waistCm = resp.waist_cm ?? 0
                    model.neckCm = resp.neck_cm ?? 0
                    model.hipCm = resp.hip_cm ?? 0
                    model.chestCm = resp.chest_cm ?? 0
                    model.bodyFatPercent = resp.body_fat_percent ?? 0
                    if let al = resp.activity_level { model.activityLevel = ActivityLevel(rawValue: al) ?? .sedentary }
                    bodyData = model
                    BodyDataRepository.save(model)
                    didLoadBodyFromAPI = true
                    print("[MainTab] 从后端加载身体数据成功")
                }
            } catch {
                print("[MainTab] 后端加载身体数据失败: \(error.localizedDescription)，使用本地数据")
                // 尝试从本地 UserDefaults 加载已保存的数据
                let local = BodyDataRepository.load()
                if local.heightCm > 0 || local.weightKg > 0 {
                    bodyData = local
                }
                didLoadBodyFromAPI = true
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            GlobalViewManager.shared.selectedTab = newValue
        }
    }
}

// MARK: - FilterChip
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(isSelected ? .white : AppleGlassStyle.textSecondary)
                .padding(.horizontal, AppleGlassStyle.spacingMD)
                .padding(.vertical, AppleGlassStyle.spacingSM)
                .background(
                    isSelected
                        ? AppleGlassStyle.accent
                        : Color(.systemFill).opacity(0.3),
                    in: Capsule()
                )
        }
    }
}

// MARK: - Preview
// 【修复Preview预览崩溃｜故障根源：预览代码未注入GlobalCreatineManager环境对象】
#Preview {
    MainTabContentView()
        .environmentObject(GlobalCreatineManager.shared)
}
