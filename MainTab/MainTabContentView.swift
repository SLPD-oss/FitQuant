import SwiftUI

// MARK: - MainTabContentView
// Root TabView with 5 tabs and standard Material dock design.

struct MainTabContentView: View {
    @State private var bodyData = BodyDataModel()
    @State private var selectedTab: Int = 0

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
