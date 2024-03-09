import Foundation
import JXKit
import AsyncHTTPClient
import NIO

extension JSFunctions {
    // MARK: - Networking

    /// Result object that a `fetch` returns when call was succeeded
    struct FetchResponse: Codable {
        /// HTTP status code of the response
        let code: UInt
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
        let clientConfiguration = HTTPClient.Configuration(
            redirectConfiguration: .follow(max: 100, allowCycles: true)
        )

        let httpClient = HTTPClient(
            eventLoopGroupProvider: .singleton,
            configuration: clientConfiguration
        )

        func doDefer() {
            do {
                try httpClient.syncShutdown()
            } catch {
                Log.error("Can't shutdown http client. \(error.localizedDescription)")
            }
        }

        // swiftlint:disable:next closure_body_length
        return JXValue(newFunctionIn: ctx) { context, _, arguments in
            // swiftlint:disable:next closure_body_length
            JXValue(newPromiseIn: context) { _, resolve, reject in
                /// Internal function that rejects thre request, because of any error.
                /// Parameter: 
                /// - error, String that describes the error
                func requestFailed(error: String) {
                    Log.error("Request failed: \(error)")
                    reject.call(withArguments: [
                        JXValue(newErrorFromMessage: error, in: context)
                    ])
                }

                guard let urlArgument = arguments.first?.stringValue else {
                    requestFailed(error: "Can not fetch without url")
                    return
                }
                guard let url = URL(string: urlArgument) else {
                    requestFailed(error: "Can not fetch, because url is not valid")
                    return
                }

                let settingsArgument: JXValue? = arguments.count > 1 ? arguments[1] : nil
                let method: String = settingsArgument?["method"].stringValue ?? "get"
                Log.info("Fetch \(method): \(url)")

                guard var request = try? HTTPClient.Request(
                    url: url.absoluteString,
                    method: .RAW(value: method.uppercased() )
                    ) else {
                        requestFailed(error: "Can not construct a request to \(url.absoluteString)")
                        return
                }

                if let headers = settingsArgument?["headers"].dictionary {
                    headers.forEach { key, value in
                        request.headers.add(name: key, value: value.stringValue ?? "true")
                    }
                }

                if let body = settingsArgument?["body"].stringValue, body != "undefined" {
                    request.body = .string(body)
                }

                httpClient.execute(request: request).whenComplete { result in
                    // swiftlint:disable:next switch_case_alignment
                    switch result {
                        case .failure(let error):
                            requestFailed(error: error.localizedDescription)
                        case .success(let response):
                        switch response.status.code {
                        case (200...299):
                            let code = response.status.code
                            let body = String(buffer: response.body ?? ByteBuffer(string: "String"))
                            Log.info("""
                                        Response from \(urlArgument) with
                                         status code \(code): \(code != 200 ? body : "length: \(body.count)")
                                        """)

                            let fetchResponse = FetchResponse(code: code, body: body)
                            let jsonResponse = try? encoder.encode(fetchResponse)

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
                        default:
                            requestFailed(
                                error: "Call to \(urlArgument) failed. Error status code \(response.status.code)."
                            )
                        }
                    }
                }
            } ?? JXValue(nullIn: context)
        }
    }
}
