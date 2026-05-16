import Foundation

enum VisitorCounterService {
    private static let visitCountURL = URL(string: "https://ghaslunch1-default-rtdb.asia-southeast1.firebasedatabase.app/stats/visitCount.json")!
    private static let maxIncrementAttempts = 3

    static func fetchCount() async throws -> Int {
        var request = URLRequest(url: visitCountURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return decodeCount(from: data)
    }

    static func incrementCount() async throws -> Int {
        for _ in 0..<maxIncrementAttempts {
            var readRequest = URLRequest(url: visitCountURL)
            readRequest.cachePolicy = .reloadIgnoringLocalCacheData
            readRequest.setValue("true", forHTTPHeaderField: "X-Firebase-ETag")

            let (readData, readResponse) = try await URLSession.shared.data(for: readRequest)
            let readHTTPResponse = try validate(readResponse)
            let etag = readHTTPResponse.value(forHTTPHeaderField: "ETag")
            let nextCount = decodeCount(from: readData) + 1

            var writeRequest = URLRequest(url: visitCountURL)
            writeRequest.httpMethod = "PUT"
            writeRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let etag {
                writeRequest.setValue(etag, forHTTPHeaderField: "if-match")
            }
            writeRequest.httpBody = Data(String(nextCount).utf8)

            let (writeData, writeResponse) = try await URLSession.shared.data(for: writeRequest)
            if let httpResponse = writeResponse as? HTTPURLResponse, httpResponse.statusCode == 412 {
                continue
            }

            try validate(writeResponse)
            return decodeCount(from: writeData)
        }

        throw VisitorCounterError.tooManyConflicts
    }

    @discardableResult
    private static func validate(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VisitorCounterError.invalidResponse
        }
        return httpResponse
    }

    private static func decodeCount(from data: Data) -> Int {
        (try? JSONDecoder().decode(Int.self, from: data)) ?? 0
    }
}

enum VisitorCounterError: Error {
    case invalidResponse
    case tooManyConflicts
}

enum NativeNotificationService {
    static func requestAuthorization() async -> Bool {
        // Temporarily disabled while Web FCM/Web Push is removed.
        // Reconnect through native FCM when FirebaseMessagingService-style handling
        // is implemented for the iOS app.
        false
    }

    static func disableNotifications() async {
        // No-op while notifications are disabled.
    }
}
