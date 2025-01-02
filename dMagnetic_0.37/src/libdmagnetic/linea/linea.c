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

//#define	DEBUG_PRINT

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "linea.h"
#include "gfxloader.h"
#include "vm68k_datatypes.h"
#include "vm68k_macros.h"

#define	MAGICVALUE	0x42696e61	// ="Lina"
#define	MAXINPUTBUFFER	256
#define	MAXTEXTBUFFER	4096	// 4kByte ought to be enough
#define	MAXHEADLINEBUFFER 256


typedef struct _tProperties
{
	tVM68k_ubyte unknown1[5];
	tVM68k_ubyte flags1;
	tVM68k_ubyte flags2;
	tVM68k_ubyte unknown2;
	tVM68k_uword parentobject;
	tVM68k_ubyte unknown3[2];
	tVM68k_uword endflags;
} tProperties;

typedef struct _tLineA
{
	tVM68k_ulong magic;
	tVM68k_ubyte	version;

	// pointers to important memory sections.
	tVM68k_ubyte* 	pMem;
	tVM68k_ulong	memsize;
	tVM68k_ulong	codesize;
	tVM68k_ubyte*	pStrings1;
	tVM68k_ulong	string1size;	// the strings for some adventures were stored in two parts, since they have gotten too big
	tVM68k_ulong	string2size;	// 
	tVM68k_ubyte*	pDict;
	tVM68k_ulong	dictsize;
	tVM68k_ulong	decsize;
	tVM68k_ubyte*	pStringHuffman;
	tVM68k_ubyte*	pUndo;
	tVM68k_ulong	undosize;
	tVM68k_slong	undopc;

	// pointers to the callback functions
	cbLineANewOutput	pcbNewOutput;
	void*			contextNewOutput;
	cbLineAInputString	pcbInputString;
	void*			contextInputString;
	cbLineADrawPicture	pcbDrawPicture;
	void*			contextDrawPicture;
	tdMagneticPicture* 	pPicture;
	cbLineASaveGame		pcbSaveGame;
	void*			contextSaveGame;
	cbLineALoadGame		pcbLoadGame;
	void*			contextLoadGame;

	// persistent memory for some A0xx instructions.
	tVM68k_slong	random_state;
	tVM68k_bool  random_mode;
	tVM68k_uword	properties_offset;
	tVM68k_uword	linef_subroutine;			// version >0
	tVM68k_uword	linef_tab;				// version >1
	tVM68k_uword	linef_tabsize;				// version >1
	tVM68k_uword	properties_tab;				// version >2
	tVM68k_uword	properties_size;			// version >2
	tVM68k_slong	interrupted_byteidx;
	tVM68k_ubyte	interrupted_bitidx;

	// input buffer queue.
	char inputbuf[MAXINPUTBUFFER];
	int level;
	int used;


// decoding of the output
	char textbuf[MAXTEXTBUFFER];
	int textbuf_writeidx;
	int textbuf_level;
	char headlinebuf[MAXHEADLINEBUFFER];
	int headline_writeidx;
	int headline_level;
	int headlineflagged;
	int capital;
	unsigned char lastchar;
	int jinxterslide;		// workaround for the sliding puzzle in Jinxter
	char picname[16];		// name or number of the picture to be shown


	tVM68k_ubyte *magbuf;
	tVM68k_ulong magsize;
	tVM68k_ubyte *gfxbuf;
	tVM68k_ulong gfxsize;

	// prefer ega images when set.
	tVM68k_bool egamode;

	// dump the pictures as .xpm and quit
	tVM68k_bool dumpxpm;


} tLineA;


tVM68k_ulong lineA_getrandom(tLineA* pLineA)
{
	if (pLineA->random_mode==0)
	{
		pLineA->random_state*=1103515245ull;
		pLineA->random_state+=12345ull;
	} else {
		pLineA->random_state=rand();
	}
	return pLineA->random_state&0x7fffffff;
}

