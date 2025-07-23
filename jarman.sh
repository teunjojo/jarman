#!/bin/bash
#
# This script scans the JAR files in a specified directory, checks for updates, and allows you to update them.
#
# Author: Teuntje Kuipers (teunjojo)
#

#
# Script parameters
#

# GitHub API authentication (This is not necessary, but will prevent the script from exceeding the API rate limit)
GITHUB_TOKEN=""
# The cache file used to remember JAR file data
cache_file=".cache.json"
# If error outputs should be more verbose
DEBUG=true

#
#! Don't touch anything below this line!
#

#
# Script setup
#

# Version of the script
version="0.4.1-dev"

# Line used for seperating
seperator="----------------------------------------"

# Relative root directory of the script
root_dir="$(dirname "$0")"

# Exit if not bash
[ -z "$BASH_VERSION" ] && echo "This script requires bash to run." && exit 1

# Error Handling
pid=$$
trap 'error_handler "Unknown error occurred while trying to execute: ${BASH_COMMAND}"' ERR
trap 'echo -e "\e[33mExited unexpectedly.\nIf you think this is a bug, report it at the following link: https://github.com/teunjojo/jarman/issues\e[0m";exit' SIGTERM

#######################################
# Function that handles errors
# Globals:
#   DEBUG
# Arguments:
#   message
#######################################
error_handler() {
	local msg="$1"
	local file="${BASH_SOURCE[1]}"
	ansi_red='\e[31m'
	ansi_bold_red='\e[1;31m'
	ansi_reset='\e[0m'
	ansi_clear_line='\033[1G\033[0m'


	# If not DEBUG, print error like the following:
	# <file>: <msg>
	if [[ "$DEBUG" == "false" ]]; then
		echo -e "${ansi_clear_line}${ansi_red}$file: $msg${ansi_reset}" >&2
	else
		local lineno="${BASH_LINENO[1]}"
		local func="${FUNCNAME[2]}"
		# If DEBUG, print error like the following:
		# <file>: line <lineno>: (<func>): <msg>
		echo -e "${ansi_clear_line}${ansi_red}$file: line $lineno: ($func)${msg:+:${ansi_bold_red} $msg}${ansi_reset}" >&2
	fi
	kill $pid
}

# Check if DEBUG variable is set correctly
case "$DEBUG" in
true) ;;
false) ;;
*) error_handler "Unknown value for DEBUG: '$DEBUG'. It can only be 'true' or 'false'" ;;
esac

# Source required functions
[ ! -d "$root_dir/lib" ] && error_handler "Library directory '$root_dir/lib' not found"
source "$root_dir/lib/functions.sh" || error_handler "Failed to source '$root_dir/lib/functions.sh'"

working_directory=""

# Filter flags
while [ $# -gt 0 ]; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
	-v | --version)
		echo -e "$0 version $version"
		exit 0
		;;
	-*)
		echo -e "Unknown option: $1"
		usage
		exit 1
		;;
	*)
		# First item that is not a flag
		# If empty, display usage and exit
		echo "$1" && read
		[[ -z "$1" ]] && usage && exit 0
		# Set working directory variable
		working_directory="$1"
		shift
		;;
	esac
	shift
done

shift $((OPTIND - 1))

# Check if working directory is set
[ -z "$working_directory" ] && error_handler "Directory not set\n\e[0m" && usage
[ ! -d "$working_directory" ] && error_handler "Directory '$working_directory' not found"

#
# Begin script
#

