*** dMagnetic
*** Use at your own risk
*** Copyright 2023 by dettus@dettus.net
***************************************


Welcome, brave adventurer. This is Version 0.36.
If you are interested in playing "The Pawn", just follow these simple steps.

STEP 1: BUILD
just run 

% make all


STEP 2: CHECK BASE FUNCTIONALITY
run

% ./dMagnetic -mag testcode/minitest.mag 

you should see a colourful X and the request to press enter.
Alternatively, on OpenBSD, NetBSD or FreeBSD you could simply run

% make check

On Linux, the command would be

% make SHA256_CMD=sha256sum check


STEP 3: GET THE BINARIES
Get the files pawn.mag and pawn.gfx. For example from this excellent website 
https://msmemorial.if-legends.org/games.htm/pawn.php
Alternatively, if you have the MS-DOS version of the games, copy them onto
your harddrive. 

Try them out by running

% ./dMagnetic -mag pawn.mag

(for example)

STEP 4: CONFIGURE
edit dMagnetic.ini, especially the lines that start with one of ????mag= and 
???gfx=, ???msdosdir= or ???tworsc=. Make sure that only one of those methods
is being commented in.
To see an example of the .ini file, type in

% ./dMagnetic -helpini


STEP 5: RUN
run one of

% ./dMagnetic -ini dMagnetic.ini pawn
% ./dMagnetic -ini dMagnetic.ini guild
% ./dMagnetic -ini dMagnetic.ini jinxter
% ./dMagnetic -ini dMagnetic.ini corruption
% ./dMagnetic -ini dMagnetic.ini fish
% ./dMagnetic -ini dMagnetic.ini myth
% ./dMagnetic -ini dMagnetic.ini wonderland

Remember that for some games you have to type in GRAPHICS before you see them.

Alternatively, you can select the .mag files like this:

% ./dMagnetic -ini dMagnetic.ini -mag /usr/local/share/games/pawn.mag

TO SEE GRAPHICS IN WONDERLAND OR ANY GAME FROM THE MAGNETIC SCROLLS COLLECTION,
you have to type in 'GRAPHICS'. To see the EGA version of those pictures, run

% ./dMagnetic -ega -ini dMagnetic.ini wonderland

To play using the binaries from the MS DOS release, simply run

% ./dMagnetic -ini dMagnetic.ini -msdosdir /C/GAMES/THEPAWN/

To play using the resource files from the Magnetic Scrolls Collection or
Wonderland, the parameter -tworsc can be used to provide the location of the
most important resource file

% ./dMagnetic -ini dMagnetic.ini -tworsc /C/GAMES/WONDER/TWO.RSC
% ./dMagnetic -ini dMagnetic.ini -tworsc /C/GAMES/MSC/CTWO.RSC
% ./dMagnetic -ini dMagnetic.ini -tworsc /C/GAMES/MSC/FTWO.RSC
% ./dMagnetic -ini dMagnetic.ini -tworsc /C/GAMES/MSC/GTWO.RSC

If you wish to play using .d64 images from the Commodore 64 (C64) releases,
you have to provide both sides of the floppy disks as filenames:

% ./dMagnetic -ini dMagnetic.ini -d64 pawn1.d64,pawn2.d64

For Amstrad CPC/Schneider CPC enthusiasts, there is the possibility to use
image files in the DSK format.

% ./dMagnetic -ini dMagnetic.ini -amstradcpc DISK1.DSK,DISK2.DSK

For the Spectrum+3/Spectrum128 releases, the commandline would be this one:

% ./dMagnetic -ini dMagnetic.ini -spectrum DISKIMAGE.DSK

