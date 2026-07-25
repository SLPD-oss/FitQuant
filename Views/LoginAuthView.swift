import SwiftUI

// MARK: - LoginAuthView
// 首次启动专属登录注册页面，对接后端 MySQL 认证
// 页面整体复用项目统一AppleGlassStyle液态玻璃视觉风格

struct LoginAuthView: View {
    // 登录成功回调 → 标记已登录并跳转主页
    var onLoginSuccess: () -> Void

    // 账号密码登录
    @State private var account: String = ""
    @State private var password: String = ""

    // 三方登录模拟弹窗
    @State private var showThirdPartyAlert: Bool = false
    @State private var thirdPartyTitle: String = ""

    // 【注册流程】注册页面弹窗控制
    @State private var showRegisterSheet: Bool = false

    // 【注册流程】励志引导页路由控制（新注册用户首次登录时弹出）
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

    var body: some View {
        ScrollView {
            VStack(spacing: AppleGlassStyle.spacingLG) {
                // 顶部标题区
                headerSection

                // 【网络层对接】后端连接状态提示条
                backendStatusBar

                // 账号密码登录区
                accountLoginSection

                // 没有账号？用户注册
                registerEntrySection

                // 分割线
                dividerSection("其他登录方式")

                // 三方快捷登录图标行
                thirdPartySection

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
        // 【注册流程】注册页面弹窗
        .sheet(isPresented: $showRegisterSheet) {
            RegisterView(onRegisterSuccess: {
                showRegisterSheet = false
                // 注册成功后跳转励志引导页（新用户首次引导）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showMotivationGuide = true
                }
            })
        }
        // 【注册流程】励志引导页 — 新用户注册成功后跳转
        .sheet(isPresented: $showMotivationGuide) {
            MotivationGuideView(onReady: {
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

    // MARK: - 注册入口区
    private var registerEntrySection: some View {
        HStack {
            Spacer()
            Text("没有账号？")
                .font(.subheadline)
                .foregroundColor(AppleGlassStyle.textSecondary)
            Button {
                showRegisterSheet = true
            } label: {
                Text("用户注册")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppleGlassStyle.accent)
            }
            Spacer()
        }
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
            Text("账号密码登录和注册已对接后端 MySQL 数据库")
                .font(.caption).foregroundColor(AppleGlassStyle.textTertiary)
            Text("三方登录当前为本地演示模式")
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

    // MARK: - 登录逻辑函数

    /// 账号密码登录：调用后端 API 验证
    /// 后端不可用时降级到本地模拟登录
    private func performAccountLogin() {
        guard !account.isEmpty, !password.isEmpty else { return }
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
}

// MARK: - RegisterView — 用户注册页面

/// 新用户注册页面，包含手机号、密码、确认密码、昵称
/// 注册成功后自动跳转励志引导页（MotivationGuideView）
struct RegisterView: View {
    /// 注册成功回调：关闭注册页 → 弹出引导页
    var onRegisterSuccess: () -> Void

    // 注册表单字段
    @State private var phone: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var nickname: String = ""

    // 错误提示
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppleGlassStyle.spacingMD) {
                    // 顶部标题
                    VStack(spacing: AppleGlassStyle.spacingSM) {
                        Image(systemName: "person.badge.plus.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(AppleGlassStyle.accent)
                        Text("注册新账号")
                            .font(.title2.weight(.bold))
                            .foregroundColor(AppleGlassStyle.textPrimary)
                        Text("注册后即可开始科学管理你的健身数据")
                            .font(.subheadline)
                            .foregroundColor(AppleGlassStyle.textSecondary)
                    }
                    .padding(.top, AppleGlassStyle.spacingLG)

                    // 注册表单
                    VStack(spacing: AppleGlassStyle.spacingSM) {
                        // 手机号
                        VStack(alignment: .leading, spacing: 4) {
                            Text("手机号").font(.caption).foregroundColor(AppleGlassStyle.textSecondary)
                            TextField("请输入11位手机号", text: $phone)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.plain)
                                .padding(AppleGlassStyle.spacingSM)
                                .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
                        }

                        // 密码
                        VStack(alignment: .leading, spacing: 4) {
                            Text("设置密码").font(.caption).foregroundColor(AppleGlassStyle.textSecondary)
                            SecureField("至少6位密码", text: $password)
                                .textFieldStyle(.plain)
                                .padding(AppleGlassStyle.spacingSM)
                                .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
                        }

                        // 确认密码
                        VStack(alignment: .leading, spacing: 4) {
                            Text("确认密码").font(.caption).foregroundColor(AppleGlassStyle.textSecondary)
                            SecureField("再次输入密码", text: $confirmPassword)
                                .textFieldStyle(.plain)
                                .padding(AppleGlassStyle.spacingSM)
                                .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
                        }

                        // 昵称（选填）
                        VStack(alignment: .leading, spacing: 4) {
                            Text("昵称（选填）").font(.caption).foregroundColor(AppleGlassStyle.textSecondary)
                            TextField("给自己起个名字吧", text: $nickname)
                                .textFieldStyle(.plain)
                                .padding(AppleGlassStyle.spacingSM)
                                .background(AppleGlassStyle.thin, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
                        }
                    }
                    .padding(.horizontal, AppleGlassStyle.spacingMD)

                    // 注册按钮
                    Button {
                        performRegister()
                    } label: {
                        Label("注 册", systemImage: "person.badge.plus")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppleGlassStyle.spacingSM)
                            .background(canRegister ? AppleGlassStyle.accent : Color.gray, in: RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium))
                    }
                    .disabled(!canRegister)
                    .padding(.horizontal, AppleGlassStyle.spacingMD)

                    // 登录入口
                    HStack {
                        Text("已有账号？")
                            .font(.subheadline)
                            .foregroundColor(AppleGlassStyle.textSecondary)
                        Button {
                            dismiss()
                        } label: {
                            Text("返回登录")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppleGlassStyle.accent)
                        }
                    }

                    // 合规提示
                    ComplianceText(text: "注册即表示同意服务条款和隐私政策，数据将加密存储在云端服务器。")
                        .padding(.horizontal, AppleGlassStyle.spacingMD)
                }
                .padding(.bottom, AppleGlassStyle.spacingLG)
            }
            .background(AppleGlassStyle.groupedBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("注册失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    /// 表单是否可提交
    private var canRegister: Bool {
        phone.count == 11
            && password.count >= 6
            && confirmPassword == password
    }

    /// 执行注册请求
    private func performRegister() {
        // 前端校验
        guard phone.count == 11 else {
            errorMessage = "请输入正确的11位手机号"
            showError = true
            return
        }
        guard password.count >= 6 else {
            errorMessage = "密码至少6位"
            showError = true
            return
        }
        guard password == confirmPassword else {
            errorMessage = "两次密码不一致"
            showError = true
            return
        }

        // 调用后端注册 API
        let finalNickname = nickname.trimmingCharacters(in: .whitespaces).isEmpty ? nil : nickname.trimmingCharacters(in: .whitespaces)
        Task {
            let (success, message) = await AuthService.shared.register(
                phone: phone,
                password: password,
                nickname: finalNickname
            )
            await MainActor.run {
                if success {
                    // 注册成功 → 回调关闭当前页 → 弹出 MotivationGuideView
                    onRegisterSuccess()
                } else {
                    errorMessage = message ?? "注册失败，请重试"
                    showError = true
                }
            }
        }
    }
}

#Preview {
    LoginAuthView(onLoginSuccess: {})
}
