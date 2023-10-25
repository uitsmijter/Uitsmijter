#
# GIT Information
#

GIT_HASH=$( git rev-parse --short HEAD )
GIT_BRANCH=$( git name-rev --name-only HEAD )
GIT_TAG=$( git describe --tags 2> /dev/null || true )
GIT_FEATUREBRANCH=$( git name-rev --name-only HEAD | grep feature | sed -e 's,.*/\(.*\),\1,' | tr '[:upper:]' '[:lower:]' ) || true
if [ -z ${GIT_FEATUREBRANCH} ]; then
    GIT_FEATUREBRANCH=$( echo "${CI_COMMIT_BRANCH}" | grep feature | sed -e 's,.*/\(.*\),\1,' | tr '[:upper:]' '[:lower:]' ) || true
fi

## reformat branch
GIT_BRANCH=${GIT_BRANCH/remotes\/origin\//}
GIT_BRANCH=${GIT_BRANCH/\//-}
GIT_BRANCH=${GIT_BRANCH/^/-}
