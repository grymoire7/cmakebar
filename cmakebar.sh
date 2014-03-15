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
#     build_technology make 2>&1 | cmakebar.sh -s blocky
#     cat cmake.log | cmakebar.sh
#
# Todo:
#   [ ] Something is making this slow...
#
#           Go   version processes a.log in 83ms, b.log in 467ms
#           This version processes a.log in 8s, b.log in 46s
#
#       Inlined progress() which helped a bit.
#
#           This version processes a.log in 7s, b.log in 41s
#
#       Not calling timer/date in the inner loop processes b.log in 28s.
#       Of course, we need the timer.
#
#       In practice, this could be dwarfed by i/o latency on stdin.
#
# Author: Tracy Atteberry
# Date:   Spring 2014

TWIDTH=`tput cols`
highlightDoneBegin="\033[46;1m"
highlightTodoBegin="\033[47;1m"
doneChar=" "
todoChar=" "
bar_start=" ["
bar_end="] "

usage()
{
    cat <<'EOM'

Options: $0 [-h | -o cmake.log | -l | -r ]

    -h        Show this help
    -r        Remove existing log file before logging
              Otherwise append if it exists
    -l        Log to cmake.log
    -o file   Log to named file
    -s style  One of: normal, blocky, pointy, happy

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
# Un-updated to not track nanoseconds until things move fast enough
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


# The following four functions are unused.
# They've been inlined for performance reasons.
bold() { printf "\033[1m%s\033[0m" "$1"; }
highlightDone() { printf "$highlightDoneBegin%s\033[0m" "$1"; }
highlightTodo() { printf "$highlightTodoBegin%s\033[0m" "$1"; }

# Usage: progress current total elapsed
#    current  is the current amount done of total (int)
#    total    is the amount to be done (int)
#    elapsed  is the elapsed time
progress()
{
    current=$1
    total=$2
    elapsed="$3 "

    percent=$((100 * current / total ))
    printf -v prefix " $percent%%"
    printf -v postfix "$elapsed"
    bar_size=$(($TWIDTH - ${#prefix} - ${#bar_start} - ${#bar_end} - ${#postfix}))
    amount=$(( bar_size * current / total ))
    remain=$(( bar_size - amount ))
    amount_bar=$(repeat "$doneChar"  $amount)
    remain_bar=$(repeat "$todoChar"  $remain)
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
while getopts "rhlo:s:" flag; do
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
        s)
            case $OPTARG in
                blocky)
                    doneChar="▣"
                    todoChar="□"
                    highlightDoneBegin="\033[34;1m"
                    highlightTodoBegin="\033[37;0m"
                    ;;
                pointy)
                    doneChar="▶"
                    todoChar="▷"
                    highlightDoneBegin="\033[32;1m"
                    highlightTodoBegin="\033[37;0m"
                    ;;
                happy)
                    doneChar="☻"
                    todoChar="☹"
                    highlightDoneBegin="\033[33;1m"
                    highlightTodoBegin="\033[37;0m"
                    ;;
                \?)
                    ;;
            esac
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
    # prog=$(progress $i 100 $elapsed)

    # ---- inlined progress() below
    prefix=" $i%"
    postfix="$elapsed "
    bar_size=$(($TWIDTH - ${#prefix} - ${#bar_start} - ${#bar_end} - ${#postfix}))
    amount_bar=$(repeat "$doneChar" $(( bar_size * i / 100 )))
    remain_bar=$(repeat "$todoChar" $(( bar_size * (100 - i) / 100  )))
    prefix_s=$(printf "\033[1m%s\033[0m" "$prefix")
    amount_bar_s=$(printf "$highlightDoneBegin%s\033[0m" "$amount_bar")
    remain_bar_s=$(printf "$highlightTodoBegin%s\033[0m" "$remain_bar")
    printf "%s%s%s%s%s%s\r" "$prefix_s" "$bar_start" "$amount_bar_s" "$remain_bar_s" "$bar_end" "$postfix"
    # ---- inlined progress() above

    # printf "%s\r" "$prog"
done

printf "\nDone. $elapsed\n\n"


