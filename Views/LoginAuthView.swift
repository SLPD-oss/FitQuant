import SwiftUI

// MARK: - LoginAuthView
// 首次启动专属登录注册页面，纯前端演示功能，无真实云端交互
// 预留后端账号接口适配层，后期对接云端账号系统仅修改适配层内网络请求逻辑
// 页面整体复用项目统一AppleGlassStyle液态玻璃视觉风格

struct LoginAuthView: View {
    // 登录成功回调 → 标记已登录并跳转主页
    var onLoginSuccess: () -> Void

    // 账号密码登录
    @State private var account: String = ""
    @State private var password: String = ""

    // 手机号一键登录
    @State private var phoneNumber: String = ""

    // 三方登录模拟弹窗
    @State private var showThirdPartyAlert: Bool = false
    @State private var thirdPartyTitle: String = ""

    // 【新增代码】验证码弹窗相关状态 — 新用户注册流程专属控件
    @State private var showVerificationSheet: Bool = false
    @State private var verificationCode: String = ""
    @State private var generatedDemoCode: String = "" // 本地演示用随机生成6位验证码

    // 【新增代码】励志引导页路由控制
    @State private var showMotivationGuide: Bool = false

    // 【网络层对接】登录错误提示
    @State private var showLoginError: Bool = false
    @State private var loginErrorMessage: String = ""

    // 【网络层对接】后端连接状态
    @State private var backendStatus: BackendStatus = .checking

    enum BackendStatus: String {
        case checking = "检查中…"
        case connected = "已连接"
        case disconnected = "未连接"
    }

    // 【新增代码】本地已注册手机号记录，用于区分新用户/老用户
    @AppStorage("registeredPhoneNumbers") private var registeredPhoneNumbers: String = ""

    /// 解析本地存储的手机号数组
    private var registeredPhones: [String] {
        registeredPhoneNumbers.components(separatedBy: ",").filter { $0.count == 11 }
    }

