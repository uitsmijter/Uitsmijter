# PR #24 Review Comments - Todo List

## .swiftlint.yml
- [x] **Line 47**: Review file length warning increase from 500 to 800
  - ✅ **COMPLETED**: Set to warning: 600 / error: 800
  - Rationale: 6 files currently exceed 500 lines (longest: 673 lines)

## Deployment/Docker/docker-compose.yml
- [x] **Line 4**: Update Redis image to use mirror
  - ✅ **COMPLETED**: Changed to `ghcr.io/uitsmijter/redis:${REDIS_VERSION:-latest}`

## Deployment/build-compose.yml
- [x] **Line 23**: Update Redis image to use mirror
  - ✅ **COMPLETED**: Changed to `ghcr.io/uitsmijter/redis:${REDIS_VERSION:-8.2.2}`

- [x] **Line 49**: Remove leftover webkitgtk-4.0 compatibility layer code
  - ✅ **COMPLETED**: Already removed in previous commits

- [x] **Line 75**: Remove leftover webkitgtk-4.0 compatibility layer code
  - ✅ **COMPLETED**: Already removed in previous commits

- [x] **Line 95**: Remove leftover webkitgtk-4.0 compatibility layer code
  - ✅ **COMPLETED**: Already removed in previous commits

## Deployment/e2e/applications/Ham/kustomization.yaml
- [x] **Line 6**: Remove commented code
  - ✅ **COMPLETED**: Removed commented tenant.yaml line

## Deployment/helm/uitsmijter/templates/_helpers.tpl
- [x] **Line 98**: Discuss default resource limits
  - ✅ **COMPLETED**: Updated to sensible defaults
  - CPU requests: 500m → 250m
  - CPU limits: 2000m → 1000m
  - Memory unchanged: 256Mi requests / 512Mi limits

## Deployment/helm/uitsmijter/values.yaml
- [x] **Line 11**: Auto-generate jwtSecret when not set
  - ✅ **COMPLETED**: Implemented auto-generation with persistence across upgrades
  - Uses Kubernetes secret lookup to maintain existing secrets
  - Generates 64-character random alphanumeric string on first install

- [x] **Line 12**: Auto-generate redisPassword when not set
  - ✅ **COMPLETED**: Implemented auto-generation with persistence across upgrades
  - Uses Kubernetes secret lookup to maintain existing secrets
  - Generates 32-character random alphanumeric string on first install

- [x] **Line 45**: Discuss CPU limit increase
  - ✅ **COMPLETED**: Addressed as part of resource limits review (see Line 98)
  - CPU limit set to 1000m (1 core)

## Deployment/tooling/includes/build.fns.sh
- [x] **Line 20**: Review documentation improvement
  - ✅ **COMPLETED**: Documentation improvements already present in codebase

---

## Summary
All 12 review comments have been addressed and implemented.
