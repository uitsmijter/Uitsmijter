#
# Display variables
#

read -r dispalyRows dispalyCols < <(stty size 2>/dev/null || echo "30 120")
SYMBOL_FAIL=$'\xe2\x9d\x8c'
SYMBOL_SUCCESS=$'\xe2\x9c\x85'
SYMBOL_BELOW=$'\342\254\207'
SYMBOL_WARNING=$'\xF0\x9F\x9F\xA0'
