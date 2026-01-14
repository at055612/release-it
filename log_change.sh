#!/usr/bin/env bash

##########################################################################
# Version: <BUILD_VERSION>
# Date: <BUILD_DATE>
#
# Script to record changelog entries in individual files to get around
# the issue of merge conflicts on the CHANGELOG file when doing PRs.
#
# Credit for this idea goes to 
# https://about.gitlab.com/blog/2018/07/03/solving-gitlabs-changelog-conflict-crisis/
# 
# Change log entries are stored in files in <repo_root>/unreleased_changes
# This script is used in conjunction with tag_release.sh which adds the
# change entries to the CHANGELOG at release time.
##########################################################################

set -euo pipefail

IS_DEBUG=${IS_DEBUG:-false}
UNRELEASED_DIR_NAME="unreleased_changes"

# File containing the configuration values for this script
TAG_RELEASE_CONFIG_FILENAME='tag_release_config.env'
TAG_RELEASE_SCRIPT_FILENAME='tag_release.sh'

# e.g
# * Fix bug
# Used to look for lines that might be a change entry
#ISSUE_LINE_SIMPLE_PREFIX_REGEX="^\* [A-Z]"

# e.g.
# * Issue **#1234** : 
# * Issue **gchq/stroom-resources#104** : 
# https://regex101.com/r/VcvbFV/1
#ISSUE_LINE_NUMBERED_PREFIX_REGEX="^\* Issue \*\*([a-zA-Z0-9_\-.]+\/[a-zA-Z0-9_\-.]+\#[0-9]+|#[0-9]+)\*\* : "
ISSUE_LINE_REGEX_NUMBER_PART="\*\*([a-zA-Z0-9_\-.]+\/[a-zA-Z0-9_\-.]+\#[0-9]+|#[0-9]+)\*\*"

ISSUE_LINE_REGEX_PREFIX="^\* "

# e.g.
# 1234
# my-namespace/my-repor#1234
# foo/bar#1234
GIT_ISSUE_REGEX="^(([_.a-zA-Z0-9-]+\/[_.a-zA-Z0-9-]+\#)?[1-9][0-9]*)$"

# https://regex101.com/r/Pgvckt/1
ISSUE_LINE_TEXT_REGEX="^[A-Z].+\.$"

# Lines starting with a word in the past tense
PAST_TENSE_FIRST_WORD_REGEX='^(Add|Allow|Alter|Attempt|Chang|Copi|Correct|Creat|Disabl|Extend|Fix|Import|Improv|Increas|Inherit|Introduc|Limit|Mark|Migrat|Modifi|Mov|Preferr|Recognis|Reduc|Remov|Renam|Reorder|Replac|Restor|Revert|Stopp|Supersed|Switch|Turn|Updat|Upgrad)ed[^a-z]'

setup_echo_colours() {
  # Exit the script on any error
  set -e

  # shellcheck disable=SC2034
  if [ "${MONOCHROME:-false}" = true ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BLUE2=''
    DGREY=''
    NC='' # No Colour
  else 
    RED='\033[1;31m'
    GREEN='\033[1;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[1;34m'
    BLUE2='\033[1;34m'
    DGREY='\e[90m'
    NC='\033[0m' # No Colour
  fi
}

info() {
  echo -e "${GREEN}$*${NC}"
}

warn() {
  echo -e "${YELLOW}WARNING${NC}: $*${NC}" >&2
}

error() {
  echo -e "${RED}ERROR${NC}: $*${NC}" >&2
}

error_exit() {
  error "$@"
  exit 1
}

debug_value() {
  local name="$1"; shift
  local value="$1"; shift
  
  if [ "${IS_DEBUG}" = true ]; then
    echo -e "${DGREY}DEBUG ${name}: [${value}]${NC}"
  fi
}

debug() {
  local str="$1"; shift
  
  if [ "${IS_DEBUG}" = true ]; then
    echo -e "${DGREY}DEBUG ${str}${NC}"
  fi
}

show_help_and_exit() {
  local msg="${1:-Invalid arguments}"
  error "${msg}"
  echo -e "Usage: ${script_name} github_issue [change_text]" >&2
  echo -e "git_issue - GitHub issue number in one of the following formats:" >&2
  echo -e "            0 - No issue exists for this change" >&2
  echo -e "            n - Just the issue number." >&2
  echo -e "            namespace/repo#n - Issue number on another repo." >&2
  echo -e "            auto - Will derive the issue number from the current branch." >&2
  echo -e "            list - List all unreleased issues." >&2
  echo -e "change_text - The change text in github markdown format. This will be appended to" >&2
  echo -e "              change log entry" >&2
  echo -e "E.g:   ${script_name} 1234 \"Fix nasty bug\"" >&2
  echo -e "E.g:   ${script_name} gchq/stroom#1234 \"Fix nasty bug\"" >&2
  echo -e "E.g:   ${script_name} 1234" >&2
  echo -e "E.g:   ${script_name} auto \"Fix nasty bug\"" >&2
  echo -e "E.g:   ${script_name} 0 \"Fix something without an issue number\"" >&2
  echo -e "E.g:   ${script_name} list" >&2
  exit 1
}

# Parse the git issue number from the branch into git_issue variable,
# if possible
get_git_issue_from_branch() {
  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD)"

  # Examples of branches that will give us an issue number:
  # 1234
  # gh-1234
  # gh-1234_some-text
  # foo_1234_bar
  git_issue="$( \
    echo "${current_branch}" \
    | grep \
      --only-matching \
      --perl-regexp \
      '(^[1-9][0-9]*$|((?<=[_-])|^)[1-9][0-9]*((?=[-_])|$))' \
  )"

  debug "git_issue (from branch)" "${git_issue}"

  #if [[ -z "${git_issue_from_branch}" ]]; then
    #error_exit "Unable to establish GitHub issue number from" \
      #"branch ${BLUE}${current_branch}${NC}"
  #fi
  #echo "${git_issue_from_branch}"
}

