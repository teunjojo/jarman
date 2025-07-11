# Script should be sourced, not executed
if [ "${BASH_SOURCE-}" = "$0" ] || [ -z "${BASH_SOURCE-}" ]; then
	echo "This script must be sourced, not executed."
	exit 1
fi

root_dir="$(dirname "${BASH_SOURCE[1]}")"

#
# Source required functions
#
[ ! -d "$root_dir/lib" ] && error_handler "Directory '$root_dir' not found"
source "$root_dir/lib/jenkins.sh" || error_handler "Failed to source '$root_dir/lib/jenkins.sh'"

#######################################
# Function that prints the script usage
# Globals:
#   None
# Arguments:
#   None
#######################################
usage() {
	cat <<EOF
Usage: $0 [ -v ] [ -h ] <working_directory>

This script scans the plugins in a specified directory, checks for updates, and allows you to update them.

Example: $0 plugins
EOF
}

#######################################
# Returns plugin data in JSON format for a plugin specified by the filename of a plugin
# Globals:
#   None
# Arguments:
#   plugin_filename
#######################################
get_plugin() {
	local plugin_filename=$1
	jq -r --arg filename "$plugin_filename" 'first(.[] | select(.filename == $filename))' "$cache_file" 2>/dev/null
}

#######################################
# Registers a plugin to the cache
# Globals:
#	cache_file
#   seperator
# Arguments:
#   plugin_filename
#######################################
register_plugin() {
	local plugin_filename=$1

	local type=""
	local url=""
	local artifact=""
	local artifact_number=""

	if [ ! -f "$cache_file" ]; then
		echo "[]" >"$cache_file"
	fi

	while true; do
		echo $seperator
		echo -e "Unregistered Plugin found!"
		read -p "Do you want to register '$plugin_filename'? [Y/n] " -r
		if [[ $REPLY =~ ^[Nn]$ ]]; then # If 'N' or 'n' then dont ask for user input
			break
		fi
		if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then # If 'Y', 'y' or empty, then ask for user input
			read -p "What is the plugin update type? [jenkins]: " type
			read -p "What is the update URL? [<Jenkins URL>/job/<Plugin>]: " url
			if [ "$type" == "jenkins" ]; then
				local metadata=$(curl -s "$url/lastSuccessfulBuild/api/json")
				readarray artifacts < <(echo "$metadata" | jq -r '.artifacts[].displayPath')
				echo "Available artifacts: "
				for i in "${!artifacts[@]}"; do
					echo -ne " $i) ${artifacts[$i]}"
				done
				read -p "Select the number of the artifact: [0]: " artifact_number
			fi
			break
		fi
	done

	local new_plugin=$(jq -n \
		--arg filename "$plugin_filename" \
		--arg type "$type" \
		--arg url "$url" \
		--arg version "unknown" \
		--arg artifactNumber "$artifact_number" \
		'{filename: $filename, type: $type, url: $url, version: $version, artifactNumber: $artifactNumber}')

	tmp_file=$(mktemp)
	jq --argjson new_plugin "$new_plugin" '. + [$new_plugin]' $cache_file >"$tmp_file" && mv "$tmp_file" "$cache_file"
	echo $seperator
}

#######################################
# Updates a plugin to the latest version
# Globals:
#	None
# Arguments:
#   plugin_json
#######################################
update_plugin() {
	local plugin_json=$1
	local plugin_type=$(echo $plugin_json | jq -r '.type' 2>/dev/null)
	case "$plugin_type" in
	"jenkins")
		jenkins_update_plugin "$plugin_json"
		;;
	"")
		error_handler "Plugin type empty"
		;;
	*)
		error_handler "Plugin type '$plugin_type' unknown"
		;;
	esac
}

#######################################
# Returns the latest version of a plugin
# Globals:
#	None
# Arguments:
#   plugin_json
#######################################
get_version() {
	local plugin_json=$1
	local plugin_type=$(echo $plugin_json | jq -r '.type' 2>/dev/null)
	case "$plugin_type" in
	"jenkins")
		jenkins_get_version "$plugin_json"
		;;
	"")
		# Plugin type not set
		exit 2
		;;
	*)
		# Unknown plugin type
		exit 3
		;;
	esac
}
