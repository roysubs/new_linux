#Copyright 2023, dettus@dettus.net
#
#Redistribution and use in source and binary forms, with or without modification,
#are permitted provided that the following conditions are met:
#
#1. Redistributions of source code must retain the above copyright notice, this 
#   list of conditions and the following disclaimer.
#
#2. Redistributions in binary form must reproduce the above copyright notice, 
#   this list of conditions and the following disclaimer in the documentation 
#   and/or other materials provided with the distribution.
#
#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
#ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
#WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
#DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE 
#FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
#DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
#SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
#CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
#OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
#OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


### the following lines are the post-compilation test. This is a formality on some operating systems ###########################

ECHO_CMD?=echo
SHA256_CMD?=sha256
AWK_CMD?=awk

## the checks work by checking the sha256 sum of the output. 
## since this one relies on the input, as well as the .ini file,
## it might not work as a post-install check. it is more of a 
## post-compilation check, to see if it would support a new platform.


## check those graphic modes
CHECKS=        \
	check-none      \
	check-monochrome        \
	check-monochrome_inv    \
	check-low_ansi  \
	check-low_ansi2 \
	check-high_ansi \
	check-high_ansi2        \
	check-sixel	\
	check-utf

### this is the input. it does not really matter, but I thought I put in some easter egg in here.
### :::W WEYHE IST BUNT!!
INPUT_none=		"Weyhe-Leeste"
INPUT_monochrome=	"Sudweyhe"
INPUT_monochrome_inv=	"Melchiorshausen"
INPUT_low_ansi=		"Ahausen"
INPUT_low_ansi2=	"Kirchweyhe"
INPUT_high_ansi=	"Jeebel"
INPUT_high_ansi2=	"Erichshof"
INPUT_sixel=		"Dreye"
INPUT_utf=		"Lahausen"

### this is the output
### Do not change the CHECKSUM_none, because of the automated tests on the brew.sh repository.
CHECKSUM_none=		"3211640dc669f6b960a84a51559fc88a25bbc26966f01cdf44b9f4d9f4d71e1c"	# DO!NOT!CHANGE!
CHECKSUM_monochrome=	"f64136e269dbcc87236cd8e091fbb95deae7de9d063b89814749fc71fbb5f632"
CHECKSUM_monochrome_inv="99662688679715515bf8a13982ad07a9322e561609103337df8bfa702d8bc8de"
CHECKSUM_low_ansi=	"f88fb79247d9e9062c034f488b2a973e2e7cc0a8a299e3ea3d6ec293d5bf59fc"
CHECKSUM_low_ansi2=	"671dd3823eadb6591db0345f5e990a78a249da2431fc6c6e66371883431ee5ac"
CHECKSUM_high_ansi=	"0176d9f03f63c02bdb77af948a6ca7ab021e67744900c4b0bb1b8ed177fe721e"
CHECKSUM_high_ansi2=	"9e650c68fc910510967f2989f91c79511bef0d4c8ee8a6d636ae413f57bc1abf"
CHECKSUM_sixel=		"f7f997a8c881bf46968f93ffe635383c2349c6c3508ae7f783aae4405d7e043e"
CHECKSUM_utf=		"b09b342cdd4d4ba8489291c7f704965e0d868418cbf63b0a121445dbda07d481"



## so, here is my problem: I wanted to be able to run those checks in GNU make as well as BSD make.
## both of them have great features, like check-%, for-loops and check-{none,monochrome,sixel} as 
## targets. but none of those features worked in both makes.
## the only way it truely did what it was supposed to do was by having a little bit of spaghettified
## code. please enjoy.
##
## btw: if you want to run the checks on Linux, run 
## make SHA256_CMD="sha256sum" check


# the code for the 8 checks is IDENTICAL. the only difference is the target's name. 
check-none:		dMagnetic dMagnetic.ini
	if [ "`${ECHO_CMD} ${INPUT_${@:check-%=%}}    | ./dMagnetic -ini dMagnetic.ini -vmode "${@:check-%=%}" -vcols 300 -vrows 300 -vecho -sres 1024x768 -mag testcode/minitest.mag | ${SHA256_CMD} | ${AWK_CMD} -F' ' '{ print $$1; }' - `" = ${CHECKSUM_${@:check-%=%}} ]       ; then ${ECHO_CMD} "$@ OK" ; else ${ECHO_CMD} "$@ failed" ; exit 1 ; fi

check-monochrome:	dMagnetic dMagnetic.ini
	if [ "`${ECHO_CMD} ${INPUT_${@:check-%=%}}    | ./dMagnetic -ini dMagnetic.ini -vmode "${@:check-%=%}" -vcols 300 -vrows 300 -vecho -sres 1024x768 -mag testcode/minitest.mag | ${SHA256_CMD} | ${AWK_CMD} -F' ' '{ print $$1; }' - `" = ${CHECKSUM_${@:check-%=%}} ]       ; then ${ECHO_CMD} "$@ OK" ; else ${ECHO_CMD} "$@ failed" ; exit 1 ; fi

