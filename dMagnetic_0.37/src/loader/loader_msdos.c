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

// the purpose of this file is to read the MS DOS Game binaries,
// and to translate them into the .mag/.gfx format.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "loader_msdos.h"
#include "loader_common.h"
#include "configuration.h"
#include "vm68k_macros.h"
typedef enum _eGame
{
	GAME_UNKNOWN,
	GAME_JINXTER,
	GAME_CORRUPTION,
	GAME_FISH,
	GAME_MYTH,
	GAME_PAWN,
	GAME_GUILD
} eGame;


typedef struct _tGameInfo
{
	char gamename[24];
	eGame game;
	char prefix[8];	// the prefix for the game's binaries.
	int disk1size;	// the size of the DISK1.PIX file is in an indicator for the game being used.
	int version;	// the interpreter version.
} tGameInfo;
// The others have some opcodes which I can not decode (yet)
#define	KNOWN_GAMES	6
const tGameInfo gameInfo[KNOWN_GAMES]={
	{.gamename="The Pawn",
		.version=0,
		.game=GAME_PAWN,
		.prefix="PAWN",
		.disk1size=209529,
	},	// THE PAWN
	{.gamename="The Guild of Thieves",
		.version=1,
		.game=GAME_GUILD,
		.prefix="GUILD",
		.disk1size=185296,
	},	// THE GUILD OF THIEVES
	{.gamename="Jinxter",
		.version=2,
		.game=GAME_JINXTER,
		.prefix="JINX",
		.disk1size=159027,
	},	// JINXTER
	{.gamename="Corruption",
		.version=3,
		.game=GAME_CORRUPTION,
		.prefix="CORR",
		.disk1size=160678,
	},	// CORRUPTION
	{.gamename="Fish!",
		.version=3,
		.game=GAME_FISH,
		.prefix="FILE",
		.disk1size=162541,
	},	// FISH
	{.gamename="Myth",
		.version=3,
		.game=GAME_MYTH,
		.prefix="FILE",
		.disk1size=67512,
	}	// MYTH
};

