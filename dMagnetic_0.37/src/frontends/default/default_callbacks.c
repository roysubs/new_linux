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


// the purpose of this file is to provide a callback-fallback until proper
// user interfaces have been established. It will do ;)
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "default_render.h"
#include "default_palette.h"
#include "dMagnetic.h"
#include "configuration.h"
#include "default_callbacks.h"
#ifdef	 EXPERIMENTAL_SAVEGAME_SLOTS
#include <time.h>
typedef struct _tSaveGameSlots
{
	int valid;
	char filename[65];
	int gamelen;
	unsigned char gamedata[131072];
	int year;
	int month;
	int day;

	int hour;
	int minute;
	int sec;
} tSaveGameSlots;
#endif

#define	MAGIC	0x68654879	// = yHeh, the place where I grew up ;)
#define	MAX_SRESX		4096

#define	ALIGNMENT_LEFT	1
#define	ALIGNMENT_BLOCK	2
#define	ALIGNMENT_RIGHT	3
typedef enum _tMode
{
	eMODE_NONE,
	eMODE_MONOCHROME,
	eMODE_LOW_ANSI,
	eMODE_LOW_ANSI2,
	eMODE_HIGH_ANSI,
	eMODE_HIGH_ANSI2,
	eMODE_SIXEL,
	eMODE_UTF
} tMode;
typedef	struct _tContext
{
	unsigned int magic;
	// ansi output
	int	columns;
	int	rows;
	tMode	mode;	// 0=none. 1=ascii art. 2=ansi art. 3=high ansi. 4=high ansi2
	// log the input
	FILE* f_logfile;
	int	echomode;

	int	capital;	// =1 if the next character should be a capital letter.
	int	lastchar;
	int	jinxterslide;	// THIS workaround makes the sliding puzzle in Jinxter solvable
	int headlineflagged;
	char	low_ansi_characters[128];	// characters that are allowed for low ansi rendering
	char	monochrome_characters[128];	// characters that are allowed for monochrome rendering
	int	monochrome_inverted;

// this is the line buffer.
// text is stored here, before
// being printed on the console.
	int	textalign;	// 0=left aligned. 1=block aligned. 2=right aligned.
	int	skip_newline;

// sixel parameter
	int 	screenheight;
	int	screenwidth;
	int	forceres;


// for the "advanced saves", where the whole virtual machine is being written to a file
	void *hEngine;
	int advancedSaves;

#ifdef	EXPERIMENTAL_SAVEGAME_SLOTS
	tSaveGameSlots	saveGameSlots[10];
	char advancedSavesFilename[1024];
#endif
} tContext;




