import Foundation

/// Content for a placeholder section: a one-line blurb plus the sub-screens the tab will eventually
/// contain (rendered as disabled rows). This is the §9 information architecture as static data.
struct SectionContent: Hashable {
    let blurb: String
    let items: [String]
}

/// Maps each tab to its §9 / §9.9 information architecture.
enum SectionCatalog {
    static func personal(_ tab: AppTab) -> SectionContent {
        switch tab {
        case .home:
            return SectionContent(
                blurb: "AI-инсайт строкой и продуктовые блоки (§9.1).",
                items: ["Дашборд", "Карты (карусель, заказ)", "Счета", "Крипто-кошелёк",
                        "Вклады / Стейкинг", "Кредиты", "Ромео Mobile", "Поиск (AI)", "Оплата"]
            )
        case .payments:
            return SectionContent(
                blurb: "Переводы, платежи, цифровой рубль и крипта (§9.2).",
                items: ["Между счетами", "По телефону (СБП)", "По реквизитам", "За рубеж",
                        "Крипто-перевод контакту", "Цифровым рублём (QR)", "Шаблоны / Автоплатежи"]
            )
        case .market:
            return SectionContent(
                blurb: "Крипто/ЦФА-биржа: портфель, live-цены, трейдинг (§9.6).",
                items: ["Крипто-дашборд (портфель, ₽/$)", "Актив (график, ордер)", "Конвертация крипто↔₽",
                        "Отправить / Принять", "ЦФА (259-ФЗ)", "История сделок", "Статус инвестора"]
            )
        case .history:
            return SectionContent(
                blurb: "Лента операций и AI-аналитика бюджета (§9.4).",
                items: ["Лента операций", "Деталь операции", "Аналитика бюджета (AI-прогноз)",
                        "Мои категории", "Отчёты / экспорт"]
            )
        case .chats:
            return SectionContent(
                blurb: "AI-поддержка, операторы и обращения (§9.5).",
                items: ["AI-поддержка (Claude)", "Чат с банком", "Чат с оператором",
                        "Обращения", "Уведомления"]
            )
        }
    }

    static func business(_ tab: BusinessTab) -> SectionContent {
        switch tab {
        case .dashboard:
            return SectionContent(
                blurb: "Баланс, кэшфлоу и задачи бизнеса (§9.9).",
                items: ["Баланс по счетам", "Кэшфлоу", "Задачи (счета / подписи)", "AI-инсайт"]
            )
        case .accounts:
            return SectionContent(
                blurb: "РКО, мультивалюта и крипто-трежери (§8.2).",
                items: ["Счета / РКО", "Мультивалютные счета", "Крипто-трежери (стейблы)", "Выписки"]
            )
        case .acquiring:
            return SectionContent(
                blurb: "Приём оплат онлайн, по QR и криптой (§8.2).",
                items: ["Онлайн (линки / интернет-эквайринг)", "QR / NFC / терминал",
                        "Крипто-эквайринг (авто-конвертация в ₽)", "Отчёты по выручке"]
            )
        case .team:
            return SectionContent(
                blurb: "Роли, многоступенчатые подписи, корп-карты (§8.2).",
                items: ["Пользователи и роли", "Подписи 2-of-N", "Корп-карты", "Права доступа"]
            )
        case .chats:
            return SectionContent(
                blurb: "Бизнес-AI (Claude) и поддержка (§8.2).",
                items: ["Бизнес-AI (счета, прогноз кэшфлоу)", "Уведомления", "Поддержка"]
            )
        }
    }
}
