import SwiftUI

// MARK: - GlobalViewManager
// Centralized singleton for coordinating global UI state and user identity.

@MainActor
final class GlobalViewManager: ObservableObject {
    static let shared = GlobalViewManager()

    // MARK: User Identity
    enum UserIdentity: String, CaseIterable {
        case beginner = "简易"
        case enthusiast = "爱好者"
        case coach = "教练"

        var supplementModuleCount: Int {
            switch self {
            case .beginner: return 3
            case .enthusiast: return 5
            case .coach: return 7
            }
        }

        var labelSuffix: String { "" }
    }

    @Published var currentIdentity: UserIdentity = .enthusiast {
        didSet { syncIdentityToPublished() }
    }
    //【已修复】原 userIdentity 重命名为 currentIdentity 以匹配外部调用，删除重复声明

    @Published var labelSuffix: String = ""

    @Published var supplementModuleCount: Int = 5 {
        didSet {
            let valid = [3, 5, 7]
            if !valid.contains(supplementModuleCount) {
                supplementModuleCount = valid.min(by: {
                    abs($0 - oldValue) < abs($1 - oldValue)
                }) ?? 5
            }
        }
    }

    // MARK: Tab & Navigation
    @Published var selectedTab: Int = 0
    @Published var isPresentingLaunchFlow: Bool = false

    // MARK: Drug-Training Risk Validation
    // 【解耦改动】药物风险校验逻辑已迁移至 DrugRiskService
    // 此处仅保留兼容方法委托给 DrugRiskService，确保 TrainView 等调用方无感知

    // MARK: Drug-Training Risk Validation
    // 【解耦改动】药物风险校验逻辑已迁移至 DrugRiskService
    // TrainView 已改用 drugRiskService.hasHighTendonRiskFromAPI() 异步方法

    private init() {
        // 【网络层对接】从存储中读取后端返回的真实 identity
        if let storedIdentity = UserIdentity(rawValue: LoginUserStorage.userIdentity) {
            currentIdentity = storedIdentity
        }
    }

    func switchToTab(_ index: Int) {
        guard (0..<5).contains(index) else { return }
        selectedTab = index
    }

    /// 当 identity 变化时同步到 supplementModuleCount 和 labelSuffix
    private func syncIdentityToPublished() {
        supplementModuleCount = currentIdentity.supplementModuleCount
        labelSuffix = ""
    }

    func resetToDefaults() {
        selectedTab = 0
        isPresentingLaunchFlow = false
    }
}
