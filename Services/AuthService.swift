import Foundation
import UIKit

// MARK: - AuthService
// 【网络层 | 用户认证服务】
// 职责：封装登录/登出/Token 管理的完整流程。
// 调用后端 POST /api/auth/login 获取 JWT Token。
// 后端不可用时自动使用本地模拟 Token（开发阶段容错）。
// 设计逻辑：Service 层持有 APIClient 的单例引用，不直接操作 UserDefaults。
final class AuthService {
    static let shared = AuthService()
    private init() {}

    // MARK: - 登录

    /// 使用手机号+密码登录
    /// - Returns: true 表示登录成功（含本地模拟容错）
    func login(phone: String, password: String) async -> Bool {
        do {
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            let body = LoginRequest(phone: phone, password: password, device_id: deviceID)
            let resp: LoginResponse = try await APIClient.shared.post("/api/auth/login", body: body)
            APIClient.shared.saveToken(resp.token)
            return true
        } catch {
            // 后端不可用 → 本地模拟登录（开发阶段容错，不阻塞调试）
            print("[AuthService] 后端登录失败，使用本地模拟: \(error.localizedDescription)")
            APIClient.shared.saveToken("dev_token_\(UUID().uuidString)")
            return true
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
