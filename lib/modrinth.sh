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
	# TODO: Implement logic for downloading latest version JAR of a project
	local jar_json=$1
	local latest_version=$(modrinth_get_version "$jar_json")
	local jar_filename=$(echo $jar_json | jq -r '.filename' 2>/dev/null)

	local download_url=""

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
	# TODO: Implement logic for retrieving latest version number of a project
	local jar_json=$1

	local modrinth_latest_version=""
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
	"200")
		;;

	"403")
		error_handler "$(cat "$response" | jq '.message')"
		;;

	"404")
		error_handler "Not Found"
		;;
	esac

	cat "$response" | jq .
	rm "$response"
}
