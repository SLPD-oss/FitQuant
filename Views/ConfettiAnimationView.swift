import SwiftUI

// MARK: - ConfettiAnimationView
// 【全新重写代码】从屏幕底部向上喷发的彩色礼花粒子动画组件
// 废弃旧版中间放射式动画，全部粒子统一从底部向上飘散渐隐
// 无第三方SDK依赖，可全局复用于任意成功场景

struct ConfettiAnimationView: View {
    @Binding var isPlaying: Bool
    var onFinished: () -> Void

    /// 粒子颜色池
    private let colors: [Color] = [
        .red, .orange, .yellow, .green, .mint,
        .blue, .purple, .pink, .cyan, .indigo
    ]

    @State private var particles: [BottomUpParticle] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    particleView(p)
                }
            }
            .onChange(of: isPlaying) { _, playing in
                if playing { launch(screenHeight: geo.size.height) }
            }
        }
    }

    /// 单个粒子视图
    private func particleView(_ p: BottomUpParticle) -> some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(p.color)
            .frame(width: p.size, height: p.size * 1.5)
            .position(x: p.x, y: p.y)
            .rotationEffect(.degrees(p.rotation))
            .scaleEffect(p.scale)
            .opacity(p.opacity)
    }

    /// 发射粒子：全部从底部向上喷发
    /// 参数可调：particleCount=粒子数，duration=动画时长
    private func launch(screenHeight: CGFloat, particleCount: Int = 70, duration: Double = 2.8) {
        let sw = UIScreen.main.bounds.width

        // 生成所有粒子，初始坐标统一在屏幕底部
        particles = (0..<particleCount).map { i in
            BottomUpParticle(
                id: i,
                x: CGFloat.random(in: 20...(sw - 20)),
                y: screenHeight + 40,          // 初始在最底部
                color: colors.randomElement()!,
                size: CGFloat.random(in: 7...16),
                delay: Double.random(in: 0...0.8),
                duration: duration + Double.random(in: -0.3...0.5),
                driftX: CGFloat.random(in: -60...60),
                initialScale: CGFloat.random(in: 0.6...1.5),
                rotation: Double.random(in: -360...360),
                endY: CGFloat.random(in: -80...(screenHeight * 0.15))
            )
        }

        // 延迟一帧后触发所有粒子向上飘散动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            for i in particles.indices {
                // 粒子向上飞到目标Y + 横向飘移 + 旋转 + 渐隐
                withAnimation(.easeOut(duration: particles[i].duration).delay(particles[i].delay)) {
                    particles[i].y = particles[i].endY
                    particles[i].x += particles[i].driftX
                    particles[i].rotation += particles[i].rotation * 1.5
                    particles[i].opacity = 0
                }
            }
        }

        // 动画结束后回调
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 1.2) {
            isPlaying = false
            onFinished()
        }
    }
}

// MARK: - 底部向上粒子数据模型

struct BottomUpParticle: Identifiable {
    let id: Int
    var x: CGFloat
    var y: CGFloat          // 当前位置（动画驱动）
    let color: Color
    let size: CGFloat
    let delay: Double
    let duration: Double
    let driftX: CGFloat
    let initialScale: CGFloat
    var rotation: Double
    let endY: CGFloat       // 最终目标Y坐标（屏幕顶部区域）
    var opacity: Double = 1.0
    var scale: CGFloat = 0.3
}

#Preview {
    ConfettiAnimationView(isPlaying: .constant(true), onFinished: {})
}
