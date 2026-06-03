import SwiftUI

/// Soft upsell shown when the Base / Бизнес-Старт daily AI limit is reached (§0.6 / §10.9). Wraps the
/// shared ``UpsellCard`` — Pro+ tiers have unlimited copilot.
struct CopilotQuotaNotice: View {
    let tier: Tier
    let limit: Int

    var body: some View {
        UpsellCard(
            title: "Дневной лимит AI на тарифе \(tier.displayName)",
            message: "На \(tier.displayName) доступно \(limit) запросов к ассистенту в день — на сегодня лимит исчерпан. На Pro и Infinite копилот без ограничений.",
            recommendedTier: .pro
        )
    }
}
