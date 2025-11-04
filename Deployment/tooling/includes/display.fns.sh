#
# Display functions
#
# This file contains utility functions for formatting and displaying output in the terminal,
# including headings, separators, boxes, and banners for better readability.
#

include "display.var.sh"

# Display a horizontal separator line
# Parameters:
#   $1: char - Character to use for the line (default: "-")
#   $2: length - Length of the line in characters (default: terminal width from displayCols)
# Returns: None (outputs to stdout)
# Example: printSeparatorLine "=" 50
function printSeparatorLine() {
  local char=${1:-"-"}
  local length=${2:-${displayCols}}
  printf '%*s\n' "${length}" '' |  tr ' ' "${char}"
}

# Display a level 1 heading (most prominent)
# Parameters:
#   $1: text - The heading text to display (required)
# Returns: None (outputs to stdout)
# Format:
#   Headline
#   *******************************************************************************************************************
# Example: h1 "Uitsmijter Build System"
function h1(){
  echo ""
  echo "${1}"
  printSeparatorLine "*"
  echo ""
}

# Display a level 2 heading
# Parameters:
#   $1: text - The heading text to display (required)
# Returns: None (outputs to stdout)
# Format:
#   Headline
#   ===================================================================================================================
# Example: h2 "Running Unit Tests"
function h2(){
  echo ""
  echo "${1}"
  printSeparatorLine "="
}

# Display a level 3 heading (least prominent)
# Parameters:
#   $1: text - The heading text to display (required)
# Returns: None (outputs to stdout)
# Format:
#   Headline
#   -------------------------------------------------------------------------------------------------------------------
# Example: h3 "Setting up certificates"
function h3(){
  echo ""
  echo "${1}"
  printSeparatorLine "-"
}

# Display text with an underline
# Parameters:
#   $1: text - The text to underline (required)
#   $2: char - Character to use for underlining (default: "-")
# Returns: None (outputs to stdout)
# Example: underline "Important Section" "="
function underline() {
  local text=${1}
  local char=${2:-"-"}
  local length=${#text}
  echo "${text}"
  printf '%*s\n' "${length}" '' |  tr ' ' "${char}"
}

# Display a message in a compact box (width fits the message)
# Parameters:
#   $1: msg - The message to display in the box (required)
#   $2: char - Character to use for box borders (default: "*")
# Returns: None (outputs to stdout)
# Format:
#   ********
#   * Text *
#   ********
# Example: echoBox "Build completed successfully" "="
function echoBox() {
  local msg="${1}"
  local char="${2:-"*"}"
  local size=${#msg}
  local length=$((size + 4))
  printSeparatorLine "${char}" "${length}"
  echo -n "${char} "
  echo -n "${msg}"
  echo " ${char}"
  printSeparatorLine "${char}" "${length}"
}

# Display a message as a full-width banner
# Parameters:
#   $1: msg - The message to display in the banner (required)
#   $2: char - Character to use for banner borders (default: "*")
# Returns: None (outputs to stdout)
# Format:
#   *******************************************************************************************************************
#   * Text                                                                                                            *
#   *******************************************************************************************************************
# Example: echoBanner "Uitsmijter Tooling" "~"
function echoBanner() {
  local msg="${1}"
  local char="${2:-"*"}"
  local size=${#msg}
  local length=$((size + 4))
  length=$((displayCols - length))
  printSeparatorLine "${char}"
  echo -n "${char} "
  echo -n "${msg}"
  printf '%*s' "${length}" ''
  echo " ${char}"
  printSeparatorLine "${char}"
}