parse_git_issue() {
  local git_issue="$1";
  debug_value "git_issue" "${git_issue}"

  if [[ "${git_issue}" =~ ^[1-9][0-9]*$ ]]; then
    # Issue in this repo so use the values we got from the local repo
    issue_namespace="${GITHUB_NAMESPACE}"
    issue_repo="${GITHUB_REPO}"
    issue_number="${git_issue}"
  else
    # Fully qualified issue so extract the parts by replacing / and # with
    # space then reading into an array which will split on space
    local parts=()
    IFS=" " read -r -a parts <<< "${git_issue//[\#\/]/ }"
    issue_namespace="${parts[0]}"
    issue_repo="${parts[1]}"
    issue_number="${parts[2]}"
  fi

  debug_value "issue_namespace" "${issue_namespace}"
  debug_value "issue_repo" "${issue_repo}"
  debug_value "issue_number" "${issue_number}"

  local github_issue_api_url="https://api.github.com/repos/${issue_namespace}/${issue_repo}/issues/${issue_number}"

  debug_value "github_issue_api_url" "${github_issue_api_url}"

  local curl_return_code=0
  # Turn off exit on error so we can get the curl return code in the subshell
  set +e 

  if command -v jq >/dev/null 2>&1; then
    # jq is available so use it
    local response_json
    response_json="$( \
      curl \
        --silent \
        --fail \
        "${github_issue_api_url}" \
    )"
    curl_return_code=$?

    issue_title="$( \
      jq \
        --raw-output \
        '.title' \
        <<< "${response_json}"
    )"
    issue_type="$( \
      jq \
        --raw-output \
        '.type.name' \
        <<< "${response_json}"
    )"
  else
    # No jq so fall back to grep, very dirty
    issue_title="$( \
      curl \
        --silent \
        --fail \
        "${github_issue_api_url}" \
      | grep \
        --only-matching \
        --prl-regexp \
        '(?<="title": ").*(?=",)' \
    )"
    curl_return_code=$?
  fi
  set -e

  debug_value "curl_return_code" "${curl_return_code}"

  # curl_return_code is NOT the http status, just sucess/fail
  if [[ "${curl_return_code}" -ne 0 ]]; then
    # curl failed so check to see what the status code was
    local http_status_code
    http_status_code="$( \
      curl \
        --silent \
        --output /dev/null \
        --write-out "%{http_code}" \
        "${github_issue_api_url}"\
    )"
    debug_value "http_status_code" "${http_status_code}"

    if [[ "${http_status_code}" = "404" ]]; then
      error_exit "Issue ${BLUE}${git_issue}${NC} does not exist on" \
        "${BLUE}github.com/(${issue_namespace}/${issue_repo}${NC}"
    else
      warn "Unable to obtain issue title for issue ${BLUE}${issue_number}${NC}" \
        "from ${BLUE}github.com/(${issue_namespace}/${issue_repo}${NC}" \
        "(HTTP status: ${BLUE}${http_status_code}${NC})"
      issue_title=""
    fi
  else
    info "Issue title: ${BLUE}${issue_title}${NC}"
  fi
}

validate_in_git_repo() {
  if ! git rev-parse --show-toplevel > /dev/null 2>&1; then
    error_exit "You are not in a git repository. This script should be run from" \
      "inside a repository.${NC}"
  fi
}

