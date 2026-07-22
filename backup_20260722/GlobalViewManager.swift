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

    @Published var currentIdentity: UserIdentity = .enthusiast
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
    // 新增：药物风险校验，读取在用药品匹配喹诺酮类风险药物
    // 远期兼容：后端第一套「药物↔训练RAG库」搭建后，可替换此本地黑名单，由RAG库下发权威数据

    /// 喹诺酮类抗生素本地黑名单（肌腱损伤高风险药物）
    private let quinoloneBlacklist: Set<String> = [
        "左氧氟沙星",
        "氧氟沙星",
        "环丙沙星",
        "莫西沙星",
        "诺氟沙星",
        "依诺沙星",
        "洛美沙星",
        "氟罗沙星",
        "司帕沙星",
        "加替沙星"
    ]

    /// 检测当前是否有高风险肌腱损伤药物正在服用
    /// 遍历所有 status != .stopped 的药品，匹配喹诺酮黑名单
    /// - Returns: true 表示存在高风险药物，应触发训练页弹窗警告
    func hasHighTendonRiskMedication() -> Bool {
        let activeDrugs = DrugDataManager.shared.records.filter { $0.status != .stopped }
        for drug in activeDrugs {
            for quinolone in quinoloneBlacklist {
                if drug.drugName.contains(quinolone) {
                    return true
                }
            }
        }
        return false
    }

    private init() {}

    func switchToTab(_ index: Int) {
        guard (0..<5).contains(index) else { return }
        selectedTab = index
    }

    func resetToDefaults() {
        selectedTab = 0
        isPresentingLaunchFlow = false
    }
}