    /// 判断当前输入手机号是否为新用户
    private var isNewUser: Bool {
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespaces)
        return trimmed.count == 11 && !registeredPhones.contains(trimmed)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppleGlassStyle.spacingLG) {
                // 顶部标题区
                headerSection

                // 【网络层对接】后端连接状态提示条
                backendStatusBar

                // 账号密码登录区
                accountLoginSection

                // 分割线
                dividerSection("其他登录方式")

                // 三方快捷登录图标行
                thirdPartySection

                Divider().padding(.horizontal, AppleGlassStyle.spacingLG)

                // 手机号一键登录区
                phoneLoginSection

                // 底部演示说明
                demoDisclaimer
            }
            .padding(.vertical, AppleGlassStyle.spacingLG)
        }
        .background(AppleGlassStyle.groupedBackground)
        // 三方登录模拟授权弹窗
        .sheet(isPresented: $showThirdPartyAlert) {
            thirdPartyMockAlert
        }
        // 【新增代码】验证码输入弹窗 — 新用户手机号注册专属流程
        .sheet(isPresented: $showVerificationSheet) {
            verificationCodeSheet
        }
        // 【新增代码】励志语录引导页 — 新用户验证码提交后跳转
        .sheet(isPresented: $showMotivationGuide) {
            MotivationGuideView(onReady: {
                // 引导完成：标记登录成功，记录手机号为已注册用户
                savePhoneNumberAsRegistered()
                onLoginSuccess()
            })
        }
        // 【网络层对接】登录失败弹窗提示
        .alert("登录失败", isPresented: $showLoginError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(loginErrorMessage)
        }
        // 【网络层对接】页面加载时检查后端连接状态
        .task {
            backendStatus = .checking
            if let healthy = try? await APIClient.shared.healthCheck(), healthy {
                backendStatus = .connected
            } else {
                backendStatus = .disconnected
            }
        }
    }

    // MARK: - 页面标题
    private var headerSection: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppleGlassStyle.accent)

            Text("量化补充")
                .font(.largeTitle.weight(.bold))
                .foregroundColor(AppleGlassStyle.textPrimary)

            Text("科学训练 · 精准管理")
                .font(.subheadline)
                .foregroundColor(AppleGlassStyle.textSecondary)
        }
        .padding(.top, AppleGlassStyle.spacingLG)
    }

    // MARK: - 账号密码登录区
    private var accountLoginSection: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            Text("账号密码登录").font(.headline).foregroundColor(AppleGlassStyle.textPrimary)

            // 手机号登录区：输入手机号和密码
            TextField("请输入手机号", text: $account)
                .textFieldStyle(.plain)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
                .padding(AppleGlassStyle.spacingSM)
                .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))

            SecureField("请输入密码", text: $password)
                .textFieldStyle(.plain)
                .padding(AppleGlassStyle.spacingSM)
                .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))

            // 登录按钮
            Button {
                performAccountLogin()
            } label: {
                Label("登 录", systemImage: "arrow.right.circle.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppleGlassStyle.spacingSM)
                    .background(AppleGlassStyle.accent, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
            }
            .disabled(account.isEmpty || password.isEmpty)
            .opacity(account.isEmpty || password.isEmpty ? 0.5 : 1.0)
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.standard, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
        .padding(.horizontal, AppleGlassStyle.spacingMD)
    }

    // MARK: - 三方快捷登录图标行
    private var thirdPartySection: some View {
        HStack(spacing: AppleGlassStyle.spacingLG) {
            thirdPartyButton(icon: "message.fill", color: .green, title: "微信登录", platform: "微信")
            thirdPartyButton(icon: "bird.fill", color: .blue, title: "QQ登录", platform: "QQ")
            thirdPartyButton(icon: "applelogo", color: .black, title: "苹果登录", platform: "Apple ID")
        }
        .padding(.horizontal, AppleGlassStyle.spacingMD)
    }

    /// 单个三方登录按钮
    private func thirdPartyButton(icon: String, color: Color, title: String, platform: String) -> some View {
        VStack(spacing: AppleGlassStyle.spacingXS) {
            Button {
                // 模拟三方授权弹窗
                thirdPartyTitle = "\(platform) 授权登录（演示）"
                showThirdPartyAlert = true
            } label: {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(color, in: Circle())
            }
            Text(title).font(.caption2).foregroundColor(AppleGlassStyle.textTertiary)
        }
    }

    // MARK: - 手机号一键登录区
    private var phoneLoginSection: some View {
        VStack(spacing: AppleGlassStyle.spacingSM) {
            Text("手机号一键登录/注册").font(.headline).foregroundColor(AppleGlassStyle.textPrimary)

            HStack(spacing: AppleGlassStyle.spacingSM) {
                Text("+86").font(.body).foregroundColor(AppleGlassStyle.textSecondary)
                    .padding(.vertical, AppleGlassStyle.spacingSM)
                    .padding(.horizontal, AppleGlassStyle.spacingSM)
                    .background(AppleGlassStyle.ultraThin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))

                // 任意11位数字均可一键登录
                TextField("请输入11位手机号", text: $phoneNumber)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .padding(AppleGlassStyle.spacingSM)
                    .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
            }

            Button {
                performPhoneLogin()
            } label: {
                Label("一键登录 / 注册", systemImage: "phone.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppleGlassStyle.spacingSM)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
            }
            .disabled(phoneNumber.count != 11)
            .opacity(phoneNumber.count != 11 ? 0.5 : 1.0)

            // 【修改代码】新老用户分支：老用户直接登录，新用户唤起验证码弹窗
            if phoneNumber.count == 11 && registeredPhones.contains(phoneNumber.trimmingCharacters(in: .whitespaces)) {
                // 老用户提示
                Text("⇢ 检测到您已是老用户，点击直接登录")
                    .font(.caption2).foregroundColor(.green)
            } else if phoneNumber.count == 11 {
                // 新用户提示
                Text("⇢ 检测到新手机号，将进入短信验证码注册流程（本地演示）")
                    .font(.caption2).foregroundColor(.orange)
            }
        }
        .padding(AppleGlassStyle.spacingMD)
        .background(AppleGlassStyle.standard, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
        .padding(.horizontal, AppleGlassStyle.spacingMD)
    }

    // MARK: - 三方模拟授权弹窗
    private var thirdPartyMockAlert: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppleGlassStyle.spacingXS) {
                Image(systemName: "info.circle").font(.caption2)
                Text(ComplianceText.alertDisclaimerPrefix).font(.caption2)
                Spacer()
            }
            .foregroundColor(AppleGlassStyle.textTertiary)
            .padding(.horizontal, AppleGlassStyle.spacingSM)
            .padding(.vertical, AppleGlassStyle.spacingXS)
            .background(AppleGlassStyle.ultraThin)

            VStack(spacing: AppleGlassStyle.spacingSM) {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.1)).frame(width: 56, height: 56)
                    Image(systemName: "checkmark.shield.fill").font(.title2).foregroundStyle(.blue)
                }
                Text(thirdPartyTitle).font(.headline).foregroundColor(AppleGlassStyle.textPrimary)

                VStack(alignment: .leading, spacing: AppleGlassStyle.spacingXS) {
                    Text("当前为本地模拟授权演示，无需真实安装\(thirdPartyTitle.prefix(2))客户端。")
                        .font(.subheadline).foregroundColor(AppleGlassStyle.textSecondary)
                    Text("点击「确认授权」后，将模拟完成授权并自动登录App。")
                        .font(.subheadline).foregroundColor(AppleGlassStyle.textSecondary)
                    Text("后期对接真实三方登录SDK时，仅替换此弹窗跳转逻辑，登录页面UI无需改动。")
                        .font(.subheadline.weight(.medium)).foregroundColor(AppleGlassStyle.textTertiary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(AppleGlassStyle.spacingSM)
                .background(Color.blue.opacity(0.04), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))

                Divider().padding(.horizontal, -AppleGlassStyle.spacingSM)

                HStack(spacing: AppleGlassStyle.spacingSM) {
                    Button {
                        showThirdPartyAlert = false
                    } label: {
                        Text("取消").font(.body.weight(.medium))
                            .foregroundColor(AppleGlassStyle.textSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(AppleGlassStyle.ultraThin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
                    }

                    Button {
                        // 模拟授权成功，直接登录
                        showThirdPartyAlert = false
                        onLoginSuccess()
                    } label: {
                        Text("确认授权").font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(AppleGlassStyle.accent, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
                    }
                }
            }
            .padding(AppleGlassStyle.spacingSM)
            .background(AppleGlassStyle.standard)
            .clipShape(RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
        }
        .padding(.horizontal, AppleGlassStyle.spacingMD)
        .padding(.vertical, AppleGlassStyle.spacingMD)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppleGlassStyle.groupedBackground)
        .presentationDetents([.medium])
    }

    // MARK: - 分割线
    private func dividerSection(_ text: String) -> some View {
        HStack {
            Rectangle().frame(height: 1).foregroundColor(AppleGlassStyle.textTertiary.opacity(0.2))
            Text(text).font(.caption).foregroundColor(AppleGlassStyle.textTertiary).fixedSize()
            Rectangle().frame(height: 1).foregroundColor(AppleGlassStyle.textTertiary.opacity(0.2))
        }
        .padding(.horizontal, AppleGlassStyle.spacingMD)
    }

    // MARK: - 底部说明

    private var demoDisclaimer: some View {
        VStack(spacing: AppleGlassStyle.spacingXS) {
            Image(systemName: "info.circle").font(.caption).foregroundColor(AppleGlassStyle.textTertiary)
            Text("账号密码登录已对接后端 MySQL 数据库，使用数据库中录入的手机号+密码登录")
                .font(.caption).foregroundColor(AppleGlassStyle.textTertiary)
            Text("手机号一键登录和三方登录当前为本地演示模式")
                .font(.caption2).foregroundColor(AppleGlassStyle.textTertiary)
        }
        .padding(AppleGlassStyle.spacingSM)
    }

    // MARK: - 后端连接状态提示条

    private var backendStatusBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(backendStatusColor)
                .frame(width: 8, height: 8)
            Text(backendStatus == .checking ? "正在连接后端…" : "后端\(backendStatus.rawValue)")
                .font(.caption2)
                .foregroundColor(backendStatusTextColor)
            if backendStatus == .disconnected {
                Text("（仅本地演示）")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            Spacer()
        }
        .padding(.horizontal, AppleGlassStyle.spacingMD)
        .padding(.vertical, 4)
    }

    private var backendStatusColor: Color {
        switch backendStatus {
        case .checking: return .gray
        case .connected: return .green
        case .disconnected: return .red
        }
    }

    private var backendStatusTextColor: Color {
        switch backendStatus {
        case .checking: return .gray
        case .connected: return .green
        case .disconnected: return .red
        }
    }

    // MARK: - 登录逻辑函数（独立适配层，后端 MySQL 验证）
    // 【网络层对接】从本地模拟改为调用后端 API 验证账号密码
    // 后端查 users 表验证密码哈希，返回真实用户数据

    /// 账号密码登录：调用后端 API 验证
    /// 后端不可用时降级到本地模拟登录
    private func performAccountLogin() {
        guard !account.isEmpty, !password.isEmpty else { return }
        // 显示登录中状态（界面保持不变，0.5s延迟模拟网络请求）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task {
                let (success, message) = await AuthService.shared.login(
                    phone: self.account,
                    password: self.password
                )
                await MainActor.run {
                    if success {
                        self.onLoginSuccess()
                    } else {
                        self.loginErrorMessage = message ?? "登录失败，请重试"
                        self.showLoginError = true
                    }
                }
            }
        }
    }

    /// 手机号一键登录：调用后端 API 验证，后端不可用时降级到本地模拟
    private func performPhoneLogin() {
        guard phoneNumber.count == 11 else { return }
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespaces)

        if registeredPhones.contains(trimmed) {
            // 老用户：调用后端验证密码（默认密码 666666），不走验证码
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Task {
                    let (success, _) = await AuthService.shared.login(
                        phone: trimmed,
                        password: "666666"
                    )
                    if success {
                        await MainActor.run { self.onLoginSuccess() }
                    }
                }
            }
        } else {
            // 新用户：生成演示验证码，唤起验证码弹窗
            generatedDemoCode = String(format: "%06d", Int.random(in: 100000...999999))
            verificationCode = ""
            showVerificationSheet = true
        }
    }

    /// 【新增代码】将当前手机号保存为已注册用户
    /// 远期云端兼容：后期替换为云端用户注册接口，本地记录仅作缓存
    private func savePhoneNumberAsRegistered() {
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespaces)
        guard trimmed.count == 11 else { return }
        var phones = registeredPhones
        if !phones.contains(trimmed) {
            phones.append(trimmed)
            registeredPhoneNumbers = phones.joined(separator: ",")
        }
    }

    // MARK: - 【新增代码】验证码输入弹窗
    // 新用户注册专属流程，本地演示随机生成6位数字验证码
    // 封装独立短信接口适配函数，后期对接云端短信服务仅修改适配层内部逻辑

    private var verificationCodeSheet: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppleGlassStyle.spacingXS) {
                Image(systemName: "info.circle").font(.caption2)
                Text(ComplianceText.alertDisclaimerPrefix).font(.caption2)
                Spacer()
            }
            .foregroundColor(AppleGlassStyle.textTertiary)
            .padding(.horizontal, AppleGlassStyle.spacingSM)
            .padding(.vertical, AppleGlassStyle.spacingXS)
            .background(AppleGlassStyle.ultraThin)

            VStack(spacing: AppleGlassStyle.spacingSM) {
                ZStack {
                    Circle().fill(Color.orange.opacity(0.1)).frame(width: 56, height: 56)
                    Image(systemName: "envelope.badge.fill").font(.title2).foregroundStyle(.orange)
                }

                Text("短信验证码").font(.headline).foregroundColor(AppleGlassStyle.textPrimary)

                VStack(alignment: .leading, spacing: AppleGlassStyle.spacingXS) {
                    Text("验证码已发送至 \(phoneNumber)（本地演示）")
                        .font(.subheadline).foregroundColor(AppleGlassStyle.textSecondary)

                    // 显示演示验证码
                    HStack {
                        Text("演示验证码：")
                            .font(.subheadline.weight(.medium)).foregroundColor(AppleGlassStyle.textSecondary)
                        Text(generatedDemoCode)
                            .font(.title2.weight(.bold)).foregroundColor(.orange)
                        Spacer()
                        Button("重新发送") {
                            generatedDemoCode = String(format: "%06d", Int.random(in: 100000...999999))
                        }
                        .font(.caption).foregroundColor(AppleGlassStyle.accent)
                    }
                    .padding(AppleGlassStyle.spacingSM)
                    .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))

                    // 验证码输入框
                    TextField("请输入6位验证码", text: $verificationCode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .font(.title2.weight(.bold))
                        .padding(AppleGlassStyle.spacingSM)
                        .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))

                    Text("后期对接真实短信服务时，此处改为真实下发的验证码")
                        .font(.caption2).foregroundColor(AppleGlassStyle.textTertiary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(AppleGlassStyle.spacingSM)
                .background(Color.orange.opacity(0.04), in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusSmall))

                Divider().padding(.horizontal, -AppleGlassStyle.spacingSM)

                // 确认提交按钮
                Button {
                    guard verificationCode.count >= 1 else { return }
                    // 验证码提交成功 → 关闭弹窗 → 跳转励志引导页
                    showVerificationSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showMotivationGuide = true
                    }
                } label: {
                    Text("确认提交")
                        .font(.headline.weight(.semibold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, AppleGlassStyle.spacingSM)
                        .background(AppleGlassStyle.accent, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
                }
                .disabled(verificationCode.isEmpty)
                .opacity(verificationCode.isEmpty ? 0.5 : 1.0)
            }
            .padding(AppleGlassStyle.spacingSM)
            .background(AppleGlassStyle.standard)
            .clipShape(RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
        }
        .padding(.horizontal, AppleGlassStyle.spacingMD)
        .padding(.vertical, AppleGlassStyle.spacingMD)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppleGlassStyle.groupedBackground)
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    LoginAuthView(onLoginSuccess: {})
}
