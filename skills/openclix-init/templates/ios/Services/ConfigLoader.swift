import Foundation

public enum ConfigLoaderError: LocalizedError {
    case invalidEndpoint(String)
    case timeout(endpoint: String, timeoutMs: Int)
    case httpError(statusCode: Int, endpoint: String)
    case parseError(endpoint: String, underlyingError: Error)
    case fetchError(endpoint: String, underlyingError: Error)

    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint(let endpoint):
            return "Local file paths are not supported by ConfigLoader on iOS. "
                + "Use ClixCampaignManager.replaceConfig() with a bundled config object instead. "
                + "Received endpoint: \"\(endpoint)\""
        case .timeout(let endpoint, let timeoutMs):
            return "Config fetch timed out after \(timeoutMs)ms for endpoint: \"\(endpoint)\""
        case .httpError(let statusCode, let endpoint):
            return "Config fetch returned HTTP \(statusCode) for endpoint: \"\(endpoint)\""
        case .parseError(let endpoint, let underlyingError):
            return "Failed to parse config JSON from endpoint \"\(endpoint)\": \(underlyingError.localizedDescription)"
        case .fetchError(let endpoint, let underlyingError):
            return "Config fetch failed for endpoint \"\(endpoint)\": \(underlyingError.localizedDescription)"
        }
    }
}

public enum ConfigLoader {

    private static let defaultTimeoutSeconds: TimeInterval = 10

    public static func load(
        endpoint: String,
        timeoutSeconds: TimeInterval? = nil,
        extraHeaders: [String: String]? = nil
    ) async throws -> Config? {
        guard endpoint.hasPrefix("http://") || endpoint.hasPrefix("https://") else {
            throw ConfigLoaderError.invalidEndpoint(endpoint)
        }

        guard let url = URL(string: endpoint) else {
            throw ConfigLoaderError.invalidEndpoint(endpoint)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeoutSeconds ?? defaultTimeoutSeconds

        if let extraHeaders = extraHeaders {
            for (key, value) in extraHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            let timeoutMs = Int((timeoutSeconds ?? defaultTimeoutSeconds) * 1000)
            throw ConfigLoaderError.timeout(endpoint: endpoint, timeoutMs: timeoutMs)
        } catch {
            throw ConfigLoaderError.fetchError(endpoint: endpoint, underlyingError: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConfigLoaderError.fetchError(
                endpoint: endpoint,
                underlyingError: NSError(
                    domain: "ConfigLoader",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Response is not an HTTP response"]
                )
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ConfigLoaderError.httpError(
                statusCode: httpResponse.statusCode,
                endpoint: endpoint
            )
        }

        let config: Config
        do {
            let decoder = JSONDecoder()
            config = try decoder.decode(Config.self, from: data)
        } catch {
            throw ConfigLoaderError.parseError(endpoint: endpoint, underlyingError: error)
        }

        return config
    }
}
