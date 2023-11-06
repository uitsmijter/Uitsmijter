import Foundation

extension URL {
    #if os(Linux)
    public func appending(queryItems: [URLQueryItem]) -> URL {
        if queryItems.isEmpty {
            return self
        }

        // combine query items to a string
        let appendingQueryPairs = queryItems.map { item -> String in
            "\(item.name)=\(item.value ?? "")"
        }
        let appendingQueryString = appendingQueryPairs.joined(separator: "&")

        let fullQueryString = "?" + (query ?? "").appending((query == nil ? "" : "&")).appending(appendingQueryString)
        let portInfo = port != nil ? ":\(port?.description ?? "")" : ""
        let delimiter = scheme != nil ? "://" : ""
        let url = URL(
                string: "\(scheme ?? "")\(delimiter)\(host ?? "")\(portInfo)\(path)\(fullQueryString)"
        )

        return url ?? self
    }
    #endif
}
