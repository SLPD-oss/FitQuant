import SwiftUI

// MARK: - FitQuantApp
// App entry point.

@main
struct FitQuantApp: App {
    @StateObject private var globalVM = GlobalViewManager.shared
    // 【修复肌酸饮水单次同步BUG｜改动业务：注入全局肌酸单例为环境对象，补剂页+饮食页均可通过@EnvironmentObject访问】
    @StateObject private var creatineManager = GlobalCreatineManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(globalVM)
                .environmentObject(creatineManager)  // 全局肌酸环境对象注入
        }
    }
}
