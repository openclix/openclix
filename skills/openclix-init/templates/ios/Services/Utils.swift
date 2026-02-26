import Foundation

private let templateVariablePattern = try! NSRegularExpression(
    pattern: "\\{\\{([a-zA-Z_][a-zA-Z0-9_.]*)\\}\\}"
)

private func resolvePath(_ obj: [String: Any], path: String) -> Any? {
    let segments = path.split(separator: ".").map(String.init)
    var current: Any = obj

    for segment in segments {
        guard let dict = current as? [String: Any] else { return nil }
        guard let next = dict[segment] else { return nil }
        current = next
    }

    return current
}

private func valueToString(_ value: Any?) -> String {
    guard let value = value else { return "" }
    if value is NSNull { return "" }
    if let s = value as? String { return s }
    if let b = value as? Bool { return b ? "true" : "false" }
    if let i = value as? Int { return String(i) }
    if let d = value as? Double {
        if d.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(d))
        }
        return String(d)
    }
    if let n = value as? NSNumber { return n.stringValue }
    if let data = try? JSONSerialization.data(withJSONObject: value, options: []),
       let json = String(data: data, encoding: .utf8) {
        return json
    }
    return String(describing: value)
}

public func renderTemplate(_ template: String, variables: [String: Any]) -> String {
    let nsTemplate = template as NSString
    let range = NSRange(location: 0, length: nsTemplate.length)
    let matches = templateVariablePattern.matches(in: template, range: range)

    if matches.isEmpty { return template }

    var result = template
    for match in matches.reversed() {
        let fullRange = Range(match.range, in: template)!
        let varNameRange = Range(match.range(at: 1), in: template)!
        let variableName = String(template[varNameRange])

        let resolved = resolvePath(variables, path: variableName)
        if resolved == nil { continue }

        let replacement = valueToString(resolved)
        result = result.replacingCharacters(in: fullRange, with: replacement)
    }

    return result
}

public func generateUUID() -> String {
    return UUID().uuidString.lowercased()
}