int loader_huffman_unpack(char* magbuf,int* decodedbytes,FILE *f)
{
	unsigned char huffsize;
	unsigned char hufftab[256];
	int huffidx;
	unsigned short todo;
	unsigned char byte;
	unsigned char mask;
	unsigned char tmp[3];
	int threebytes;
	int n;	// this variable is getting rid of some compiler warnings.
	int magidx;

	magidx=0;

	n=fread(&huffsize,sizeof(char),1,f);
	if (huffsize==0x49)
	{
		magbuf[0]=(char)huffsize;magidx=1;
		magidx+=fread(&magbuf[1],sizeof(char),(1<<20),f);


	} else {
		n+=fread(hufftab,sizeof(char),huffsize,f);
		n+=fread(&todo,sizeof(short),1,f);	// what are those two bytes?
		mask=0;
		huffidx=0;
		threebytes=0;
		while (!feof(f) || mask)
		{
			unsigned char branch0,branch1;
			unsigned char branch;
			if (mask==0)
			{
				n+=fread(&byte,sizeof(char),1,f);
				mask=0x80;
			}
			branch1=hufftab[2*huffidx+0];
			branch0=hufftab[2*huffidx+1];
			branch=(byte&mask)?branch1:branch0;
			if (branch&0x80)	// the highest bit signals a terminal symbol.
			{
				huffidx=0;
				branch&=0x7f;
				// the terminal symbols from the tree are only 6 bits wide.  
				// to extend this to 8 bits, the fourth symbol contains the
				// two MSB for the previous three:
				// 00AAAAAA 00BBBBBB 00CCCCCC 00aabbcc
				if (threebytes==3)
				{
					int i;
					threebytes=0;
					for (i=0;i<3;i++)
					{
						// add the 2 MSB to the existing 6.
						tmp[i]|=((branch<<2)&0xc0);	// MSB first
						magbuf[magidx]|=(char)tmp[i];
						magidx++;
						branch<<=2;	// MSB first
					}
				} else {
					tmp[threebytes]=branch;
					threebytes++;
				}
			} else {
				huffidx=branch;
			}
			mask>>=1;
		}
	}
	*decodedbytes=magidx;
	return (n==0);
}
int loader_msdos(char* msdosdir,
		char *magbuf,int* magsize,
		char* gfxbuf,int* gfxsize,
		int nodoc)
{
#define	OPENFILE(filename)	\
	f=fopen((filename),"rb");	\
	if (!f)		\
	{	\
		fprintf(stderr,"ERROR. Unable to open %s. Sorry.\n",(filename));	\
		return -1;	\
	}

	FILE *f;
	char filename[1024];
	int i;
	int gameID;
	int magsize0;
	int gfxsize0;
	char postfix;

	magsize0=*magsize;
	gfxsize0=*gfxsize;
	*magsize=0;
	*gfxsize=0;

	// clear the headers.
	memset(gfxbuf,0,16);
	memset(magbuf,0,42);

	postfix=0;

	{
		int sizedisk1,sizedisk2,sizeindex;
		/////////////////////// GFX packing
		// the header of the GFX is always 16 bytes.
		// values are stored as BigEndians
		//  0.. 3 are the magic word 'MaP3'
		//  4.. 7 are the size of the GAME4 (index) file (always 256)
		//  8..11 are the size of the DISK1.PIX file
		// 12..15 are the size of the DISK2.PIX file
		// then the INDEX file (beginning at 16)
		// then the DISK1.PIX file
		// then the DISK2.PIX file
		// step 1: find out which game it is.
		snprintf(filename,1024,"%s/DISK1.PIX",msdosdir);
		OPENFILE(filename);

		sizedisk1=fread(&gfxbuf[16+256],sizeof(char),gfxsize0-16-256,f);
		fclose(f);
		gameID=-1;
		for (i=0;i<KNOWN_GAMES;i++)
		{
			if (sizedisk1==gameInfo[i].disk1size) gameID=i;
		}
		if (gameID<0 || gameID>=KNOWN_GAMES)
		{
			fprintf(stderr,"ERROR: Unable to recognize game\n");
			return -2;
		} else {
			printf("Detected %s\n",gameInfo[gameID].gamename);
		}
		// step 2: read the binary files, and store them in the gfxbuffer
		snprintf(filename,1024,"%s/DISK2.PIX",msdosdir);
		f=fopen(filename,"rb");
		if (!f)	// MYTH does not have a second disc.
		{
			sizedisk2=0;
		} else {
			sizedisk2=fread(&gfxbuf[16+256+sizedisk1],sizeof(char),gfxsize0-sizedisk1-16-256,f);
			fclose(f);
		}
		// some versions have filenames ending in a .
		{

			snprintf(filename,1024,"%s/%s4%c",msdosdir,gameInfo[gameID].prefix,postfix);
			f=fopen(filename,"rb");
			if (!f) postfix='.';
			else fclose(f);
		}
		snprintf(filename,1024,"%s/%s4%c",msdosdir,gameInfo[gameID].prefix,postfix);
		OPENFILE(filename);
		sizeindex=fread(&gfxbuf[16],sizeof(char),256,f);
		fclose(f);
		// step 3: add the header to the gfx buffer
		gfxbuf[0]='M';gfxbuf[1]='a';gfxbuf[2]='P';gfxbuf[3]='3';
		WRITE_INT32BE(gfxbuf, 4,sizeindex);
		WRITE_INT32BE(gfxbuf, 8,sizedisk1);
		WRITE_INT32BE(gfxbuf,12,sizedisk2);
		*gfxsize=16+sizeindex+sizedisk1+sizedisk2;
	}
	////////////////////////// done with GFX packing

	////////////////////////// MAG packing
	{
		int codesize=0;
		int dictsize=0;
		int string1size=0;
		int string2size=0;
		int magidx=0;

		magidx=42;
		// the program for the 68000 machine is stored in the file ending with 1.
		snprintf(filename,1024,"%s/%s1%c",msdosdir,gameInfo[gameID].prefix,postfix);
		OPENFILE(filename);

		// sometimes, this file is packed. 
		// this can be checked quite easily, because in the other cases it starts with the instruction
		// 49FA= LEA.
		//
		if (loader_huffman_unpack(&magbuf[magidx],&codesize,f)) return -1;
		fclose(f);
		magidx+=codesize;
		// the strings for the game are stored in the files ending with 3 and 2
		snprintf(filename,1024,"%s/%s3%c",msdosdir,gameInfo[gameID].prefix,postfix);
		OPENFILE(filename);
		string1size=fread(&magbuf[magidx],sizeof(char),magsize0-magidx,f);
		fclose(f);
		magidx+=string1size;
		snprintf(filename,1024,"%s/%s2%c",msdosdir,gameInfo[gameID].prefix,postfix);
		OPENFILE(filename);
		string2size=fread(&magbuf[magidx],sizeof(char),magsize0-magidx,f);
		fclose(f);
		magidx+=string2size;


		if (gameInfo[gameID].version>=2)
		{
			// dictionaries are packed. 

			dictsize=0;
			snprintf(filename,1024,"%s/%s0%c",msdosdir,gameInfo[gameID].prefix,postfix);
			OPENFILE(filename);
			if (loader_huffman_unpack(&magbuf[magidx],&dictsize,f)) return -1;
			fclose(f);
			magidx+=dictsize;
		}
		// TODO: what about the 5?

		if (nodoc)
		{
			int i;
			unsigned char* ptr=(unsigned char*)&magbuf[0];
			for (i=0;i<magidx-4;i++)
			{
				if (ptr[i+0]==0x62 && ptr[i+1]==0x02 && ptr[i+2]==0xa2 && ptr[i+3]==0x00) {ptr[i+0]=0x4e;ptr[i+1]=0x71;}
				if (ptr[i+0]==0xa4 && ptr[i+1]==0x06 && ptr[i+2]==0xaa && ptr[i+3]==0xdf) {ptr[i+0]=0x4e;ptr[i+1]=0x71;}
			}
		}
		if (gameInfo[gameID].game==GAME_MYTH && magbuf[0x314a]==0x66) magbuf[0x314a]=0x60;	// final touch
		loader_common_addmagheader((unsigned char*)magbuf,magidx,gameInfo[gameID].version,codesize,string1size,string2size,dictsize,-1);

		*magsize=magidx;
	}
	return 0;
}

