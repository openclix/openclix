import '../models/clix_types.dart';

bool applyEventConditionOperator(
  EventConditionOperator operator,
  Object? leftHandSide,
  List<String> values,
) {
  if (leftHandSide == null) {
    switch (operator) {
      case EventConditionOperator.notEqual:
      case EventConditionOperator.notContains:
      case EventConditionOperator.notInList:
      case EventConditionOperator.notExists:
        return true;
      case EventConditionOperator.exists:
        return false;
      default:
        return false;
    }
  }

  final leftHandSideString = leftHandSide.toString();
  final firstValue = values.isNotEmpty ? values.first : '';

  switch (operator) {
    case EventConditionOperator.equal:
      return leftHandSideString == firstValue;
    case EventConditionOperator.notEqual:
      return leftHandSideString != firstValue;
    case EventConditionOperator.greaterThan:
      final leftNumber = num.tryParse(leftHandSideString);
      final rightNumber = num.tryParse(firstValue);
      return leftNumber != null &&
          rightNumber != null &&
          leftNumber > rightNumber;
    case EventConditionOperator.greaterThanOrEqual:
      final leftNumber = num.tryParse(leftHandSideString);
      final rightNumber = num.tryParse(firstValue);
      return leftNumber != null &&
          rightNumber != null &&
          leftNumber >= rightNumber;
    case EventConditionOperator.lessThan:
      final leftNumber = num.tryParse(leftHandSideString);
      final rightNumber = num.tryParse(firstValue);
      return leftNumber != null &&
          rightNumber != null &&
          leftNumber < rightNumber;
    case EventConditionOperator.lessThanOrEqual:
      final leftNumber = num.tryParse(leftHandSideString);
      final rightNumber = num.tryParse(firstValue);
      return leftNumber != null &&
          rightNumber != null &&
          leftNumber <= rightNumber;
    case EventConditionOperator.contains:
      return leftHandSideString.contains(firstValue);
    case EventConditionOperator.notContains:
      return !leftHandSideString.contains(firstValue);
    case EventConditionOperator.startsWith:
      return leftHandSideString.startsWith(firstValue);
    case EventConditionOperator.endsWith:
      return leftHandSideString.endsWith(firstValue);
    case EventConditionOperator.matches:
      try {
        return RegExp(firstValue).hasMatch(leftHandSideString);
      } catch (_) {
        return false;
      }
    case EventConditionOperator.exists:
      return true;
    case EventConditionOperator.notExists:
      return false;
    case EventConditionOperator.inList:
      return values.contains(leftHandSideString);
    case EventConditionOperator.notInList:
      return !values.contains(leftHandSideString);
  }
}

class EventConditionProcessor {
  bool process(EventConditionGroup group, Event event) {
    if (group.conditions.isEmpty) {
      return group.connector == 'and';
    }

    bool evaluateCondition(EventCondition condition) {
      Object? leftHandSide;

      switch (condition.field) {
        case 'name':
          leftHandSide = event.name;
          break;
        case 'property':
          leftHandSide = event.properties?[condition.propertyName];
          break;
        default:
          return false;
      }

      return applyEventConditionOperator(
        condition.operator,
        leftHandSide,
        condition.values,
      );
    }

    if (group.connector == 'and') {
      return group.conditions.every(evaluateCondition);
    }

    return group.conditions.any(evaluateCondition);
  }
}
