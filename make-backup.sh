#!/bin/bash

#==============================================================================
# FILE : make-backup.sh
# USAGE : make-backup.sh -c configfile
# DESCRIPTION : Make a back-up with Borg of the files listed in the configfile
# NOTES : 
#==============================================================================

set -euo pipefail

# Load shared variables and functions
{
    'source' "$(dirname "$0")/shared.sh" 
} || {
    'echo' -e "\\033[0;31mUnable to load shared.sh\\033[0m" && exit 1 
}

'echo' -e "${GREEN}make-backup starts !${NC}"

# Parse command line
POSITIONAL=()
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        -c|--configfile)
            CONFIGFILE="$2"
            'shift'
            'shift'
            ;;
        -h|--help)
            help "make-backup"
            ;;
        *)
        POSITIONAL+=("$1")
        'shift'
        ;;
    esac
done
set -- "${POSITIONAL[@]}"

# Load configfile
{
    'echo' -e "* ${BLUE}Load ${CONFIGFILE}${NC}"
    'source' "${CONFIGFILE}"
} || {
    'echo' -e "${RED}Something happens while loading ${CONFIGFILE}${NC}" && exit 1
}

if [ -z "$BORGREPO" ]
then
    'echo' -e "${RED}There is no borg repo specified${NC}" && exit 1
fi

# Create and init borg repo if needed
if [ ! -d "$BORGREPO" ]
then
    {
        'echo' -e "* ${BLUE}Create ${BORGREPO}${NC}"
        'mkdir' -p "${BORGREPO}"
        'echo' -e "* ${BLUE}Init ${BORGREPO}${NC}"
        if [ "${BORG_PASSPHRASE}" != "" ]
        then
            'borg' init --critical --encryption=repokey "${BORGREPO}"
        else
            'borg' init --critical --encryption=none "${BORGREPO}"
        fi
    } || {
        'echo' -e "${RED}Unable to create and init ${BORGREPO}${NC}" && exit 1
    }
fi

# Execute before backup commands
if [ -n "$(type before_backup)" ]
then
    'echo' -e "${BLUE}Executing before commands${NC}"
    {
        before_backup
    } || {
        'echo' -e "${YELLOW}Failed to execute \"function before_backup\"${NC}"
    }
fi

# Create archives
# Files
if [[ ! -v FILES[@] ]]
then
    'echo' -e "${YELLOW}No files to back-up${NC}"
else
    'echo' -e "* ${BLUE}Start archiving files${NC}"
fi

for file in "${FILES[@]}"
do
    archive_name=${file}
    if [ "${archive_name:0:1}" = "/" ]
    then
        archive_name=$('echo' "${archive_name}" | ${CUT} -c2-)
    fi
    archive_name=$(${DATE} +%Y-%m-%d)"-"${archive_name//\//-}
    'echo' -e "${BLUE}Create back-up ${archive_name}${NC}"
    {
        'borg' create "${BORGREPO}"::"${archive_name}" "${file}"
    } || {
        if [ $? -eq 2 ]
        then
            'echo' -e "${YELLOW}Archive already exists${NC}"
        else
            'echo' -e "${RED}Unable to create the back-up${NC}" && exit 1
        fi
    }
    sleep 1
done

'echo' -e "${GREEN}Back-up for files succeed !${NC}"

# Sqlite databases
if [[ ! -v SQLITEDB[@] ]]
then
    'echo' -e "${YELLOW}No sqlitedb to back-up${NC}"
else
    'echo' -e "* ${BLUE}Start archiving sqlitedb${NC}"
fi

for file_name in "${!SQLITEDB[@]}"
do
    today_date=$(${DATE} +%Y-%m-%d)
    archive_name=${file_name##*/}
    archive_name="${today_date}-"${archive_name//\//-}

    archive_path=${file_name%/*}
    if [ ! -d "${archive_path}" ]
    then
        {
            'echo' -e "* ${BLUE}Create ${archive_path}${NC}"
            'mkdir' -p "${archive_path}"
        } || {
            'echo' -e "${RED}Unable to create ${archive_path}${NC}" && exit 1
        }
    fi


    'echo' -e "${BLUE}.backup ${SQLITEDB[$file_name]}${NC}"
    if [ ! "$('date' +%Y-%m-%d -r ${file_name})" = "${today_date}" ]
    then
        {
            'sqlite3' ${SQLITEDB[${file_name}]} ".backup $file_name"
        } || {
            'echo' -e "${RED}Unable to execute the .dump command${NC}"
            'echo' -e "${RED}Unable to create the back-up${NC}" && exit 1
        }
    else
        'echo' -e "${YELLOW}Dump for today already exists${NC}"
    fi
    'echo' -e "${BLUE}Create back-up ${archive_name}${NC}"
    {
        'borg' create "${BORGREPO}"::"${archive_name}" "${file_name}"
    } || {
        if [ $? -eq 2 ]
        then
            'echo' -e "${YELLOW}Archive already exists${NC}"
        else
            'echo' -e "${RED}Unable to create the back-up${NC}" && exit 1
        fi
    }
    sleep 1
done

'echo' -e "${GREEN}Back-up for sqlitedb succeed !${NC}"


# Postgres databases
if [[ ! -v POSTGRESDB[@] ]]
then
    'echo' -e "${YELLOW}No postgresdb to back-up${NC}"
else
    'echo' -e "* ${BLUE}Start archiving postgresdb${NC}"
fi

for file_name in "${!POSTGRESDB[@]}"
do
    today_date=$(${DATE} +%Y-%m-%d)
    archive_name=${file_name##*/}
    archive_name="${today_date}-"${archive_name//\//-}

    archive_path=${file_name%/*}
    if [ ! -d "${archive_path}" ]
    then
        {
            'echo' -e "* ${BLUE}Create ${archive_path}${NC}"
            'mkdir' -p "${archive_path}"
        } || {
            'echo' -e "${RED}Unable to create ${archive_path}${NC}" && exit 1
        }
    fi


    'echo' -e "${BLUE}pg_dump ${POSTGRESDB[$file_name]}${NC}"
    if [ ! "$('date' +%Y-%m-%d -r ${file_name})" = "${today_date}" ]
    then
        {
            'pg_dump' ${POSTGRESDB[${file_name}]} > "$file_name"
        } || {
            'echo' -e "${RED}Unable to execute the pg_dump command${NC}"
            'echo' -e "${RED}Unable to create the back-up${NC}" && exit 1
        }
    else
        'echo' -e "${YELLOW}Dump for today already exists${NC}"
    fi
    'echo' -e "${BLUE}Create back-up ${archive_name}${NC}"
    {
        'borg' create "${BORGREPO}"::"${archive_name}" "${file_name}"
    } || {
        if [ $? -eq 2 ]
        then
            'echo' -e "${YELLOW}Archive already exists${NC}"
        else
            'echo' -e "${RED}Unable to create the back-up${NC}" && exit 1
        fi
    }
    sleep 1
done

'echo' -e "${GREEN}Back-up for postgresdb succeed !${NC}"

'echo' -e "* ${BLUE}Cleaning back-ups${NC}"
{
    'borg' prune ${PRUNE_OPT} "${BORGREPO}"
} || {
    'echo' -e "${RED}Unable to clean the back-ups${NC}" && exit 1
}

# Execute after backup commands
if [ -n "$(type after_backup)" ]
then
    'echo' -e "${BLUE}Executing after commands${NC}"
    {
        after_backup
    } || {
        'echo' -e "${YELLOW}Failed to execute \"function after_backup\"${NC}"
    }
fi

'echo' -e "${GREEN}make-backup ended !${NC}"
