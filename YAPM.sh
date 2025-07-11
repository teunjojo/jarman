#!/bin/bash
#
# This script scans the plugins in a specified directory, checks for updates, and allows you to update them.
#
# Author: Teuntje Kuipers (teunjojo)
#

#
# Script parameters
#

# The cache file used to remember plugin data
cache_file=".cache.json"
# If error outputs should be more verbose
DEBUG=false

#
#! Don't touch anything below this line!
#

#
# Script setup
#

# Version of the script
version="0.1"

# Line used for seperating
seperator="----------------------------------------"

# Relative root directory of the script
root_dir="$(dirname "$0")"

# Exit if not bash
[ -z "$BASH_VERSION" ] && echo "This script requires bash to run." && exit 1

# Error Handling
trap 'error_handler "Unknown error occured while trying to execute: ${BASH_COMMAND}"' ERR

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
	# If not DEBUG, print error like the following:
	# <file>: <msg>
	[[ "$DEBUG" == "false" ]] && echo -e "\033[1G\033[0m\e[31m$file: $msg\e[0m" >&2 && exit 1
	local lineno="${BASH_LINENO[$((level - 1))]}"
	local func="${FUNCNAME[$level]}"
	# If DEBUG, print error like the following:
	# <file>: line <lineno>: (<func>): <msg>
	echo -e "\033[1G\033[0m\e[31m$file: line $lineno: ($func)${msg:+:\e[1;31m $msg}\e[0m" >&2
	exit 1
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

# Filter flags
while getopts "hv" opt; do
	case "$opt" in
	h | -help)
		usage
		exit 0
		;;
	v | -version)
		echo -e "$0 version $version"
		exit 0
		;;
	*)
		usage
		exit
		;;
	esac
done

shift $((OPTIND - 1))

working_directory=$1

# Check if working directory is set
[ -z "$working_directory" ] && error_handler "Plugin directory not set\n\e[0m" && usage
[ ! -d "$working_directory" ] && error_handler "Directory '$working_directory' not found"

#
# Begin script
#

main() {

	# Go to working directory
	cd "$working_directory"
	echo -e "Plugins in '$working_directory':"

	# Check if cache file is set
	[ -z $cache_file ] && error_handler "Cache file location not set"
	# If no cache file exists, create it
	[ ! -f "$cache_file" ] && echo [] >$cache_file

	# Get exising plugins from directory
	local plugin_files=(*.jar)
	if [ ${#plugin_files[@]} -eq 0 ]; then
		echo "No plugins found in '$working_directory'"
		exit 0
	fi

	local outdated_plugins=()

	for plugin_file in "${plugin_files[@]}"; do
		# Get plugin from cache
		plugin=$(get_plugin "$plugin_file")

		# If its not in cache, register it
		if [[ "$plugin" == "null" || -z "$plugin" ]]; then
			register_plugin $plugin_file
			# Reload plugin from cache
			plugin=$(jq -r --arg filename "$plugin_file" 'first(.[] | select(.filename == $filename))' "$cache_file" 2>/dev/null)
			# If still not in cache, this is a problem. Exit with error
			[[ "$plugin" == "null" || -z "$plugin" ]] && error_handler "Unable to register plugin '$plugin_file' in cache file '$cache_file'"
		fi

		# Write plugin with status to the terminal
		echo -ne " - $plugin_file "

		# Prepare to get plugin status
		plugin_type=$(echo $plugin | jq -r '.type' 2>/dev/null)
		plugin_version=$(echo $plugin | jq -r '.version' 2>/dev/null)

		# Get the latest version of the plugin
		local latest_version
		latest_version=$(get_version "$plugin")
		local latest_version_exitcode=$?

		if [[ $latest_version_exitcode != 0 ]]; then
			if [[ $latest_version_exitcode == 2 ]]; then
				# Plugin type not set, print status as unmanaged and continue to next plugin
				echo -e "\033[1;34m[Unmanaged]\033[0m\033[0m"
				continue
			fi
			if [[ $latest_version_exitcode == 3 ]]; then
				# Plugin type not known, throw error
				echo -e "\033[1;31m[Unknown Type]\033[0m\033[2;37m ($plugin_version)\033[0m"
				continue
			fi
			# Unknown error, throw error
			error_handler "An unknown error occurred while getting the plugin version"
		fi

		# If the latest version is not the same as the plugin version, then it is outdated
		if [ "$plugin_version" != "$latest_version" ]; then
			echo -e "\033[1;33m[Outdated]\033[0m\033[2;37m ($plugin_version -> $latest_version)\033[0m"
			outdated_plugins+=($plugin_file)
		else
			echo -e "\033[1;32m[Up to date]\033[0m\033[2;37m ($plugin_version)\033[0m"
		fi
	done

	echo $seperator

	if [ ${#outdated_plugins[@]} -eq 0 ]; then
		echo "All plugins in '$working_directory' are up to date!"
		exit 0
	fi

	echo "Plugins to update:"

	for plugin_file in "${!outdated_plugins[@]}"; do
		echo " [${plugin_file}] ${outdated_plugins[$plugin_file]}"
	done

	read -p "Plugins to EXCLUDE from update (separated by space) [eg: \"0 1\"]: " exclude_numbers

	plugins_to_update=("${outdated_plugins[@]}")

	# Exclude plugins from update
	if [ -n "$exclude_numbers" ]; then
		for plugin_file in $exclude_numbers; do
			if [[ $plugin_file =~ ^[0-9]+$ ]] && [ $plugin_file -lt ${#outdated_plugins[@]} ]; then
				unset 'plugins_to_update[$number]'
			else
				echo "Invalid number: $plugin_file"
			fi
		done
		# Re-index the array
		plugins_to_update=("${plugins_to_update[@]}")
	fi

	echo $seperator
	echo "Updating the following plugins:"

	for plugin_file in "${plugins_to_update[@]}"; do
		echo " - $plugin_file"
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
	echo "Updating plugins..."

	for plugin_file in "${plugins_to_update[@]}"; do
		plugin=$(get_plugin "$plugin_file")
		echo -ne "$plugin_file..."
		update_plugin "$plugin"
		echo -e "\033[1;32mDone\033[0m"
	done

}

main