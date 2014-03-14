#!/bin/bash

# cmakebar.sh - a CMake progress bar
# This code takes output from 'build_technology make' as input on stdin
# and displays a progress bar in the terminal.  This is unteseted with
# generic cmake output.
#
# Usage:
#
#     build_technology make 2>&1 | cmakebar.sh
#     build_technology make 2>&1 | cmakebar.sh --out cmake.log
#     build_technology make 2>&1 | cmakebar.sh -o
#     cat cmake.log | cmakebar.sh --replay
#     cat cmake.log | cmakebar.sh -r
#
# Todo:
#  [ ] Use non-blocking i/o, otherwise buffering pauses output
#  [ ] Allow spaces in bar
#  [ ] Change timer resolution to remove days
#  [ ] Change timer resolution to include fractional seconds
#
# Author: Tracy Atteberry
# Date:   Spring 2014

TWIDTH=`tput cols`

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
# Source:
# http://www.linuxjournal.com/content/use-date-command-measure-elapsed-time
#
# If called with no arguments a new timer is returned.
# If called with arguments the first is used as a timer
# value and the elapsed time is returned in the form HH:MM:SS.
#
timer()
{
    if [[ $# -eq 0 ]]; then
        echo $(date '+%s')
    else
        local  stime=$1
        etime=$(date '+%s')

        if [[ -z "$stime" ]]; then stime=$etime; fi

        dt=$((etime - stime))
        ds=$((dt % 60))
        dm=$(((dt / 60) % 60))
        dh=$((dt / 3600))
        printf '%d:%02d:%02d' $dh $dm $ds
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
    printf -v postfix "$elapsed"
    bar_size=$(($TWIDTH - ${#prefix} - ${#bar_start} - ${#bar_end} - ${#postfix}))
    amount=$(( bar_size * current / total ))
    remain=$(( bar_size - amount ))
    amount_bar=$(repeat "_"  $amount)
    remain_bar=$(repeat "_"  $remain)
    prefix_s=" $(bold $prefix)"
    amount_bar_s=$(highlightDone $amount_bar)
    remain_bar_s=$(highlightTodo $remain_bar)

    printf "%s%s%s%s%s%s" "$prefix_s" "$bar_start" "$amount_bar_s" "$remain_bar_s" "$bar_end" "$postfix"
}


###############################################################################
# Main
#
t=$(timer)
grep -Eo '^\[ *[0-9]+%\]' | grep -Eo '[0-9]+' | while read i
do
    prefix="howdy"
    plen=${#prefix}
    q=$(($i - $plen))
    # printf "\n$q\n"
    elapsed=$(timer $t)
    prog=$(progress $i 100 $elapsed)
    printf "%s\r" "$prog"
    sleep 0.01
done

printf "\nDone.\n"


