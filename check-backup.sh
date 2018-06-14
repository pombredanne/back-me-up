#!/bin/bash

#==============================================================================
# FILE : check-backup.sh
# USAGE : check-backup.sh -t target_path
# DESCRIPTION : Check if the last update of the target_path is today
# NOTES : 
#==============================================================================

# Load shared variables and functions
{
    source "$(dirname "$0")/shared.sh" 
} || {
    echo -e "\\033[0;31mUnable to load shared.sh\\033[0m" && exit 1 
}

# Parse command line
POSITIONAL=()
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        -t)
            TARGET_PATH="$2"
            shift
            shift
            ;;
        *)
        POSITIONAL+=("$1")
        shift
        ;;
    esac
done
set -- "${POSITIONAL[@]}"

# Exit if there is a missing parameter in the command line
if [ -z "$TARGET_PATH" ]
then
    echo -e "${RED}There is no target specified${NC}" && exit 1
fi

TODAY_DATE=$(${DATE} +%Y-%m-%d)

update=$(${STAT} -c %y "${TARGET_PATH}" | ${AWK} '{print $1;}')

if [ ! "$update" == "${TODAY_DATE}" ]
then
    exit 1
fi
