import Foundation

//【合规隔离红线】APIClient 为占位实现。
// 正式接入真实后端之前，必须完成：
// 1. 传输层加密（TLS 1.3）
// 2. 请求签名与防重放机制
// 3. 敏感字段（药物、身体数据）字段级加密
// 4. 用户知情同意与授权令牌管理
// 未满足以上条件前，禁止将 baseURL 指向公网地址。
final class APIClient {

    // MARK: - Singleton

    static let shared = APIClient()

    private init() {}

    // MARK: - Configuration

    /// 本地开发服务器地址
    let baseURL = "http://127.0.0.1:8000"

    // MARK: - Placeholder

    func healthCheck() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else {
            throw URLError(.badURL)
        }
        let (_, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        return httpResponse.statusCode == 200
    }
}
