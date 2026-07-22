import Foundation

// MARK: - APIError
// 【网络层 | API 统一错误类型】
// 设计逻辑：区分"网络不可用"(抛 networkUnavailable 触发 Service 降级)
// 和"业务错误"(抛 businessError)。Service 层 catch 到 networkUnavailable 时
// 自动降级到本地模拟数据，用户无感知。
enum APIError: LocalizedError {
    case invalidURL
    case networkUnavailable          // 网络不可用 → 触发 Service 层本地降级
    case serverError(statusCode: Int)
    case decodeFailed
    case unauthorized                // 401 → 清除 Token
    case businessError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: return "网络不可用"
        case .unauthorized: return "登录已过期"
        case .serverError(let code): return "服务器错误(\(code))"
        case .businessError(_, let msg): return msg
        case .invalidURL: return "地址错误"
        case .decodeFailed: return "数据解析失败"
        }
    }

    /// 是否为网络层错误（用于 Service 层判断是否降级到本地逻辑）
    var isNetworkError: Bool {
        if case .networkUnavailable = self { return true }
        if case .serverError(let code) = self, code >= 500 { return true }
        return false
    }
}

// MARK: - APIResponse
/// 后端统一响应结构：{ code: 0, message: "ok", data: {...} }
struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
}

// MARK: - APIClient
// 【网络层 | 统一异步 HTTP 客户端】
// 职责：所有 API 请求的唯一入口，封装 GET/POST/PUT、JWT Token 管理、
// 统一 JSON 解析、错误码处理。Service 层通过 APIClient.shared 调用。
final class APIClient {
    static let shared = APIClient()
    private init() {}

    /// 后端地址（开发环境指向本地 FastAPI）
    var baseURL = "http://127.0.0.1:8000"

    // MARK: - Token 管理

    private var token: String? {
        get { UserDefaults.standard.string(forKey: "api_token") }
        set { UserDefaults.standard.set(newValue, forKey: "api_token") }
    }

    var isLoggedIn: Bool { token != nil }

    func saveToken(_ newToken: String) { token = newToken }
    func clearToken() { token = nil }

    // MARK: - 通用请求构建

    private func buildRequest(
        method: String,
        path: String,
        body: (any Encodable)? = nil
    ) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 10

        // 自动附加 JWT Token
        if let token = token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // 编码请求体
        if let body = body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }
        return req
    }

    // MARK: - 通用请求执行

    /// 发送请求并解析返回的 data 字段为 T 类型
    func request<T: Decodable>(
        method: String = "GET",
        path: String,
        body: (any Encodable)? = nil
    ) async throws -> T {
        let req = try buildRequest(method: method, path: path, body: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            // 网络不可达（超时/无网络）→ 抛出 networkUnavailable 触发降级
            throw APIError.networkUnavailable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError(statusCode: 0)
        }

        // 401 → Token 过期，清除 Token
        if httpResponse.statusCode == 401 {
            clearToken()
            throw APIError.unauthorized
        }

        // 非 2xx → 服务器错误
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }

        // 解析统一响应体 { code, message, data }
        let decoder = JSONDecoder()
        guard let apiResp = try? decoder.decode(APIResponse<T>.self, from: data) else {
            throw APIError.decodeFailed
        }

        // 业务错误码非 0
        if apiResp.code != 0 {
            throw APIError.businessError(code: apiResp.code, message: apiResp.message)
        }

        guard let result = apiResp.data else {
            throw APIError.decodeFailed
        }
        return result
    }

    // MARK: - 便捷方法

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await request(method: "GET", path: path)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await request(method: "POST", path: path, body: body)
    }

    func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await request(method: "PUT", path: path, body: body)
    }

    func healthCheck() async throws -> Bool {
        let _: String = try await get("/health")
        return true
    }
}

// MARK: - AnyEncodable
/// 擦除 Encodable 的具体类型，使任意 Encodable 结构体可通过 URLRequest.httpBody 传递
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ wrapped: any Encodable) {
        _encode = { try wrapped.encode(to: $0) }
    }
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
