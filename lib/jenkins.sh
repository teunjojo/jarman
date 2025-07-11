# Script should be sourced, not executed
if [ "${BASH_SOURCE-}" = "$0" ] || [ -z "${BASH_SOURCE-}" ]; then
	echo "This script must be sourced, not executed."
	exit 1
fi

#######################################
# Updates a jenkins plugin to the latest version
# Globals:
#	None
# Arguments:
#   plugin_json
#######################################
jenkins_update_plugin() {
	local plugin_json=$1
	local plugin_url=$(echo $plugin_json | jq -r '.url' 2>/dev/null)
	local latest_version=$(curl -s "$plugin_url/lastSuccessfulBuild/buildNumber")
	local plugin_filename=$(echo $plugin_json | jq -r '.filename' 2>/dev/null)
	local artifact_number=$(echo $plugin_json | jq -r '.artifactNumber' 2>/dev/null)
	if [ -z "$plugin_url" ]; then error_handler "Plugin url is empty"; fi

	metadata=$(curl -s "$plugin_url/lastSuccessfulBuild/api/json")
	artifact_path=$(echo "$metadata" | jq --arg artifactNumber "$artifact_number" -r '.artifacts[$artifactNumber | tonumber].relativePath')

	download_url="$plugin_url/lastSuccessfulBuild/artifact/$artifact_path"

	curl -sS -L -o "$plugin_filename" "$download_url"

	tmp_file=$(mktemp)
	jq --arg filename "$plugin_filename" --arg version "$latest_version" 'map(if .filename == $filename then .version = $version else . end)' "$cache_file" >"$tmp_file" && mv "$tmp_file" "$cache_file"
}

#######################################
# Returns the latest version of a jenkins plugin
# Globals:
#	None
# Arguments:
#   plugin_json
#######################################
jenkins_get_version() {
	local plugin_json=$1
	local plugin_url=$(echo $plugin_json | jq -r '.url' 2>/dev/null)
	[ -z "$plugin_url" ] && error_handler "plugin_url is empty" "$0"
	local jenkins_latest_version=$(curl -s "$plugin_url/lastSuccessfulBuild/buildNumber")
	[ -z "$jenkins_latest_version" ] && error_handler "Failed to retrieve latest build number"

	echo "$jenkins_latest_version"
}
