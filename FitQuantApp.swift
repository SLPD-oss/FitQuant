import SwiftUI

// MARK: - FitQuantApp
// App entry point.

@main
struct FitQuantApp: App {
    @StateObject private var globalVM = GlobalViewManager.shared
    // 【修复肌酸饮水单次同步BUG｜改动业务：注入全局肌酸单例为环境对象，补剂页+饮食页均可通过@EnvironmentObject访问】
    @StateObject private var creatineManager = GlobalCreatineManager.shared
    // 【本次更新｜深色模式】全局深浅色开关：默认 false = 浅色模式（"我的"页 Toggle 控制，持久化）
    @AppStorage("darkModeEnabled") private var darkModeEnabled: Bool = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(globalVM)
                .environmentObject(creatineManager)  // 全局肌酸环境对象注入
                // 【本次更新｜深色模式】按开关强制全 App 深浅色：开=深色，关=浅色（初始浅色）
                .preferredColorScheme(darkModeEnabled ? .dark : .light)
        }
    }
}
