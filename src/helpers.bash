# helpers.bash

# This file contains helper functions for the generated configuration scripts.

####################################################################################################

#
# AddPackage [--foreign] PACKAGE...
#
# Adds a package to the list of packages to be installed.
#

function AddPackage() {
	local fn='packages.txt'
	if [[ "$1" == "--foreign" ]]
	then
		shift
		fn='foreign-packages.txt'
	fi

	printf '%q\n' "$@" >> "$output_dir"/"$fn"
}

#
# AddPackageGroup GROUP
#
# Adds all packages belonging to a group to the list of packages to be installed.
#

function AddPackageGroup() {
	local group=$1

	pacman --sync --quiet --groups "$group" >> "$output_dir"/packages.txt
}

#
# RemovePackage [--foreign] PACKAGE...
#
# Removes an earlier-added package to the list of packages to be installed.
#
# Emitted by `aconfmgr save` when a package is present in the configuration,
# but absent on the system.
#
# You should refactor out any occurrences of this function from your configuration.
#

function RemovePackage() {
	local fn='packages.txt'
	if [[ "$1" == "--foreign" ]]
	then
		shift
		fn='foreign-packages.txt'
	fi

	local package
	for package in "$@"
	do
		sed -i "$output_dir"/"$fn" -e "/^${package}\$/d"
	done
}

#
# IgnorePackage [--foreign] PACKAGE...
#
# Adds a package to the list of packages to be ignored.
#

function IgnorePackage() {
	if [[ "$1" == "--foreign" ]]
	then
		shift
		ignore_foreign_packages+=("$@")
	else
		ignore_packages+=("$@")
	fi
}

####################################################################################################

#
# CopyFile PATH [MODE [OWNER [GROUP]]]
#
# Copies a file from the "files" subdirectory to the output.
#
# The specified path should be relative to the root of the "files" subdirectory.
#
# If MODE, OWNER and GROUP are blank or unspecified, they default to
# "644", "root" and "root" respectively for new files.
# Values corresponding to the above defaults must be specified
# as an empty string ('').
#

function CopyFile() {
	local file="$1"
	local mode="${2:-}"
	local owner="${3:-}"
	local group="${4:-}"

	CopyFileTo "$file" "$file" "$mode" "$owner" "$group"
}

#
# CopyFileTo SRC-PATH DST-PATH [MODE [OWNER [GROUP]]]
#
# Copies a file from the "files" subdirectory to the output,
# under a different name or path.
#
# The source path should be relative to the root of the "files" subdirectory.
# The destination path is relative to the root of the output directory.
#