int lineA_parsegamefiles(tLineA* pLineA,void* pMag,int magsize,void* pGfx,int gfxsize)
{
	int idx;
	// first: store the mag and gfx data
	if (pMag==NULL) return LINEA_NOK_INVALID_PTR;
	pLineA->magbuf=(tVM68k_ubyte*)pMag;pLineA->magsize=magsize;

	// lets start with the header.
	// @0   4 bytes "MaSc"
	// @4   9 bytes TODO
	// @13  1 byte version
	// @14  4 bytes codesize
	// @18  4 bytes string1size
	// @22  4 bytes string2size
	// @26  4 bytes dictsize
	// @30  4 bytes decsize
	// @34  4 bytes undosize
	// @38  4 bytes undopc

	// ----------
	// @42   codesize bytes   code
	// @42+codesize  string1size bytes...
	// @...  string2size
	// @...  dictsize
	// @...  undo

	if (pLineA->magbuf[0]!='M' || pLineA->magbuf[1]!='a' || pLineA->magbuf[2]!='S' || pLineA->magbuf[3]!='c') return LINEA_NOK_INVALID_PARAM;
//	since the magic word seemed to be okay, start reading the header.
	pLineA->version=pLineA->magbuf[13];
	pLineA->codesize=READ_INT32BE(pLineA->magbuf,14);
	pLineA->string1size=READ_INT32BE(pLineA->magbuf,18);
	pLineA->string2size=READ_INT32BE(pLineA->magbuf,22);
	pLineA->dictsize=READ_INT32BE(pLineA->magbuf,26);
	pLineA->decsize=READ_INT32BE(pLineA->magbuf,30);
	pLineA->undosize=READ_INT32BE(pLineA->magbuf,34);
	pLineA->undopc=READ_INT32BE(pLineA->magbuf,38);

	/////////////////////////////////////
	// the code section has to be copied into the shared memory section.
	// because the same section is writable. first: drain the memory.
	memset(pLineA->pMem,0,pLineA->memsize);
	if (pLineA->memsize<pLineA->codesize) return LINEA_NOK_NOT_ENOUGH_MEMORY;

	pLineA->memsize=pLineA->codesize;
	if (pLineA->memsize<0x10000) pLineA->memsize=0x10000;	// miminum memory size


	idx=42;	// the header held 42 bytes.
	memcpy(pLineA->pMem,&pLineA->magbuf[idx],pLineA->codesize);	idx+=pLineA->codesize;


	// every other sections is just read-only. they can stay where they are.
	// for conveniance reasons, i am adding the pointers.
	pLineA->pStrings1=&pLineA->magbuf[idx];idx+=pLineA->string1size+pLineA->string2size;
	pLineA->pDict=&pLineA->magbuf[idx];idx+=pLineA->dictsize;
	pLineA->pUndo=&pLineA->magbuf[idx];//idx+=pLineA->undosize;
	pLineA->pStringHuffman=&pLineA->pStrings1[pLineA->decsize];

	pLineA->gfxsize=gfxsize;
	if (pGfx!=NULL)
	{
		pLineA->gfxbuf=(tVM68k_ubyte*)pGfx;
	} 
	if (idx>magsize)
	{
		fprintf(stderr,"ERROR: .mag file broken? %d > %d\n",idx,magsize);
		return LINEA_NOK;
	}

	return LINEA_OK;
}
int lineA_dumppics(void *hLineA)
{
	int i;
	tLineA* pLineA=(tLineA*)hLineA;
	if (hLineA==NULL) return LINEA_NOK_INVALID_PTR;

	if (pLineA->pcbDrawPicture==NULL)
	{
		return LINEA_OK;
	}
	if (pLineA->version!=4)
	{
		for (i=0;i<30;i++)
		{
			snprintf(pLineA->picname,8,"%02d",i);
			if (gfxloader_unpackpic(pLineA->gfxbuf,pLineA->gfxsize,pLineA->version,i,NULL,pLineA->pPicture,0)==LINEA_OK)
			{
				pLineA->pcbDrawPicture(pLineA->contextDrawPicture,pLineA->pPicture,pLineA->picname,1);
			}
		}
	} else {
		int dirsize;
		int diridx;

		int entrysize;


		diridx=6;				// first entry is at byte 6
		if (pLineA->gfxbuf[3]=='4') 
		{
			entrysize=14;
			dirsize=entrysize*(READ_INT16LE(pLineA->gfxbuf,4));	// bytes 4..5 are the number of entries
		} else {
			dirsize=READ_INT16BE(pLineA->gfxbuf,4);	// bytes 4..5 are the size of the directory
			entrysize=16;
		}
		while (dirsize>=entrysize)
		{
			pLineA->picname[0]='v'; pLineA->picname[1]='g'; pLineA->picname[2]='a';pLineA->picname[3]='_';
			memcpy(&pLineA->picname[4],&(pLineA->gfxbuf[diridx]),6);
			pLineA->picname[10]=0;

			if (gfxloader_unpackpic(pLineA->gfxbuf,pLineA->gfxsize,pLineA->version,-1,&pLineA->picname[4],pLineA->pPicture,0)==LINEA_OK)	// extract the VGA picture
			{
				pLineA->picname[0]='v';
				pLineA->pcbDrawPicture(pLineA->contextDrawPicture,pLineA->pPicture,pLineA->picname,2);
			}
			if (gfxloader_unpackpic(pLineA->gfxbuf,pLineA->gfxsize,pLineA->version,-1,&pLineA->picname[4],pLineA->pPicture,1)==LINEA_OK)	// extract the EGA picture
			{
				pLineA->picname[0]='e';
				pLineA->pcbDrawPicture(pLineA->contextDrawPicture,pLineA->pPicture,pLineA->picname,2);
			}

			dirsize-=entrysize;
			diridx+=entrysize;
		}

	}
	return LINEA_OK;
}
int lineA_flush(tLineA* pLineA)
{
	if (pLineA->pcbNewOutput!=NULL)
	{
		pLineA->pcbNewOutput(pLineA->contextNewOutput,pLineA->headlinebuf,pLineA->textbuf,pLineA->picname);
	}

	pLineA->headline_level=pLineA->headline_writeidx;
	pLineA->textbuf_level=pLineA->textbuf_writeidx;
	pLineA->headline_writeidx=pLineA->textbuf_writeidx=0;
	return 0;
}
int lineA_newchar(tLineA* pLineA,unsigned char c,unsigned char controlD2,unsigned char flag_headline)
{
	unsigned char c2;

	// one line, ending with a dash -
	// is some kind of code for a "verbatim" mode.
	// it is needed for a sliding puzzle in JINXTER.
	if (pLineA->jinxterslide)
	{
		if ((c>='a' && c<='z') || (c>='A' && c<='Z') || (c==0x5a && pLineA->lastchar=='\n'))
		{
			// The sliding puzzle ends with the phrase "As the blocks slide into their final position". Or with two newlines.
			pLineA->jinxterslide=0;
		}
	} else if (c==0x5e && pLineA->lastchar==0x2d) {
		pLineA->jinxterslide=1;
	}

	if (flag_headline && !pLineA->headlineflagged) 	// this starts a headline
	{
		lineA_flush(pLineA);	// make sure the output buffers are being flushed
		pLineA->headline_writeidx=0;
	}
	if (!flag_headline && pLineA->headlineflagged)	// after the headline ends, a new paragraph is beginning
	{
		int i;
		pLineA->capital=1;	// obviously, this starts with a capital letter
		for (i=0;i<pLineA->headline_writeidx;i++)
		{
			if (pLineA->headlinebuf[i]<' ')
			{
				pLineA->headlinebuf[i]=0;
				pLineA->headline_writeidx--;
			}
		}
	}
	pLineA->headlineflagged=flag_headline;

	//newline=0;
	if (c==0xff)	// mark the next letter as Capital
	{
		pLineA->capital=1;
	} else {
		c2=c&0x7f;	// the highest bit was an end marker for the hufman tree in the dictionary
		// THE RULES FOR THE OUTPUT ARE:
		// replace tabs and _ with space.
		// the headline is printed in upper case letters.
		// after a . there has to be a space.
		// and after a . The next letter has to be uppercase.
		// multiple spaces are to be reduced to a single one.
		// the characters ~ and ^ are to be translated into line feeds.
		// the caracter 0xff makes the next one upper case.
		// after a second newline comes a capital letter.
		// the special marker '@' is either an end marker, or must be substituted by an 's', so that "He thank@ you", and "It contain@ a key" become gramatically correct.
		if (!(pLineA->jinxterslide))
		{
			if (c2==9 || c2=='_') c2=' ';
			if (flag_headline && (c2==0x5f || c2==0x40)) c2=' ';	// in a headline, those are the control codes for a space.
			if (c2==0x40) 	// '@' is a special character
			{
				if (controlD2 || pLineA->lastchar==' ') return 0;	// When D2 is set, or the last character was a whitespace, it is an end marker
				else c2='s';						// otherwise it must be substituted for an 's'. One example would be "It contain@ a key".
			}
			if (c2==0x5e || c2==0x7e) c2=0x0a;	// ~ or ^ is actually a line feed.
			if (c2==0x0a && pLineA->lastchar==0x0a) 	// after two consequitive newlines comes a capital letter.
			{
				pLineA->capital=1;
			}
			if (c2=='.' || c2=='!' || c2==':' || c2=='?')	// a sentence is ending.
			{
				pLineA->capital=1;
			}
			if (((c2>='a' && c2<='z') || (c2>='A' && c2<='Z')) && (pLineA->capital||flag_headline)) 	// the first letter must be written as uppercase. As well as the headline.
			{
				pLineA->capital=0;	// ONLY the first character
				c2&=0x5f;	// upper case
			}
			//newline=0;
			if (
					(pLineA->lastchar=='.' || pLineA->lastchar=='!' || pLineA->lastchar==':' || pLineA->lastchar=='?'|| pLineA->lastchar==',' || pLineA->lastchar==';') 	// a sentence as ended
					&&  ((c2>='A' && c2<='Z') ||(c2>='a' && c2<='z') ||(c2>='0' && c2<='9'))) 	// and a new one is beginning.
			{
				// after those letters comes an extra space.otherwise,it would look weird.
				if (flag_headline) 
				{
					if (pLineA->headline_writeidx<MAXHEADLINEBUFFER-1)
						pLineA->headlinebuf[pLineA->headline_writeidx++]=' ';
				} else {
					if (pLineA->textbuf_writeidx<MAXTEXTBUFFER-1)
					{
						pLineA->textbuf[pLineA->textbuf_writeidx++]=' ';
					}
				}
			}
			if (pLineA->textbuf_writeidx>0 && pLineA->lastchar==' ' && (c2==',' || c2==';' || c2=='.' || c2=='!'))	// there have been some glitches with extra spaces, right before a komma. which , as you can see , looks weird.
			{
				pLineA->textbuf_writeidx--;
			}
			if (	//allow multiple spaces in certain scenarios
					flag_headline || pLineA->lastchar!=' ' || c2!=' ')	// combine multiple spaces into a single one.
			{
				if (c2==0x0a || (c2>=32 && c2<127 && c2!='@')) 
				{
					if (flag_headline) 
					{
						if (pLineA->headline_writeidx<MAXHEADLINEBUFFER-1)
						{
							if ((c2&0x7f)>=' ')
							{
								pLineA->headlinebuf[pLineA->headline_writeidx++]=c2&0x7f;
							} else {
								pLineA->headlinebuf[pLineA->headline_writeidx++]=0;
							}
						}
					} else if (pLineA->textbuf_writeidx<MAXTEXTBUFFER-1) {
						if (pLineA->textbuf_writeidx<MAXTEXTBUFFER-1)
						{
							pLineA->textbuf[pLineA->textbuf_writeidx++]=c2;
						}

						//					if (c2=='\n') newline=1;
					}
					pLineA->lastchar=c2;
				}
			}
		} else if (c2) {
			if (c2==0x5e) c2='\n';
			if (c2=='_') c2=' ';
			pLineA->textbuf[pLineA->textbuf_writeidx++]=c2;
			pLineA->lastchar=c2;
		}
	}
	// make sure that the buffers are zero-terminated.
	pLineA->headlinebuf[pLineA->headline_writeidx]=0;
	pLineA->textbuf[pLineA->textbuf_writeidx]=0;
	if (pLineA->headline_writeidx>=(MAXHEADLINEBUFFER-1) || pLineA->textbuf_writeidx>=(MAXTEXTBUFFER-1))
	{
		lineA_flush(pLineA);	// the buffers are full, and flushing them is required
	}
	return 0;
}

