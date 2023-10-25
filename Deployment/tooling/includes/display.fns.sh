#
# Display functions
#

include "display.var.sh"

# Display a line of optional 1:characters and optional 2:length
# if no character is given the default is `-`
# if no length is given than the line will be in full width of the terminal
function printSeparatorLine() {
  local char=${1:-"-"}
  local length=${2:-${dispalyCols}}
  printf '%*s\n' "${length}" '' |  tr ' ' "${char}"
}

# Headline 1
function h1(){
  echo ""
  echo "${1}"
  printSeparatorLine "*"
  echo ""
}

# Headline 2
function h2(){
  echo ""
  echo "${1}"
  printSeparatorLine "="
}

# Headline 3
function h3(){
  echo ""
  echo "${1}"
  printSeparatorLine "-"
}

# Underline given 1:text with optional 2:character
# If no optional character is set the default `-` is taken
function underline() {
  local text=${1}
  local char=${2:-"-"}
  local length=${#text}
  echo "${text}"
  printf '%*s\n' "${length}" '' |  tr ' ' "${char}"
}

# Show a 1:message in a box. The box is made with optional 2:character.
# If no character is set a `*` is used
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

# Show a 1:message as a banner. The banner box is made with optional 2:character.
# If no character is set a `*` is used
function echoBanner() {
  local msg="${1}"
  local char="${2:-"*"}"
  local size=${#msg}
  local length=$((size + 4))
  length=$((dispalyCols - length))
  printSeparatorLine "${char}"
  echo -n "${char} "
  echo -n "${msg}"
  printf '%*s' "${length}" ''
  echo " ${char}"
  printSeparatorLine "${char}"
}