function CopyFileTo() {
	local src_file="$1"
	local dst_file="$2"
	local mode="${3:-}"
	local owner="${4:-}"
	local group="${5:-}"

	if [[ "$src_file" != /* ]]
	then
		Log '%s: Source file path %s is not absolute.\n' \
			"$(Color Y "Warning")" \
			"$(Color C "%q" "$src_file")"
		config_warnings+=1
	fi

	if [[ "$dst_file" != /* && "$dst_file" != "$src_file" ]]
	then
		Log '%s: Target file path %s is not absolute.\n' \
			"$(Color Y "Warning")" \
			"$(Color C "%q" "$dst_file")"
		config_warnings+=1
	fi

	mkdir --parents "$(dirname "$output_dir"/files/"$dst_file")"

	cp --no-dereference\
	   "$config_dir"/files/"$src_file"\
	   "$output_dir"/files/"$dst_file"

	SetFileProperty "$dst_file" mode  "$mode"
	SetFileProperty "$dst_file" owner "$owner"
	SetFileProperty "$dst_file" group "$group"

	used_files["$src_file"]=y
}

#
# CreateFile PATH [MODE [OWNER [GROUP]]]
#
# Creates an empty file, to be included in the output.
# Prints its absolute path to standard output.
#

function CreateFile() {
	local file="$1"
	local mode="${2:-}"
	local owner="${3:-}"
	local group="${4:-}"

	mkdir --parents "$(dirname "$output_dir"/files/"$file")"

	truncate --size 0 "$output_dir"/files/"$file"

	SetFileProperty "$file" mode  "$mode"
	SetFileProperty "$file" owner "$owner"
	SetFileProperty "$file" group "$group"

	printf '%s' "$output_dir"/files/"$file"
}

#
# GetPackageOriginalFile PACKAGE PATH
#
# Extracts the original file from a package's archive for inclusion in the output.
# Prints its absolute path to standard output.
#
# As in the case of CreateFile, the file can be further modified after extraction.
#

function GetPackageOriginalFile() {
	local package="$1" # Package to extract the file from
	local file="$2" # Absolute path to file in package

	local output_file="$output_dir"/files/"$file"

	mkdir --parents "$(dirname "$output_file")"

	AconfGetPackageOriginalFile	"$package" "$file" > "$output_file"

	printf '%s' "$output_file"
}

#
# CreateLink PATH TARGET [OWNER [GROUP]]
#
# Creates a symbolic link with the specified target.
#

function CreateLink() {
	local file="$1"
	local target="$2"
	local owner="${3:-}"
	local group="${4:-}"

	mkdir --parents "$(dirname "$output_dir"/files/"$file")"

	ln --symbolic "$target" "$output_dir"/files/"$file"

	SetFileProperty "$file" owner "$owner"
	SetFileProperty "$file" group "$group"
}

#
# CreateDir PATH [MODE [OWNER [GROUP]]]
#
# Creates an empty directory at the specified path.
#
# Normally calling this function is not necessary, as creating files
# will implicitly create all parent directories. Use this function
# only when you need to create an empty directory without any files in
# it.
#

function CreateDir() {
	local file="$1"
	local mode="${2:-}"
	local owner="${3:-}"
	local group="${4:-}"

	mkdir --parents "$output_dir"/files/"$file"

	SetFileProperty "$file" mode  "$mode"
	SetFileProperty "$file" owner "$owner"
	SetFileProperty "$file" group "$group"
}

#
# RemoveFile PATH
#
# Removes an earlier-added file.
#
# Emitted by `aconfmgr save` when a file is present in the configuration,
# but absent (or, in case of files owned by packages, unmodified) on the system.
#
# You should refactor out any occurrences of this function from your configuration.
#
# If you want to delete a file owned by a package, instead use:
# SetFileProperty /path/to/file deleted y
#

function RemoveFile() {
	local file="$1"

	rm --dir "$output_dir"/files/"$file"
}

#
# SetFileProperty PATH TYPE VALUE
#
# Sets a file property.
# TYPE can be "owner", "group" "mode", or "deleted".
#
# Set "deleted" to "y" to mark a file owned by some package for deletion.
#
# To reset a file property to its default value,
# specify an empty string ('') for the VALUE parameter.
#

function SetFileProperty() {
	local file="$1"
	local type="$2"
	local value="$3"

	printf '%s\t%s\t%q\n' "$type" "$value" "$file" >> "$output_dir"/file-props.txt
}

#
# IgnorePath PATH
#
# Adds the specified path to the list of ignored paths.
#
# The argument should be a shell pattern, e.g. '/etc/foo/*'.
#

function IgnorePath() {
	ignore_paths+=("$@")
}

####################################################################################################

#
# Require DIST [URL]
#
# Adds the specified distro to the requirements. Also load its vars if any.
#
# The argument DIST must be a valid dir name located in dist_list.
# The argument URL should be a valid git url (http or ssh). If the
# distro does not exists, aconfmgr will download the repo.
#
function Require ()
{
  local dist=${1}
  local url=${2:-}
  local dist_path=

  if [[ ":$dist_list:" =~ :$dist: ]] ; then
    Log 'Require: Module %s already loaded (%s)\n' "$dist" "$dist_list"
    return
  fi

  # BUG: Implement git clone !
  dist_path=$(AconfDistPath "$dist" || true)
  if [[ ! -d "$dist_path" ]]
  then
    if [[ ! -z "$url" ]]
    then
      echo "BUG git clone $url $dist_dir/$dist"
      FatalError "Require: Can't install repo, not implemeted %s\n" "$url"
    else
      FatalError "Require: Missing repo for dist: %s\n" "$url"
    fi
  fi

  # Read vars of dist
  dist_list="$dist:$dist_list"
  Log 'Require: %s dist (%s)\n' "$dist" "$dist_list"
  AconfSource "$dist" vars || true
  # AconfSource "$dist" lib || true

}

#
# Load TYPE [FILTER]
#
# Load specific type file from the current distro.
# See AconfSource documentation below
#
function Load ()
{
  local dist=${config_dir##*/}
  AconfSource "$dist" "$@" || {
    FatalError 'Load: Failed to source: %s\n' "$@"
    }
}

#
# Import DIST TYPE [FILTER]
#
# Load specific type from any distro. DIST must have been loaded with
# the Require directive first before being able to source a file.
#
# See AconfSource documentation below
#

function Import ()
{
  AconfSource "$@" || {
    FatalError 'Import: Failed to source: %s\n' "$@"
    }
}

#
# AconfSource DIST TYPE [FILTER]
#
# Low level API.
# Load specific type from any distro. DIST must have been loaded with
# the Require directive first before being able to source a file.
#
# The argument DIST must be a valid dir name located in dist_list.
# The argument TYPE must be one of those:
# - vars: any
# - lib: any
# - state: only on state mode
# - inherit: only on state mode
# - setup: only on setup mode
# The argument FILTER is usually a filename
#
function AconfSource ()
{
  local config_name=$1
  local type=$2
  local filter=${3-}
  local config_name_path=

  # Sanity Check
  if ! [[ ":$dist_list:" =~ :$config_name: ]]
  then
    FatalError 'AconfSource: Module %s must be loaded first with a Require statement. (%s)\n' "$config_name" "$dist_list"
  fi

  config_name_path=$(AconfDistPath "$config_name" || true)
  case "$type" in
    vars)
      # Vars does not fail if not found
      AconfSourcePath "$config_name_path" "$type" "$filter" || true ;;
    unsorted)
      # Does not fail if not found
      AconfSourcePath "$config_name_path" "$type" "99-unsorted" || true ;;
    *)  #lib|state|setup|inherit)
      # Fails by default
      AconfSourcePath "$config_name_path" "$type" "$filter" 
      ;;
  esac || FatalError 'AconfSource: Cant find any suitable "%s/%s/%s"\n' "$config_name" "$type" "${filter:-*}"
}