int lineA_getsize(int* size)
{
	if (size==NULL) return LINEA_NOK_INVALID_PTR;
	*size=sizeof(tLineA);
	return LINEA_OK;
}
int lineA_showTitleScreen(void* hLineA)
{
	tLineA* pLineA=(tLineA*)hLineA;
	if (hLineA==NULL) return LINEA_NOK_INVALID_PTR;
	// the pc version has title screens. it would be a shame not to show them.
	if (pLineA->gfxsize) {
		if (pLineA->gfxbuf[0]=='M' && pLineA->gfxbuf[1]=='a' && pLineA->gfxbuf[2]=='P' && pLineA->gfxbuf[3]=='3')
		{
			int i;
			char string[]="Press Enter\n";
			gfxloader_unpackpic(pLineA->gfxbuf,pLineA->gfxsize,pLineA->version,30,NULL,pLineA->pPicture,0);
			if (pLineA->pcbDrawPicture!=NULL)
			{
				pLineA->pcbDrawPicture(pLineA->contextDrawPicture,pLineA->pPicture,"30",1);

			}
			for (i=0;i<strlen(string);i++)
			{
				lineA_newchar(pLineA,string[i],0,0);
			}
			lineA_flush(pLineA);
			// wait for an ENTER
			if (pLineA->pcbInputString!=NULL)
			{
				pLineA->level=0;
				pLineA->pcbInputString(pLineA->contextInputString,&pLineA->level,pLineA->inputbuf);
				pLineA->level=0;
			}
		}

	}
	return LINEA_OK;
}



// the purpose of this function is to load the properties for a specific object.
int lineA_loadproperties(tLineA* pLineA,tVM68k* pVM68k,tVM68k_uword objectnum,tVM68k_ulong* retaddr,tProperties* pProperties)
{
	tVM68k_ulong addr;
	int i;

	if (pLineA->version>2 && (objectnum>pLineA->properties_size))
	{
		addr=(pLineA->properties_size-objectnum)^0xffff;	// TODO: WTF?
		addr*=2;
		addr+=pLineA->properties_tab;
		objectnum=READ_INT16BE(pVM68k->memory,addr);
	}
	addr=pLineA->properties_offset+14*objectnum;

	for (i=0;i<5;i++)
	{
		pProperties->unknown1[i]=pVM68k->memory[addr+i];
	}
	pProperties->flags1=pVM68k->memory[addr+5];
	pProperties->flags2=pVM68k->memory[addr+6];
	pProperties->unknown2=pVM68k->memory[addr+7];
	pProperties->parentobject=READ_INT16BE(pVM68k->memory,addr+8);
	for (i=0;i<2;i++)
	{
		pProperties->unknown3[i]=pVM68k->memory[addr+i+10];
	}
	pProperties->endflags=READ_INT16BE(pVM68k->memory,addr+12);
	if (retaddr!=NULL) *retaddr=addr;
	return LINEA_OK;
}
int lineA_substitute_aliases(void* hLineA,unsigned short* opcode)
{
	tVM68k_uword inst;
	inst=*opcode;
	if ((inst&0xfe00)==0xA400) {inst&=0x01ff;inst|=0x6100;}	// BSR
	if ((inst&0xfe00)==0xA200) {inst=0x4e75;}	// RTS
	if ((inst&0xfe00)==0xA600) {inst&=0x01ff;inst|=0x4a00;}	// TST
	if ((inst&0xfe00)==0xA800) {inst&=0x01ff;inst|=0x4800;}	// MOVEM, register to memory (=0x4800)
	if ((inst&0xfe00)==0xAA00) {inst&=0x01ff;inst|=0x4C00;}	// MOVEM, memory to register (=0x4C00)

	*opcode=inst;
	return LINEA_OK;

}
int lineA_init(void* hLineA,void* pSharedMem,int sharedmemsize,void* pMag,int magsize,void* pGfx,int gfxsize)
{
	tLineA* pLineA=(tLineA*)hLineA;
	int retval;
	if (hLineA==NULL) return LINEA_NOK_INVALID_PTR;
	memset(pLineA,0,sizeof(tLineA));
	pLineA->magic=MAGICVALUE;
	pLineA->random_mode=0;
	pLineA->random_state=12345;

	pLineA->pMem=pSharedMem;
	pLineA->memsize=sharedmemsize;

	pLineA->pcbNewOutput=NULL;	pLineA->contextNewOutput=NULL;
	pLineA->pcbInputString=NULL;	pLineA->contextInputString=NULL;
	pLineA->pcbDrawPicture=NULL;	pLineA->contextDrawPicture=NULL;pLineA->pPicture=NULL;
	pLineA->pcbSaveGame=NULL;	pLineA->contextSaveGame=NULL;
	pLineA->pcbLoadGame=NULL;	pLineA->contextLoadGame=NULL;

	retval=lineA_parsegamefiles(pLineA,pMag,magsize,pGfx,gfxsize);

	return retval;
}
int lineA_configrandom(void* hLineA,char random_mode,unsigned int random_seed)
{
	tLineA* pLineA=(tLineA*)hLineA;
	if (hLineA==NULL) return LINEA_NOK_INVALID_PTR;
	if (pLineA->magic!=MAGICVALUE) return LINEA_NOK_INVALID_PARAM;
	if (random_mode!=0 && random_mode!=1) return LINEA_NOK_INVALID_PARAM;
	if (random_seed<1 || random_seed>0x7fffffff) return LINEA_NOK_INVALID_PARAM;

	pLineA->random_mode=random_mode;
	pLineA->random_state=random_seed;
	srand(random_seed);

	return 0;
}
int lineA_setEGAMode(void* hLineA,int egamode)
{
	tLineA* pLineA=(tLineA*)hLineA;
	if (hLineA==NULL) return LINEA_NOK_INVALID_PTR;
	if (pLineA->magic!=MAGICVALUE) return LINEA_NOK_INVALID_PARAM;
	if (egamode!=0 && egamode!=1) return LINEA_NOK_INVALID_PARAM;

	pLineA->egamode=egamode;
	return 0;
}

