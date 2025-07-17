# Script should be sourced, not executed
if [ "${BASH_SOURCE-}" = "$0" ] || [ -z "${BASH_SOURCE-}" ]; then
	echo "This script must be sourced, not executed."
	exit 1
fi

#######################################
# Updates a JAR to the latest version via GitHub Releases
# Globals:
#	None
# Arguments:
#   jar_json
#######################################
ghr_update() {
	local jar_json=$1
	local jar_repo=$(echo $jar_json | jq -r '.repo' 2>/dev/null)
	local latest_version=$(ghr_get_version "$jar_json")
	local jar_filename=$(echo $jar_json | jq -r '.filename' 2>/dev/null)
	local artifact_number=$(echo $jar_json | jq -r '.artifactNumber' 2>/dev/null)
	[ -z "$artifact_number" ] && error_handler "artifact_number not set"
	if [ -z "$jar_repo" ]; then error_handler "JAR GitHub repository is not set"; fi

	local metadata="$(ghr_curl "https://api.github.com/repos/$jar_repo/releases/latest")"

	[ -z "$metadata" ] && error_handler "Failed to retrieve metadata for latest release of '$jar_repo'"

	local assets_url=$(echo $metadata | jq -r ".assets_url")

	[ -z "assets_url" ] && error_handler "Failed to retrieve assets_url"

	local download_url="$(ghr_curl "$assets_url" | jq -r --arg artifactNumber $artifact_number '.[$artifactNumber|tonumber].browser_download_url')"

	curl -sS -L -o "$jar_filename" "$download_url"

	tmp_file=$(mktemp)
	jq --arg filename "$jar_filename" --arg version "$latest_version" 'map(if .filename == $filename then .version = $version else . end)' "$cache_file" >"$tmp_file" && mv "$tmp_file" "$cache_file"
}

#######################################
# Returns the latest version of a JAR via GitHub Releases
# Globals:
#	None
# Arguments:
#   jar_json
#######################################
ghr_get_version() {
	local jar_json=$1
	local jar_repo=$(echo $jar_json | jq -r '.repo' 2>/dev/null)
	[ -z "$jar_repo" ] && error_handler "JAR GitHub repository is not set" "$0"

	local ghr_latest_version=$(ghr_curl "https://api.github.com/repos/$jar_repo/releases/latest" | jq -r .tag_name)
	[ -z "$ghr_latest_version" ] && error_handler "Failed to retrieve latest release tag_name"

	echo "$ghr_latest_version"
}

#######################################
# Curl for GitHub Releases API
# Globals:
#	None
# Arguments:
#   jar_json
#######################################
ghr_curl() {
	local url=$1
	local response=$(mktemp)
	local status=$(curl -s -w "%{http_code}" -o "$response" "$url")

	if [[ "$status" == "403" ]]; then 
		error_handler "$(cat "$response" | jq '.message')"
	fi

	cat "$response" | jq .
	rm "$response"
}
