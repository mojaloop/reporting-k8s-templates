#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

: "${GITHUB_TOKEN:?Environment variable GITHUB_TOKEN must be set}"
: "${CR_REPO_URL:?Environment variable CR_REPO_URL must be set}"
: "${GIT_USERNAME:?Environment variable GIT_USERNAME must be set}"
: "${GIT_REPOSITORY_NAME:?Environment variable GIT_REPOSITORY_NAME must be set}"

readonly REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"
export CR_TOKEN="$GITHUB_TOKEN"

main() {
    pushd "$REPO_ROOT" > /dev/null

    echo "Fetching tags..."
    git fetch --tags

    echo "Fetching charts..."

    local changed
    local chart_name
    local chart_ver
    local tag

    chart_name=$(awk '/^name: /{print $NF}' < Chart.yaml )
    chart_ver=$(awk '/^version: /{print $NF}' < Chart.yaml)
    tag="${chart_name}-${chart_ver}"
    if git rev-parse "$tag" >/dev/null 2>&1; then
	    echo "Chart '$chart_name': tag '$tag' already exists, skipping."
	    changed=false
    else
	    echo "Chart '$chart_name': new version '$chart_ver' detected."
	    changed=true
    fi

    # preparing dirs
    rm -rf .cr-release-packages
    mkdir -p .cr-release-packages

    rm -rf .cr-index
    mkdir -p .cr-index

    if $changed; then
	echo "Packaging chart '$chart_name'..."
	helm package . --destination .cr-release-packages --dependency-update

        release_charts

        # the newly created GitHub releases may not be available yet; let's wait a bit to be sure.
        sleep 5

        update_index
    else
        echo "Nothing to do. No chart changes detected."
    fi

    popd > /dev/null
}

release_charts() {
    cr upload -o "$GIT_USERNAME" -r "$GIT_REPOSITORY_NAME" --release-name-template "v{{ .Version }}"
}

update_index() {
    git config user.email "$GIT_USERNAME@users.noreply.github.com"
    git config user.name "$GIT_USERNAME"

    cr index -o "$GIT_USERNAME" -r "$GIT_REPOSITORY_NAME" -c "$CR_REPO_URL" --push --release-name-template "v{{ .Version }}"
}

main
