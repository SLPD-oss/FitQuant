import SwiftUI

// MARK: - MotivationGuideView
// 【全新重写代码】全屏分页励志语录引导页
// 前5页各展示一条全屏语录，点击屏幕依次切换，不可跳过
// 第6页为欢迎确认页，底部按钮触发底部向上喷发的礼花动画
// 礼花结束 → 自动跳转App主界面
// 远期可替换为云端接口拉取个性化语录与用户标签

struct MotivationGuideView: View {
    /// 引导完成后回调 → 标记登录成功 → 跳转主页
    var onReady: () -> Void

    // 【全新重写代码】内置5条励志语录 + 身体数据录入页 + 欢迎页
    // 索引0~4=语录页，5=身体录入页，6+=欢迎页
    private let quotes: [String] = [
        "不要自甘堕落，你的潜力远超想象",
        "汗水不会骗人，坚持终会看见改变",
        "当下每一次自律，都是未来更好的自己",
        "减脂增肌的路上，拒绝半途而废",
        "自律不是束缚，是拿回人生的掌控权"
    ]

    /// 当前页面索引：0~4=语录页，5=身体录入页，6+=欢迎确认页
    @State private var currentPage: Int = 0
    @State private var showConfetti: Bool = false

    var body: some View {
        ZStack {
            // 液态玻璃背景铺满全屏
            AppleGlassStyle.groupedBackground.ignoresSafeArea()

            if currentPage < quotes.count {
                // 【全新重写代码】全屏单语录页面 — 无多余控件，点击切换下一张
                quotePage(index: currentPage)
            } else if currentPage == quotes.count {
                // 【修改路由跳转逻辑】语录浏览完毕 → 插入全新身体数据录入页面（仅新用户）
                BodyDataInputView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        currentPage = quotes.count + 1
                    }
                }
            } else {
                // 【全新重写代码】欢迎确认页
                welcomePage
            }

            // 【全新重写代码】底部向上喷发礼花粒子动画层
            ConfettiAnimationView(isPlaying: $showConfetti) {
                onReady()
            }
        }
    }

    // MARK: - 全屏单语录页面
    private func quotePage(index: Int) -> some View {
        VStack(spacing: AppleGlassStyle.spacingLG) {
            Spacer()

            // 语录顶部小标签
            Text("\(index + 1) / \(quotes.count)")
                .font(.caption.weight(.medium))
                .foregroundColor(AppleGlassStyle.textTertiary)

            // 大号语录正文
            Text(quotes[index])
                .font(.system(size: 32, weight: .medium, design: .default))
                .foregroundColor(AppleGlassStyle.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppleGlassStyle.spacingLG)
                .padding(.vertical, AppleGlassStyle.spacingMD)

            Spacer()

            // 底部点击提示
            VStack(spacing: 6) {
                Image(systemName: "hand.tap.fill")
                    .font(.title3)
                    .foregroundColor(AppleGlassStyle.accent.opacity(0.5))
                Text("点击屏幕任意位置继续")
                    .font(.caption)
                    .foregroundColor(AppleGlassStyle.textTertiary)
            }
            .padding(.bottom, AppleGlassStyle.spacingLG)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            // 切换到下一张语录
            withAnimation(.easeInOut(duration: 0.35)) {
                currentPage = index + 1
            }
        }
    }

    // MARK: - 第6张欢迎确认页
    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            // 图标
            ZStack {
                Circle()
                    .fill(AppleGlassStyle.accent.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundStyle(AppleGlassStyle.accent)
            }
            .padding(.bottom, AppleGlassStyle.spacingLG)

            // 标题
            Text("欢迎加入量化补充")
                .font(.largeTitle.weight(.bold))
                .foregroundColor(AppleGlassStyle.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, AppleGlassStyle.spacingMD)

            // 引导提问文案
            Text("你准备好开启你的改变之旅了吗？")
                .font(.title3.weight(.medium))
                .foregroundColor(AppleGlassStyle.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppleGlassStyle.spacingLG)

            Spacer()

            // 底部确认按钮 — 液态玻璃风格
            Button {
                showConfetti = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("是的，我已准备好了")
                        .fontWeight(.semibold)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppleGlassStyle.spacingMD)
                .background(
                    AppleGlassStyle.accent,
                    in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium)
                )
            }
            .padding(.horizontal, AppleGlassStyle.spacingLG)
            .padding(.bottom, AppleGlassStyle.spacingLG)

            // 远期云端兼容注释
            Text("后期可替换为云端接口拉取个性化欢迎页内容")
                .font(.caption2)
                .foregroundColor(AppleGlassStyle.textTertiary)
                .padding(.bottom, AppleGlassStyle.spacingSM)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MotivationGuideView(onReady: {})
}
