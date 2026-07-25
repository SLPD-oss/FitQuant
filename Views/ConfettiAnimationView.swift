import SwiftUI

// MARK: - ConfettiAnimationView
// 【全面增强版礼花动画】— 无第三方依赖，纯 SwiftUI
//
// 增强内容：
// P0: 5 种粒子形状混合（矩/圆/星星/心形/火花）
// P1: 双波次发射（主波 60 + 副波 40）+ 弧线抛物线轨迹
// P2: Liquid Glass 毛玻璃光晕质感（thin 材质 + 阴影 + 环境光）
// P3: 二次爆裂收尾（主波结束后中心爆裂 18 粒）
//

struct ConfettiAnimationView: View {
    @Binding var isPlaying: Bool
    var onFinished: () -> Void

    // MARK: - 粒子颜色池（明亮高饱和）
    private let colors: [Color] = [
        .red, .orange, .yellow, .green, .mint,
        .blue, .purple, .pink, .cyan, .indigo
    ]

    /// 粒子形状类型（5 种混合）
    enum ParticleShape: CaseIterable {
        case rectangle  // 矩形纸片
        case circle     // 圆点
        case star       // 星星 ★
        case heart      // 心形 ♥
        case sparkle    // 火花 ✦
    }

    @State private var particles: [ConfettiParticle] = []
    @State private var burstParticles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 主粒子层（双波次）
                ForEach(particles) { p in
                    builtParticleView(p)
                }
                // 二次爆裂粒子层（在屏幕中上方爆开）
                ForEach(burstParticles) { p in
                    builtParticleView(p)
                }
            }
            .onChange(of: isPlaying) { _, playing in
                if playing { launch(screenHeight: geo.size.height, screenWidth: geo.size.width) }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - 单个粒子视图（形状分发 + Liquid Glass 材质）

    @ViewBuilder
    private func builtParticleView(_ p: ConfettiParticle) -> some View {
        // 基础形状/图标
        Group {
            switch p.shape {
            case .rectangle:
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(p.color)
                    .frame(width: p.size, height: p.size * 1.5)
            case .circle:
                Circle()
                    .fill(p.color)
                    .frame(width: p.size, height: p.size)
            case .star:
                Image(systemName: "star.fill")
                    .font(.system(size: p.size * 0.9))
                    .foregroundColor(p.color)
            case .heart:
                Image(systemName: "heart.fill")
                    .font(.system(size: p.size * 0.9))
                    .foregroundColor(p.color)
            case .sparkle:
                Image(systemName: "sparkle")
                    .font(.system(size: p.size * 0.9))
                    .foregroundColor(p.color)
            }
        }
        // 【P2: Liquid Glass 光晕】底层环境光（模糊大圆）
        .background(
            Circle()
                .fill(p.color.opacity(0.15))
                .blur(radius: 6)
                .frame(width: p.size * 3, height: p.size * 3)
        )
        // 【P2: Liquid Glass 光泽】薄玻璃材质叠加（仅非图标粒子）
        .overlay(
            Group {
                if p.shape == .rectangle || p.shape == .circle {
                    AppleGlassStyle.ultraThin
                        .clipShape(p.shape == .rectangle
                            ? AnyShape(RoundedRectangle(cornerRadius: 2.5))
                            : AnyShape(Circle()))
                        .frame(width: p.shape == .rectangle ? p.size : p.size,
                               height: p.shape == .rectangle ? p.size * 1.5 : p.size)
                }
            }
        )
        // 【P2: Liquid Glass 阴影】发光描边效果
        .shadow(color: p.color.opacity(0.5), radius: 3, x: 0, y: 0)
        // 位置/旋转/缩放/透明度
        .position(x: p.x, y: p.y)
        .rotationEffect(.degrees(p.rotation))
        .scaleEffect(p.scale)
        .opacity(p.opacity)
    }

    // MARK: - 发射入口（双波次 + 二次爆裂）

    /// 主发射函数：
    /// - 第一波 60 粒（延迟 0~0.4s）
    /// - 第二波 40 粒（延迟 0.6~1.0s）
    /// - 2.0s 后中心二次爆裂 18 粒
    private func launch(screenHeight: CGFloat, screenWidth: CGFloat) {
        let shapes = ParticleShape.allCases

        // 第一波：主波 60 粒
        let wave1 = (0..<60).map { i in
            makeParticle(id: i, sw: screenWidth, sh: screenHeight,
                         shapes: shapes, delayRange: 0...0.4, isWave2: false)
        }
        // 第二波：副波 40 粒
        let wave2 = (60..<100).map { i in
            makeParticle(id: i, sw: screenWidth, sh: screenHeight,
                         shapes: shapes, delayRange: 0.6...1.0, isWave2: true)
        }
        particles = wave1 + wave2

        // ---- 触发主粒子动画 ----
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            for i in particles.indices {
                let p = particles[i]
                // 【P1: 垂直上升】easeOut 先快后慢
                withAnimation(.easeOut(duration: p.riseDuration).delay(p.delay)) {
                    particles[i].y = p.endY
                }
                // 【P1: 水平弧线】easeInOut 左右摆动，形成弧线轨迹
                withAnimation(.easeInOut(duration: p.arcDuration).delay(p.delay)) {
                    particles[i].x += p.driftX
                }
                // 旋转
                withAnimation(.linear(duration: p.spinDuration).delay(p.delay)) {
                    particles[i].rotation += p.rotationDelta
                }
                // 缩放展开
                withAnimation(.easeOut(duration: p.riseDuration * 0.5).delay(p.delay)) {
                    particles[i].scale = 1.0
                }
                // 【P1: 渐隐】在上升后半段才开始消失
                withAnimation(.easeIn(duration: 0.5).delay(p.delay + p.riseDuration * 0.55)) {
                    particles[i].opacity = 0
                }
            }
        }

        // ---- 【P3: 二次爆裂】2.0s 后在屏幕中上区域爆裂 ----
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            burstParticles = (0..<18).map { i in
                let angle = Double(i) * 20.0
                let radius = CGFloat.random(in: 50...140)
                return ConfettiParticle(
                    id: i + 1000,
                    x: screenWidth / 2 + CGFloat.random(in: -30...30),
                    y: screenHeight * 0.35 + CGFloat.random(in: -30...30),
                    endY: screenHeight * 0.35 - sin(angle * .pi / 180) * radius * 0.6,
                    color: colors.randomElement()!,
                    size: CGFloat.random(in: 6...14),
                    shape: shapes.randomElement()!,
                    delay: Double(i) * 0.025,
                    riseDuration: 0.7 + Double.random(in: 0...0.2),
                    arcDuration: 0.8 + Double.random(in: 0...0.2),
                    spinDuration: 1.0,
                    driftX: CGFloat.random(in: -80...80),
                    rotationDelta: Double.random(in: -300...300),
                    scale: 0.2,
                    rotation: 0,
                    opacity: 1.0
                )
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                for i in burstParticles.indices {
                    let bp = burstParticles[i]
                    // 爆裂扩散（弹簧效果更灵动）
                    withAnimation(.interpolatingSpring(stiffness: 120, damping: 7).delay(bp.delay)) {
                        burstParticles[i].x += bp.driftX
                        burstParticles[i].y = bp.endY
                        burstParticles[i].scale = 1.0
                        burstParticles[i].rotation += bp.rotationDelta
                    }
                    // 爆裂渐隐
                    withAnimation(.easeIn(duration: 0.3).delay(bp.delay + 0.5)) {
                        burstParticles[i].opacity = 0
                    }
                }
            }
        }

        // 整个动画结束回调（3.5s 后）
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            isPlaying = false
            onFinished()
        }
    }

    // MARK: - 粒子工厂

    /// 创建一个粒子，参数随机化 + 波次差异化
    private func makeParticle(id: Int, sw: CGFloat, sh: CGFloat,
                              shapes: [ParticleShape],
                              delayRange: ClosedRange<Double>,
                              isWave2: Bool) -> ConfettiParticle {
        // 第二波粒子更小、飘得更低
        let sizeRange: ClosedRange<CGFloat> = isWave2 ? 6...13 : 7...16
        let endYRange: ClosedRange<CGFloat> = isWave2 ?
            -60...(sh * 0.25) : -80...(sh * 0.15)
        let driftRange: ClosedRange<CGFloat> = isWave2 ? -60...60 : -80...80

        // 弧线参数：垂直上升和水平漂移用不同时长，形成自然抛物线
        let riseDur = 2.0 + Double.random(in: -0.3...0.5)
        let arcDur = riseDur * CGFloat.random(in: 1.1...1.4)  // 水平弧线比垂直慢
        let spinDur = riseDur * CGFloat.random(in: 1.2...2.0) // 旋转持续更久

        return ConfettiParticle(
            id: id,
            x: CGFloat.random(in: 30...(sw - 30)),
            y: sh + 40,
            endY: CGFloat.random(in: endYRange),
            color: colors.randomElement()!,
            size: CGFloat.random(in: sizeRange),
            shape: shapes.randomElement()!,
            delay: Double.random(in: delayRange),
            riseDuration: riseDur,
            arcDuration: arcDur,
            spinDuration: max(spinDur, 1.5),
            driftX: CGFloat.random(in: driftRange),
            rotationDelta: Double.random(in: -200...200),
            scale: 0.2 + CGFloat.random(in: 0...0.2),
            rotation: Double.random(in: -30...30),
            opacity: 1.0
        )
    }
}

// MARK: - AnyShape（形状擦除包装器）

struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    init<S: Shape>(_ shape: S) {
        _path = { rect in shape.path(in: rect) }
    }
    func path(in rect: CGRect) -> Path { _path(rect) }
}

// MARK: - ConfettiParticle 粒子数据模型

struct ConfettiParticle: Identifiable {
    let id: Int

    // 位置动画
    var x: CGFloat          // 当前 X（动画驱动）
    var y: CGFloat          // 当前 Y（动画驱动）
    let endY: CGFloat       // 目标 Y

    // 外观
    let color: Color
    let size: CGFloat
    let shape: ConfettiAnimationView.ParticleShape

    // 时间参数
    let delay: Double
    let riseDuration: Double  // 垂直上升时长
    let arcDuration: Double   // 水平弧线时长
    let spinDuration: Double  // 旋转持续时长

    // 运动参数
    let driftX: CGFloat       // 水平漂移量
    let rotationDelta: Double // 旋转总角度

    // 动画状态
    var scale: CGFloat
    var rotation: Double
    var opacity: Double
}

#Preview {
    ConfettiAnimationView(isPlaying: .constant(true), onFinished: {})
}