validate_change_text_arg() {
  local change_text="$1"; shift

  if ! grep --quiet --perl-regexp "${ISSUE_LINE_TEXT_REGEX}" <<< "${change_text}"; then
    error "The change entry text is not valid"
    echo -e "${DGREY}------------------------------------------------------------------------${NC}"
    echo -e "${YELLOW}${change_text}${NC}"
    echo -e "${DGREY}------------------------------------------------------------------------${NC}"
    echo -e "Validation regex: ${BLUE}${ISSUE_LINE_TEXT_REGEX}${NC}"
    exit 1
  fi

  if ! validate_tense "${change_text}"; then
    error "The change entry text should be in the imperitive mood" \
      "\ni.e. \"Fix nasty bug\" rather than \"Fixed nasty bug\""
    echo -e "${DGREY}------------------------------------------------------------------------${NC}"
    echo -e "${YELLOW}${change_text}${NC}"
    echo -e "${DGREY}------------------------------------------------------------------------${NC}"
    exit 1
  fi
}

validate_tense() {
  debug "validate_tense()"
  local change_text="$1"; shift
  debug_value "change_text" "${change_text}"

  if [[ "${IS_TENSE_VALIDATED:-true}" = true ]]; then
    if echo "${change_text}" | grep --quiet --perl-regexp "${PAST_TENSE_FIRST_WORD_REGEX}"; then
      debug "Found past tense first word"
      return 1
    else
      debug "Tense validated ok"
      return 0
    fi
  else
    debug "Tense validation disabled"
    return 0
  fi
}

select_file_from_list() {
  local file_list=( "$@" );
  
  info "Change file(s) already exist for this issue:"
  echo

  list_unreleased_changes "${git_issue_str}"

  echo
  echo "Do you want to create a new change file for the issue or open an existing one?"
  echo "If it is a different change tied to the same issue then you should create a new"
  echo "file to avoid merge conflicts."

  # Build the menu options
  local menu_item_arr=()
  if [[ "${mode}" != "edit" ]]; then
    menu_item_arr+=( "Create new file" )
  fi

  for filename in "${file_list[@]}"; do
    menu_item_arr+=( "Open ${filename}" )
  done

  local msg="Select the change file to open:"

  if [[ "${has_fzf}" = true ]]; then
    echo "${msg}"

    user_input="$( \
      printf "%s\n" "${menu_item_arr[@]}" \
        | fzf \
          --height ~40% \
          --border \
          --raw  \
          --bind result:best \
          --bind enter:accept-non-empty \
          --header="${msg} (CTRL-c or ESC to quit)" \
    )"
  else
    # Present the user with a menu of options in a single column
    COLUMNS=1
    PS3="Select the change file:"
    select user_input in "${menu_item_arr[@]}"; do
      if [[ -n "${user_input}" ]]; then
        break
      else
        echo "Invalid option. Try another one."
        continue
      fi
    done
  fi

  if [[ "${user_input}" = "Create new file" ]]; then
    write_change_entry "${change_category}" "${git_issue}" "${change_text:-}"
    # If the user didn't provide the change text as an arg, open the file
    if [[ -z "${change_text}" ]]; then
      open_file_in_editor "${change_file}" "${git_issue}"
    fi
  elif [[ "${user_input}" =~ ^Open ]]; then
    local chosen_file_name="${user_input#Open }"
    local chosen_file="${unreleased_dir}/${chosen_file_name}"
    debug_value "chosen_file_name" "${chosen_file_name}"
    if [[ -z "${git_issue}" ]]; then
      # If we have come here via the edit mode, then we may not have
      # a git_issue, so try to get it from the file/filename
      read_git_issue_from_change_file "${chosen_file}"
    fi
    open_file_in_editor "${chosen_file}" "${git_issue}"
  else
    error_exit "Unknown user_input ${user_input}"
  fi
}

read_git_issue_from_change_file() {
  local file="$1"; shift
  if [[ ! -f "${file}" ]]; then
    error_exit "File ${file} not found."
  fi

  # This regex needs to look for the line added in write_change_entry()
  # Examples:
  # # Issue number: 1234
  # # Issue number: some-user/some-repo#1234
  git_issue="$( \
    grep \
      --only-matching \
      --perl-regexp \
      '(?<=^# Issue number: )([a-zA-Z0-9_\-.]+\/[a-zA-Z0-9_\-.]+\#[0-9]+|[0-9]+)$' \
      "${file}" \
  )"
  
  # In case this is an old change file without the '# Issue number:' line
  # attempt to get it from the filename
  if [[ -z "${git_issue}" ]]; then
    local filename; filename="$(basename "${existing_file}" )"
    git_issue="$( \
      grep \
        --only-matching \
        --perl-regexp \
        '(?<=__)[0-9]+(?=\.md)' \
        <<< "${filename}" \
    )"
    if [[ -z "${git_issue}" ]]; then
      error_exit "Unable to extract git_issue from file ${file}".
    fi
  fi
}