int default_printline(char* text,int startidx,int endidx,int spaceidx,int columns,int newline,int end,int alignment)
{
	int i;
	int delta;
	int spaces;
	int outcnt;
	char c;

	if (!newline)	// in case there is a newline, the line ends there.
	{
		endidx=spaceidx;	// otherwise, there is a word after which the line ends.
	}
	endidx--;	// the last character was either a space or a newline
	delta=columns-endidx+startidx;	// how much 'room' is there?

	if (alignment==ALIGNMENT_RIGHT && delta<(columns-1))	// in right alignment
	{
		if (newline) delta++;
		for (i=0;i<delta;i++)	// fill the beginning of the line
		{
			printf(" ");
		}
	}
	spaces=0;
	outcnt=0;
	for (i=startidx;i<endidx;i++)
	{
		c=text[i];
		if (c==' ') spaces++;
	}
	{
		int accu;
		accu=0;
		for (i=startidx;i<endidx;i++)
		{
			c=text[i];
			if (c==' ' && alignment==ALIGNMENT_BLOCK && !newline)
			{
				accu+=delta;
				while (accu>=spaces)
				{
					accu-=spaces;
					printf(" ");
				}
			} 
			if (outcnt || c!='\n')
			{
				printf("%c",c);
			}
			outcnt++;
		}
	}
	if (!end) printf("\n");
	return 0;
}
int default_cbNewOutput(void* context,char* headline,char* text,char* picname)
{
	tContext *pContext=(tContext*)context;
	int i;
//	printf("\x1b[1;37;41m%s\x1b[0m\n",headline);
//	printf("\x1b[1;37;42m%s\x1b[0m\n",text);
//	printf("\x1b[1;47;44m%s\x1b[0m\n",picname);

	if (headline[0])	// when there is a headline, print it
	{
		if (pContext->mode==eMODE_NONE)
		{
			printf("\n[%s]\n",headline);
		} else {
			if (pContext->skip_newline)
			{
				printf("\n");
				pContext->skip_newline=0;
			}
			for (i=0;i<pContext->columns-strlen(headline)-3;i++)
			{
				printf("-");
			}
			if (pContext->mode==eMODE_LOW_ANSI || pContext->mode==eMODE_HIGH_ANSI)	// high or low ansi -> make the headline text pop out
				printf("[\x1b[0;30;47m%s\x1b[0m]-\n",headline);
			else 
				printf("[%s]-\n",headline);
		}
	}
	if (text[0])
	{
		int i;
		int l;
		int col;
		int lastspace;
		int newline;
		int skip_newline;
		int linestart;

		l=strlen(text);
		lastspace=-1;
		newline=0;
		col=0;
		linestart=0;
		i=0;
		while (i<l)
		{
			char c;
			c=text[i++];
			col++;
			skip_newline=0;
			if (c==' ')
			{
				lastspace=i;
			}
			if (c=='\n')
			{
				newline=1;
			}
			if (i==l)
			{
				newline=1;
				skip_newline=1;
			}
			if (newline || col==pContext->columns)	// this is the end of the line.
			{
				default_printline(text,linestart,i,lastspace, pContext->columns,newline,skip_newline,pContext->textalign);
				if (!newline)
				{
					i=lastspace;
				}
				linestart=i;
				newline=0;
				col=0;
				pContext->skip_newline=skip_newline;
			}
		}
	}
	return 0;
}
int default_cbInputString(void* context,int* len,char* string)
{
	int l;
	tContext *pContext=(tContext*)context;

	printf(" ");
	fflush(stdout);
	if (feof(stdin)) exit(0);
	if (fgets(string,256,stdin)==NULL) exit(0);
	if (pContext->echomode)
	{
		for (l=0;l<strlen(string);l++) 
		{
			if (string[l]>='a' && string[l]<='z') 
			{
				printf("%c",string[l]&0x5f);
			} else {
				printf("%c",string[l]);	// print upper case letters.
			}
		}
	}
	if (pContext->f_logfile)
	{
		fprintf(pContext->f_logfile,"%s",string);
		fflush(pContext->f_logfile);
	}
	l=strlen(string);
	*len=l;
	pContext->capital=1;	// the next line after the input is most definiately the beginning of a sentence! 
	return 0;
}
int default_cbDrawPicture(void* context,tdMagneticPicture* picture,char* picname,int mode)
{
	tContext *pContext=(tContext*)context;
	int retval;

	if (pContext->mode==eMODE_NONE) return 0;
	// flush the output buffer
	printf("\n");
	switch (pContext->mode)
	{
		case eMODE_MONOCHROME:
			retval=default_render_monochrome(pContext->monochrome_characters,pContext->monochrome_inverted,picture,pContext->rows,pContext->columns);
			break;
		case eMODE_LOW_ANSI:
			retval=default_render_lowansi(pContext->low_ansi_characters,picture,pContext->rows,pContext->columns);
			break;
		case eMODE_LOW_ANSI2:
			retval=default_render_lowansi2(pContext->low_ansi_characters,picture,pContext->rows,pContext->columns);
			break;
		case eMODE_HIGH_ANSI:
		case eMODE_HIGH_ANSI2:
			retval=default_render_highansi(picture,pContext->rows,pContext->columns,(pContext->mode==eMODE_HIGH_ANSI2));
			break;
		case eMODE_SIXEL:
			retval=default_render_sixel(picture,pContext->screenwidth,pContext->screenheight,pContext->forceres);
			break;
		case eMODE_UTF:
			retval=default_render_utf(picture,pContext->rows,pContext->columns);
			break;
		default:
			retval=0;
			break;
	}

	return retval;
}
int default_setEngine(void* context,void *hEngine)
{
	tContext *pContext=(tContext*)context;

	pContext->hEngine=hEngine;
	return 0;
}
#ifdef	 EXPERIMENTAL_SAVEGAME_SLOTS


