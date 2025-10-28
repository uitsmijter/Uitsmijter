# PR #24 Review Comments - Todo List

## ✅ COMPLETED (12 comments)

### .swiftlint.yml
- [x] **Line 47**: Review file length warning increase from 500 to 800
  - ✅ Set to warning: 600 / error: 800

### Deployment/Docker/docker-compose.yml
- [x] **Line 4**: Update Redis image to use mirror
  - ✅ Changed to `ghcr.io/uitsmijter/redis:${REDIS_VERSION:-latest}`

### Deployment/build-compose.yml
- [x] **Line 23**: Update Redis image to use mirror
  - ✅ Changed to `ghcr.io/uitsmijter/redis:${REDIS_VERSION:-8.2.2}`
- [x] **Line 49, 75, 95**: Remove leftover webkitgtk-4.0 compatibility layer code
  - ✅ Already removed in previous commits

### Deployment/e2e/applications/Ham/kustomization.yaml
- [x] **Line 6**: Remove commented code
  - ✅ Removed commented tenant.yaml line

### Deployment/helm/uitsmijter/templates/_helpers.tpl
- [x] **Line 98**: Discuss default resource limits
  - ✅ Updated to: CPU 250m/1000m, Memory 256Mi/512Mi

### Deployment/helm/uitsmijter/values.yaml
- [x] **Line 11**: Auto-generate jwtSecret when not set
  - ✅ Implemented with persistence across upgrades
- [x] **Line 12**: Auto-generate redisPassword when not set
  - ✅ Implemented with persistence across upgrades
- [x] **Line 45**: Discuss CPU limit increase
  - ✅ Set to 1000m (1 core)

---

## ✅ COMPLETED - Additional Comments (18 comments)

### Deployment/tooling/includes/build.fns.sh
- [x] **Line 28**: Describe which images
  - ✅ Clarified: "Resizes and reformats image assets first"

### Deployment/tooling/includes/check.fns.sh
- [x] **Line 31**: Set an error message that tells how to get it from
  - ✅ Added: kubectl installation link
- [x] **Line 39**: Set an error message that tells how to get it from
  - ✅ Added: helm installation link
- [x] **Line 47**: Set an error message that tells how to get it from
  - ✅ Added: openssl installation commands
- [x] **Line 55**: Set an error message that tells how to get it from
  - ✅ Added: Go installation link and command
- [x] **Line 93**: Set an error message that tells how to get it from
  - ✅ Added: s3cmd installation commands

### Deployment/tooling/includes/display.fns.sh
- [x] **Lines 26, 39, 51, 96**: Show output format
  - ✅ Already resolved: All functions have format documentation

### Deployment/tooling/includes/exports.fns.sh
- [x] **Line 53**: Set all variables locally
  - ✅ Deleted exports.fns.sh entirely
  - ✅ Removed exportDefaults() call from tooling.sh
  - ✅ Variables now set locally at docker compose call sites

### Deployment/tooling/includes/kind.fns.sh
- [x] **Line 167**: Clarify use case
  - ✅ Updated: "Check if cluster is running and start it if stopped"
- [x] **Line 194**: Remove duplicated domains
  - ✅ Created generateCertDomains() function
  - ✅ Domains now generated from TEST_HOSTS (single source of truth)

### Sources/Logger/CircularBuffer.swift
- [x] **Line 118**: Remove redundant thread-safe comment
  - ✅ Removed "This operation is thread-safe."
- [x] **Line 136**: Remove redundant thread-safe comment
  - ✅ Removed "This operation is thread-safe."
- [x] **Line 207**: Remove redundant thread-safe comment
  - ✅ Removed "This operation is thread-safe."

### Sources/Logger/Log.swift
- [x] **Line 14**: Use "request id" not "context"
  - ✅ Changed to "request id"
- [x] **Line 17**: Clarify audit logger purpose
  - ✅ Changed to "login logs"
- [x] **Line 25**: Use "request id" not "context"
  - ✅ Changed to "request id"

---

## Summary
- **Completed**: 30 comments ✅
- **Remaining**: 0 comments 📋
- **Total**: 30 review comments

All PR review comments have been successfully addressed!
