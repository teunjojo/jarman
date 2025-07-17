# Script should be sourced, not executed
if [ "${BASH_SOURCE-}" = "$0" ] || [ -z "${BASH_SOURCE-}" ]; then
	echo "This script must be sourced, not executed."
	exit 1
fi

#######################################
# Updates a JAR to the latest version via Jenkins
# Globals:
#	None
# Arguments:
#   jar_json
#######################################
jenkins_update() {
	local jar_json=$1
	local jar_url=$(echo $jar_json | jq -r '.url' 2>/dev/null)
	local latest_version=$(jenkins_get_version "$jar_json")
	local jar_filename=$(echo $jar_json | jq -r '.filename' 2>/dev/null)
	local artifact_number=$(echo $jar_json | jq -r '.artifactNumber' 2>/dev/null)
	if [ -z "$jar_url" ]; then error_handler "JAR url is empty"; fi

	metadata=$(curl -s "$jar_url/lastSuccessfulBuild/api/json")
	artifact_path=$(echo "$metadata" | jq --arg artifactNumber "$artifact_number" -r '.artifacts[$artifactNumber | tonumber].relativePath')

	download_url="$jar_url/lastSuccessfulBuild/artifact/$artifact_path"

	curl -sS -L -o "$jar_filename" "$download_url"

	tmp_file=$(mktemp)
	jq --arg filename "$jar_filename" --arg version "$latest_version" 'map(if .filename == $filename then .version = $version else . end)' "$cache_file" >"$tmp_file" && mv "$tmp_file" "$cache_file"
}

#######################################
# Returns the latest version of a JAR via Jenkins
# Globals:
#	None
# Arguments:
#   jar_json
#######################################
jenkins_get_version() {
	local jar_json=$1
	local jar_url=$(echo $jar_json | jq -r '.url' 2>/dev/null)
	[ -z "$jar_url" ] && error_handler "JAR url is empty" "$0"
	local jenkins_latest_version=$(curl -s "$jar_url/lastSuccessfulBuild/buildNumber")
	[ -z "$jenkins_latest_version" ] && error_handler "Failed to retrieve latest build number"

	echo "$jenkins_latest_version"
}
