import Foundation

extension PackageBuild {
    var describe: String {
        if tag == nil,
           digest.isEmpty {
            return "dirty"
        }
        guard tag != nil else {
            return String(commit.prefix(8))
        }
        var desc = tag ?? "nightly"
        if countSinceTag != 0 {
            desc += "-" + String(countSinceTag) + "-g" + commit.prefix(7)
        }
        if isDirty {
            desc += "-dirty"
        }
        return desc
    }
}