int lineA_getVersion(void* hLineA,int* version)
{
	tLineA* pLineA=(tLineA*)hLineA;

	if (pLineA==NULL) return LINEA_NOK_INVALID_PTR;
	if (version==NULL) return LINEA_NOK_INVALID_PTR;
	if (pLineA->magic!=MAGICVALUE) return LINEA_NOK_INVALID_PARAM;


	*version=pLineA->version;
	return LINEA_OK;
}
int lineA_singlestep(void* hLineA,void* hVM68k,unsigned short opcode)
{
	tLineA* pLineA=(tLineA*)hLineA;
	tVM68k* pVM68k=(tVM68k*)hVM68k;


	int retval=LINEA_NOK_UNKNOWN_INSTRUCTION;
	if (pLineA==NULL) return LINEA_NOK_INVALID_PTR;
	if (pVM68k==NULL) return LINEA_NOK_INVALID_PTR;
	if (pLineA->magic!=MAGICVALUE) return LINEA_NOK_INVALID_PARAM;

	if (pLineA->version!=0 && (opcode&0xf000)==0xf000)	// version 1 introduced programmable subroutines.
								// with version 2, it became programmable
	{
//		PUSHLONGTOSTACK(pVM68k,&next,next.pcr);
		if (pLineA->version==1)
		{
			// push long to stack
			pVM68k->a[7]-=4;
			WRITE_INT32BE(pVM68k->memory,pVM68k->a[7],pVM68k->pcr);
			pVM68k->pcr=(pLineA->linef_subroutine)%pVM68k->memsize;
		}
		else
		{
			tVM68k_uword idx;
			tVM68k_sword base;
			idx=opcode&0x7ff;
			if (idx>=pLineA->linef_tabsize)
			{
				// so... at linef_tab is a list of jump-points.
				// the virtually, the pc jumps onto the address given by the opcode, and from there another XXXX samples on.
				if (!(opcode&0x0800))	// when it is a call to a subroutine
				{
					// push long to stack
					pVM68k->a[7]-=4;
					WRITE_INT32BE(pVM68k->memory,pVM68k->a[7],pVM68k->pcr);
					pVM68k->pcr=(pLineA->linef_subroutine)%pVM68k->memsize;
				}
				idx=(opcode|0x0800);
				idx^=0xffff;
				base=READ_INT16BE(pVM68k->memory,(pLineA->linef_tab+2*idx));
				pVM68k->pcr=(pLineA->linef_tab+2*idx+base)%pVM68k->memsize;	// jump, then jump again.
			} else {
				// push long to stack
				pVM68k->a[7]-=4;
				WRITE_INT32BE(pVM68k->memory,pVM68k->a[7],pVM68k->pcr);
				pVM68k->pcr=(pLineA->linef_subroutine)%pVM68k->memsize;
			}

		}
		return LINEA_OK;
	}
	if ((opcode&0xff00)!=0xa000) return LINEA_NOK_INVALID_PARAM;
	retval=LINEA_OK;
	if ((opcode&0xff)<0xdd || (pLineA->version < 4 && (opcode&0xff) < 0xe4) || (pLineA->version < 2 && (opcode&0xff) < 0xed))
	{
		lineA_getrandom(pLineA);	// advance the random generator
	}
	switch (opcode)
	{
		case 0xa000:	// getchar
				// the way i implemented the input is this:
				// i have a buffer, inputbuf[256]. holding the last input string.
				// when this instruction is called, one character is read and written into D1.
				// 
				// when the buffer is empty, the callback function for inputs is called first.
			{
				if (pLineA->level==pLineA->used) 
				{
					// flush the output
					lineA_flush(pLineA);
					pLineA->level=0;
					pLineA->used=0;


					if (pLineA->pcbInputString!=NULL)
					{
						pLineA->pcbInputString(pLineA->contextInputString,&pLineA->level,pLineA->inputbuf);	// callback to fill the input buffer.
					} else {
						fprintf(stderr,"INTERNAL ERROR: no input set!\n");
						exit(0);
					}
				}
				if (pLineA->level>pLineA->used)	// still characters in the buffer?
				{
					pVM68k->d[1]=pLineA->inputbuf[pLineA->used];	// yes. take one out
					pLineA->used++;					// increase the read pointer for the next time.
				}
			}
			break;
		case 0xa0de:	// version 3 (corruption) introduced this. the other implementation wrote a 1 into D1.
			{
				pVM68k->d[1]&=0xffffff00;
				pVM68k->d[1]|=0x01;
			}
			break;
		case 0xa0df:	// version 3 (corruption) introduced this.
			{

				tVM68k_ubyte	datatype;
				int i;
				datatype=READ_INT8BE(pVM68k->memory,pVM68k->a[1]+2);

				for (i=0;i<8;i++)
				{
					pLineA->picname[i]=READ_INT8BE(pVM68k->memory,pVM68k->a[1]+3+i);
				}
				pLineA->picname[8]=0;

				switch (datatype)
				{
					case 7:	// show picture
						if (pLineA->gfxsize && pLineA->pcbDrawPicture!=NULL)
						{
							gfxloader_unpackpic(pLineA->gfxbuf,pLineA->gfxsize,pLineA->version,-1,pLineA->picname,pLineA->pPicture,pLineA->egamode);
							pLineA->pcbDrawPicture(pLineA->contextDrawPicture,pLineA->pPicture,pLineA->picname,2);

						}
						lineA_flush(pLineA);	// report the new picture
						break;
					default:
						break;
				}
			}
			break;
		case 0xa0e0:	// unknown, PROMPT_EV
			break;
		case 0xa0e1:	// getstring, new feature by corruption! (version4)
			{
				int i;
				// the way i implemented the input is this:
				// i have a buffer, inputbuf[256]. holding the last input string.
				// when this instruction is being called, the argument is the output pointer in A1.
				// up to 256 bytes may be written there. A1 itself is being incremented, until
				// the end of the output is being reached.
				//
				// when the amount of bytes is either 256 or 1, D1 is set to 1. (TODO: why?)
				// 
				// when the buffer is empty, the callback function for inputs is called first.
				lineA_getrandom(pLineA);	// advance the random generator
				if (pLineA->level==pLineA->used) 
				{
					pLineA->level=0;
					pLineA->used=0;
					lineA_flush(pLineA);
					if (pLineA->pcbInputString!=NULL)
					{
						pLineA->pcbInputString(pLineA->contextInputString,&pLineA->level,pLineA->inputbuf);	// callback to fill the input buffer.
					} else {
						fprintf(stderr,"INTERNAL ERROR: no input set!\n");
						exit(0);
					}
				}
				i=0;
				if (pLineA->level>pLineA->used)	// still characters in the buffer?
				{
					tVM68k_ubyte c;
					do
					{
						c=pLineA->inputbuf[pLineA->used];
						if (c==0) c='\n';	// apparently, the virtual machine wants its strings CR terminated.
						WRITE_INT8BE(pVM68k->memory,(pVM68k->a[1]+i),c);
						pLineA->used++;					// increase the read pointer for the next time.
						i++;
					} while (i<MAXINPUTBUFFER  && pLineA->level>pLineA->used && c!='\n');
				}
				pVM68k->a[1]+=(i-1);
				pVM68k->d[1]&=0xffff0000;
				if (i==MAXINPUTBUFFER || i==1)
				{
					pVM68k->d[1]|=1;
				}
			}
			break;

		case 0xa0e3:	// this one apparently erases the picture
			if (pVM68k->d[1]==0)
			{
				if (pLineA->version<4 || pVM68k->d[6]==0)
				{
					// TODO: clear window
				}
			}
			break;
		case 0xa0e4:
			{
					pVM68k->a[7]+=4;	// increase the stack pointer? maybe skip an entry or something?
					pVM68k->pcr=READ_INT32BE(pVM68k->memory,pVM68k->a[7])%pVM68k->memsize;
					pVM68k->a[7]+=4;
			}
			break;
		case 0xa0e5:	// set the Z-flag, RTS, introduced with jinxter.
		case 0xa0e6:	// clear the Z-flag, RTS, introduced with jinxter.
		case 0xa0e7:	// set the Z-flag, introduced with jinxter.
		case 0xa0e8:	// clear the Z-flag, introduced with jinxter.
			{
				if (opcode==0xa0e5 || opcode==0xa0e7)	// set zflag
				{
					pVM68k->sr|=(1<<2);		// BIT 2 is the Z-flag
				} else {	// clear z-flag
					pVM68k->sr&=~(1<<2);		// BIT 2 is the Z-flag
				}
				if (opcode==0xa0e4 || opcode==0xa0e5 || opcode==0xa0e6)
				{
					// RTS: poplongfromstack(pcr);
					pVM68k->pcr=READ_INT32BE(pVM68k->memory,pVM68k->a[7])%pVM68k->memsize;
					pVM68k->a[7]+=4;
				}
			}
			break;
		case 0xa0e9:
			{	// strcpy a word from the dictionary into the memory.
				// source is in A1
				// destination is A0
				tVM68k_ubyte tmp;
				do
				{
					tmp=pLineA->pDict[pVM68k->a[1]++];
					pVM68k->memory[pVM68k->a[0]++]=tmp;
				} while (!(tmp&0x80));
			}
			break;
		case 0xa0ea:	// print a word from the dictionary. the beginning INDEX is stored in A1. the headline flag is signalled in D1.
			{
				unsigned char c;
				tVM68k_ubyte*	dictptr;
				tVM68k_uword	dictidx;

				if (pLineA->pDict==NULL || pLineA->dictsize==0) 
				{
					retval=LINEA_NOK_INVALID_PTR;
				} else {
					dictptr=pLineA->pDict;
					dictidx=pVM68k->a[1]&0xffff;
					do
					{
						c=dictptr[dictidx++];
						lineA_newchar(pLineA,c,pVM68k->d[2]&0xff,pVM68k->d[1]&0xff);
					} while (!(c&0x80));
					pVM68k->a[1]&=0xffff0000;
					pVM68k->a[1]|=dictidx;
				}
			}
			break;
		case 0xa0eb:	// write the byte stored in D1 into the dictionary at index A1
			{
				pLineA->pDict[pVM68k->a[1]&0xffff]=pVM68k->d[1]&0xff;
			}
			break;
		case 0xa0ec:	// read one byte stored @A1 from the dictionary. write it into register D0.	(jinxter)
			{
				pVM68k->d[1]&=0xffffff00;
				pVM68k->d[1]|=pLineA->pDict[pVM68k->a[1]&0xffff]&0xff;
			}
			break;
		case 0xa0ed:	// quit
			{
				retval=LINEA_OK_QUIT;
			}
			break;

		case 0xa0ee:	// restart
			{
				retval=LINEA_OK_RESTART;
			}
			break;

		case 0xa0f0:
			{
				//printf("\x1b[1;37;44mLINEA: show picture %d mode %d\x1b[0m\n",pVM68k->d[0],pVM68k->d[1]);
				int picnum;
				int picmode;

				picnum=pVM68k->d[0];
				picmode=pVM68k->d[1];
				snprintf(pLineA->picname,8,"%d",picnum);
				if (pVM68k->d[1])
				{
					if (pLineA->gfxsize && pLineA->pcbDrawPicture!=NULL)
					{
						gfxloader_unpackpic(pLineA->gfxbuf,pLineA->gfxsize,pLineA->version,picnum,NULL,pLineA->pPicture,pLineA->egamode);
						pLineA->pcbDrawPicture(pLineA->contextDrawPicture,pLineA->pPicture,pLineA->picname,picmode);
					}
					lineA_flush(pLineA);	// report the new picture
				}
			}
			break;
		case 0xa0f1:
			{	// skip some words in the input buffer
				tVM68k_ubyte*	inputptr;
				tVM68k_uword	inputidx;
				tVM68k_ubyte	cinput;
				int i,n;
				inputptr=&pVM68k->memory[pVM68k->a[1]&0xffff];
				inputidx=0;
				n=(pVM68k->d[0])&0xffff;
				for (i=0;i<n;i++)
				{
					do
					{
						cinput= READ_INT8BE(inputptr,inputidx++);
					} while (cinput);	// words are zero-terminated
				}
				pVM68k->a[1]+=inputidx;
			}
			break;
		case 0xa0f2:
			{
				tVM68k_uword objectnum;
				tProperties properties;
				int n;
				tVM68k_bool found;
				objectnum=(pVM68k->d[2])&0x7fff;
				n=pVM68k->d[4]&0x7fff;
				pVM68k->d[0]&=0xffff0000;
				pVM68k->d[0]|=pVM68k->d[2]&0xffff;
				found=0;
				retval=lineA_loadproperties(pLineA,pVM68k,objectnum,&pVM68k->a[0],&properties);
				do
				{
					if (properties.endflags&0x3fff) 
					{
						found=1;
					} else {
						retval=lineA_loadproperties(pLineA,pVM68k,objectnum-1,NULL,&properties);
						if (objectnum==n) found=1;
						else objectnum--;
					}
				} while ((objectnum!=0) && !found);
				if (found) pVM68k->sr|=(1<<0);            // bit 0 is the cflag
				pVM68k->d[2]&=0xffff0000;
				pVM68k->d[2]|=objectnum&0xffff;
			}
			break;
		case 0xa0f3: 
			lineA_newchar(pLineA,pVM68k->d[1],pVM68k->d[2]&0xff,pVM68k->d[3]&0xff);
			break;
		case 0xa0f4:
			{
				if (pLineA->pcbSaveGame!=NULL)
				{
					pLineA->pcbSaveGame(pLineA->contextSaveGame,
						(char*)&pVM68k->memory[(pVM68k->a[0]&0xffff)],	// filename
						&pVM68k->memory[(pVM68k->a[1]&0xffff)],	// ptr
						(pVM68k->d[1]&0xffff)	// len
					);
				}
			}
			break;
		case 0xa0f5:
			{
				if (pLineA->pcbLoadGame!=NULL)
				{
					pLineA->pcbLoadGame(pLineA->contextLoadGame,
						(char*)&pVM68k->memory[(pVM68k->a[0]&0xffff)],	// filename
						&pVM68k->memory[(pVM68k->a[1]&0xffff)],	// ptr
						(pVM68k->d[1]&0xffff)	// len
					);
				}
			}
			break;
		case 0xa0f6:	// get random number (word), modulo D1.
			{
				tVM68k_ulong rand;
				tVM68k_uword limit;
				rand=lineA_getrandom(pLineA);	// advance the random generator
				limit=(pVM68k->d[1])&0xff;
				if (limit==0) limit=1;
				rand%=limit;
				pVM68k->d[1]&=0xffff0000;
				pVM68k->d[1]|=(rand&0xffff);
			}
			break;
		case 0xa0f7:
			{	// get a random value between 0 and 255, and write it to D0.
				tVM68k_ulong rand;
				rand=lineA_getrandom(pLineA);	// advance the random generator

				pVM68k->d[0]&=0xffffff00;
				pVM68k->d[0]|=((rand+(rand>>8))&0xff);
			}
			break;
		case 0xa0f8:	// write string
			{
				// strings are huffman-coded.
				// version 0: 'string2' holds the decoding tree in the first 256 bytes.
				// and the offset addresses for the bit streams in string1.
				// modes have bit 7 set.
				//
				// when the string is terminated with a \0 it ends.
				// when the string terminates with the sequence " @", it will be
				// extended. 
				//
				// the extension will have the cflag set.
				//
				tVM68k_ulong idx;
				tVM68k_uword tmp;
				tVM68k_ubyte val;
				tVM68k_ubyte prevval;
				tVM68k_ulong byteidx;
				tVM68k_ubyte bitidx;

				char c;
				if (!(pVM68k->sr&(1<<0)))	// cflag is in bit 0.
				{
					bitidx=0;
					idx=pVM68k->d[0]&0xffff;
					if (idx==0) byteidx=idx;
					// version 0: string 2 holds the table to decode the strings.
					// the decoder table is 256 bytes long. afterwards, a bunch of pointers
					// to bit indexes follow.
					else byteidx=READ_INT16BE(pLineA->pStringHuffman,(0x100+2*idx));
					tmp=READ_INT16BE(pLineA->pStringHuffman,0x100);
					if (tmp && idx>=tmp)
					{
						byteidx+=pLineA->string1size;
					}
				} else {
					byteidx=pLineA->interrupted_byteidx;
					bitidx=pLineA->interrupted_bitidx;

				}
				val=0;
				do
				{
					prevval=val;
					val=0;
					while (!(val&0x80))	// terminal symbols have bit 7 set.
					{
						tVM68k_ubyte bit;
						bit=pLineA->pStrings1[byteidx];
						if (bit>>(bitidx)&1)
						{
							val=pLineA->pStringHuffman[0x80+val];	// =1 -> go to the right
						} else {
							val=pLineA->pStringHuffman[     val];	// =0 -> go to the left
						}
						bitidx++;
						if (bitidx==8)
						{
							bitidx=0;
							byteidx++;
						}
					}
					val&=0x7f;	// remove bit 7.
					c=val;


					lineA_newchar(pLineA,c,pVM68k->d[2]&0xff,pVM68k->d[3]&0xff);

				}
				while (val!=0 && !(prevval==' ' && val=='@'));	// end markers for the string are \0 and " @"
				if (prevval==' ' && val=='@')		// extend the string next time this function is being called.
				{
					pVM68k->sr|=(1<<0);	// set the cflag. cflag=bit 0.
					pLineA->interrupted_byteidx=byteidx;
					pLineA->interrupted_bitidx=bitidx;
				} else {
					pVM68k->sr&=~(1<<0);	// clear the cflag. cflag=bit 0.
				}


			}
			break;
		case 0xa0f9:	//get inventory item(d0)
			{
					// there is a list of parent objects
					//
					// apparently, the structure of the properties is as followed:
					// byte 0..4: UNKNOWN
					// byte 5: Flags. 
					//		bit 0: is_described
					// byte 6: some flags
					//		=bit 7: worn
					//		=bit 6: bodypart
					//		=bit 3: room
					//		=bit 2: hidden
					// byte 8/9: parent object. the player is =0x0000
					// byte 10..13: UNKNOWN
					// the data structure is a list.
				tVM68k_bool found;
				tVM68k_uword objectnum1;
				tVM68k_uword objectnum2;
				tProperties properties;

				found=0;
				// go backwards from the objectnumber
				for (objectnum1=pVM68k->d[0];objectnum1>0 && !found;objectnum1--)
				{
					objectnum2=objectnum1;
					do
					{
						// search for the parent
						retval=lineA_loadproperties(pLineA,pVM68k,objectnum2,&pVM68k->a[0],&properties);
						objectnum2=properties.parentobject;
						if ((properties.flags1&1) //is described
							|| (properties.flags2&0xcc))	// worn, bodypart, room or hidden
						{
							objectnum2=0;	// break the loop
						}
						else if (properties.parentobject==0) found=1;
						if (!(properties.flags2&1))
						{
							objectnum2=0;	// break the loop
						}
					} while (objectnum2);
				}
				// set the z-flag when the object was found. otherwise clear it.
				pVM68k->sr&=~(1<<2);	// zflag is bit 2
				if (found) pVM68k->sr|=(1<<2);
				pVM68k->d[0]&=0xffff0000;
				pVM68k->d[0]|=(objectnum1+1)&0xffff;	// return value
			}
			break;
		case 0xa0fa:
			{
				// search the properties database for a match with the entry in D2.
				// starting adress is stored in A0. D3 is the variable counter.
				// d4 is the limit. for (;D3<D4;D3++) {}
				// d5 =0 is a byte search. D5=1 is a word search.
				// set cflag when the entry is found.

				tVM68k_uword i;
				tVM68k_bool found;
				tVM68k_ulong addr;
				tVM68k_uword pattern;
				tVM68k_uword value;
				tVM68k_bool byte0word1;

				found=0;
				addr=pVM68k->a[0];
				pattern=pVM68k->d[2];
				byte0word1=pVM68k->d[5];
				pVM68k->sr&=~(1<<0);	// cflag is bit 0;
				for (i=(pVM68k->d[3]&0xffff);i<(pVM68k->d[4]&0xffff) && !found;i++)
				{
					if (byte0word1)
					{
						value=READ_INT16BE(pVM68k->memory,addr);
						value&=0x3fff;
					} else {
						value= READ_INT8BE(pVM68k->memory,addr);
						value&=0xff;
					}
					addr+=14;
					if (value==pattern)
					{
						found=1;
						pVM68k->a[0]=addr;
						pVM68k->sr|=(1<<0);	// cflag is bit 0.
					}
				}
				pVM68k->d[3]=i;

			}
			break;
		case 0xa0fb:
			{	// skip D2 many words in the dictionary, that is pointed at by A1
				tVM68k_ubyte*	dictptr;
				tVM68k_uword	dictidx;
				tVM68k_ubyte	cdict;
				int i;
				int n;


				dictidx=0;
				if (pLineA->version==0 || pLineA->pDict==NULL || pLineA->dictsize==0) 
				{
					dictptr=&pVM68k->memory[pVM68k->a[1]&0xffff];
				} else {
					//dictptr=pLineA->pDict;
					dictptr=&pLineA->pDict[pVM68k->a[1]&0xffff];
				}
				n=(pVM68k->d[2]&0xffff);
				for (i=0;i<n;i++)
				{
					do
					{
						cdict= READ_INT8BE(dictptr,dictidx++);
					} while (!(cdict&0x80));
				}
				pVM68k->d[2]&=0xffff0000;	// that was a counter
				pVM68k->a[1]+=dictidx;
			}
			break;
		case 0xa0fc:	// skip D0 many words in the input buffer, as well as the dictionary.
			{
				tVM68k_ubyte*	dictptr;
				tVM68k_ubyte*	inputptr;
				tVM68k_uword	dictidx;
				tVM68k_uword	inputidx;
				int i,n;
				dictidx=0;
				inputidx=0;
				if (pLineA->version==0 || pLineA->pDict==NULL || pLineA->dictsize==0) 
				{
					dictptr=&pVM68k->memory[pVM68k->a[0]&0xffff];	// TODO: version 0. 
				} else {
					dictptr=&pLineA->pDict[pVM68k->a[0]&0xffff];
				}
				inputptr=&pVM68k->memory[pVM68k->a[1]&0xffff];
				n=(pVM68k->d[0])&0xffff;
				for (i=0;i<n;i++)
				{
					tVM68k_ubyte cdebug;
					do
					{
						cdebug=dictptr[dictidx++];
					}
					while (!(cdebug&0x80));	// in the dictionary, the end marker is bit 7 being set.
					do
					{
						cdebug=inputptr[inputidx++];
					}
					while (cdebug!=0x00);	// search for the end of the input.
				}
				pVM68k->d[0]&=0xffff0000;	// d0 was used as a counter
				pVM68k->a[0]+=dictidx;
				pVM68k->a[1]+=inputidx;
			}
			break;
		case 0xa0fd: 
				pLineA->properties_offset=pVM68k->a[0];
				if (pLineA->version!=0)
				{
					// version 1 introduced line F instructions
					pLineA->linef_subroutine=(pVM68k->a[3]&0xffff);
					if (pLineA->version>1)
					{
						// version 2 instruduced programmable instructions
						pLineA->linef_tab=(pVM68k->a[5])&0xffff;
						pLineA->linef_tabsize=(pVM68k->d[7]+1)&0xffff;
					}
					if (pLineA->version>2)
					{
						pLineA->properties_tab=(pVM68k->a[6])&0xffff;
						pLineA->properties_size=(pVM68k->d[6]);
					}
				}
				break;
		case 0xa0fe: 
				{
					// register D0 conatins an object number. calculate the address in memory
					tVM68k_sword objectnum;
					tVM68k_ulong objectidx;

					if (pLineA->version>2 && (pVM68k->d[0]&0x3fff)>pLineA->properties_size)
					{
						pVM68k->d[0]&=0xffff7fff;
//						objectidx=((pLineA->properties_size-(pVM68k->d[0]&0x3fff))^0xffff);	// TODO: I THINK THIS IS JUST A MODULO!!!
						objectidx=((pVM68k->d[0]&0x3fff)-pLineA->properties_size)-1;
						objectnum=READ_INT16BE(pVM68k->memory,pLineA->properties_tab+objectidx*2);
					} else {
						if (pLineA->version>=2) 
						{
							pVM68k->d[0]&=0xffff7fff;
						}
						else 
						{
							pVM68k->d[0]&=0x00007fff;
						}
						objectnum=pVM68k->d[0]&0x7fff;

					}
					objectnum&=0x3fff;
					pVM68k->a[0]=pLineA->properties_offset+objectnum*14;
				}
				break;
			case 0xa0ff:
				{
					// so, here's what i know: (version 0)
					// the dictonary is stored at A3. 
					// the word entered at A6
					// there is a "bank" in register D6
					//
					// the data structure is more or less plain. but the last char of each word has bit 7 set. 
					// special characters 0x81=ENDOFDICT 0x82=BANKSEPARATOR are used.
					//
					// input: (A6)
					// output: (A2)
					// dict: (A3)
					// objects: (A1)

					{
						tVM68k_ubyte* dtabptr;
						tVM68k_ubyte* inputptr;
						tVM68k_ubyte* outputptr;
						tVM68k_ubyte* dictptr;
						tVM68k_ubyte* objectptr;
						tVM68k_ubyte* adjptr;

						tVM68k_uword	inputidx;
						tVM68k_uword	outputidx;
						tVM68k_uword	outputidx2;
						tVM68k_uword	dictidx;
						tVM68k_uword	adjidx;

						tVM68k_uword	wordidx;
						tVM68k_ubyte	bank;
						tVM68k_ubyte	flag;
						tVM68k_bool	matching;

						tVM68k_ubyte	cdict;
						tVM68k_bool	matchfound;
						tVM68k_ulong	wordmatch;
						tVM68k_uword	longestmatch;

						tVM68k_ubyte	flag2;

						int i,j;
						longestmatch=0;
						flag2=0;

						inputptr  =&pVM68k->memory[pVM68k->a[6]];
						if (pLineA->version==0 || pLineA->pDict==NULL || pLineA->dictsize==0) 
						{
							dictptr=&pVM68k->memory[pVM68k->a[3]&0xffff];
							dtabptr=&pVM68k->memory[pVM68k->a[5]&0xffff];	// version>0
						} else {
							dictptr=&pLineA->pDict[pVM68k->a[3]&0xffff];
							dtabptr=&pLineA->pDict[pVM68k->a[5]&0xffff];	// version>0

						}
						outputptr =&pVM68k->memory[pVM68k->a[2]];
						objectptr =&pVM68k->memory[pVM68k->a[1]];
						adjptr    =&pVM68k->memory[pVM68k->a[0]];
						inputidx=dictidx=outputidx=0;
						pVM68k->d[0]&=0xffff0000;		// this regsiter was used during the adjective search.
						pVM68k->d[1]&=0xffff0000;		// this regsiter was used during the adjective search.

						flag=0;
						bank=(pVM68k->d[6]&0xff);
						wordidx=0;
						cdict=0;
						matching=1;
						matchfound=0;
						pVM68k->d[0]&=0xffff0000;
						// the way the first loop works is this:
						// character by character, a word from the dictionary is compared to the input.
						// when a mismatch happens, the beginning of the next word is searched. -> matching=0;
						// 
						while (cdict!=0x81)	// 0x81 is the end marker of the dictionary
						{
							cdict=dictptr[dictidx++];
							if (cdict==0x82)	// bank separator
							{
								flag=0;
								inputidx=0;
								wordidx=0;
								bank++;
								matching=1;
							} else if (matching) {	// actively comparing
								tVM68k_ubyte	cinput1,cinput2;
								cinput1=inputptr[inputidx++];	// the current character
								cinput2=inputptr[inputidx];	// and the next onea
								if (pLineA->version!=0)
								{
									if (cdict==0x5f && (cinput2!=0 || cinput1==' '))
									{
										flag=0x80;	// the dictionary uses _ to signal objects that consist of longer words. "can of worms" thus becomes "can_of_worms". the matcher has to find it.
										cinput1='_';	// replace the space from the input with an _ to see if there is a match.
									}

								}
								if (cdict&0x80)	// the end of an entry in the dictionary is marked by bit 7 being set.
								{
									matchfound=0;
									if ((cinput1&0x5f)==(cdict&0x5f)) 	// still a match. wonderful.
									{
										if (cinput2==0x27)	// rabbit's (Wonderland)
										{
											tVM68k_ubyte cinput3;
											inputidx++;
											cinput3=inputptr[inputidx];	// store the letter after the ' into register D0. for example: rabbit's -> store the S
											pVM68k->d[0]&=0xffff0000;
											pVM68k->d[0]|=(cinput3)&0xff;
											pVM68k->d[0]|=0x200;
										}
										if (cdict!=0xa0 || pLineA->version<4)		// corruption started using " " as word separator for multi-word objects
										{
											if (cinput2==0 || cinput2==0x20 || cinput2==0x27) matchfound=1;	// and the input word ends as well. perfect match.
										}
									} else {
										if (pLineA->version==0 && inputidx>7) matchfound=1;	// the first 7 characters matched. good enough.
										matching=0;
									}
								} else {	// keep comparing.
									if (pLineA->version!=0)	// version 1 introduced objects with multiple words.
									{
										if (cinput1==' ' && cdict==0x5f) // multiple word entry found
										{
											flag=1;
											cinput1=0x5f;	// multiple word entries are marked by a _ instead of a space. this one makes sure that the next if() will work.
										}
									}
									if ((cinput1&0x5f)!=(cdict&0x5f) 
										|| (cdict&0x5f)==0x00 	// FIXME
									)
									{
										if (cinput2==' ' && pLineA->version==0 && inputidx>=7) matchfound=1;	// the first 7 characters matched. good enough.
										matching=0;	// there was a mismatch.
									}
								}
							}
							if (matchfound)
							{
								// the matches are stored in the following format:
								// bit 31..24 are a flag, which is =0 in version 0.
								// bit 23..16 is the bank.
								// bit 15..0 contain the matched word number in the bank.
								wordmatch =(((tVM68k_ulong)flag)<<24);
								wordmatch|=(((tVM68k_ulong)bank)<<16);
								wordmatch|=((tVM68k_ulong)wordidx);
								if (inputidx>=longestmatch) longestmatch=inputidx;
								WRITE_INT32BE(outputptr,outputidx,wordmatch);	// store the candidates in the output location.
								outputidx+=4;	// length of the result: 4 bytes.
								matchfound=0;
							}
							if (cdict&0x80 && cdict!=0x82 && !(pLineA->version>4 && cdict==0xa0))	// when the end of the word is reached. bit 7 is set.
							{
								wordidx++;
								matching=1;	// start over
								inputidx=0;	// start over.
								flag=0;
							}
						}

						WRITE_INT16BE(outputptr,outputidx,0xffff);// the end marker in the buffer is a 0xffff.
						// the output buffer holds outputidx/4 many results.
						if (pLineA->version!=0)	// version 1 introduced synonyms.
						{
							// search the list of output words
							for (i=0;i<outputidx;i+=4)
							{
								wordmatch=READ_INT32BE(outputptr,i);
								flag=(wordmatch>>24)&0xff;
								bank=(wordmatch>>16)&0xff;
								wordidx=wordmatch&0xffff;
								if (bank==0x0b)
								{
									tVM68k_uword substword;
									substword=READ_INT16BE(dtabptr,wordidx*2);		// TODO: version >1???

									// the lower 5 bits are the bank.
									// the upper 11 bits in the substitute database are the actual word index.
									bank=substword&0x1f;
									wordidx=substword>>5;
									wordmatch=flag;wordmatch<<=8;
									wordmatch|=(bank&0xff);wordmatch<<=16;
									wordmatch|=wordidx&0xffff;
									WRITE_INT32BE(outputptr,i,wordmatch);

								}

							} 
						}

						outputidx2=0;
						adjidx=0;
						for (i=0;i<outputidx;i+=4)
						{
							tVM68k_uword	objectidx;
							tVM68k_uword	adjidx_base;
							tVM68k_uword	obj;
							tVM68k_bool	mismatch;
							wordmatch=READ_INT32BE(outputptr,i);
							objectidx=0;
							flag=(wordmatch>>24)&0xff;
							bank=(wordmatch>>16)&0xff;
							wordidx=wordmatch&0xffff;

							mismatch=0;
							obj=READ_INT16BE(objectptr,objectidx);
							if (obj && bank==6)
							{
								// first step: skip the adjectives that are not meant for this word. each adjective list is separated by a 0.
								for (j=0;j<wordidx;j++)
								{
									do
									{
										cdict=READ_INT8BE(adjptr,adjidx++);
									} while (cdict!=0);
								}
								adjidx_base=adjidx;	// remeber the beginning of the list of adjectives for this word.

/*
								match=1;
								while (!match && obj)
								{
									adjidx=adjidx_base;
									obj=READ_INT16BE(objectptr,objectidx);
									cinput1=(obj&0xff);	// given adjective
									if (obj)
									{
										objectidx+=2;
										do	// see if it matches any of the legal adjectives.
										{
											cdict=READ_INT8BE(adjptr,adjidx++);
											printf("MATCHER: c:%02X c2:%02X\n",cdict,cinput1);
											if ((cinput1+3)==cdict) {match=1;printf("MATCH!\n");}
										} while (!match && cdict);
									}
								}
								*/
								do
								{
									tVM68k_ubyte cinput2;
									adjidx=adjidx_base;
									cinput2=READ_INT8BE(objectptr,objectidx+1);
									obj=READ_INT16BE(objectptr,objectidx);
									if (obj)
									{
										objectidx+=2;
										do
										{
											cdict=READ_INT8BE(adjptr,adjidx++);
											//printf("MATCHER: c:%02X c2:%02X\n",cdict,cinput2);
										} while (cdict && ((cdict-3)!=cinput2));
										//if ((cdict-3)==cinput2)	printf("MATCH!\n");
										if ((cdict-3)!=cinput2) mismatch=1;

									}
								}
								while (obj && !mismatch);
								adjidx=0;
							}

							pVM68k->d[1]&=0xffff0000;
							if (mismatch==0) 
							{
								flag2|=flag;
								wordmatch =flag2&0xff;wordmatch<<=8;
								wordmatch|=bank&0xff;wordmatch<<=16;
								wordmatch|=wordidx&0xffff;
								WRITE_INT32BE(outputptr,outputidx2,wordmatch);
								outputidx2+=4;
							} else {

								pVM68k->d[1]|=1;
							}
						}
						pVM68k->a[5]=pVM68k->a[6];
						// flag2 being set denotes that there has been an object that is occupying multiple words. 
						if (flag2 && outputidx)	// that match is probably a better one, so move it to the front of the output word list.
						{
							for (i=0;i<outputidx && flag2;i+=4)
							{

								wordmatch=READ_INT32BE(outputptr,i);	// find the wordmatch with the flag set.
								if (wordmatch&0x80000000)
								{
									wordmatch&=0x7fffffff;
									WRITE_INT32BE(outputptr,0,wordmatch);	// move it to the front.
									flag2=0;
								}
							}
							outputidx2=4;
							if (longestmatch)
							{
								pVM68k->a[5]=pVM68k->a[6]+(longestmatch-3);
							}

						}
						pVM68k->a[2]+=outputidx2;
//						pVM68k->d[0]=0;
						pVM68k->a[6]=pVM68k->a[5]+1;

					}
				}
				break;
		default:
				printf("\n \x1b[0;37;44mUNIMPLEMENTED LINEA opcode %04X\x1b[0m\n",opcode);
				break;
	}

	return retval;
}

