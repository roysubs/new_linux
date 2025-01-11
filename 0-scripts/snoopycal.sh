#!/bin/sh
# snoopycal.sh - output old-school ASCII art Snoopy calendar
#   scruss, 2021-11
#
# optional argument: year
#   otherwise, chooses one for you
#
# requires: cal, banner
#   typically in the ncal and sysvbanner packages
#
# Original "WW1 Fighter Pilot" Snoopy ASCII art from
#   "SNOOPY.BA" for the DEC PDP-8, written by Mr Kay R. Fisher of DEC
#   some time before July 1973. (It's referred to in the first printing
#   of the "101 Basic Computer Games" book, which was published in 1973.)

# check that we have the right tools
for exe in cal banner
do
    if
	[ ! -n "$(command -v $exe)" ]
    then
	echo '###' $exe "command not found, exiting."
	exit 1
    fi
done

# pick a default year
year=$(date +%Y)
month=$(date +%m)
if
    [ $month -gt 6 ]
then
    year=$((year + 1))
fi
# but use $1 if specified and it's sensible
if
    [ $# -gt 0 ]
then
    if
	[ $1 -gt 1899 ]
    then
	year=$1
    fi
fi

echo ''
echo ''
echo ''
echo ''
echo ''
echo ''
echo '                          XXXX'
echo '                         X    XX'
echo '                        X  ***  X                XXXXX'
echo '                       X  *****  X            XXX     XX'
echo '                    XXXX ******* XXX      XXXX          XX'
echo '                  XX   X ******  XXXXXXXXX                XX XXX'
echo '                XX      X ****  X                           X** X'
echo '               X        XX    XX     X                      X***X'
echo '              X         //XXXX       X                      XXXX'
echo '             X         //   X                             XX'
echo '            X         //    X          XXXXXXXXXXXXXXXXXX/'
echo '            X     XXX//    X          X'
echo '            X    X   X     X         X'
echo '            X    X    X    X        X'
echo '             X   X    X    X        X                    XX'
echo '             X    X   X    X        X                 XXX  XX'
echo '              X    XXX      X        X               X  X X  X'
echo '              X             X         X              XX X  XXXX'
echo '               X             X         XXXXXXXX!     XX   XX  X'
echo '                XX            XX              X     X    X  XX'
echo '                  XX            XXXX   XXXXXX/     X     XXXX'
echo '                    XXX             XX***         X     X'
echo '                       XXXXXXXXXXXXX *   *       X     X'
echo '                                    *---* X     X     X'
echo '                                   *-* *   XXX X     X'
echo '                                   *- *       XXX   X'
echo '                                  *- *X          XXX'
echo '                                  *- *X  X          XXX'
echo '                                 *- *X    X            XX'
echo '                                 *- *XX    X             X'
echo '                                *  *X* X    X             X'
echo '                                *  *X * X    X             X'
echo '                               *  * X**  X   XXXX          X'
echo '                               *  * X**  XX     X          X'
echo '                              *  ** X** X     XX          X'
echo '                              *  **  X*  XXX   X         X'
echo '                             *  **    XX   XXXX       XXX'
echo '                            *  * *      XXXX      X     X'
echo '                           *   * *          X     X     X'
echo '             =======*******   * *           X     X      XXXXXXXX!'
echo '                    *         * *      /XXXXX      XXXXXXXX!      )'
echo '               =====**********  *     X                     )  !  )'
echo '                 ====*         *     X               !  !   )XXXXX'
echo '            =========**********       XXXXXXXXXXXXXXXXXXXXXX'
echo ''
echo ''
echo ''
echo '                          CURSE  YOU  RED  BARON  ! !'
# new page - remember we're not bash 
echo -n '\f'
echo ''
echo ''
echo ''
echo ''
echo ''
echo ''
echo ''
banner $year |\
    sed 's/^/                        /;s/^  *$//;'
echo ''
echo ''
echo ''
cal $year |\
    grep -v "$year" |\
    tr '[a-z]' '[A-Z]' |\
    sed 's/  *$//;s/^/        /;s/^  *$//;'
