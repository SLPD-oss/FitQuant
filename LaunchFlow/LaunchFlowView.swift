import SwiftUI

// MARK: - LaunchFlowView (协调器)

/// 【设计规范】Launch 流程协调器，管理 0-5 共 6 页导航
/// 使用 NavigationStack + @State currentPage 做页面切换
struct LaunchFlowView: View {

    // MARK: - State

    /// 当前页面索引: 0..5
    @State private var currentPage: Int = 0

    // MARK: - Callbacks

    /// 全部流程完成后回调
    var onComplete: () -> Void

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                switch currentPage {
                case 0:
                    // 中国大陆法律免责协议
                    Page1_AgreementView(
                        onContinue: { advanceTo(1) }
                    )

                case 1:
                    // Apple 平台合规协议
                    Page1b_AppleAgreementView(
                        onContinue: { advanceTo(2) }
                    )

                case 2:
                    // 注册方式预览
                    Page2_RegisterPreviewView(
                        onContinue: { advanceTo(4) }
                    )

                case 3:
                    // 预留页面 —— 暂无内容，自动跳过
                    Color.clear
                        .onAppear { advanceTo(4) }

                case 4:
                    // 身份选择
                    Page4_IdentitySelectView(
                        onContinue: { advanceTo(5) }
                    )

                case 5:
                    // 首次启动励志文案
                    Page5_OnceAlertView(
                        onFinish: { onComplete() }
                    )

                default:
                    EmptyView()
                }
            }
        }
    }

    // MARK: - Helpers

    private func advanceTo(_ page: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage = page
        }
    }
}
