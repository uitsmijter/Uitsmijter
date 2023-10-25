import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import JXKit

extension JSFunctions {
    // MARK: - Networking

    /// Result object that a `fetch` returns when call was succeeded
    struct FetchResponse: Codable {
        /// HTTP status code of the response
        let code: Int
        /// Content of the response
        let body: String
    }

    /// Fetch function implementation
    /// `fetch` will return a Promise that can be evaluated to an error, or when succeeded it returns an object with
    /// properties: `code` for the http status code and `body` with the response body.
    ///
    /// - Returns: A function that produces a Promise to fetch content
    ///
    func fetch() -> JXValue {
        // swiftlint:disable:next closure_body_length
        JXValue(newFunctionIn: ctx) { context, _, arguments in
            // swiftlint:disable:next closure_body_length
            JXValue(newPromiseIn: context) { _, resolve, reject in
                guard let urlArgument = arguments.first?.stringValue else {
                    let err = "Can not fetch without url"
                    Log.error("\(err)")
                    reject.call(withArguments: [JXValue(newErrorFromMessage: err, in: ctx)])
                    return
                }
                guard let url = URL(string: urlArgument) else {
                    let err = "Can not fetch, because url is not valid"
                    Log.error("\(err)")
                    reject.call(withArguments: [JXValue(newErrorFromMessage: err, in: ctx)])
                    return
                }

                let settingsArgument: JXValue? = arguments.count > 1 ? arguments[1] : nil
                let method: String = settingsArgument?["method"].stringValue ?? "get"
                Log.info("Fetch \(method): \(url)")

                let session = URLSession.shared
                var request = URLRequest(url: url)
                request.httpMethod = method

                if let headers = settingsArgument?["headers"].dictionary {
                    headers.forEach { key, value in
                        request.setValue(value.stringValue, forHTTPHeaderField: key)
                    }
                }

                if let body = settingsArgument?["body"].stringValue, body != "undefined" {
                    request.httpBody = body.data(using: .utf8)
                }

                let task = session.dataTask(with: request) { data, response, error in
                    if let error = error {
                        Log.error("Request failed: \(error.localizedDescription)")
                        reject.call(withArguments: [
                            JXValue(newErrorFromMessage: error.localizedDescription, in: context)
                        ])

                    } else if let data = data {
                        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                        let body = (String(data: data, encoding: .utf8) ?? "")
                        Log.info(
                                "Response with status code \(code): \(code != 200 ? body : "length: \(body.count)")"
                        )

                        let response = FetchResponse(code: code, body: body)
                        let jsonResponse = try? encoder.encode(response)

                        if let jsonResponseData = jsonResponse,
                           let jsonResponseString = String(data: jsonResponseData, encoding: .utf8) {
                            if let argument = JXValue(json: jsonResponseString, in: context) {
                                Log.info("Resolve \(context.ident)")
                                resolve.call(withArguments: [
                                    argument
                                ])
                            } else {
                                Log.info("Reject \(context.ident)")
                                resolve.call()
                            }
                        } else {
                            Log.error("Reject \(context.ident) - Can not encode response")
                            reject.call(withArguments: [
                                JXValue(newErrorFromMessage: "Can not encode response", in: ctx)
                            ])
                        }
                    }
                }
                task.resume()
            } ?? JXValue(nullIn: context)
        }
    }
}
