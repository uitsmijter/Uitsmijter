import Foundation

protocol RedirectUriProtocol {
    /// The `redirect_uri` to Uitsmijter redirect the answer to
    var redirect_uri: URL { get }
}

enum RedirectError: Error {
    case notAnUrl(Any)
}

struct RedirectUri: RedirectUriProtocol {
    let redirect_uri: URL

    init(_ uri: URL) {
        redirect_uri = uri
    }

    init(_ string: String) throws {
        guard let uri = URL(string: string) else {
            throw RedirectError.notAnUrl(string)
        }
        redirect_uri = uri
    }
}