edit_change_file_if_present() {
  local git_issue="$1"; shift
  local change_text="$1"; shift

  local git_issue_str
  git_issue_str="$(format_git_issue_for_filename "${git_issue}")"

  local existing_files=()

  for existing_file in "${unreleased_dir}"/*__"${git_issue_str}".md; do
    if [[ -f "${existing_file}" ]]; then
      debug_value "existing_file" "${existing_file}"
      local filename
      filename="$(basename "${existing_file}" )"
      existing_files+=( "${filename}" )
    fi
  done

  debug_value "existing_files" "${existing_files[@]:-()}"

  local existing_file_count="${#existing_files[@]}"
  debug_value "existing_file_count" "${existing_file_count}"

  if [[ "${existing_file_count}" -eq 0 ]]; then
    debug "File does not exist"
    return 1
  else 
    select_file_from_list "${existing_files[@]}"
    return 0
  fi
}

edit_all_files() {
  local existing_files=()

  for existing_file in "${unreleased_dir}"/*__*.md; do
    if [[ -f "${existing_file}" ]]; then
      debug_value "existing_file" "${existing_file}"
      local filename
      filename="$(basename "${existing_file}" )"
      existing_files+=( "${filename}" )
    fi
  done

  debug_value "existing_files" "${existing_files[@]:-()}"
  local existing_file_count="${#existing_files[@]}"
  debug_value "existing_file_count" "${existing_file_count}"

  if [[ "${existing_file_count}" -eq 0 ]]; then
    info "There are no change files to edit."
  else 
    select_file_from_list "${existing_files[@]}"
  fi
}

format_git_issue_for_filename() {
  local git_issue="$1"; shift

  local git_issue_str
  if [[ "${git_issue}" = "0" ]]; then
    git_issue_str="0"
  else
    # replace / and # with _
    git_issue_str="${git_issue//[\#\/]/_}"
    #debug_value "git_issue_str" "${git_issue_str}"
  fi
  echo "${git_issue_str}"
}

write_change_entry() {
  local change_category="$1"; shift
  local git_issue="$1"; shift
  local change_text="$1"; shift

  local date_str
  date_str="$(date --utc +%Y%m%d_%H%M%S_%3N)"

  local git_issue_str
  git_issue_str="$(format_git_issue_for_filename "${git_issue}")"
  
  # Use two underscores to help distinguish the date from the issue part
  # which may itself contain underscores.
  local filename="${date_str}__${git_issue_str}.md"
  local change_file="${unreleased_dir}/${filename}"

  debug_value "change_file" "${change_file}"

  if [[ -e "${change_file}" ]]; then
    error_exit "File ${BLUE}${change_file}${NC} already exists"
  fi

  local line_prefix="* "
  local category_part="${change_category}"
  local issue_prefix="**"
  local issue_suffix="**"

  # * Bug **#1234** : Some text
  # * Feature **#1234** : Some text
  # * Feature **user/repo#1234** : Some text
  # * Refactor : Some text

  local issue_part
  if [[ "${git_issue}" = "0" ]]; then
    issue_part=": "
  elif [[ "${git_issue}" =~ ^[0-9]+$ ]]; then
    # * Issue **#1234** : My change text
    issue_part="${issue_prefix}#${git_issue}${issue_suffix} : "
  else
    # * Issue **gchq/stroom#1234** : 
    issue_part="${issue_prefix}${git_issue}${issue_suffix} : "
  fi

  local change_entry_line="${line_prefix}${category_part} ${issue_part}${change_text}"
  local all_content

  # Craft the content of the file
  # shellcheck disable=SC2016
  all_content="$( \
    echo "${change_entry_line}" 
    echo
    echo
    echo '```sh'
    if [[ -n "${issue_title:-}" ]]; then
      local github_issue_url="https://github.com/${issue_namespace}/${issue_repo}/issues/${issue_number}"
      echo "# ********************************************************************************"
      echo "# Issue number: ${git_issue}"
      echo "# Issue title:  ${issue_title}"
      echo "# Issue link:   ${github_issue_url}"
      echo "# ********************************************************************************"
      echo
    fi
    echo "# ONLY the top line will be included as a change entry in the CHANGELOG."
    echo "# The entry should be in GitHub flavour markdown and should be written on a SINGLE"
    echo "# line with no hard breaks. You can have multiple change files for a single GitHub issue."
    echo "# The  entry should be written in the imperative mood, i.e. 'Fix nasty bug' rather than"
    echo "# 'Fixed nasty bug'."
    echo "#"
    echo "# Examples of acceptable entries are:"
    echo "#"
    echo "#"
    echo "# * Bug **#123** : Fix bug with an associated GitHub issue in this repository."
    echo "#"
    echo "# * Bug **namespace/other-repo#456** : Fix bug with an associated GitHub issue in another repository."
    echo "#"
    echo "# * Feature **#789** : Add new feature X."
    echo "#"
    echo "# * Bug : Fix bug with no associated GitHub issue."
    echo "#"
    echo "#"
    echo "# Note: The line must start '* XXX ', where 'XXX' is a valid category,"
    echo "#       one of [${change_categories[*]}]."
    echo
    echo
    echo "# --------------------------------------------------------------------------------"
    echo "# The following is random text to make this file unique for git's change detection"
    # shellcheck disable=SC2034
    for ignored in {1..30}; do
      # Print 80 random chars to std out
      echo -n "# "
      tr -dc A-Za-z0-9 </dev/urandom \
        | head -c 80 \
        || true
      # Add the line break
      echo
    done
    echo "# --------------------------------------------------------------------------------"
    echo
    echo '```'
  )"

  info "Writing file ${BLUE}${change_file}${GREEN}:"
  info "${DGREY}------------------------------------------------------------------------${NC}"
  info "${YELLOW}${change_entry_line}${NC}"
  info "${DGREY}------------------------------------------------------------------------${NC}"

  echo -e "${all_content}" > "${change_file}"

  #if [[ -z "${change_text}" ]]; then
    #open_file_in_editor "${change_file}" "${git_issue}"
  #fi
}

# Return zero if the file was changed, else non-zero
open_file_in_editor() {
  local file_to_open="$1"; shift
  local git_issue="$1"; shift
  
  local editor
  editor="${VISUAL:-${EDITOR:-vi}}"

  local is_first_pass=true

  info "Opening file ${BLUE}${file_to_open}${GREEN} in editor" \
    "(${BLUE}${editor}${GREEN})${NC}"

  while true; do
    if [[ "${is_first_pass}" = true ]]; then
      read -n 1 -s -r -p "Press any key to open the file"
    else
      read -n 1 -s -r -p "Press any key to re-open the file"
      # Extra line break for subsequent passes to separate them
      echo
    fi

    echo
    echo

    # Open the user's preferred editor or vi/vim if not set
    "${editor}" "${file_to_open}"

    if validate_issue_line_in_file "${file_to_open}" "${git_issue}"; then
      # Happy with the file so break out of loop
      info "File passed validation"
      break;
    fi
    is_first_pass=false
  done
}

validate_issue_line_in_file() {
  debug "validate_issue_line_in_file ($*)"
  local change_file="$1"; shift
  local git_issue="$1"; shift

  debug "Validating file ${change_file}"
  debug_value "git_issue" "${git_issue}"

  # * Bug **#1234** : Some text
  # * Feature **#1234** : Some text
  # * Feature **user/repo#1234** : Some text
  # * Refactor : Some text

  local issue_line_prefix_regex
  issue_line_prefix_regex+="${ISSUE_LINE_REGEX_PREFIX}"
  issue_line_prefix_regex+="${change_categories_regex} "
  if [[ "${git_issue}" = "0" ]]; then
    #issue_line_prefix_regex="${ISSUE_LINE_SIMPLE_PREFIX_REGEX}"
    issue_line_prefix_regex+=": "
  else
    #issue_line_prefix_regex="${ISSUE_LINE_NUMBERED_PREFIX_REGEX}"
    issue_line_prefix_regex+="${ISSUE_LINE_REGEX_NUMBER_PART} : "
  fi
  # Change text should start with a capital
  issue_line_prefix_regex+="[A-Z]"
  debug_value "issue_line_prefix_regex" "${issue_line_prefix_regex}"

  local issue_line_count
  issue_line_count="$( \
    grep \
      --count \
      --perl-regexp \
      "${issue_line_prefix_regex}" \
      "${change_file}" \
    || true
    )"

  debug_value "issue_line_count" "${issue_line_count}"

  if [[ "${issue_line_count}" -eq 0 ]]; then
    error "No change entry line found in ${BLUE}${change_file}${NC}"
    echo -e "Line prefix regex: ${BLUE}${issue_line_prefix_regex}${NC}"
    return 1
  elif [[ "${issue_line_count}" -gt 1 ]]; then
    local matching_change_lines
    matching_change_lines="$(grep --perl-regexp "${issue_line_prefix_regex}" "${change_file}" )"
    error "More than one entry lines found in ${BLUE}${change_file}${NC}:"
    echo -e "${DGREY}------------------------------------------------------------------------${NC}"
    echo -e "${YELLOW}${matching_change_lines}${NC}"
    echo -e "${DGREY}------------------------------------------------------------------------${NC}"
    echo -e "Line prefix regex: ${BLUE}${issue_line_prefix_regex}${NC}"
    return 1
  else
    # Found one issue line which should be on the top line so validate it
    local issue_line
    issue_line="$(head -n1 "${change_file}")"

    # Line should look like one of
    # * Bug : Fix something.
    # * Bug **#1234** : Fix something.
    # * Feature **gchq/stroom-resources#104** : Change something.
    # Delete the prefix part
    local issue_line_text="${issue_line#*: }"

    debug_value "issue_line" "${issue_line}"
    debug_value "issue_line_text" "${issue_line_text}"

    if ! echo "${issue_line_text}" | grep --quiet --perl-regexp "${ISSUE_LINE_TEXT_REGEX}"; then
      error "The change entry text is not valid in ${BLUE}${change_file}${NC}:"
      echo -e "${DGREY}------------------------------------------------------------------------${NC}"
      echo -e "${YELLOW}${issue_line_text}${NC}"
      echo -e "${DGREY}------------------------------------------------------------------------${NC}"
      echo -e "Validation regex: ${BLUE}${ISSUE_LINE_TEXT_REGEX}${NC}"
      return 1
    fi

    if ! validate_tense "${issue_line_text}"; then
      error "The change entry text should be in the imperitive mood" \
        "\ni.e. \"Fix nasty bug\" rather than \"Fixed nasty bug\""
      echo -e "${DGREY}------------------------------------------------------------------------${NC}"
      echo -e "${YELLOW}${issue_line_text}${NC}"
      echo -e "${DGREY}------------------------------------------------------------------------${NC}"
      return 1
    fi
  fi
}

list_unreleased_changes() {

  # if no git issue is provided use a wildcard so we can get all issues
  local git_issue_str="${1:-*}"; shift
  debug_value "git_issue_str" "${git_issue_str}"
  local found_change_files=false
  local list_output=""

  local format_cmds=()
  if command -v fmt >/dev/null 2>&1; then
    format_cmds=( "fmt" "--width=80" )
  else
    # No fmt cmd so use tee to just send stdin to stdout
    format_cmds=( "tee" )
  fi

  echo "[${git_issue_str}]"

  # git_issue_str may be '*' so we must not quote it else the
  # globbing won't work
  # shellcheck disable=SC2231
  for file in "${unreleased_dir}/"*__${git_issue_str}.md; do
    if [[ -f "${file}" ]]; then
      local filename
      local change_entry_line

      found_change_files=true
      filename="$(basename "${file}" )"

      # Get first line of the file and word wrap it
      change_entry_line="$( \
        head \
          -n1 \
          "${file}" \
        | "${format_cmds[@]}" )"
      list_output+="${BLUE}${filename}${NC}:\n${change_entry_line}\n\n"
    fi
  done

  #if [[ "${#entry_map[@]}" -gt 0 ]]; then
  if [[ "${found_change_files}" = true ]]; then
    #for filename in "${!MYMAP[@]}"; do echo $K; done

    # Remove the trailing blank lines
    list_output="$(echo -e "${list_output}" | head -n-2 )"

    echo -e "${list_output}"
  else
    info "There are no unreleased changes"
  fi
}

validate_bash_version() {
  if (( BASH_VERSINFO[0] < 4 )); then
    error_exit "This script requires Bash version 4 or greater." \
      "Please install it."
  fi
}

validate_env() {
  if [[ -n "${GITHUB_NAMESPACE}" ]]; then
    error_exit "Variable ${YELLOW}GITHUB_NAMESPACE${NC} must be set in the " \
      "${BLUE}${TAG_RELEASE_CONFIG_FILENAME}${NC} file."
  fi
  if [[ -n "${GITHUB_REPO}" ]]; then
    error_exit "Variable ${YELLOW}GITHUB_REPO${NC} must be set in the " \
      "${BLUE}${TAG_RELEASE_CONFIG_FILENAME}${NC} file."
  fi
  if [[ -n "${CHANGE_CATEGORIES}" ]]; then
    error_exit "Variable ${YELLOW}CHANGE_CATEGORIES${NC} must be set in the " \
      "${BLUE}${TAG_RELEASE_CONFIG_FILENAME}${NC} file."
  fi
  if ! command -v basename >/dev/null 2>&1; then
    error_exit "${BLUE}basename${NC} is not installed." \
      "Please install it via the GNU coreutils package."
  fi
}

build_categories_regex() {
  change_categories_regex="("
  local idx=0
  for category in "${change_categories[@]}"; do

    if [[ "${idx}" -ne 0 ]]; then
      change_categories_regex+="|"
    fi
    change_categories_regex+="${category}"
    (( idx++ )) || true
  done
  change_categories_regex+=")"
}

is_change_category() {
  local text="${1:-}"
  if [[ -z "${text}" ]]; then
    return 1
  elif [[ ${#change_categories[@]} -eq 0 ]]; then
    # Empty arr, no change categories
    return 1
  else
    local lower_text="${1,,}"
    for category in "${change_categories[@]}"; do
      local lower_category="${category,,}"
      if [[ "${lower_text}" = "${lower_text}" ]]; then
        return 0
      fi
    done
    # Not found
    return 1
  fi
}

# Update change_category variable to match the case from the env file
normalise_change_category() {
  if [[ -z "${change_category}" ]]; then
    error_exit "change_category is unset in call to normalise_change_category"
  fi

  for category in "${change_categories[@]}"; do
    if [[ "${change_category,,}" = "${category,,}" ]]; then
      # Set it to the case from the env file
      change_category="${category}"
      return 0
    fi
    error_exit "Category '${category}' not found in ${change_categories[*]}"
  done
}

# Make sure it has not been configured with any categories that
# will get confused with other special args.
validate_categories() {
  for category in "${change_categories[@]}"; do
    local lower_category="${category,,}"
    if [[ "${lower_category}" =~ (list|edit|auto) ]]; then
      error_exit "'${category}' is a reserved word so cannot be used" \
        "as a category"
    fi
  done
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    mode="interactive"
    return 0
  fi

  if [[ "$1" = "list" ]] ; then
    if [[ $# -eq 1 ]]; then
      mode="list"
      return 0
    else
      show_help_and_exit "Invalid arguments. 'list' should be the only" \
        "argument if you want to list the unreleased changes."
    fi
  fi

  if [[ $# -gt 3 ]]; then
    show_help_and_exit
  fi

  if [[ "$1" = "edit" ]] ; then
    mode="edit"
    if [[ $# -gt 2 ]]; then
      show_help_and_exit "Invalid arguments. 'edit' should be the only" \
        "argument or followed by the git issue number."
    fi
  else
    change_category="$1"
    if is_change_category "$1"; then
      normalise_change_category
      debug_value "change_category" "${change_category}"
    else
      show_help_and_exit "Invalid arguments. Expecting the first argument" \
        "${BLUE}${change_category}${NC} to be a change " \
        "category [${BLUE}${change_categories[*]}${NC}]."
    fi
  fi

  git_issue="$2"
  debug_value "git_issue" "${git_issue}"
  if [[ "${git_issue}" != "0" ]]; then
    if [[ "${git_issue}" = "auto" ]]; then
      # Extract the GH issue from the branch name
      get_git_issue_from_branch

      if [[ -z "${git_issue}" ]]; then
        error_exit "Unable to establish GitHub issue number from" \
          "branch ${BLUE}${current_branch}${NC}"
      fi
    fi

    if [[ "${git_issue}" =~ $GIT_ISSUE_REGEX ]]; then
      parse_git_issue "${git_issue}"
    else
      show_help_and_exit "Invalid arguments. Expecting second argument" \
        "${BLUE}${git_issue}${NC} to be" \
        "a GitHub issue number (e.g. ${BLUE}1234${NC} or " \
        "${BLUE}some-user/some-repo#1234${NC}) or '${BLUE}auto${NC}' to " \
        "determine the issue number from the branch."
    fi
  fi

  if [[ $# -gt 2 ]]; then
    change_text="$3"
    debug_value "change_text" "${change_text}"
    if [[ -n "${change_text}" ]]; then
      validate_change_text_arg "${change_text}"
    fi
  fi
}

capture_git_issue() {
  while true; do
    echo -e "Enter one of the following:"
    echo -e "  * The GitHub issue number (e.g. ${BLUE}1234${NC})."
    echo -e "  * A fully qualified issue (e.g. ${BLUE}user/repo#1234${NC})."
    echo -e "  * '0' to not associate the change entry with an issue."

    read -e -r user_input

    if [[ "${user_input}" = "0" || "${user_input}" =~ ${GIT_ISSUE_REGEX} ]]; then
      git_issue="${user_input}"
      break
    else
      echo
      echo -e "Invalid GitHub issue ${BLUE}${user_input}${NC}"
      echo
      # Go round again
    fi
  done
}

capture_category() {
  local msg="Select the appropriate category for this change:"

  if [[ "${has_fzf}" = true ]]; then
    echo "${msg}"

    # Use FZF to get the category
    # Printf to convert space delim to line delim for FZF
    user_input="$( \
      printf "%s\n" "${change_categories[@]}" \
        | fzf \
          --height ~40% \
          --border \
          --raw  \
          --bind result:best \
          --bind enter:accept-non-empty \
          --header="${msg} (CTRL-c or ESC to quit)" \
    )"

    if [[ -z "${user_input}" ]]; then
      # User must have done a ctrl-c
      echo "No category selected, quitting." >&2
      exit 1
    else
      change_category="${user_input}"
    fi
  else
    echo "${msg}"
    COLUMNS=1
    PS3="Select the category for this change:"
    select user_input in "${change_categories[@]}"; do
      if [[ -n "${user_input}" ]]; then
        change_category="${user_input}"
        break
      fi
    done
  fi
}

# Prompt the user to get the category, issue and change text
# depending on the mode
prompt_user_for_remaining_args() {
  if [[ "${mode}" != "edit" && -z "${change_category}" ]]; then
    infer_category_from_issue_type
    if [[ -z "${change_category}" ]]; then
      capture_category
    fi
  fi

  if [[ -z "${git_issue}" ]]; then
    # Have a stab at getting the git issue number from the branch first
    if [[ -z "${git_issue}" ]]; then
      get_git_issue_from_branch
    fi
    capture_git_issue
  fi
}

# If we have a issue_type from the GH api call and it matches
# one of our categories, then use that category.
infer_category_from_issue_type() {
  if [[ -n "${issue_type}" && -z "${change_category}" ]]; then
    for category in "${change_categories[@]}"; do
      # ',,' to compare in  lower case
      if [[ "${issue_type,,}" = "${category,,}" ]]; then
        change_category="${category}"
        echo -e "Inferred change category '${BLUE}${change_category}${NC}'" \
          "from the GitHub issue."
        break
      fi
    done
  fi
}

check_for_fzf() {
  if command -v fzf > /dev/null; then
    has_fzf=true
  fi
}

main() {
  #local SCRIPT_DIR
  #SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
  #debug_value "SCRIPT_DIR" "${SCRIPT_DIR}"
  local script_name="$0"
  local has_fzf=false

  setup_echo_colours
  validate_bash_version
  validate_env
  validate_in_git_repo
  check_for_fzf

  local repo_root_dir
  repo_root_dir="$(git rev-parse --show-toplevel)"

  local tag_release_config_file="${repo_root_dir}/${TAG_RELEASE_CONFIG_FILENAME}"
  if [[ -f "${tag_release_config_file}" ]]; then
    # Source any repo specific config
    # shellcheck disable=SC1090
    source "${tag_release_config_file}"
  else
    error_exit "Config file ${BLUE}${tag_release_config_file}${NC}" \
      "doesn't exist. Run ${BLUE}./${TAG_RELEASE_SCRIPT_FILENAME}${NC}" \
      "to generate it."
  fi

  # Ensure change_categories is set to an empty arr if unset
  local -a change_categories=${CHANGE_CATEGORIES:-( )}
  local change_categories_regex
  local change_category
  local git_issue
  local change_text
  local mode="log"
  local issue_title=""
  local issue_namespace
  local issue_type
  local issue_repo
  local issue_number
  local unreleased_dir="${repo_root_dir}/${UNRELEASED_DIR_NAME}"
  mkdir -p "${unreleased_dir}"

  build_categories_regex
  parse_args "$@"

  debug_value "Parsed arguments" "$*"
  debug_value "mode" "${mode}"
  debug_value "change_category" "${change_category}"
  debug_value "git_issue" "${git_issue}"
  debug_value "change_text" "${change_text}"
  debug_value "GITHUB_NAMESPACE" "${GITHUB_NAMESPACE}"
  debug_value "GITHUB_REPO" "${GITHUB_REPO}"

  if [[ "${mode}" = "list" ]]; then
    list_unreleased_changes ""
  elif [[ "${mode}" = "edit" ]]; then
    if [[ -n "${git_issue}" ]]; then
      edit_change_file_if_present "${git_issue}" "" || true
    else
      edit_all_files
    fi
  elif [[ "${mode}" = "log" ]]; then
    # Capture the category or git issue if required
    prompt_user_for_remaining_args

    if [[ "${git_issue}" = "0" ]] \
      || ! edit_change_file_if_present "${git_issue}" "${change_text:-}"; then

      write_change_entry "${change_category}" "${git_issue}" "${change_text:-}"

      # If the user didn't provide the change text as an arg, open the file
      if [[ -z "${change_text}" ]]; then
        open_file_in_editor "${change_file}" "${git_issue}"
      fi
    fi
  else
    error_exit "Unexpected mode ${mode}"
  fi
}

main "$@"

# vim: set tabstop=2 shiftwidth=2 expandtab:
