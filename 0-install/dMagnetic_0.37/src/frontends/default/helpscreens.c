/*

Copyright 2023, dettus@dettus.net

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this 
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
   this list of conditions and the following disclaimer in the documentation 
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE 
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "default_callbacks.h"
#include "helpscreens.h"
#include "pathnames.h"
#include "version.h"

#define	NUMGAMES	7
#define	NUMPLATFORMS	10

#define	PLATFORM_MAG		(1<<0)
#define	PLATFORM_GFX		(1<<1)
#define	PLATFORM_MSDOS		(1<<2)
#define	PLATFORM_TWORSC		(1<<3)
#define	PLATFORM_D64		(1<<4)
#define	PLATFORM_AMSTRADCPC	(1<<5)
#define	PLATFORM_SPECTRUM	(1<<6)
#define	PLATFORM_ARCHIMEDES	(1<<7)
#define	PLATFORM_ATARIXL	(1<<8)
#define	PLATFORM_APPLEII	(1<<9)

typedef	struct _tPlatformInfo
{
	char* name;
	char* dir;
	char* suffix;
	char uppercase;
	char special;
	int disksexpected;	// some games require komma seperated names for the images. PAWN1.D64,PAWN2.D64, for example
	int active;
	unsigned short mask;
	char *cmdline;
	char *helptext;
} tPlatformInfo;
typedef struct _tGameInfo
{
	char *name;
	char *description;
	char *maggfxname;
	int disknum;
	char *specialPrefix;
	unsigned short ported;
} tGameInfo;

const tPlatformInfo	cdMagnetic_platformInfo[NUMPLATFORMS]={
	{.name="mag",
		.dir=PATH_USR_LOCAL_SHARE_GAMES"magneticscrolls/",
		.suffix=".mag"	,
		.uppercase=0,
		.special=0,
		.disksexpected=1,
		.active=1,
		.mask=PLATFORM_MAG,
		.cmdline="-mag MAGFILE.mag",
		.helptext="to provide the game binary\n"
	},
	{.name="gfx",
		.dir=PATH_USR_LOCAL_SHARE_GAMES"magneticscrolls/",
		.suffix=".gfx",
		.uppercase=0,
		.special=0,
		.disksexpected=1,
		.active=1,
		.mask=PLATFORM_GFX,
		.cmdline="-gfx GFXFILE.gfx",
		.helptext="to provide the game graphics\n"
	},
	{.name="msdos",
		.dir="/MSDOS/C/",
		.suffix="",
		.uppercase=1,
		.special=0,
		.disksexpected=1,
		.active=0,
		.mask=PLATFORM_MSDOS,
		.cmdline="-msdosdir DIRECTORY/",
		.helptext="to provide the binaries from MSDOS\n"
	},
	{.name="tworsc",
		.dir=PATH_USR_LOCAL_SHARE"games/",
		.suffix="TWO.RSC",
		.uppercase=0,
		.special=1,
		.disksexpected=1,
		.active=0,
		.mask=PLATFORM_TWORSC,
		.cmdline="-tworsc DIRECTORY/TWO.RSC",
		.helptext="to use resource files from Wonderland\n\tor The Magnetic Scrolls Collection Vol.1\n"
	},
	{.name="d64",
		.dir="/8/",
		.suffix=".D64"	,
		.uppercase=1,
		.special=0,
		.disksexpected=2,
		.active=0,
		.mask=PLATFORM_D64,
		.cmdline="-d64 IMAGE1.d64,IMAGE2.d64",
		.helptext="use d64 images. (Separated by ,)\n"
	},
	{.name="amstradcpc",
		.dir="/dsk/amstradcpc/",
		.suffix=".DSK",
		.uppercase=1,
		.special=0,
		.disksexpected=2,
		.active=0,
		.mask=PLATFORM_AMSTRADCPC,
		.cmdline="-amstradcpc IMAGE1.DSK,IMAGE2.DSK",
		.helptext="use DSK images. (Separated by ,)\n"
	},
	{.name="spectrum",
		.dir="/dsk/spectrum/",
		.suffix=".DSK"	,
		.uppercase=0,
		.special=0,
		.disksexpected=1,
		.active=0,
		.mask=PLATFORM_SPECTRUM,
		.cmdline="-spectrum IMAGE.DSK",
		.helptext="use DSK images for the Spectrum+3\n"
	},
	{.name="archimedes",
		.dir="/adf/",
		.suffix=".adf",
		.uppercase=0,
		.special=0,
		.disksexpected=1,
		.active=0,
		.mask=PLATFORM_ARCHIMEDES,
		.cmdline="-archimedes IMAGE.adf",
		.helptext="use adf/adl images from the Archimedes\n"
	},
	{.name="atarixl",
		.dir="/atr/",
		.suffix=".ATR"	,
		.uppercase=1,
		.special=0,
		.disksexpected=2,
		.active=0,
		.mask=PLATFORM_ATARIXL,
		.cmdline="-atarixl IMAGE1.atr,IMAGE2.atr",
		.helptext="use .atr images from the AtariXL\n"
	},
	{.name="appleii",
		.dir="/appleii/",
		.suffix=".NIB",
		.uppercase=1,
		.special=0,
		.disksexpected=3,
		.active=0,
		.mask=PLATFORM_APPLEII,
		.cmdline="-appleii 1.NIB,2.2MG,3.WOZ",
		.helptext="use Apple ][ images\n"
	}
};
const tGameInfo		cdMagnetic_gameInfo[NUMGAMES]={
	{.name="pawn",	
		.description="The Pawn",		
		.maggfxname="pawn",		
		.disknum=2,
		.specialPrefix="",
		.ported=PLATFORM_MAG|PLATFORM_GFX|PLATFORM_MSDOS|PLATFORM_D64|PLATFORM_AMSTRADCPC|PLATFORM_SPECTRUM|PLATFORM_ARCHIMEDES|PLATFORM_ATARIXL                |PLATFORM_APPLEII},
	{.name="guild",	
		.description="The Guild of Thieves",	
		.maggfxname="guild",	
		.disknum=2,
		.specialPrefix="MSC/G",
		.ported=PLATFORM_MAG|PLATFORM_GFX|PLATFORM_MSDOS|PLATFORM_D64|PLATFORM_AMSTRADCPC|PLATFORM_SPECTRUM|PLATFORM_ARCHIMEDES|PLATFORM_ATARIXL|PLATFORM_TWORSC|PLATFORM_APPLEII},
	{.name="jinxter",	
		.description="Jinxter",		
		.maggfxname="jinxter",	
		.disknum=2,
		.specialPrefix="",
		.ported=PLATFORM_MAG|PLATFORM_GFX|PLATFORM_MSDOS|PLATFORM_D64|PLATFORM_AMSTRADCPC|PLATFORM_SPECTRUM|PLATFORM_ARCHIMEDES|PLATFORM_ATARIXL                |PLATFORM_APPLEII},
	{.name="corruption",
		.description="Corruption",		
		.maggfxname="corrupt",	
		.disknum=3,
		.specialPrefix="MSC/C",
		.ported=PLATFORM_MAG|PLATFORM_GFX|PLATFORM_MSDOS|PLATFORM_D64|PLATFORM_AMSTRADCPC|PLATFORM_SPECTRUM|PLATFORM_ARCHIMEDES                 |PLATFORM_TWORSC|PLATFORM_APPLEII},
	{.name="fish",	
		.description="Fish!",		
		.maggfxname="fish",		
		.disknum=2,
		.specialPrefix="MSC/F",
		.ported=PLATFORM_MAG|PLATFORM_GFX|PLATFORM_MSDOS|PLATFORM_D64|PLATFORM_AMSTRADCPC|PLATFORM_SPECTRUM|PLATFORM_ARCHIMEDES                 |PLATFORM_TWORSC                 },
	{.name="myth",	
		.description="Myth",			
		.maggfxname="myth",		
		.disknum=1,
		.specialPrefix="",
		.ported=PLATFORM_MAG|PLATFORM_GFX|PLATFORM_MSDOS|PLATFORM_D64|PLATFORM_AMSTRADCPC|PLATFORM_SPECTRUM                                                                      },
	{.name="wonderland",	
		.description="Wonderland",		
		.maggfxname="wonder",	
		.disknum=1,
		.specialPrefix="wonderland/",
		.ported=PLATFORM_MAG|PLATFORM_GFX                                                                                                       |PLATFORM_TWORSC                 },
};

void helpscreens_header()
{
	fprintf(stderr,"*** dMagnetic %d.%d%d\n",VERSION_MAJOR,VERSION_MINOR,VERSION_REVISION);
	fprintf(stderr,"*** Use at your own risk\n");
	fprintf(stderr,"*** Copyright 2023 by dettus@dettus.net\n");
	fprintf(stderr,"***************************************\n");
	fprintf(stderr,"\n");
}
void helpscreens_license()
{
	printf("Copyright 2023, dettus@dettus.net\n");
	printf("\n");
	printf("Redistribution and use in source and binary forms, with or without modification,\n");
	printf("are permitted provided that the following conditions are met:\n");
	printf("\n");
	printf("1. Redistributions of source code must retain the above copyright notice, this \n");
	printf("   list of conditions and the following disclaimer.\n");
	printf("\n");
	printf("2. Redistributions in binary form must reproduce the above copyright notice, \n");
	printf("   this list of conditions and the following disclaimer in the documentation \n");
	printf("   and/or other materials provided with the distribution.\n");
	printf("\n");
	printf("THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\" AND\n");
	printf("ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED \n");
	printf("WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE \n");
	printf("DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE \n");
	printf("FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL \n");
	printf("DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR \n");
	printf("SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER \n");
	printf("CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, \n");
	printf("OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE \n");
	printf("OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.\n");
	printf("\n");
}

void helpscreens_basic(char* argv0,FILE *output,int mention_help)
{
	fprintf(output,"Please provide a .mag or a .gfx file by using one of\n");
	fprintf(output,"\n");
	fprintf(output,"%s -mag GAMEFILE.mag\n",argv0);
	fprintf(output,"%s -gfx GAMEFILE.gfx\n",argv0);
	fprintf(output,"\n");
	if (mention_help)
	{
		fprintf(output,"To see other options, or to get more help, use\n");
		fprintf(output,"\n");
		fprintf(output,"%s -help\n",argv0);
		fprintf(output,"%s -license\n",argv0);
		fprintf(output,"\n");
	}
}
void helpscreens_general(char* argv0,FILE *output)
{
	int i,j,maxlen;
	helpscreens_basic(argv0,output,0);
	fprintf(output,"\n");
	fprintf(output,"For conveniance, games can be referenced in an .ini file\n");
	fprintf(output,"\n");
	fprintf(output,"%s [-ini dMagnetic.ini] GAME\n",argv0);
	fprintf(output,"where GAME is one of \n[");
	maxlen=0;
	for (i=0;i<NUMGAMES;i++)
	{
		
		fprintf(output,"%s ",cdMagnetic_gameInfo[i].name);
	}
	fprintf(output,"]\n\n");
	fprintf(output,"-ini      dMagnetic.ini          to provide an inifile\n");
	fprintf(output,"-helpini  >dMagnetic.ini         generate a generic inifile\n");
	fprintf(output,"\n");
	fprintf(output,"\n");
	fprintf(output,"SELECTING INPUT SOURCES DIRECTLY\n");

	maxlen=0;
	for (i=0;i<NUMPLATFORMS;i++)
	{
		int l;
		l=strlen(cdMagnetic_platformInfo[i].cmdline)+1;
		if (l>maxlen)
		{
			maxlen=l;
		}

	}
	for (i=0;i<NUMPLATFORMS;i++)
	{
		int l;
		fprintf(output,"%s",cdMagnetic_platformInfo[i].cmdline);
		l=strlen(cdMagnetic_platformInfo[i].cmdline);
		for (j=l;j<maxlen;j++) fprintf(output," ");
		l=strlen(cdMagnetic_platformInfo[i].helptext);
		for (j=0;j<l;j++)
		{
			if (cdMagnetic_platformInfo[i].helptext[j]=='\t')
			{
				int k;
				for (k=0;k<maxlen;k++) fprintf(output," ");
			} else {
				fprintf(output,"%c",cdMagnetic_platformInfo[i].helptext[j]);
			}
		}
	}
	fprintf(output,"\n");

}
void helpscreens_help(char* argv0)
{
	helpscreens_general(argv0,stdout);
	printf("OPTIONAL PARAMETERS\n");
	printf("-rmode RANDOMMODE   where mode is one of\n  [");
	printf("pseudo ");
	printf("real");
	printf("]");
	printf("\n");
	printf("-rseed RANDOMSEED   to set the random seed between 1 and %d\n",0x7fffffff);

	printf("-vrows ROWS         to set the number of rows for the pictures\n");
	printf("-vcols COLUMNS      to set the number of columns for the pictures\n");
	printf("-vmode MODE         where mode is one of\n  [");
	printf("none");
	printf(" monochrome");
	printf(" monochrome_inv");
	printf(" low_ansi");
	printf(" low_ansi2");
	printf(" high_ansi\n  ");
	printf(" high_ansi2");
	printf(" sixel");
	printf(" utf");
	printf("]");
	printf("\n");
	printf("-vlog LOGFILE       to write a log of the commands used\n");
	printf("-vecho              to reprint the commands (useful for | tee)\n");
	printf("\n");
	printf("The sixel output mode can be customized with the following parameters\n");
	printf("-sres 1024x768      render the pictures in this resolution\n");
	printf("-sforce             force the resolution (ignore the aspect ratio)\n");
	printf("\n");
	printf("Savegames can be stored in one of the following formats\n");
	printf("-savegames classic  stores savegames in the historic format\n");
	printf("-savegames advanced stores savegames in a more robust format\n");

	printf(" OTHER PARAMETERS\n");
	printf(" -dumpmag GAME.mag -dumpgfx GAME.gfx   writes the internal game data\n");
	printf(" -dumppics                             writes the pictures as .xpm files\n");
	printf(" -ega                                  prefers EGA images\n");
	printf(" -nodoc                                play the games with no documentation.\n");
	printf(" -bsd                                  shows the license\n");
	printf(" -help                                 shows this help\n");
	printf(" --version                             shows %d.%d%d\n",VERSION_MAJOR,VERSION_MINOR,VERSION_REVISION);

}
void helpscreens_helpini()
{
	int i,j;
	printf(";Maybe you need to create a file called dMagnetic.ini\n");
	printf(";Place it in your home directory, with the following content:\n");
	printf(";\n");
	printf(";-------------------------------------------------------------------------------\n");
	printf(";you can download the files from https://msmemorial.if-legends.org/magnetic.php\n");
	printf("[FILES]\n");

	for (i=0;i<NUMGAMES;i++)
	{
		for (j=0;j<NUMPLATFORMS;j++)
		{
			if (cdMagnetic_gameInfo[i].ported&cdMagnetic_platformInfo[j].mask)
			{
				int k;
				char uppercase[16];
				for (k=0;k<strlen(cdMagnetic_gameInfo[i].name)+1;k++)
				{
					uppercase[k]=cdMagnetic_gameInfo[i].name[k]&0x5f;
				}
				if (!cdMagnetic_platformInfo[j].active) printf(";");
				printf("%s%s=",cdMagnetic_gameInfo[i].name,cdMagnetic_platformInfo[j].name);
				if (cdMagnetic_platformInfo[j].special)
				{
					printf("%s",cdMagnetic_platformInfo[j].dir);
					printf("%s",cdMagnetic_gameInfo[i].specialPrefix);
					printf("%s",cdMagnetic_platformInfo[j].suffix);
				} else {
					int l;
					int num;
					num=(cdMagnetic_platformInfo[j].disksexpected<cdMagnetic_gameInfo[i].disknum)?cdMagnetic_platformInfo[j].disksexpected:cdMagnetic_gameInfo[i].disknum;
					for (l=0;l<num;l++)
					{
						if (l) printf(",");
						printf("%s",cdMagnetic_platformInfo[j].dir);
						printf("%s",cdMagnetic_platformInfo[j].uppercase?uppercase:cdMagnetic_gameInfo[i].maggfxname);
						if (num!=1) printf("%d",(l+1));
						printf("%s",cdMagnetic_platformInfo[j].suffix);
					}

				}
				printf("\n");
			}
		}
	}

	printf("\n");
	printf("[RANDOM]\n");
	printf("mode=pseudo\n");
	printf(";mode=real\n");
	printf("seed=12345\n");
	printf("\n");
	printf("[DEFAULTGUI]\n");
	printf("rows=40\n");
	printf("columns=120\n");
	printf(";align=left\n");
	printf("align=block\n");
	printf(";align=right\n");
	printf(";mode=none\n");
	printf(";mode=monochrome\n");
	printf(";mode=monochrome_inv\n");
	printf("mode=low_ansi\n");
	printf(";mode=low_ansi2\n");
	printf(";mode=high_ansi\n");
	printf(";mode=high_ansi2\n");
	printf(";mode=sixel\n");
	printf(";mode=utf\n");
	printf("low_ansi_characters=");
	for (i=0;i<strlen(default_low_ansi_characters);i++)
	{
		char c;
		c=default_low_ansi_characters[i];
		if (c==' ' || c=='\\') 
		{
			printf("\\");
		}
		printf("%c",c);
	}
	printf("\n");
	printf("monochrome_characters=");
	for (i=0;i<strlen(default_monochrome_characters);i++)
	{
		char c;
		c=default_monochrome_characters[i];
		if (c==' ' || c=='\\') 
		{
			printf("\\");
		}
		printf("%c",c);
	}
	printf("\n");

	printf("sixel_resolution=800x600\n");
	printf("sixel_forceresolution=No\n");
	printf(";savegames=classic\n");
	printf("savegames=advanced\n");
	printf("[GAMEPLAY]\n");
	printf("nodoc=No\n");
	printf(";nodoc=Yes\n");
	printf(";-------------------------------------------------------------------------------\n");
}
void helpscreens_loaderfailed(char* argv0)
{
	helpscreens_general(argv0,stderr);
	fprintf(stderr,"\n");
	fprintf(stderr,"You can get the .mag and .gfx files from\n");
	fprintf(stderr," https://msmemorial.if-legends.org/\n");
	fprintf(stderr,"\n");
	fprintf(stderr,"To get a more detailed help, please run\n");
	fprintf(stderr," %s --help\n",argv0);
}
