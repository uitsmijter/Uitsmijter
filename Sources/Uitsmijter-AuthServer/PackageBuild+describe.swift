import Foundation

/// Extension to provide a human-readable version description string for `PackageBuild`.
///
/// This extension adds a computed property that generates a descriptive version string
/// following Git describe conventions. The format mimics the output of `git describe --tags --dirty`
/// and is commonly used for version identification in builds and deployments.
extension PackageBuild {
    /// Generates a human-readable version description string.
    ///
    /// This computed property creates a version string based on the build's Git metadata,
    /// following a format similar to `git describe`. The output varies depending on the
    /// repository state and available Git information.
    ///
    /// ## Format Variants
    ///
    /// The version string follows these patterns:
    ///
    /// 1. **Dirty build with no tag**: `"dirty"`
    ///    - No Git tag exists and the working directory has uncommitted changes
    ///    - Indicates a local development build
    ///
    /// 2. **Untagged commit**: `"abc12345"`
    ///    - First 8 characters of the commit hash
    ///    - No Git tag has been found in the repository history
    ///
    /// 3. **Tagged release**: `"v1.2.3"`
    ///    - Exact tag name when built directly from a tagged commit
    ///    - No additional commits since the tag
    ///
    /// 4. **Post-release commits**: `"v1.2.3-5-gabc1234"`
    ///    - Tag name + number of commits since tag + shortened commit hash
    ///    - Format: `{tag}-{count}-g{commit_hash}`
    ///    - Example: `"v1.2.3-5-gabc1234"` means 5 commits after v1.2.3 tag
    ///
    /// 5. **Dirty post-release**: `"v1.2.3-5-gabc1234-dirty"`
    ///    - Same as above but with uncommitted changes in working directory
    ///    - The `-dirty` suffix indicates local modifications
    ///
    /// 6. **Nightly build**: `"nightly"` or `"nightly-5-gabc1234"`
    ///    - Used when tag is somehow empty but set
    ///    - Typically for automated nightly builds
    ///
    /// ## Git Describe Equivalence
    ///
    /// This format is equivalent to:
    /// ```bash
    /// git describe --tags --dirty --always
    /// ```
    ///
    /// ## Properties Used
    ///
    /// - `tag`: The most recent Git tag (if any)
    /// - `commit`: The full commit SHA hash
    /// - `countSinceTag`: Number of commits since the most recent tag
    /// - `isDirty`: Whether there are uncommitted changes in the working directory
    /// - `digest`: Build digest hash
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let version = PackageBuild.info.describe
    /// print("Running version: \(version)")
    /// // Output examples:
    /// // "v1.2.3"
    /// // "v1.2.3-15-gabc1234"
    /// // "v1.2.3-dirty"
    /// // "abc12345"
    /// // "dirty"
    /// ```
    ///
    /// ## Implementation Details
    ///
    /// The method prioritizes information in this order:
    /// 1. Checks for dirty state without tag or digest → returns `"dirty"`
    /// 2. If no tag exists → returns shortened commit hash (8 chars)
    /// 3. Uses tag as base, appending commit count and hash if commits exist since tag
    /// 4. Appends `-dirty` suffix if working directory has uncommitted changes
    ///
    /// - Returns: A descriptive version string following Git describe conventions.
    ///
    /// - SeeAlso: ``VersionsController`` for HTTP endpoint exposing this version
    /// - SeeAlso: `PackageBuild` from PackageBuildInfo plugin for the base type
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
