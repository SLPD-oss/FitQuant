import SwiftUI

// MARK: - Page4_IdentitySelectView (身份选择)

/// 【设计规范】用户选择身份类型：普通减脂用户 / 健身爱好者 / 专业教练
struct Page4_IdentitySelectView: View {

    // MARK: - State

    @State private var selectedIdentity: IdentityOption = .beginner

    // MARK: - Callbacks

    var onContinue: () -> Void

    // MARK: - Identity Options

    enum IdentityOption: String, CaseIterable, Identifiable {
        case beginner
        case enthusiast
        case coach

        var id: String { rawValue }

        var title: String {
            switch self {
            case .beginner:   return "普通减脂用户"
            case .enthusiast: return "健身爱好者"
            case .coach:      return "专业教练"
            }
        }

        var subtitle: String {
            switch self {
            case .beginner:
                return "刚开始减脂旅程，希望科学瘦身"
            case .enthusiast:
                return "规律训练，追求更优体态与体能"
            case .coach:
                return "持有专业认证，为学员提供指导"
            }
        }

        var iconName: String {
            switch self {
            case .beginner:   return "figure.walk"
            case .enthusiast: return "figure.strengthtraining.traditional"
            case .coach:      return "figure.cooldown"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: AppleGlassStyle.spacingLG) {

            // MARK: Header

            VStack(spacing: AppleGlassStyle.spacingSM) {
                Text("选择您的身份")
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppleGlassStyle.textPrimary)

                Text("以便为您提供更精准的训练建议与内容")
                    .font(.subheadline)
                    .foregroundStyle(AppleGlassStyle.textSecondary)
            }
            .padding(.top, AppleGlassStyle.spacingLG)

            Spacer()

            // MARK: Identity Selection Cards

            VStack(spacing: AppleGlassStyle.spacingMD) {
                ForEach(IdentityOption.allCases) { option in
                    identityCard(option)
                }
            }
            .padding(.horizontal, AppleGlassStyle.spacingLG)

            Spacer()

            // MARK: Confirm Button

            Button {
                GlobalViewManager.shared.currentIdentity = selectedIdentity.toGlobalIdentity
                onContinue()
            } label: {
                Text("确认选择")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppleGlassStyle.spacingMD)
                    .background(
                        RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium)
                            .fill(AppleGlassStyle.accent)
                    )
            }
            .padding(.horizontal, AppleGlassStyle.spacingLG)
            .padding(.bottom, AppleGlassStyle.spacingLG)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppleGlassStyle.groupedBackground)
        .navigationBarBackButtonHidden()
    }

    // MARK: - View Components

    @ViewBuilder
    private func identityCard(_ option: IdentityOption) -> some View {
        let isSelected = selectedIdentity == option

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedIdentity = option
            }
        } label: {
            HStack(spacing: AppleGlassStyle.spacingMD) {
                // Icon
                Image(systemName: option.iconName)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : AppleGlassStyle.accent)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(isSelected ? AppleGlassStyle.accent : AppleGlassStyle.accent.opacity(0.12))
                    )

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(isSelected ? AppleGlassStyle.textPrimary : AppleGlassStyle.textPrimary)
                    Text(option.subtitle)
                        .font(.caption)
                        .foregroundStyle(AppleGlassStyle.textTertiary)
                }

                Spacer()

                // Radio indicator
                Image(systemName: isSelected ? "record.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppleGlassStyle.accent : AppleGlassStyle.textTertiary)
            }
            .padding(AppleGlassStyle.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusMedium)
                            .stroke(isSelected ? AppleGlassStyle.accent : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - GlobalViewManager Identity Bridge
//【已修复】简化bridge：仅需赋值，不再引用不存在的 identity 属性

extension Page4_IdentitySelectView.IdentityOption {
    var toGlobalIdentity: GlobalViewManager.UserIdentity {
        switch self {
        case .beginner:   return .beginner
        case .enthusiast: return .enthusiast
        case .coach:      return .coach
        }
    }
}