For the Apple ][ releases, the .nib,.2mg and .woz format can be used:

% ./dMagnetic -ini dMagnetic.ini -appleii PAWN.NIB
% ./dMagnetic -ini dMagnetic.ini -appleii GUILD.2MG
% ./dMagnetic -ini dMagnetic.ini -appleii CorrA.woz,CorrB.woz,CorrC.woz



STEP 6: GRAPHICS
You can select output modes by using one of the following parameters:

% ./dMagnetic -ini dMagnetic.ini pawn -vmode none           -vrows 40 -vcols 120
% ./dMagnetic -ini dMagnetic.ini pawn -vmode monochrome     -vrows 40 -vcols 120
% ./dMagnetic -ini dMagnetic.ini pawn -vmode monochrome_inv -vrows 40 -vcols 120
% ./dMagnetic -ini dMagnetic.ini pawn -vmode low_ansi       -vrows 40 -vcols 120
% ./dMagnetic -ini dMagnetic.ini pawn -vmode low_ansi2      -vrows 40 -vcols 120
% ./dMagnetic -ini dMagnetic.ini pawn -vmode high_ansi      -vrows 40 -vcols 120
% ./dMagnetic -ini dMagnetic.ini pawn -vmode high_ansi2     -vrows 40 -vcols 120
% ./dMagnetic -ini dMagnetic.ini pawn -vmode sixel     -sres 1024x768 -vcols 120
% ./dMagnetic -ini dMagnetic.ini pawn -vmode utf            -vrows 40 -vcols 120

The defaut mode is "low_ansi", since it works on most terminals. The mode 
called "high_ansi" provides the richest amount of colors, even though the 
graphics are slightly block-y. When playing the PC version, the high_ansi2
mode is recommended.
if your terminal does not support them, please try one of the others. 

The sixel mode can be used in certain terminal emulators, such as mlterm, or
some variants of xterm, when run with 

% xterm -ti vt340.

The UTF mode should work on terminals that can handle the high_ansi modes as
well.

STEP 6: LOGGING
In case you would like to retrace our steps, you can use -vlog LOGFILE.log and
-vecho to be able to see what you have typed in before. This helps when trying
to figure out what you did wrong, and why you have been killed. :)

-------------------------------------------------------------------------------
What about GLK?
I must admit that I am not the biggest fan of GLK. I only started looking into
it, so the whole interaction is quite shaky. Plus, there has not been a modern
X11 frontend on https://www.eblong.com/zarf/glk/ in some time. If you are 
interested in building it, please contact me at dettus@dettus.net. I need some
help with that. Thank you in advance!
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
I am running dMagnetic in XTERM, but the colors look bleak in low_ansi mode?

The reason might be that the colors for the low ansi mode have been calibrated
to the ANSI rgb values. Especially the brown color (3) is vastly different
in the default xterm settings. One solution could be to set the default rgb
values for xterm, by adding the following lines to your $HOME/.Xresources:

  xterm*background: black
  xterm*foreground: grey
  xterm*color0: rgb:00/00/00
  xterm*color1: rgb:aa/00/00
  xterm*color2: rgb:00/aa/00
  xterm*color3: rgb:aa/55/00
  xterm*color4: rgb:00/00/aa
  xterm*color5: rgb:aa/00/aa
  xterm*color6: rgb:00/aa/aa
  xterm*color7: rgb:aa/aa/aa
  xterm*color8: rgb:55/55/55
  xterm*color9: rgb:ff/55/55
  xterm*color10: rgb:55/ff/55
  xterm*color11: rgb:ff/ff/55
  xterm*color12: rgb:55/55/ff
  xterm*color13: rgb:ff/55/ff
  xterm*color14: rgb:55/ff/ff
  xterm*color15: rgb:ff/ff/ff
  

Afterwards, run 

% xrdb -merge ~/.Xresources  

and open a new xterm window. In this, you can play dMagnetic with proper colors.
  
-------------------------------------------------------------------------------
ABOUT THE CHECKS
-------------------------------------------------------------------------------


They are being run in the check.mk file, so that they can be easily patched
out of the Makefile if they are not necessary. They require three programs:
SHA256, AWK and ECHO.

They way the work is by piping an input through dMagnetic, and checking the
SHA256 sum of the output. Since the program to calculate a SHA256 sum differs
between operating systems, I decided to make them parameterizable to the 
test. 

The default run would be the equivalent of 

% make SHA256_CMD=sha256 ECHO_CMD=echo AWK_CMD=awk check

On Linux, the checks may have to be invoked via

% make SHA256_CMD=sha256sum ECHO_CMD=echo AWK_CMD=awk check

And on some BSD derivates, where awk behaves differently, it could be

% make SHA256_CMD=sha256sum ECHO_CMD=echo AWK_CMD=gawk check

Why awk? Because the output of SHA256 also behaves slightly different. 
Sometimes, if simply prints out the sum, sometimes it adds a "-" at the
end. And that breaks the check.

-------------------------------------------------------------------------------
FOR INTERESTED DEVELOPERS
-------------------------------------------------------------------------------
If you enjoy the magic of Magnetic Scrolls, but are not satisfied with the
frontend, please have a look at the src/frontends/helloworld/ directory. It
contains an example.


-------------------------------------------------------------------------------
Thomas Dettbarn <dettus@dettus.net>

