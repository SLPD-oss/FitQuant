import SwiftUI

// MARK: - RootView
// Root view that gates the app behind compliance agreement checks and login.
// 路由优先级：未签协议 → 免责协议页 → 登录页 → 主Tab页

struct RootView: View {
    @AppStorage("agreedLocalLaw") private var agreedLocalLaw: Bool = false
    @AppStorage("agreedApplePolicy") private var agreedApplePolicy: Bool = false
    @AppStorage("firstOpenFlag") private var firstOpenFlag: Bool = true
    // 新增：标记用户是否完成登录，控制首次启动页面路由流转
    @AppStorage("isUserLogined") private var isUserLogined: Bool = false

    var body: some View {
        Group {
            if allAgreed {
                //【修改代码】路由判断：已签协议 → 校验登录状态
                // 正常重启（isUserLogined=true）→ 直接进主页；退出重置后（isUserLogined=false）→ 强制跳登录页
                if isUserLogined {
                    // 已签协议 + 已登录 → 直接进入主界面
                    MainTabContentView()
                } else {
                    // 新增：已签协议但未登录 → 跳转登录注册页面
                    LoginAuthView {
                        isUserLogined = true
                    }
                }
            } else {
                // 未签协议 → 启动协议流程
                LaunchFlowView {
                    agreedLocalLaw = true
                    agreedApplePolicy = true
                    firstOpenFlag = false
                }
            }
        }
        .onAppear {
            if firstOpenFlag {
                firstOpenFlag = false
            }
        }
    }

    private var allAgreed: Bool {
        agreedLocalLaw && agreedApplePolicy
    }
}

// MARK: - Preview
// 【修复Preview预览崩溃｜故障根源：预览代码未注入GlobalCreatineManager环境对象】
#Preview {
    RootView()
        .environmentObject(GlobalCreatineManager.shared)
}
