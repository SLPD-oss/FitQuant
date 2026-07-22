import Foundation

// MARK: - LoginUserStorage
// 【网络层｜登录用户信息持久化存储】
// 职责：将后端返回的用户信息（nickname、identity、user_id、phone）保存到 UserDefaults，
// 供全局各 View 读取。登出时清除。
// 设计逻辑：独立结构体而非 GlobalViewManager 的属性，避免 @MainActor 强绑定。
struct LoginUserStorage {

    // MARK: - Keys

    private static let nicknameKey = "login_user_nickname"
    private static let identityKey = "login_user_identity"
    private static let userIdKey = "login_user_id"
    private static let phoneKey = "login_user_phone"

    // MARK: - 保存

    /// 从登录响应保存用户信息
    static func save(from user: UserInfo) {
        UserDefaults.standard.set(user.nickname, forKey: nicknameKey)
        UserDefaults.standard.set(user.identity, forKey: identityKey)
        UserDefaults.standard.set(user.user_id, forKey: userIdKey)
        UserDefaults.standard.set(user.phone, forKey: phoneKey)
    }

    // MARK: - 读取

    /// 用户昵称，无数据时返回空字符串
    static var userNickname: String {
        UserDefaults.standard.string(forKey: nicknameKey) ?? ""
    }

    /// 用户身份标识，无数据时返回 enthusiast
    static var userIdentity: String {
        UserDefaults.standard.string(forKey: identityKey) ?? "enthusiast"
    }

    static var userId: String? {
        UserDefaults.standard.string(forKey: userIdKey)
    }

    static var userPhone: String? {
        UserDefaults.standard.string(forKey: phoneKey)
    }

    /// 是否有已保存的用户数据
    static var isAvailable: Bool {
        UserDefaults.standard.string(forKey: userIdKey) != nil
    }

    // MARK: - 清除

    /// 登出时清除用户信息
    static func clear() {
        UserDefaults.standard.removeObject(forKey: nicknameKey)
        UserDefaults.standard.removeObject(forKey: identityKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: phoneKey)
    }
}