int default_cbSaveGame(void* context,char* filename,void* ptr,int len)
{
	tContext *pContext=(tContext*)context;
	void *ptr2;
	int len2;
	FILE *f;
	int n;
	int i;
	int done;
	int retval;
	char line[256];

	retval=0;
	if (pContext->advancedSaves)
	{

		dMagnetic_getVM(pContext->hEngine,&ptr2,&len2);
		f=fopen(pContext->advancedSavesFilename,"rb");
		retval=0;
		if (f)
		{
			n=fread(pContext->saveGameSlots,sizeof(tSaveGameSlots),10,f);
			fclose(f);
			if (n!=10)
			{
				printf("*** FATAL SAVEGAME SLOTS ERROR\n");
				exit(1);
			}
		} else {
			for (i=0;i<10;i++)
			{
				memset(&(pContext->saveGameSlots[i]),0,sizeof(tSaveGameSlots));
			}
		}
		done=0;
		do
		{
			int inputlen;
			printf("*** APOLOGIES ABOUT THE CONFUSION! *** \n");
			printf("*** THE PREVIOUS QUESTIONS CAME FROM THE GAME.\n");
			printf("*** This is from the interpreter.\n");
			printf("\n");
			printf("*** Please select slot:\n");
			for (i=0;i<10;i++)
			{
				printf("<%d> ",i);
				if (pContext->saveGameSlots[i].valid)
				{
					printf("%04d-%02d-%02d  %02d:%02d:%02d ",pContext->saveGameSlots[i].year,pContext->saveGameSlots[i].month,pContext->saveGameSlots[i].day,
							pContext->saveGameSlots[i].hour, pContext->saveGameSlots[i].minute, pContext->saveGameSlots[i].sec);

					printf("%32s %5d bytes\n",pContext->saveGameSlots[i].filename,pContext->saveGameSlots[i].gamelen);
				} else {
					printf("free\n");
				}
			}
			inputlen=sizeof(line);
			printf(":> ");
			default_cbInputString(context,&inputlen,line);
			if (line[0]>='0' && line[0]<='9') 
			{
				int slot;
				time_t t;
				struct tm* now;

				t=time(NULL);
				now=gmtime(&t);



				slot=line[0]-'0';
				printf("*** Thank you. Saving now\n");
				printf("*** please disregard any warning about problems with the save.\n");
				done=1;
				pContext->saveGameSlots[slot].valid=1;
				pContext->saveGameSlots[slot].year=now->tm_year+1900;
				pContext->saveGameSlots[slot].month=now->tm_mon+1;
				pContext->saveGameSlots[slot].day=now->tm_mday;

				pContext->saveGameSlots[slot].hour=now->tm_hour;
				pContext->saveGameSlots[slot].minute=now->tm_min;
				pContext->saveGameSlots[slot].sec=now->tm_sec;


				memcpy(pContext->saveGameSlots[slot].filename,filename,64);
				memcpy(pContext->saveGameSlots[slot].gamedata,ptr2,len2);
				pContext->saveGameSlots[slot].gamelen=len2;
				retval=0;
				f=fopen(pContext->advancedSavesFilename,"wb");
				n=fwrite(pContext->saveGameSlots,sizeof(tSaveGameSlots),10,f);
				fclose(f);


			}
			else if (line[0]=='\n' || line[0]=='\r')
			{
				printf("*** Aborting save now.\n");
				done=1;
				retval=-1;
			}
			else
			{
				printf("*** What?\n\n");
				done=0;
			}
		} while (!done);
	} else {
		f=fopen(filename,"wb");
		if (!f)
		{
			printf("Unable to open file [%s]\n",(char*)ptr);
			return 0;
		}
		n=fwrite(ptr,sizeof(char),len,f);
		fclose(f);
		if (n!=len) retval=-1;
	}
	return retval;

}
int default_cbLoadGame(void* context,char* filename,void* ptr,int len)
{
	tContext *pContext=(tContext*)context;
	void *ptr2;
	int len2;
	FILE *f;
	int n;
	int i;
	int done;
	int retval;
	char line[256];
	retval=0;
	if (pContext->advancedSaves)
	{
		dMagnetic_getVM(pContext->hEngine,&ptr2,&len2);
		f=fopen(pContext->advancedSavesFilename,"rb");
		if (f)
		{
			n=fread(pContext->saveGameSlots,sizeof(tSaveGameSlots),10,f);
			fclose(f);
			if (n!=10) 
			{
				printf("*** FATAL SAVEGAME SLOTS ERROR\n");
				exit(1);
			}
		} else {
			printf("*** Nothing to load yet\n");
			return -1;
		}
		done=0;
		do
		{
			int inputlen;
			printf("*** APOLOGIES ABOUT THE CONFUSION! *** \n");
			printf("*** THE PREVIOUS QUESTIONS CAME FROM THE GAME.\n");
			printf("*** This is from the interpreter.\n");
			printf("\n");
			printf("*** Please select slot:\n");
			for (i=0;i<10;i++)
			{
				printf("<%d> ",i);
				if (pContext->saveGameSlots[i].valid)
				{
					printf("%04d-%02d-%02d  %02d:%02d:%02d ",pContext->saveGameSlots[i].year,pContext->saveGameSlots[i].month,pContext->saveGameSlots[i].day,
							pContext->saveGameSlots[i].hour, pContext->saveGameSlots[i].minute, pContext->saveGameSlots[i].sec);

					printf("%32s %5d bytes\n",pContext->saveGameSlots[i].filename,pContext->saveGameSlots[i].gamelen);
				} else {
					printf("free\n");
				}
			}
			inputlen=sizeof(line);
			printf(":> ");
			default_cbInputString(context,&inputlen,line);
			if (line[0]>='0' && line[0]<='9') 
			{
				int slot;
				slot=line[0]-'0';
				printf("*** Thank you. Loading now\n");
				printf("*** please disregard any warning about problems with the save.\n");
				if (pContext->saveGameSlots[slot].valid && pContext->saveGameSlots[slot].gamelen==len2)
				{
					memcpy(ptr2,pContext->saveGameSlots[slot].gamedata,len2);
					done=1;
					retval=0;
				}
			}
			else if (line[0]=='\n' || line[0]=='\r')
			{
				printf("*** Aborting load now.\n");
				done=1;
				retval=-1;
			}
			else
			{
				printf("*** What?\n\n");
				done=0;
			}
		} while (!done);
		printf("loaded\n");
	} else {
		f=fopen(filename,"rb");
		if (!f)
		{
			printf("Unable to open file [%s]\n",(char*)ptr);
			return 0;
		}
		n=fread(ptr,sizeof(char),len,f);
		fclose(f);
		if (n!=len) retval=-1;
	}
	return retval;


}

