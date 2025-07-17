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
source "$root_dir/lib/github-releases.sh" || error_handler "Failed to source '$root_dir/lib/github-releases.sh'"

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

This script scans the JAR files in a specified directory, checks for updates, and allows you to update them.

Example: $0 folder/
EOF
}

#######################################
# Returns JAR data in JSON format for a JAR specified by the filename of a JAR
# Globals:
#   None
# Arguments:
#   jar_filename
#######################################
get_data() {
	local jar_filename=$1
	jq -r --arg filename "$jar_filename" 'first(.[] | select(.filename == $filename))' "$cache_file" 2>/dev/null
}

#######################################
# Registers a JAR file to the cache
# Globals:
#	cache_file
#   seperator
# Arguments:
#   jar_filename
#######################################
register_jar() {
	local jar_filename=$1

	local source=""
	local url=""
	local repo=""
	local artifact=""
	local artifact_number=""

	if [ ! -f "$cache_file" ]; then
		echo "[]" >"$cache_file"
	fi

	while true; do
		echo $seperator
		echo -e "Unregistered JAR file found!"
		read -p "Do you want to register '$jar_filename'? [Y/n] " -r
		if [[ $REPLY =~ ^[Nn]$ ]]; then # If 'N' or 'n' then dont ask for user input
			break
		fi
		if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then # If 'Y', 'y' or empty, then ask for user input
			echo "Available sources: "
			sources=("jenkins" "github-releases" "modrinth")
			for i in "${!sources[@]}"; do
				echo -e " $i) ${sources[$i]}"
			done
			read -p "Select the number of the source: [0]: " source_index
			source="${sources[$source_index]}"
			if [ "$source" == "jenkins" ]; then
				read -p "What is the update URL? [<Jenkins URL>/job/<Project>]: " url
				local metadata=$(curl -s "$url/lastSuccessfulBuild/api/json")
				readarray artifacts < <(echo "$metadata" | jq -r '.artifacts[].displayPath')
				echo "Available artifacts: "
				for i in "${!artifacts[@]}"; do
					echo -ne " $i) ${artifacts[$i]}"
				done
				read -p "Select the number of the artifact: [0]: " artifact_number
			fi
			if [ "$source" == "github-releases" ]; then
				read -p "What is the name of the GitHub releases? [<User>/<Repository>]: " repo
				local metadata=$(ghr_curl "https://api.github.com/repos/$repo/releases/latest")
				readarray artifacts < <(echo "$metadata" | jq -r '.assets[].name')
				echo "Available artifacts: "
				for i in "${!artifacts[@]}"; do
					echo -ne " $i) ${artifacts[$i]}"
				done
				read -p "Select the number of the artifact: [0]: " artifact_number
			fi
			break
		fi
	done

	local new_jar=$(jq -n \
		--arg filename "$jar_filename" \
		--arg source "$source" \
		--arg url "$url" \
		--arg repo "$repo" \
		--arg version "unknown" \
		--arg artifactNumber "$artifact_number" \
		'{filename: $filename, source: $source, url: $url, repo: $repo, version: $version, artifactNumber: $artifactNumber}')

	tmp_file=$(mktemp)
	jq --argjson new_jar "$new_jar" '. + [$new_jar]' $cache_file >"$tmp_file" && mv "$tmp_file" "$cache_file"
	echo $seperator
}

#######################################
# Updates a JAR file to the latest version
# Globals:
#	None
# Arguments:
#   jar_files
#######################################
update() {
	local jar_data=$1
	local jar_source=$(echo $jar_data | jq -r '.source' 2>/dev/null)
	case "$jar_source" in
	"jenkins")
		jenkins_update "$jar_data"
		;;
	"github-releases")
		ghr_update "$jar_data"
		;;
	"")
		error_handler "JAR source not set"
		;;
	*)
		error_handler "JAR source '$jar_source' unknown"
		;;
	esac
}

#######################################
# Returns the latest version of a jar
# Globals:
#	None
# Arguments:
#   jar_json
#######################################
get_version() {
	local jar_data=$1
	local jar_source=$(echo $jar_data | jq -r '.source' 2>/dev/null)
	case "$jar_source" in
	"jenkins")
		jenkins_get_version "$jar_data"
		;;
	"github-releases")
		ghr_get_version "$jar_data"
		;;
	"")
		# JAR source not set
		exit 2
		;;
	*)
		# Unknown JAR source
		exit 3
		;;
	esac
}