int lineA_setCBnewOutput(void* hLineA,cbLineANewOutput pCB,void* context)
{
	tLineA* pLineA=(tLineA*)hLineA;
	if (pLineA==NULL) return LINEA_NOK_INVALID_PTR;
	if (pLineA->magic!=MAGICVALUE) return LINEA_NOK_INVALID_PARAM;

	pLineA->pcbNewOutput=pCB;
	pLineA->contextNewOutput=context;

	return LINEA_OK;

}
int lineA_setCBinputString(void* hLineA,cbLineAInputString pCB,void* context)
{
	tLineA* pLineA=(tLineA*)hLineA;
	if (pLineA==NULL) return LINEA_NOK_INVALID_PTR;
	if (pLineA->magic!=MAGICVALUE) return LINEA_NOK_INVALID_PARAM;

	pLineA->pcbInputString=pCB;
	pLineA->contextInputString=context;

	return LINEA_OK;

}


int lineA_setCBdrawPicture(void* hLineA,cbLineADrawPicture pCB,void* context,tdMagneticPicture *pPicture)
{
	tLineA* pLineA=(tLineA*)hLineA;
	if (pLineA==NULL) return LINEA_NOK_INVALID_PTR;
	if (pLineA->magic!=MAGICVALUE) return LINEA_NOK_INVALID_PARAM;

	pLineA->pcbDrawPicture=pCB;
	pLineA->contextDrawPicture=context;
	pLineA->pPicture=pPicture;

	return LINEA_OK;

}

int lineA_setCBloadGame(void* hLineA,cbLineALoadGame pCB,void* context)
{
	tLineA* pLineA=(tLineA*)hLineA;
	if (pLineA==NULL) return LINEA_NOK_INVALID_PTR;
	if (pLineA->magic!=MAGICVALUE) return LINEA_NOK_INVALID_PARAM;

	pLineA->pcbLoadGame=pCB;
	pLineA->contextLoadGame=context;

	return LINEA_OK;

}

int lineA_setCBsaveGame(void* hLineA,cbLineASaveGame pCB,void* context)
{
	tLineA* pLineA=(tLineA*)hLineA;
	if (pLineA==NULL) return LINEA_NOK_INVALID_PTR;
	if (pLineA->magic!=MAGICVALUE) return LINEA_NOK_INVALID_PARAM;

	pLineA->pcbSaveGame=pCB;
	pLineA->contextSaveGame=context;

	return LINEA_OK;

}


