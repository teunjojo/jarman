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
	# TODO: Implement logic for downloading latest release
	local jar_json=$1
	local jar_url=$(echo $jar_json | jq -r '.url' 2>/dev/null)
	local latest_version=$(ghr_latest_version $jar_json)
	local jar_filename=$(echo $jar_json | jq -r '.filename' 2>/dev/null)
	local artifact_number=$(echo $jar_json | jq -r '.artifactNumber' 2>/dev/null)
	if [ -z "$jar_url" ]; then error_handler "JAR url is empty"; fi

	download_url=""

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

	local ghr_latest_version=$(curl -s "https://api.github.com/repos/$jar_repo/releases/latest" | jq -r .tag_name)

	[ -z "$ghr_latest_version" ] && error_handler "Failed to retrieve latest release tag_name"

	echo "$ghr_latest_version"
}
