import SwiftUI

// MARK: - RootView
// Root view that gates the app behind compliance agreement checks and login.
// 路由优先级：未签协议 → 免责协议页 → 登录页 → 主Tab页

struct RootView: View {
    // 【合规整改｜协议版本化】协议内容版本号：每次修改协议文案后递增，触发已装用户重新确认
    // 依据《个人信息保护法》第 24 条：处理规则变更应重新取得用户同意
    static let agreementVersion = "2026-08-05"

    @AppStorage("agreedLocalLaw") private var agreedLocalLaw: Bool = false
    @AppStorage("agreedApplePolicy") private var agreedApplePolicy: Bool = false
    // 【合规整改｜协议版本化】记录用户确认的协议版本号（与 RootView.agreementVersion 比对）
    @AppStorage("agreedLocalLawVersion") private var agreedLocalLawVersion: String = ""
    @AppStorage("agreedApplePolicyVersion") private var agreedApplePolicyVersion: String = ""
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
                        // 【方案A】登录成功后切换账号上下文：
                        // userId 已在登录流程写入 LoginUserStorage，
                        // 此处触发一次性迁移 + 重建内存单例（用药/肌酸）
                        AccountScopedStore.accountDidChange()
                        // 【网络层对接】登录成功后后台预加载全模块数据
                        Task {
                            // 静默加载，失败不阻塞
                        }
                    }
                }
            } else {
                // 未签协议（或协议版本已更新）→ 启动协议流程
                LaunchFlowView {
                    agreedLocalLaw = true
                    agreedApplePolicy = true
                    agreedLocalLawVersion = Self.agreementVersion
                    agreedApplePolicyVersion = Self.agreementVersion
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

    /// 【合规整改｜协议版本化】已同意 且 已确认的版本号与当前协议版本一致 才视为通过
    private var allAgreed: Bool {
        agreedLocalLaw && agreedApplePolicy
            && agreedLocalLawVersion == Self.agreementVersion
            && agreedApplePolicyVersion == Self.agreementVersion
    }
}

// MARK: - Preview
// 【修复Preview预览崩溃｜故障根源：预览代码未注入GlobalCreatineManager环境对象】
#Preview {
    RootView()
        .environmentObject(GlobalCreatineManager.shared)
}
