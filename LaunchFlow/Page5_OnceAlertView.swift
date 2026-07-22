import SwiftUI

// MARK: - Page5_OnceAlertView (首次启动励志文案)

/// 【合规红线：分步点击励志文案】
/// 首次启动展示基于用户身份的 4 条励志文案，逐条点击浏览，第 4 次点击后关闭。
struct Page5_OnceAlertView: View {

    // MARK: - AppStorage

    /// 标记首次启动是否完成
    @AppStorage("firstOpenFlag") private var firstOpenFlag: Bool = false

    // MARK: - State

    /// 当前显示的文案索引 (0-3)
    @State private var quoteIndex: Int = 0

    // MARK: - Callbacks

    var onFinish: () -> Void

    // MARK: - Quotes Data

    /// 根据当前身份返回对应励志文案数组
    private var quotes: [String] {
        quotesForIdentity(GlobalViewManager.shared.currentIdentity)
    }

    /// 各地区 / 身份的 4 句文案
    private func quotesForIdentity(_ identity: GlobalViewManager.UserIdentity) -> [String] {
        switch identity {
        case .beginner:
            return [
                "每一次开始，都是对自己最勇敢的承诺。",
                "减脂的路上，汗水是最诚实的见证。",
                "今天比昨天多一点坚持，明天就比今天多一点改变。",
                "你比自己想象的更强大，迈出第一步就是胜利。"
            ]
        case .enthusiast:
            return [
                "热爱不是三分钟的热度，而是日复一日的坚持。",
                "每一次力竭，都在为更强大的自己积蓄力量。",
                "肌肉的酸痛，是成长最真实的声音。",
                "当你想要放弃的时候，想想当初为什么开始。"
            ]
        case .coach:
            return [
                "以专业之名，引领更多人走向健康之路。",
                "每一次精准指导，都是对信任的最好回应。",
                "你的专业，是他人信赖的基石；你的坚持，是他人前行的灯塔。",
                "科学训练，不仅是技术，更是一种责任。"
            ]
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 全屏模糊背景
            AppleGlassStyle.groupedBackground
                .ignoresSafeArea()

            // MARK: thickMaterial Card

            VStack(spacing: AppleGlassStyle.spacingLG) {

                Spacer()

                // Quote Content
                VStack(spacing: AppleGlassStyle.spacingLG) {
                    Text(quotes[safe: quoteIndex] ?? quotes[0])
                        .font(.title3.weight(.medium))
                        .foregroundStyle(AppleGlassStyle.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, AppleGlassStyle.spacingLG)
                        .animation(.easeInOut(duration: 0.35), value: quoteIndex)

                    // Dot Progress Indicator
                    HStack(spacing: AppleGlassStyle.spacingSM) {
                        ForEach(0..<4, id: \.self) { i in
                            Circle()
                                .fill(i <= quoteIndex ? AppleGlassStyle.accent : AppleGlassStyle.textTertiary.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(i == quoteIndex ? 1.3 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: quoteIndex)
                        }
                    }
                }

                Spacer()

                // Tap prompt
                Text(quoteIndex < 3 ? "轻点屏幕继续阅读" : "轻点屏幕完成")
                    .font(.caption)
                    .foregroundStyle(AppleGlassStyle.textTertiary)

                Spacer()
            }
            .padding(AppleGlassStyle.spacingLG)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 400)
            .background(
                RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium)
                    .fill(.thickMaterial)
            )
            .padding(.horizontal, AppleGlassStyle.spacingLG)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap()
        }
        .navigationBarBackButtonHidden()
    }

    // MARK: - Tap Handler

    private func handleTap() {
        if quoteIndex < 3 {
            withAnimation(.easeInOut(duration: 0.3)) {
                quoteIndex += 1
            }
        } else {
            // 第 4 次点击：标记首次启动已完成，关闭流程
            firstOpenFlag = true
            onFinish()
        }
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