#else
int default_cbSaveGame(void* context,char* filename,void* ptr,int len)
{
	tContext *pContext=(tContext*)context;
	FILE *f;
	int n;
	void *ptr2;
	f=fopen(filename,"wb");
	if (!f)
	{
		printf("Unable to open file [%s]\n",(char*)ptr);
		return 0;
	}
	if (pContext->advancedSaves)
	{
		dMagnetic_getVM(pContext->hEngine,&ptr2,&len);
		n=fwrite(ptr2,sizeof(char),len,f);
	} else {
		n=fwrite(ptr,sizeof(char),len,f);
	}
	fclose(f);
	if (n==len) return 0;
	return -1;
}

int default_cbLoadGame(void* context,char* filename,void* ptr,int len)
{
	tContext *pContext=(tContext*)context;
	FILE *f;
	int n;
	void *ptr2;
	f=fopen(filename,"rb");
	if (!f)
	{
		printf("Unable to open file [%s]\n",(char*)ptr);
		return 0;
	}
	if (pContext->advancedSaves)
	{
		dMagnetic_getVM(pContext->hEngine,&ptr2,&len);
		n=fread(ptr2,sizeof(char),len,f);
	} else {
		n=fread(ptr,sizeof(char),len,f);
	}
	fclose(f);
	if (n==len) return 0;
	return -1;
}
#endif
int default_getsize(int* size)
{
	if (size==NULL) return DEFAULT_NOK;
	*size=sizeof(tContext);
	return DEFAULT_OK;
}
const char *default_low_ansi_characters="1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ\\/;|(){}[]<>?";
const char *default_monochrome_characters="  .,-+=*oxm#@OXM";