check-monochrome_inv:	dMagnetic dMagnetic.ini
	if [ "`${ECHO_CMD} ${INPUT_${@:check-%=%}}    | ./dMagnetic -ini dMagnetic.ini -vmode "${@:check-%=%}" -vcols 300 -vrows 300 -vecho -sres 1024x768 -mag testcode/minitest.mag | ${SHA256_CMD} | ${AWK_CMD} -F' ' '{ print $$1; }' - `" = ${CHECKSUM_${@:check-%=%}} ]       ; then ${ECHO_CMD} "$@ OK" ; else ${ECHO_CMD} "$@ failed" ; exit 1 ; fi

check-low_ansi:		dMagnetic dMagnetic.ini
	if [ "`${ECHO_CMD} ${INPUT_${@:check-%=%}}    | ./dMagnetic -ini dMagnetic.ini -vmode "${@:check-%=%}" -vcols 300 -vrows 300 -vecho -sres 1024x768 -mag testcode/minitest.mag | ${SHA256_CMD} | ${AWK_CMD} -F' ' '{ print $$1; }' - `" = ${CHECKSUM_${@:check-%=%}} ]       ; then ${ECHO_CMD} "$@ OK" ; else ${ECHO_CMD} "$@ failed" ; exit 1 ; fi

check-low_ansi2:	dMagnetic dMagnetic.ini
	if [ "`${ECHO_CMD} ${INPUT_${@:check-%=%}}    | ./dMagnetic -ini dMagnetic.ini -vmode "${@:check-%=%}" -vcols 300 -vrows 300 -vecho -sres 1024x768 -mag testcode/minitest.mag | ${SHA256_CMD} | ${AWK_CMD} -F' ' '{ print $$1; }' - `" = ${CHECKSUM_${@:check-%=%}} ]       ; then ${ECHO_CMD} "$@ OK" ; else ${ECHO_CMD} "$@ failed" ; exit 1 ; fi

check-high_ansi:	dMagnetic dMagnetic.ini
	if [ "`${ECHO_CMD} ${INPUT_${@:check-%=%}}    | ./dMagnetic -ini dMagnetic.ini -vmode "${@:check-%=%}" -vcols 300 -vrows 300 -vecho -sres 1024x768 -mag testcode/minitest.mag | ${SHA256_CMD} | ${AWK_CMD} -F' ' '{ print $$1; }' - `" = ${CHECKSUM_${@:check-%=%}} ]       ; then ${ECHO_CMD} "$@ OK" ; else ${ECHO_CMD} "$@ failed" ; exit 1 ; fi

check-high_ansi2:	dMagnetic dMagnetic.ini
	if [ "`${ECHO_CMD} ${INPUT_${@:check-%=%}}    | ./dMagnetic -ini dMagnetic.ini -vmode "${@:check-%=%}" -vcols 300 -vrows 300 -vecho -sres 1024x768 -mag testcode/minitest.mag | ${SHA256_CMD} | ${AWK_CMD} -F' ' '{ print $$1; }' - `" = ${CHECKSUM_${@:check-%=%}} ]       ; then ${ECHO_CMD} "$@ OK" ; else ${ECHO_CMD} "$@ failed" ; exit 1 ; fi

check-sixel:		dMagnetic dMagnetic.ini
	if [ "`${ECHO_CMD} ${INPUT_${@:check-%=%}}    | ./dMagnetic -ini dMagnetic.ini -vmode "${@:check-%=%}" -vcols 300 -vrows 300 -vecho -sres 1024x768 -mag testcode/minitest.mag | ${SHA256_CMD} | ${AWK_CMD} -F' ' '{ print $$1; }' - `" = ${CHECKSUM_${@:check-%=%}} ]       ; then ${ECHO_CMD} "$@ OK" ; else ${ECHO_CMD} "$@ failed" ; exit 1 ; fi

check-utf:		dMagnetic dMagnetic.ini
	if [ "`${ECHO_CMD} ${INPUT_${@:check-%=%}}    | ./dMagnetic -ini dMagnetic.ini -vmode "${@:check-%=%}" -vcols 300 -vrows 300 -vecho -sres 1024x768 -mag testcode/minitest.mag | ${SHA256_CMD} | ${AWK_CMD} -F' ' '{ print $$1; }' - `" = ${CHECKSUM_${@:check-%=%}} ]       ; then ${ECHO_CMD} "$@ OK" ; else ${ECHO_CMD} "$@ failed" ; exit 1 ; fi


		
############## invoke all the tests ############################################
check:	${CHECKS}
	@${ECHO_CMD} "***********************************************"
	@${ECHO_CMD} "Post-compilation tests for dMagnetic successful"
	@${ECHO_CMD} "***********************************************"

do-test:	check

