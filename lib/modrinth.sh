# Script should be sourced, not executed
if [ "${BASH_SOURCE-}" = "$0" ] || [ -z "${BASH_SOURCE-}" ]; then
	echo "This script must be sourced, not executed."
	exit 1
fi

#######################################
# Updates a JAR to the latest version via Modrinth
# Globals:
#	None
# Arguments:
#   jar_json
#######################################
modrinth_update() {
	local jar_json=$1
	local jar_loader=$(echo "$jar_json" | jq -r '.loader')
	[ -z "$jar_loader" ] && error_handler "JAR loader not set"
	local jar_project=$(echo "$jar_json" | jq -r '.project')
	[ -z "$jar_project" ] && error_handler "JAR project not set"
	local jar_filename=$(echo $jar_json | jq -r '.filename' 2>/dev/null)
	local artifact_number=$(echo $jar_json | jq -r '.artifactNumber' 2>/dev/null)
	local latest_version=$(modrinth_get_version "$jar_json")

	metadata="$(modrinth_curl "https://api.modrinth.com/v2/project/$jar_project/version?loaders=%5B%22$jar_loader%22%5D")"

	local download_url="$(echo "$metadata" | jq -r --arg artifactNumber "$artifact_number" '.[0].files[$artifactNumber|tonumber].url')"

	curl -sS -L -o "$jar_filename" "$download_url"

	tmp_file=$(mktemp)
	jq --arg filename "$jar_filename" --arg version "$latest_version" 'map(if .filename == $filename then .version = $version else . end)' "$cache_file" >"$tmp_file" && mv "$tmp_file" "$cache_file"
}

#######################################
# Returns the latest version of a JAR via Modrinth
# Globals:
#	None
# Arguments:
#   jar_json
#######################################
modrinth_get_version() {
	local jar_json=$1
	local jar_loader=$(echo "$jar_json" | jq -r '.loader')
	[ -z "$jar_loader" ] && error_handler "JAR loader not set"
	local jar_project=$(echo "$jar_json" | jq -r '.project')
	[ -z "$jar_project" ] && error_handler "JAR project not set"

	metadata="$(modrinth_curl "https://api.modrinth.com/v2/project/$jar_project/version?loaders=%5B%22$jar_loader%22%5D")"

	local modrinth_latest_version="$(echo "$metadata" | jq -r '.[0].version_number')"
	[ -z "$modrinth_latest_version" ] && error_handler "Failed to retrieve latest version number"

	echo "$modrinth_latest_version"
}

#######################################
# Curl for Modrinth
# Globals:
#	None
# Arguments:
#   jar_json
#######################################
modrinth_curl() {
	local url=$1
	local response=$(mktemp)
	curl_opts=(-s -w "%{http_code}" -o "$response")

	status=$(curl "${curl_opts[@]}" "$url")

	case "$status" in
	"200") ;;
	"404")
		error_handler "Not Found"
		;;
	*)
		error_handler "$(cat "$response" | jq '.message')"
		;;
	esac

	cat "$response" | jq .
	rm "$response"
}
