import Foundation

// MARK: - AuthService
// 【网络层 | 用户认证服务】
// 职责：封装登录/登出/Token 管理的完整流程。
// 调用后端 POST /api/auth/login 获取 JWT Token。
// 设计逻辑：
// - 网络错误（后端未启动/超时）→ 降级到本地模拟 Token，不阻塞调试
// - 业务错误（密码错误/用户不存在）→ 返回 false，交给 View 层提示用户
final class AuthService {
    static let shared = AuthService()
    private init() {}

    // MARK: - 登录

    /// 使用手机号+密码登录
    /// - Returns: (success: Bool, message: String?) — message 在失败时包含后端返回的错误描述
    func login(phone: String, password: String) async -> (success: Bool, message: String?) {
        do {
            let deviceID = UUID().uuidString
            let body = LoginRequest(phone: phone, password: password, device_id: deviceID)
            let resp: LoginResponse = try await APIClient.shared.post("/api/auth/login", body: body)
            APIClient.shared.saveToken(resp.token)
            // 【网络层对接】保存真实用户信息到 UserDefaults，供全局读取
            LoginUserStorage.save(from: resp.user)
            print("[AuthService] 登录成功: \(resp.user.nickname)")
            return (true, nil)
        } catch let error as APIError {
            switch error {
            case .networkUnavailable:
                // 后端未启动/网络不可用 → 降级到本地模拟登录（开发容错）
                print("[AuthService] 后端不可达，降级到本地模拟: \(error.localizedDescription)")
                APIClient.shared.saveToken("dev_token_\(UUID().uuidString)")
                return (true, nil)
            case .businessError(let code, let message):
                // 业务错误：密码错误、用户不存在 → 返回失败信息给 View 层
                print("[AuthService] 登录失败: code=\(code) \(message)")
                return (false, message)
            case .unauthorized:
                return (false, "登录已过期，请重试")
            default:
                // 其他网络错误也降级
                print("[AuthService] 网络错误，降级到本地模拟: \(error.localizedDescription)")
                APIClient.shared.saveToken("dev_token_\(UUID().uuidString)")
                return (true, nil)
            }
        } catch {
            print("[AuthService] 未知错误，降级到本地模拟: \(error.localizedDescription)")
            APIClient.shared.saveToken("dev_token_\(UUID().uuidString)")
            return (true, nil)
        }
    }

    // MARK: - 注册

    /// 使用手机号+密码注册新账号
    /// - Returns: (success: Bool, message: String?) — 成功或失败的错误描述
    func register(phone: String, password: String, nickname: String?) async -> (success: Bool, message: String?) {
        do {
            let body = RegisterRequest(phone: phone, password: password, nickname: nickname, identity: "enthusiast")
            let resp: LoginResponse = try await APIClient.shared.post("/api/auth/register", body: body)
            APIClient.shared.saveToken(resp.token)
            LoginUserStorage.save(from: resp.user)
            print("[AuthService] 注册成功: \(resp.user.nickname)")
            return (true, nil)
        } catch let error as APIError {
            switch error {
            case .businessError(let code, let message):
                print("[AuthService] 注册失败: code=\(code) \(message)")
                return (false, message)
            case .networkUnavailable:
                print("[AuthService] 后端不可达，降级注册")
                APIClient.shared.saveToken("dev_token_\(UUID().uuidString)")
                // 降级时也模拟保存用户信息
                LoginUserStorage.saveMock(phone: phone, nickname: nickname ?? "用户" + phone.suffix(4))
                return (true, nil)
            default:
                print("[AuthService] 注册网络错误，降级: \(error.localizedDescription)")
                APIClient.shared.saveToken("dev_token_\(UUID().uuidString)")
                LoginUserStorage.saveMock(phone: phone, nickname: nickname ?? "用户" + phone.suffix(4))
                return (true, nil)
            }
        } catch {
            print("[AuthService] 注册未知错误，降级: \(error.localizedDescription)")
            APIClient.shared.saveToken("dev_token_\(UUID().uuidString)")
            LoginUserStorage.saveMock(phone: phone, nickname: nickname ?? "用户" + phone.suffix(4))
            return (true, nil)
        }
    }

    // MARK: - 状态查询

    /// 当前是否已登录（Token 是否存在）
    var isLoggedIn: Bool {
        APIClient.shared.isLoggedIn
    }

    // MARK: - 登出

    /// 清除 Token，退出登录
    func logout() {
        APIClient.shared.clearToken()
    }
}