main() {

	# Go to working directory
	cd "$working_directory"
	echo -e "JAR files in '$working_directory':"

	# Check if cache file is set
	[ -z $cache_file ] && error_handler "Cache file location not set"
	# If no cache file exists, create it
	[ ! -f "$cache_file" ] && echo [] >$cache_file

	# Get exising JAR files from directory
	shopt -s nullglob # So it returns empty when no matchces
	local jar_files=(*.jar)
	if [ ${#jar_files[@]} -eq 0 ]; then
		echo "No JAR files found in '$working_directory'"
		exit 0
	fi

	local outdated_jars=()

	for jar_file in "${jar_files[@]}"; do
		# Get JAR data from cache
		jar_data=$(get_data "$jar_file")

		# If its not in cache, register it
		if [[ "$jar_data" == "null" || -z "$jar_data" ]]; then
			register_jar $jar_file
			# Reload JAR data from cache
			jar_data=$(jq -r --arg filename "$jar_file" 'first(.[] | select(.filename == $filename))' "$cache_file" 2>/dev/null)
			# If still not in cache, this is a problem. Exit with error
			[[ "$jar_data" == "null" || -z "$jar_data" ]] && error_handler "Unable to register JAR file '$jar_file' in cache file '$cache_file'"
		fi

		# Write JAR with status to the terminal
		echo -ne " - $jar_file "

		# Prepare to get jar status
		jar_source=$(echo $jar_data | jq -r '.source' 2>/dev/null)
		jar_version=$(echo $jar_data | jq -r '.version' 2>/dev/null)

		# Get the latest version of the JAR file
		local latest_version
		latest_version=$(get_version "$jar_data")
		local latest_version_exitcode=$?

		if [[ $latest_version_exitcode != 0 ]]; then
			if [[ $latest_version_exitcode == 2 ]]; then
				# JAR source not set, print status as unmanaged and continue to next JAR file
				echo -e "\033[1;34m[Unmanaged]\033[0m\033[0m"
				continue
			fi
			if [[ $latest_version_exitcode == 3 ]]; then
				# JAR source not known, throw error
				echo -e "\033[1;31m[Unknown Source]\033[0m\033[2;37m ($jar_version)\033[0m"
				continue
			fi
			# Unknown error, throw error
			error_handler "An unknown error occurred while getting the JAR file version"
		fi

		# If the latest version is not the same as the JAR file version, then it is outdated
		if [ "$jar_version" != "$latest_version" ]; then
			echo -e "\033[1;33m[Outdated]\033[0m\033[2;37m ($jar_version -> $latest_version)\033[0m"
			outdated_jars+=($jar_file)
		else
			echo -e "\033[1;32m[Up to date]\033[0m\033[2;37m ($jar_version)\033[0m"
		fi
	done

	echo $seperator

	if [ ${#outdated_jars[@]} -eq 0 ]; then
		echo "All JAR files in '$working_directory' are up to date!"
		exit 0
	fi

	echo "JAR files to update:"

	for jar_file in "${!outdated_jars[@]}"; do
		echo " [${jar_file}] ${outdated_jars[$jar_file]}"
	done

	# Default input
	local exclude_numbers=""
	read -p "JAR files to EXCLUDE from update (separated by space) [eg: \"0 1\"]: " exclude_numbers
	# Validate user input
	[[ ! "$exclude_numbers" =~ ^([0-9]+( [0-9]+)*)?$ ]] && error_handler "Invalid input!"

	jar_files_to_update=("${outdated_jars[@]}")

	# Exclude JAR files from update
	if [ -n "$exclude_numbers" ]; then
		for jar_number in $exclude_numbers; do
			if [[ $jar_number =~ ^[0-9]+$ ]] && [ $jar_number -lt ${#outdated_jars[@]} ]; then
				unset 'jar_files_to_update[$jar_number]'
			else
				echo "Invalid number: $jar_file"
			fi
		done
		# Re-index the array
		jar_files_to_update=("${jar_files_to_update[@]}")
	fi

	echo $seperator
	echo "Updating the following JAR files:"

	for jar_file in "${jar_files_to_update[@]}"; do
		echo " - $jar_file"
	done

	while true; do
		read -p "Do you want to continue? [Y/n]: "
		if [[ $REPLY =~ ^[Nn]$ ]]; then # If 'N' or 'n' then dont update
			echo "Update cancelled."
			exit 0
		fi
		if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then # If 'Y', 'y' or empty, then continue
			break
		fi
	done

	echo $seperator
	echo "Updating JAR files..."

	for jar_file in "${jar_files_to_update[@]}"; do
		jar_data=$(get_data "$jar_file")
		echo -ne "$jar_file..."
		update "$jar_data"
		echo -e "\033[1;32mDone\033[0m"
	done

}

main
