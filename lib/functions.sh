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
source "$root_dir/lib/modrinth.sh" || error_handler "Failed to source '$root_dir/lib/modrinth.sh'"

#######################################
# Function that prints the script usage
# Globals:
#   None
# Arguments:
#   None
#######################################
usage() {
	cat <<EOF
jarman.

Usage:
  $0 <working_directory>
  $0 -h
  $0 -v

Options:
  -h  Show this screen.
  -v  Show version.
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
			# Validate user input
			[[ ! "$source_index" =~ ^[0-9]$ ]] && error_handler "Invalid input!"

			source="${sources[$source_index]}"
			case "$source" in
			"jenkins")
				local url
				read -p "What is the update URL? [<Jenkins URL>/job/<Project>]: " url
				# Validate user input
				[[ ! "$url" =~ ^https?://([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(/[^[:space:]/?#]+)*/job/[a-zA-Z0-9._~%-]+/?$ ]] && error_handler "Invalid input!"

				local metadata=$(curl -s "$url/lastSuccessfulBuild/api/json")
				readarray artifacts < <(echo "$metadata" | jq -r '.artifacts[].displayPath')
				echo "Available artifacts: "
				for i in "${!artifacts[@]}"; do
					echo -ne " $i) ${artifacts[$i]}"
				done
				local artifact_number
				read -p "Select the number of the artifact: [0]: " artifact_number
				# Validate user input
				[[ ! "$artifact_number" =~ ^[0-9]$ ]] && error_handler "Invalid input!"
				;;
			"github-releases")
				local repo
				read -p "What is the name of the GitHub repo? [<User>/<Repository>]: " repo
				# Validate user input
				[[ ! "$repo" =~ ^[a-zA-Z0-9._~%-]+/[a-zA-Z0-9._~%-]+$ ]] && error_handler "Invalid input!"

				local metadata=$(ghr_curl "https://api.github.com/repos/$repo/releases/latest")
				readarray artifacts < <(echo "$metadata" | jq -r '.assets[].name')
				echo "Available artifacts: "
				for i in "${!artifacts[@]}"; do
					echo -ne " $i) ${artifacts[$i]}"
				done
				local artifact_number
				read -p "Select the number of the artifact: [0]: " artifact_number
				# Validate user input
				[[ ! "$artifact_number" =~ ^[0-9]$ ]] && error_handler "Invalid input!"
				;;
			"modrinth")
				local project
				read -p "What is the name of the project? [id|slug]: " project
				# Validate user input
				[[ ! "$project" =~ [a-zA-Z0-9._~%-]$ ]] && error_handler "Invalid input!"

				local metadata=$(modrinth_curl "https://api.modrinth.com/v2/project/$project")
				echo "Select the correct loader: "
				readarray loaders < <(echo "$metadata" | jq -r '.loaders[]')
				for i in "${!loaders[@]}"; do
					echo -ne " $i) ${loaders[$i]}"
				done
				local loader
				read -p "Select the number of the loader: [0]: " loader_index
				# Validate user input
				[[ ! "$loader_index" =~ ^[0-9]$ ]] && error_handler "Invalid input!"

				loader="$(echo "$metadata" | jq -r --arg index $loader_index '.loaders[$index|tonumber]')"
				local version_metadata="$(modrinth_curl "https://api.modrinth.com/v2/project/$project/version?loaders=%5B%22$loader%22%5D")"
				echo "Select the correct file: "
				readarray files < <(echo "$version_metadata" | jq -r '.[0].files.[].filename')
				for i in "${!files[@]}"; do
					echo -ne " $i) ${files[$i]}"
				done
				local artifact_number
				read -p "Select the number of the file: [0]: " artifact_number
				# Validate user input
				[[ ! "$artifact_number" =~ ^[0-9]$ ]] && error_handler "Invalid input!"
				;;
			esac
			break
		fi
	done

	local new_jar=$(
		jq -n \
			--arg filename "$jar_filename" \
			--arg source "$source" \
			--arg url "$url" \
			--arg repo "$repo" \
			--arg version "unknown" \
			--arg artifactNumber "$artifact_number" \
			--arg project "$project" \
			--arg loader "$loader" \
			'{filename: $filename, source: $source, url: $url, repo: $repo, version: $version, artifactNumber: $artifactNumber, loader: $loader, project: $project}'
	)

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
	"modrinth")
		modrinth_update "$jar_data"
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
	"modrinth")
		modrinth_get_version "$jar_data"
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
