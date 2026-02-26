import Foundation

private func applyOperator(
    _ eventConditionOperator: EventConditionOperator,
    leftHandSide: Any?,
    values: [String]
) -> Bool {
    if leftHandSide == nil || leftHandSide is NSNull {
        switch eventConditionOperator {
        case .not_equal, .not_contains, .not_in, .not_exists:
            return true
        case .exists:
            return false
        default:
            return false
        }
    }

    let leftText = String(describing: leftHandSide!)
    let firstValue = values.first ?? ""

    switch eventConditionOperator {
    case .equal:
        return leftText == firstValue
    case .not_equal:
        return leftText != firstValue
    case .greater_than:
        guard let leftNumber = Double("\(leftHandSide!)"), let rightNumber = Double(firstValue)
        else { return false }
        return leftNumber > rightNumber
    case .greater_than_or_equal:
        guard let leftNumber = Double("\(leftHandSide!)"), let rightNumber = Double(firstValue)
        else { return false }
        return leftNumber >= rightNumber
    case .less_than:
        guard let leftNumber = Double("\(leftHandSide!)"), let rightNumber = Double(firstValue)
        else { return false }
        return leftNumber < rightNumber
    case .less_than_or_equal:
        guard let leftNumber = Double("\(leftHandSide!)"), let rightNumber = Double(firstValue)
        else { return false }
        return leftNumber <= rightNumber
    case .contains:
        return leftText.contains(firstValue)
    case .not_contains:
        return !leftText.contains(firstValue)
    case .starts_with:
        return leftText.hasPrefix(firstValue)
    case .ends_with:
        return leftText.hasSuffix(firstValue)
    case .matches:
        guard let regularExpression = try? NSRegularExpression(pattern: firstValue) else {
            return false
        }
        let range = NSRange(leftText.startIndex..., in: leftText)
        return regularExpression.firstMatch(in: leftText, range: range) != nil
    case .exists:
        return true
    case .not_exists:
        return false
    case .in:
        return values.contains(leftText)
    case .not_in:
        return !values.contains(leftText)
    }
}

private func decodeJsonValue(_ value: JsonValue) -> Any? {
    switch value {
    case .string(let value):
        return value
    case .number(let value):
        return value
    case .bool(let value):
        return value
    case .null:
        return nil
    case .array(let value):
        return value.compactMap { decodeJsonValue($0) }
    case .object(let value):
        return value.mapValues { decodeJsonValue($0) as Any }
    }
}

public final class EventConditionProcessor {

    public init() {}

    public func process(group: EventConditionGroup, event: Event) -> Bool {
        let conditions = group.conditions

        if conditions.isEmpty {
            return group.connector == .and
        }

        let evaluateCondition: (EventCondition) -> Bool = { condition in
            let leftHandSide: Any?

            switch condition.field {
            case .name:
                leftHandSide = event.name
            case .property:
                if let propertyName = condition.property_name,
                   let properties = event.properties {
                    leftHandSide = decodeJsonValue(properties[propertyName] ?? .null)
                } else {
                    leftHandSide = nil
                }
            }

            return applyOperator(
                condition.operator,
                leftHandSide: leftHandSide,
                values: condition.values
            )
        }

        switch group.connector {
        case .and:
            return conditions.allSatisfy(evaluateCondition)
        case .or:
            return conditions.contains(where: evaluateCondition)
        }
    }
}
