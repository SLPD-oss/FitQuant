import Foundation
import SwiftUI

// MARK: - DrugCatalogEntry
/// 药物目录条目：本地静态药物库，用于添加药物时的搜索匹配、分类自动填充与运动建议提示。
/// 数据来源与后端 mock.py 中已具备风险判断逻辑的药物保持一致。
struct DrugCatalogEntry: Identifiable, Decodable, Equatable {
    let id: String
    let name: String
    let aliases: [String]
    let category: String          // 对应 DrugCategory.rawValue
    let isPrescription: Bool
    let riskLevel: String         // "high" / "medium" / "low"
    let riskTags: [String]
    let affectedParts: [String]
    let suggestion: String        // 运动建议文案

    enum CodingKeys: String, CodingKey {
        case id, name, aliases, category, isPrescription, riskLevel, riskTags, affectedParts, suggestion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decode(String.self, forKey: .name)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "other"
        isPrescription = try c.decodeIfPresent(Bool.self, forKey: .isPrescription) ?? false
        riskLevel = try c.decodeIfPresent(String.self, forKey: .riskLevel) ?? "low"
        riskTags = try c.decodeIfPresent([String].self, forKey: .riskTags) ?? []
        affectedParts = try c.decodeIfPresent([String].self, forKey: .affectedParts) ?? []
        suggestion = try c.decodeIfPresent(String.self, forKey: .suggestion) ?? ""
    }

    /// 风险等级颜色语义（与全局风险提示风格一致）
    var riskColor: Color {
        switch riskLevel {
        case "high": return .red
        case "medium": return .orange
        default: return .green
        }
    }

    var riskLabel: String {
        switch riskLevel {
        case "high": return "高风险"
        case "medium": return "中风险"
        default: return "低风险"
        }
    }

    /// 是否为药品分类（非补剂）——与 MedicineView.isDrugCategory 保持一致
    var isDrugCategory: Bool {
        switch DrugCategory(rawValue: category) {
        case .traditionalChMedicine, .typeA, .typeB, .other: return true
        default: return false
        }
    }
}

// MARK: - DrugCatalogService
/// 本地药物目录搜索服务
/// 职责：提供添加药物时的实时搜索匹配（名称/别名模糊匹配）、分类自动填充与运动建议。
/// 存储：静态 JSON 内嵌于代码（随版本发布），离线可用、毫秒级响应，不依赖后端网络。
final class DrugCatalogService {

    static let shared = DrugCatalogService()

    /// 静态药物目录（与后端 mock.py 已具备风险判断逻辑的药物对齐）
    private static let catalogJSON = """
    [
      {
        "name": "左氧氟沙星",
        "aliases": ["可乐必妥", "Levofloxacin"],
        "category": "typeB",
        "isPrescription": true,
        "riskLevel": "high",
        "riskTags": ["喹诺酮类", "肌腱损伤高风险"],
        "affectedParts": ["肩袖肌腱", "跟腱"],
        "suggestion": "高强度抗阻训练可能加重肌腱炎风险，建议降低大重量推拉动作负荷，待停药后逐步恢复。"
      },
      {
        "name": "氧氟沙星",
        "aliases": ["奥复星", "Ofloxacin"],
        "category": "typeB",
        "isPrescription": true,
        "riskLevel": "high",
        "riskTags": ["喹诺酮类", "肌腱损伤高风险"],
        "affectedParts": ["肩袖肌腱", "跟腱"],
        "suggestion": "高强度抗阻训练可能加重肌腱炎风险，建议降低大重量推拉动作负荷。"
      },
      {
        "name": "环丙沙星",
        "aliases": ["悉复欢", "Ciprofloxacin"],
        "category": "typeB",
        "isPrescription": true,
        "riskLevel": "high",
        "riskTags": ["喹诺酮类", "肌腱损伤高风险"],
        "affectedParts": ["肩袖肌腱", "跟腱"],
        "suggestion": "高强度抗阻训练可能加重肌腱炎风险，建议降低大重量推拉动作负荷。"
      },
      {
        "name": "莫西沙星",
        "aliases": ["拜复乐", "Moxifloxacin"],
        "category": "typeB",
        "isPrescription": true,
        "riskLevel": "high",
        "riskTags": ["喹诺酮类", "肌腱损伤高风险"],
        "affectedParts": ["肩袖肌腱", "跟腱"],
        "suggestion": "高强度抗阻训练可能加重肌腱炎风险，建议降低大重量推拉动作负荷。"
      },
      {
        "name": "诺氟沙星",
        "aliases": ["氟哌酸", "Norfloxacin"],
        "category": "typeB",
        "isPrescription": true,
        "riskLevel": "high",
        "riskTags": ["喹诺酮类", "肌腱损伤高风险"],
        "affectedParts": ["肩袖肌腱", "跟腱"],
        "suggestion": "高强度抗阻训练可能加重肌腱炎风险，建议降低大重量推拉动作负荷。"
      },
      {
        "name": "布洛芬",
        "aliases": ["芬必得", "Ibuprofen"],
        "category": "typeA",
        "isPrescription": false,
        "riskLevel": "low",
        "riskTags": ["NSAIDs", "低运动风险"],
        "affectedParts": [],
        "suggestion": "非甾体抗炎药，常规运动负荷下风险较低，运动前咨询医师。"
      },
      {
        "name": "六味地黄丸",
        "aliases": ["六味地黄"],
        "category": "traditionalChMedicine",
        "isPrescription": false,
        "riskLevel": "low",
        "riskTags": ["中药", "低运动风险"],
        "affectedParts": [],
        "suggestion": "中药制剂，常规运动风险较低，按医师建议服用。"
      },
      {
        "name": "阿托伐他汀",
        "aliases": ["立普妥", "Atorvastatin"],
        "category": "typeB",
        "isPrescription": true,
        "riskLevel": "medium",
        "riskTags": ["他汀类", "肌肉损伤风险"],
        "affectedParts": ["大腿肌群", "背部肌群"],
        "suggestion": "他汀类药物可能引起肌肉酸痛，大强度训练期间关注肌肉异常，必要时咨询医师。"
      }
    ]
    """

    private let allEntries: [DrugCatalogEntry]

    private init() {
        guard let data = Self.catalogJSON.data(using: .utf8),
              let entries = try? JSONDecoder().decode([DrugCatalogEntry].self, from: data) else {
            allEntries = []
            return
        }
        allEntries = entries
    }

    /// 按关键词搜索药物（名称或别名模糊匹配，不区分大小写）
    /// - 优先返回名称精确/前缀匹配的条目
    func search(keyword: String) -> [DrugCatalogEntry] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lower = trimmed.lowercased()
        return allEntries.filter { entry in
            entry.name.lowercased().contains(lower) ||
            entry.aliases.contains { $0.lowercased().contains(lower) }
        }
    }

    /// 按名称精确匹配药物（用于已保存记录的关联展示）
    func entry(named name: String) -> DrugCatalogEntry? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allEntries.first { $0.name.lowercased() == trimmed }
    }
}