int default_open(void* hContext,FILE *f_inifile,int argc,char** argv)
{
	tContext *pContext=(tContext*)hContext;
	char result[1024];
	if (pContext==NULL) return DEFAULT_NOK;
	memset(pContext,0,sizeof(tContext));
	pContext->magic=MAGIC;

	// the hiearchy is: first the default values. 
	// if there is a .ini file, overwrite them with those values.
	// paramaters from the command line have the highest prioprity.

	pContext->rows=40;
	pContext->columns=120;
	pContext->mode=eMODE_LOW_ANSI;	// 0=none. 1=monochrome. 2=low_ansi. 3=high_ansi. 4=high_ansi2, 5=sixel
	pContext->f_logfile=NULL;
	pContext->echomode=0;
	pContext->textalign=ALIGNMENT_BLOCK;

	pContext->screenwidth=320;
	pContext->screenheight=200;
	pContext->forceres=0;
	pContext->advancedSaves=1;


	strncpy(pContext->low_ansi_characters,default_low_ansi_characters,sizeof(pContext->low_ansi_characters)-1);
	strncpy(pContext->monochrome_characters,default_monochrome_characters,sizeof(pContext->monochrome_characters)-1);


	if (f_inifile)
	{
		if (retrievefromini(f_inifile,"[DEFAULTGUI]","rows",result,sizeof(result))) 
		{
			pContext->rows=atoi(result);
		}
		if (retrievefromini(f_inifile,"[DEFAULTGUI]","columns",result,sizeof(result))) 
		{
			pContext->columns=atoi(result);
		}
		if (retrievefromini(f_inifile,"[DEFAULTGUI]","mode",result,sizeof(result)))
		{
			if (strncmp(result,"none",4)==0) pContext->mode=eMODE_NONE;
			else if (strncmp(result,"monochrome_inv",14)==0) {pContext->mode=eMODE_MONOCHROME;pContext->monochrome_inverted=1;}
			else if (strncmp(result,"monochrome",10)==0) pContext->mode=eMODE_MONOCHROME;
			else if (strncmp(result,"low_ansi2",9)==0) pContext->mode=eMODE_LOW_ANSI2;
			else if (strncmp(result,"low_ansi",8)==0) pContext->mode=eMODE_LOW_ANSI;
			else if (strncmp(result,"high_ansi2",10)==0) pContext->mode=eMODE_HIGH_ANSI2;
			else if (strncmp(result,"high_ansi",9)==0) pContext->mode=eMODE_HIGH_ANSI;
			else if (strncmp(result,"sixel",5)==0) pContext->mode=eMODE_SIXEL;
			else if (strncmp(result,"utf",4)==0) pContext->mode=eMODE_UTF;
		}
		if (retrievefromini(f_inifile,"[DEFAULTGUI]","align",result,sizeof(result)))
		{
			if (strncmp(result,"left",4)==0) pContext->textalign=ALIGNMENT_LEFT;
			if (strncmp(result,"block",5)==0) pContext->textalign=ALIGNMENT_BLOCK;
			if (strncmp(result,"right",5)==0) pContext->textalign=ALIGNMENT_RIGHT;
		}
		if (retrievefromini(f_inifile,"[DEFAULTGUI]","low_ansi_characters",pContext->low_ansi_characters,sizeof(pContext->low_ansi_characters)))
		{
			if (pContext->low_ansi_characters[0]==0x00) 
			{
				fprintf(stderr,"Error in .ini file: low_ansi_character\n");
				return -1;
			}
			
		}
		if (retrievefromini(f_inifile,"[DEFAULTGUI]","monochrome_characters",pContext->monochrome_characters,sizeof(pContext->monochrome_characters)))
		{
			if (pContext->monochrome_characters[0]==0x00) 
			{
				fprintf(stderr,"Error in .ini file: monochrome_character\n");
				return -1;
			}

		}
		if (retrievefromini(f_inifile,"[DEFAULTGUI]","sixel_forceresolution",result,sizeof(result)))
		{
			if (result[0]=='y' || result[0]=='Y' || result[0]=='t' || result[0]=='T' || result[0]=='1') pContext->forceres=1;	// set it to one if the entry reads "yes"/"True"/1
		}
		if (retrievefromini(f_inifile,"[DEFAULTGUI]","sixel_resolution",result,sizeof(result)))
		{
			int i;
			int l;
			l=strlen(result);
			pContext->screenwidth=pContext->screenheight=0;
			for (i=0;i<l;i++)
			{
				if (result[i]=='x')
				{
					result[i]=0;
					pContext->screenwidth =atoi(&result[0]);
					pContext->screenheight=atoi(&result[i+1]);
				}
			}
			if (pContext->screenwidth==0 || pContext->screenwidth>MAX_SRESX || pContext->screenheight==0) 
			{
				printf("illegal parameter for sixelresultion. please use something like 1024x768\n");
				return DEFAULT_NOK;
			}

		}
		if (retrievefromini(f_inifile,"[DEFAULTGUI]","savegames",result,sizeof(result)))
		{
			if (result[0]=='c' || result[0]=='C') pContext->advancedSaves=0;	// "classic" or "Classic"
			if (result[0]=='a' || result[0]=='A') pContext->advancedSaves=1;	// "advanced" or "Advanced"
		}
	}
	if (argc)
	{
		char result[64];
		if (retrievefromcommandline(argc,argv,"-valign",result,sizeof(result)))
		{
			if (strncmp(result,"left",4)==0) pContext->textalign=ALIGNMENT_LEFT;
			else if (strncmp(result,"block",5)==0) pContext->textalign=ALIGNMENT_BLOCK;
			else if (strncmp(result,"right",5)==0) pContext->textalign=ALIGNMENT_RIGHT;
			else {
				printf("unknown parameter for -valign. please use one of\n");
				printf("left ");
				printf("block ");
				printf("right ");
				printf("\n");
				return DEFAULT_NOK;
			}
		}
		if (retrievefromcommandline(argc,argv,"-vmode",result,sizeof(result)))
		{
			if (strncmp(result,"none",4)==0) pContext->mode=eMODE_NONE;
			else if (strncmp(result,"monochrome_inv",14)==0) {pContext->mode=eMODE_MONOCHROME;pContext->monochrome_inverted=1;}
			else if (strncmp(result,"monochrome",10)==0) pContext->mode=eMODE_MONOCHROME;
			else if (strncmp(result,"low_ansi2",9)==0) pContext->mode=eMODE_LOW_ANSI2;
			else if (strncmp(result,"low_ansi",8)==0) pContext->mode=eMODE_LOW_ANSI;
			else if (strncmp(result,"high_ansi2",10)==0) pContext->mode=eMODE_HIGH_ANSI2;
			else if (strncmp(result,"high_ansi",9)==0) pContext->mode=eMODE_HIGH_ANSI;
			else if (strncmp(result,"sixel",5)==0) pContext->mode=eMODE_SIXEL;
			else if (strncmp(result,"utf",4)==0) pContext->mode=eMODE_UTF;
			else {
				printf("unknown parameter for -vmode. please use one of\n");
				printf("none ");
				printf("monochrome ");
				printf("monochrome_inv ");
				printf("low_ansi ");
				printf("low_ansi2 ");
				printf("high_ansi ");
				printf("high_ansi2 ");
				printf("sixel ");
				printf("utf ");
				printf("\n");
				return DEFAULT_NOK;
			}
		}
		if (retrievefromcommandline(argc,argv,"-vrows",result,sizeof(result)))
		{
			int rows;
			rows=atoi(result);
			if (rows<1 || rows>500) 
			{
				printf("illegal parameter for -vrows. please use values between 1 and 500\n");
				return DEFAULT_NOK;
			}
			pContext->rows=rows;
		}
		if (retrievefromcommandline(argc,argv,"-vcols",result,sizeof(result)))
		{
			int cols;
			cols=atoi(result);
			if (cols<1 || cols>600) 
			{
				printf("illegal parameter for -vcols. please use values between 1 and 600\n");
				return DEFAULT_NOK;
			}
			pContext->columns=cols;
		}
		if (retrievefromcommandline(argc,argv,"-vecho",NULL,0))
		{
			pContext->echomode=1;
		}
		if (retrievefromcommandline(argc,argv,"-vlog",result,sizeof(result)))
		{
			fprintf(stderr,"Opening logfile [%s] for writing\n",result);
			pContext->f_logfile=fopen(result,"wb");
			if (pContext->f_logfile==NULL)
			{
				fprintf(stderr,"Error opening logfile [%s]\n",result);
				exit(0);
			}
		}
		if (retrievefromcommandline(argc,argv,"-sres",result,sizeof(result)))
		{
			int i;
			int l;
			l=strlen(result);
			pContext->screenwidth=pContext->screenheight=0;
			for (i=0;i<l;i++)
			{
				if (result[i]=='x')
				{
					result[i]=0;
					pContext->screenwidth =atoi(&result[0]);
					pContext->screenheight=atoi(&result[i+1]);
				}
			}
			if (pContext->screenwidth==0 || pContext->screenwidth>MAX_SRESX || pContext->screenheight==0) 
			{
				printf("illegal parameter for -sres. please use something like 1024x768\n");
				return DEFAULT_NOK;
			}
		}
		if (retrievefromcommandline(argc,argv,"-sforce",result,sizeof(result)))
		{
			pContext->forceres=1;
		}
#ifdef	EXPERIMENTAL_SAVEGAME_SLOTS
		snprintf(pContext->advancedSavesFilename,64,"savegames.bin");
		if (retrievefromcommandline(argc,argv,"-savegameslots",result,sizeof(result)))
		{
			pContext->advancedSaves=1;
			strncpy(pContext->advancedSavesFilename,result,sizeof(pContext->advancedSavesFilename));
		}
#else
		if (retrievefromcommandline(argc,argv,"-saves",result,sizeof(result)))
		{
			if (result[0]=='c' || result[0]=='C') pContext->advancedSaves=0;	// "classic" or "Classic"
			if (result[0]=='a' || result[0]=='A') pContext->advancedSaves=1;	// "advanced" or "Advanced"
		}
#endif
	}
	return DEFAULT_OK;

}