####################################################################################################

#
# IgnoreStart [LOCK]
#
# Will ignore package and files until next IgnoreStop directive.
# Set the LOCK to true if you want to force Ignore mode.
#

ignore_fn_pkg="AddPackage RemovePackage"
ignore_fn_files="\
CopyFile CopyFileTo CreateFile \
CreateLink RemoveFile \
SetFileProperty TrackFile \
"

function IgnoreStart() {
	local lock="${1:-false}"

  if [[ "$ignore_lock" != "$lock" ]]
  then
    #Log 'IgnoreStart: Locked as its in import\n'
    return
  elif "$ignore_status"
  then
    #Log 'IgnoreStart: Already On\n'
    return
  fi

  # Generate function code
  ignore_old_fn=$(
    IFS=' '
    for fn in $ignore_fn_pkg $ignore_fn_files
    do
      declare -f "$fn" || true
    done
  )
  ignore_new_fn=$(
    IFS=' '
    for fn in $ignore_fn_pkg
    do
      # shellcheck disable=SC2016
      printf '%s () { IgnorePackage "$1"; }\n' "$fn"
    done
    for fn in $ignore_fn_files
    do
      # shellcheck disable=SC2016
      printf '%s () { IgnorePath "$1"; }\n' "$fn"
    done
  )

  # Override functions
  eval "$ignore_new_fn"
  ignore_lock=$lock
  ignore_status=true
}

#
# IgnoreStop [LOCK]
#
# Will reconsider package and files until next IgnoreStart directive.
# Set the LOCK to true if you want to force Ignore mode.
#

function IgnoreStop() {
	local lock=${1:-false}

  if [[ "$ignore_lock" != "$lock" ]]
  then
    #Log 'IgnoreStop: Locked as its in import\n'
    return
  elif "$ignore_status"
  then
    #Log 'IgnoreStop: Already Off\n'
    return
  fi

  # Override functions
  eval "$ignore_old_fn"
  ignore_lock=false
  ignore_status=false

}

####################################################################################################

#
# ApplyStates
#
# Will simulate like a aconfmgr apply. Useful for setup that want to manage when 
# the State compliance must be enforced. By default, states are applied at the
# end of the setup, unless the --skip-setup-states is enabled.
#
# Note: Can only be called in setup mode, fails otherwise
#

ApplyStates ()
{
  if [[ $aconfmgr_run_mode != 'setup' ]]; then
    FatalError "ApplyStates: this directive can only be used in setup files\n"
    return 1
  elif $setup_skip_states; then
    Log 'ApplyStates: skipped because of --skip-setup-states flag\n'
    return
  elif $dry_mode ; then
    Log 'ApplyStates: dry mode run check instead\n'
    Exec AconfApply
    AconfCheck
  else
    Log 'ApplyStates: run\n'
    Exec AconfApply
  fi
}

#
# Exec
#
# Command line wrapper. Allows to not run commands while in dry mode.
# This should be systematically used for commands.
#
# Note: Can only be called in setup mode, fails otherwise
#

function Exec ()
{
  if [[ $aconfmgr_run_mode != 'setup' ]]
  then
    FatalError "Exec: this directive can only be used in setup files\n"
    return 1
  fi

  Log "Exec: run %s\n" "$(Color Y "%q" "$@")"
  if ! $dry_mode
  then
   "$@"
  fi
}



: # include in coverage
