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

        defer {
            //try! httpClient.syncShutdown()
        }

        // swiftlint:disable:next closure_body_length
        return JXValue(newFunctionIn: ctx) { context, _, arguments in
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

                //let session = URLSession.shared
                
                //let sessionConfiguration = URLSessionConfiguration.default
                //sessionConfiguration.timeoutIntervalForRequest = 60
                //let session = URLSession(configuration: sessionConfiguration)
                
                // var request = URLRequest(url: url)
            
                guard var request = try? HTTPClient.Request(url: url.absoluteString, method: .RAW(value: method.uppercased() )) else {
                    reject.call(withArguments: [
                        JXValue(newErrorFromMessage: "Can not construct a request to \(url.absoluteString)", in: context)
                    ])
                    return
                }
                //request.httpMethod = method

                if let headers = settingsArgument?["headers"].dictionary {
                    headers.forEach { key, value in
                        //request.setValue(value.stringValue, forHTTPHeaderField: key)
                        request.headers.add(name: key, value: value.stringValue ?? "true")
                    }
                }

                if let body = settingsArgument?["body"].stringValue, body != "undefined" {
                    //request.httpBody = body.data(using: .utf8)
                    request.body = .string(body)
                }

                /*
                let task = session.dataTask(with: request) { data, response, error in
                    Log.info("REQUEST A")
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
                */
                
                httpClient.execute(request: request).whenComplete { result in
                    Log.info("REQUEST A")
                    switch result {
                        case .failure(let error):
                            print("#### E")
                            Log.error("Request failed: \(error.localizedDescription)")
                            dump(error)
                            reject.call(withArguments: [
                                JXValue(newErrorFromMessage: error.localizedDescription, in: context)
                            ])
                        case .success(let response):
                            print("#### S")
                            switch response.status.code {
                                case (200...299):
                                    let code = response.status.code
                                    let body = String(buffer: response.body ?? ByteBuffer(string: "String"))
                                    Log.info(
                                            "Response from \(urlArgument) with status code \(code): \(code != 200 ? body : "length: \(body.count)")"
                                    )

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
                                    let err = "Call to \(urlArgument) failed. Error status code \(response.status.code)."
                                    Log.error("Request failed: \(err)")
                                    reject.call(withArguments: [
                                        JXValue(newErrorFromMessage: err, in: context)
                                    ])
                            }
                    }
                }

                

                Log.info("REQUEST 0")
                //dump(session.description)
                //task.priority = 1.0
                //print("1. Task state: \(task.state)")

                //task.resume()
                //print("2. Task state: \(task.state)")
                
                
            } ?? JXValue(nullIn: context)
        }
    }
}
