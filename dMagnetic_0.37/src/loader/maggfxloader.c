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

// the purpose of this file is to figure out what kind of binaries the 
// user has. is it the .mag/.gfx one? or is it the original MS-DOS version?
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "maggfxloader.h"
#include "configuration.h"
#include "vm68k_macros.h"
#include "loader_msdos.h"
#include "loader_mw.h"
#include "loader_d64.h"
#include "loader_dsk.h"
#include "loader_archimedes.h"
#include "loader_atarixl.h"
#include "loader_appleii.h"

// the purpose of this function is to guess
int maggfxguesstype(char* filename,eFileType *pFileType)
{
	FILE *f;
	int n;
	unsigned char buf[4];

	int retval;
	retval=0;
	*pFileType=FILETYPE_UNKNOWN;
	
	f=fopen(filename,"rb");
	if (f)
	{
		n=fread(buf,sizeof(char),4,f);
		if (n==4)
		{
			if (buf[0]=='M' && buf[1]=='a' && buf[2]=='S' && buf[3]=='c') *pFileType=FILETYPE_MAG;
			if (buf[0]=='M' && buf[1]=='a' && buf[2]=='P') *pFileType=FILETYPE_GFX;	// MaPi, MaP2, MaP3...MaP8
		}
		fclose(f);
	}
	return retval;
}


int maggfxloader(char *magbuf,int* magsize,
	char* gfxbuf,int* gfxsize,
	int nodoc,
	eBinType binType,char* magfilename,char* gfxfilename,char* binfilename)
{
	FILE *f;
	int retval;
	int n;
	switch (binType)
	{
		case BINTYPE_TWORSC:		retval=loader_magneticwindows(binfilename,magbuf,magsize,gfxbuf,gfxsize);break;
		case BINTYPE_D64:		retval=loader_d64(binfilename,magbuf,magsize,gfxbuf,gfxsize,nodoc);break;
		case BINTYPE_AMSTRADCPC:	retval=loader_dsk(binfilename,magbuf,magsize,gfxbuf,gfxsize,0,nodoc);	break;
		case BINTYPE_SPECTRUM:		retval=loader_dsk(binfilename,magbuf,magsize,gfxbuf,gfxsize,1,nodoc);break;
		case BINTYPE_ARCHIMEDES:	retval=loader_archimedes(binfilename,magbuf,magsize,gfxbuf,gfxsize,nodoc); break;
		case BINTYPE_ATARIXL:		retval=loader_atarixl(binfilename,magbuf,magsize,gfxbuf,gfxsize,nodoc); break;
		case BINTYPE_APPLEII:		retval=loader_appleii(binfilename,magbuf,magsize,gfxbuf,gfxsize,nodoc); break;
		case BINTYPE_MSDOS:		retval=loader_msdos(binfilename,magbuf,magsize,gfxbuf,gfxsize,nodoc);	break;
		case BINTYPE_MAGGFX:	
			retval=0;
			if (magfilename[0] && !gfxfilename[0])
			{
				// deducing the name of the gfx file from the mag file
				int l;
				int found;
				found=0;
				l=strlen(magfilename);
				fprintf(stderr,"Warning! -mag given, but not -gfx. Deducing filename\n");
				if (l>=4)
				{
					if (strncmp(&magfilename[l-4],".mag",4)==0)
					{
						memcpy(gfxfilename,magfilename,l+1);
						found=1;
						gfxfilename[l-4]='.';
						gfxfilename[l-3]='g';
						gfxfilename[l-2]='f';
						gfxfilename[l-1]='x';
					}
				}
				if (!found)
				{
					fprintf(stderr,"filename did not end in .mag (lower case)\n");
					return 1;
				}
			}
			if (!magfilename[0] && gfxfilename[0])
			{
				// deducing the name of the mag from the gfx
				int l;
				int found;
				found=0;
				l=strlen(gfxfilename);
				fprintf(stderr,"warning! -gfx given, but not -mag. Deducing filename\n");
				if (l>=4)
				{
					if (strncmp(&gfxfilename[l-4],".gfx",4)==0)
					{
						memcpy(magfilename,gfxfilename,l+1);
						found=1;
						magfilename[l-4]='.';
						magfilename[l-3]='m';
						magfilename[l-2]='a';
						magfilename[l-1]='g';
					}
				}
				if (!found)
				{
					fprintf(stderr,"filename did not end in .gfx (lower case)\n");
					return 1;
				}
			}
			if ((!magfilename[0] || !gfxfilename[0]))
			{
				return 1;
			}

			f=fopen(magfilename,"rb");
			if (f==NULL)
			{
				fprintf(stderr,"ERROR: unable to open [%s]\n",magfilename);
				fprintf(stderr,"This interpreter needs a the game's binaries in the .mag and .gfx\n");
				fprintf(stderr,"format from the Magnetic Scrolls Memorial website. For details, \n");
				fprintf(stderr,"see https://msmemorial.if-legends.org/memorial.php\n\n");
				return -2;
			}
			n=fread(magbuf,sizeof(char),*magsize,f);
			fclose(f);
			*magsize=n;
			f=fopen(gfxfilename,"rb");
			if (f==NULL)
			{
				fprintf(stderr,"ERROR: unable to open [%s]\n",gfxfilename);
				fprintf(stderr,"This interpreter needs a the game's binaries in the .mag and .gfx\n");
				fprintf(stderr,"format from the Magnetic Scrolls Memorial website. For details, \n");
				fprintf(stderr,"see https://msmemorial.if-legends.org/memorial.php\n\n");
				return -2;
			}
			n=fread(gfxbuf,sizeof(char),*gfxsize,f);
			*gfxsize=n;
			fclose(f);
			break;
		case BINTYPE_NONE:		
			fprintf(stderr,"Please provide the game binaries\n");
			retval=-1;
			break;
		default:
			retval=0;
			break;
	}
	// at this point, they are stored in magbuf and gfxbuf.
	return retval;
}

