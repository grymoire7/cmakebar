#!/bin/bash

# cmakebar.sh - a CMake progress bar
# This code takes output from 'build_technology make' as input on stdin
# and displays a progress bar in the terminal.  This is unteseted with
# generic cmake output.
#
# Usage:
#
#     build_technology make 2>&1 | cmakebar.sh
#     build_technology make 2>&1 | cmakebar.sh -o cmake.log
#     build_technology make 2>&1 | cmakebar.sh -ro cmake.log
#     build_technology make 2>&1 | cmakebar.sh -l
#     build_technology make 2>&1 | cmakebar.sh -rl
#     cat cmake.log | cmakebar.sh
#
# Todo:
#   [ ] See if there's a faster way than read -r line
#       Bash version processes a.log in 8s
#       Go   version processes a.log in 83ms
#       This could be dwarfed by cmake live times, but still...
#
# Author: Tracy Atteberry
# Date:   Spring 2014

TWIDTH=`tput cols`

usage()
{
    cat <<'EOM'

Options: $0 [-h | -o cmake.log | -l | -r ]

    -h        Show this help
    -r        Remove existing log file before logging
              Otherwise append if it exists
    -l        Log to cmake.log
    -o file   Log to named file

Usage:

    build_technology make 2>&1 | $0
    build_technology make 2>&1 | $0 -o cmake.log
    build_technology make 2>&1 | $0 -ro cmake.log
    build_technology make 2>&1 | $0 -l
    build_technology make 2>&1 | $0 -rl
    cat cmake.log | $0


EOM
    exit 1
}

# Usage: repeat str num
#    str  is the string to repeat
#    num  is the number of times to repeat it
repeat()
{
    if [ $2 -le 0 ]; then
        return
    fi
    printf "$1"'%.0s' $(eval "echo {1.."$(($2))"}");
} 

bold()
{
    printf "\033[1m%s\033[0m" "$1"
}

highlightDone()
{
    printf "\033[46;1m%s\033[0m" "$1"
}

highlightTodo()
{
    printf "\033[47;1m%s\033[0m" "$1"
}


# Elapsed time.  Usage:
#
#   t=$(timer)
#   ... # do something
#   printf 'Elapsed time: %s\n' $(timer $t)
#      ===> Elapsed time: 0:01:12
#
# Original source:
# http://www.linuxjournal.com/content/use-date-command-measure-elapsed-time
#
# If called with no arguments a new timer is returned.
# If called with arguments the first is used as a timer
# value and the elapsed time is returned in the form HH:MM:SS.
#
# ---
# Updated to track nanoseconds and report fractional seconds for
# times less than a minute.
#
# ---
# Un-updated to not track nanoseconds until thing move fast enough
# for it matter.
#
timer()
{
    if [[ $# -eq 0 ]]; then
        # echo $(date '+%s%N')
        echo $(date '+%s')
    else
        # local  ns_stime=$1
        # ns_etime=$(date '+%s%N')
        # if [[ -z "$ns_stime" ]]; then ns_stime=$ns_etime; fi
        # etime=$(( ns_etime / 1000000000 )) # to seconds
        # stime=$(( ns_stime / 1000000000 )) # to seconds

        local  stime=$1
        etime=$(date '+%s')
        if [[ -z "$stime" ]]; then stime=$etime; fi

        dt=$((etime - stime))
        ds=$((dt % 60))
        dm=$(((dt / 60) % 60))
        dh=$((dt / 3600))
        if [[ $dh -ne 0 ]]; then
            printf '%d:%02d:%02d' $dh $dm $ds
        else
            if [[ $dm -ne 0 ]]; then
                printf '%02dm:%02ds' $dm $ds
            else
                # ns=$(( ns_etime - ns_stime - (ds*1000000000) ))
                # ns=$(( ns / 1000000 ))
                # if [[ $ns -lt 0 ]]; then
                #     ns=0
                # fi
                # printf '%2d.%03ds' $ds $ns
                printf '%2ds' $ds
            fi
        fi
    fi
}



# Usage: progress current total elapsed
#    current  is the current amount done of total (int)
#    total    is the amount to be done (int)
#    elapsed  is the elapsed time
progress()
{
    current=$1
    total=$2
    elapsed="$3 "
    bar_start=" ["
    bar_end="] "

    percent=$((100 * current / total ))
    printf -v prefix " $percent%%"
    # printf -v postfix "$elapsed"
    postfix=$elapsed
    bar_size=$(($TWIDTH - ${#prefix} - ${#bar_start} - ${#bar_end} - ${#postfix}))
    amount=$(( bar_size * current / total ))
    remain=$(( bar_size - amount ))
    amount_bar=$(repeat " "  $amount)
    remain_bar=$(repeat " "  $remain)
    prefix_s=" $(bold $prefix)"
    amount_bar_s=$(highlightDone "$amount_bar")
    remain_bar_s=$(highlightTodo "$remain_bar")

    printf "%s%s%s%s%s%s" "$prefix_s" "$bar_start" "$amount_bar_s" "$remain_bar_s" "$bar_end" "$postfix"
}


###############################################################################
# Main
#
logfile=""
rmlogfile=false

# get options
while getopts "rhlo:" flag; do
    case $flag in
        h)
            usage
            ;;
        r)
            rmlogfile=true
            ;;
        o)
            logfile=$OPTARG
            echo "Loging to $logfile."
            ;;
        l)
            logfile="cmake.log"
            echo "Loging to $logfile."
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# if logging and file exists then delete it
if [ ! -z "$logfile" ]; then
    if [ -e "$logfile" ]; then
        if $rmlogfile; then
            rm "$logfile"
        fi
    fi
fi

# # DEBUG
# if [ -z "$logfile" ]; then
#     echo "Logging is off."
# fi
# exit 1

printf "\n"

isDone=false
percentPat="^\[ *([0-9]+)%\]"
failedPat="^Failed Modules"
t=$(timer)

while IFS='' read -r line
do
    if [ ! -z "$logfile" ]; then
        echo "$line" >> $logfile
    fi

    if [[ $line =~ $failedPat ]]; then
        printf "\n\n\n"
        isDone=true
    fi

    if $isDone; then
        echo $line
        continue
    fi

    if [[ ! $line =~ $percentPat ]]; then
        continue
    fi
    i=${BASH_REMATCH[1]}

    elapsed=$(timer $t)
    prog=$(progress $i 100 $elapsed)
    printf "%s\r" "$prog"
done

printf "\nDone. $elapsed\n\n"


