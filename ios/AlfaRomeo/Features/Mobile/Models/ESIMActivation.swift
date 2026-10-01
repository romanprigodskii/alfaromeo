import Foundation

/// Способ подключения eSIM (§7.1): мгновенный QR, новый номер, или перенос своего (MNP).
enum ESIMMethod: String, CaseIterable, Identifiable, Hashable, Sendable {
    case qr
    case newNumber
    case transfer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .qr:        return "Активировать по QR"
        case .newNumber: return "Новый номер"
        case .transfer:  return "Перенести свой номер"
        }
    }
    var subtitle: String {
        switch self {
        case .qr:        return "Сканируйте QR оператора"
        case .newNumber: return "Выберите номер Ромео Mobile"
        case .transfer:  return "Перенос от другого оператора (MNP)"
        }
    }
    var icon: String {
        switch self {
        case .qr:        return "qrcode"
        case .newNumber: return "number"
        case .transfer:  return "arrow.left.arrow.right"
        }
    }
    /// Steps shown in the realistic provisioning stub (animated one-by-one).
    var provisioningSteps: [String] {
        switch self {
        case .qr:
            return ["Проверка устройства (eSIM-ready)", "Загрузка профиля оператора", "Активация eSIM"]
        case .newNumber:
            return ["Резервирование номера", "Выпуск eSIM-профиля", "Активация eSIM"]
        case .transfer:
            return ["Проверка номера у донора", "Запрос переноса (MNP)", "Активация на Ромео Mobile"]
        }
    }
}

/// Операторы, с которых можно перенести номер (MNP donor list) — демо.
enum ESIMDonor: String, CaseIterable, Identifiable, Sendable {
    case mts = "МТС"
    case beeline = "Билайн"
    case megafon = "МегаФон"
    case tele2 = "Tele2"
    case yota = "Yota"

    var id: String { rawValue }
}
