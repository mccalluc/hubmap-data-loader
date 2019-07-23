#!/usr/bin/env bash

die() { set +v; echo "$*" 1>&2 ; exit 1; }

add_CLI_ARGS() {
    # Helper for process_cells to build argument list.

    FILE_TYPE=$1
    DATA_TITLE=$2

    FILE="$OUTPUT/$DATA_TITLE.$FILE_TYPE.json"
    if [ -e "$FILE" ]
    then
        echo "$FILE_TYPE output already exists: $FILE"
    else
        CLI_ARGS="$CLI_ARGS --${FILE_TYPE}_file $FILE"
    fi
}

usage() {
    die "Usage: $0 -b <directory> -i <directory> -o <directory> -t <target>
    -b   Base directory
    -i   Input directory
    -o   Output directory
    -t   Amazon S3 target" 1>&2

    exit 1
}

get_CLI_args(){
    while getopts "b:i:o:t:" arg; do
        count=$(($count + 1))
        case $arg in
            b)
                BASE=${OPTARG}
                [ -d "${OPTARG}" ] || \
                    usage
                ;;
            i)
                INPUT=${OPTARG}
                [ -d "${OPTARG}" ] || \
                    usage
                ;;
            o)
                OUTPUT=${OPTARG}
                [ -d "${OPTARG}" ] || \
                    usage
                ;;
            t)
                S3_TARGET=${OPTARG}
                ;;
        esac
    done

    if [ "$count" != "4" ]
    then
        echo $count
        echo "All 4 arguments are required"
        usage
    fi
}
