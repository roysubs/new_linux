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
#include "loader_common.h"
#include "loader_atarixl.h"
#include "vm68k_macros.h"

#define	LOADER_ATARIXL_OK	0
#define	LOADER_ATARIXL_NOK -1

typedef struct _tGameInfo
{
	unsigned char name[22];
	unsigned char version;		// 0=The Pawn. 1=The Guild of Thieves. 2=Jinxter
	unsigned int offs_code1;	// the offset of the first code section
	unsigned int offs_code2;	// the offset to the second code section
	unsigned int offs_string1;	// the offset to the string1 section
	unsigned int offs_string2;	// the offset to the string2 section
	unsigned int offs_dict;		// the offset to the dict section

	unsigned int offs_pictures[30];	// the offset to the pictures within the .ATR files.
} tGameInfo;

#define	DISK_SIZE	133136
#define	DISK_OFFSETMASK	0x3ffff
#define	DISK1_FLAG	0x40000
#define	DISK2_FLAG	0x80000


// i was not able to find the proper directory. 
// but i was able to find the code/string/dict sections through correlations and other means.
// this is how the following table has been created.
#define GAMENUM			3
const tGameInfo	loader_atarixl_cGameInfo[GAMENUM]={
	{.name="The Pawn",
		.version=0,
		.offs_code1=0x3990|DISK1_FLAG,
		.offs_code2=0,
		.offs_string1=0x11310|DISK1_FLAG,
		.offs_string2=0x1c710|DISK1_FLAG,
		.offs_dict=0,
		.offs_pictures={
			DISK2_FLAG|0x00010,DISK2_FLAG|0x00a90,DISK2_FLAG|0x01a10,DISK2_FLAG|0x02410,
			DISK2_FLAG|0x1d190,DISK2_FLAG|0x03310,DISK2_FLAG|0x04110,DISK2_FLAG|0x04a10,
			DISK2_FLAG|0x05210,DISK2_FLAG|0x05890,DISK2_FLAG|0x1f910,DISK2_FLAG|0x06390,
			DISK2_FLAG|0x11310,DISK2_FLAG|0x11f10,DISK2_FLAG|0x12e90,DISK2_FLAG|0x13990,

			DISK2_FLAG|0x14190,DISK2_FLAG|0x14f90,DISK2_FLAG|0x15790,DISK2_FLAG|0x1ef10,
			DISK2_FLAG|0x06f90,DISK2_FLAG|0x16510,DISK2_FLAG|0x17010,DISK2_FLAG|0x1dd90,
			DISK2_FLAG|0x1e510,DISK2_FLAG|0x18010,DISK2_FLAG|0x18600,DISK2_FLAG|0x18f90,
			DISK2_FLAG|0x19e10,DISK2_FLAG|0x1a610
		}
	},
	{.name="The Guild Of Thieves",
		.version=1,
		.offs_code1=0x3890|DISK1_FLAG,
		.offs_code2=0x10|DISK2_FLAG,
		.offs_string1=0xc010|DISK2_FLAG,
		.offs_string2=0x1b110|DISK2_FLAG,
		.offs_dict=0,
		.offs_pictures={
			DISK1_FLAG|0x1b310,DISK1_FLAG|0x09690,DISK1_FLAG|0x14210,DISK2_FLAG|0x1be90,
			DISK1_FLAG|0x11d90,DISK1_FLAG|0x08990,DISK1_FLAG|0x10090,DISK1_FLAG|0x17490,
			DISK1_FLAG|0x11110,DISK1_FLAG|0x08190,DISK2_FLAG|0x1e010,DISK1_FLAG|0x0d610,
			DISK1_FLAG|0x0ed10,DISK1_FLAG|0x18490,DISK1_FLAG|0x1f710,DISK2_FLAG|0x1d190,

			DISK1_FLAG|0x0c690,DISK1_FLAG|0x0e010,DISK1_FLAG|0x1ea10,DISK1_FLAG|0x16c90,
			DISK1_FLAG|0x0aa10,DISK1_FLAG|0x15910,DISK1_FLAG|0x0cc10,DISK1_FLAG|0x09f90,
			DISK1_FLAG|0x0ba10,DISK1_FLAG|0x19210,DISK1_FLAG|0x1a810,DISK1_FLAG|0x12b90,
			DISK1_FLAG|0x14d90,0
		}
	},
	{.name="Jinxter",
		.version=2,
		.offs_code1=0x3790|DISK1_FLAG,
		.offs_code2=0x10|DISK2_FLAG,
		.offs_string1=0xc710|DISK2_FLAG,
		.offs_string2=0x1a710|DISK2_FLAG,
		.offs_dict=0x6490|DISK1_FLAG,
		.offs_pictures={
			DISK1_FLAG|0x08690,DISK1_FLAG|0x09990,DISK1_FLAG|0x0a690,DISK1_FLAG|0x0b390,
			DISK1_FLAG|0x0c490,                 0,                 0,DISK1_FLAG|0x0d840,
			DISK1_FLAG|0x0e690,                 0,DISK1_FLAG|0x0f210,DISK1_FLAG|0x10090,
			DISK1_FLAG|0x10f10,DISK1_FLAG|0x11d10,DISK1_FLAG|0x12c10,DISK1_FLAG|0x13910,

			DISK1_FLAG|0x14590,DISK1_FLAG|0x15290,DISK1_FLAG|0x15d10,                 0,
			DISK1_FLAG|0x16d90,DISK1_FLAG|0x17f90,DISK1_FLAG|0x18810,DISK1_FLAG|0x19590,
			DISK1_FLAG|0x1a410,DISK1_FLAG|0x1b910,DISK1_FLAG|0x1c510,                 0,
			DISK1_FLAG|0x1ce90, 0
		}
	}
};

#define	BLOCKSIZE	256
#define	MAXPIVOT	8
#define	GETIDX(idx,offset,disk1offs,disk2offs) \
		idx=(offset); \
		if ((idx)&DISK1_FLAG) idx=((idx)&DISK_OFFSETMASK)+(disk1offs); \
		if ((idx)&DISK2_FLAG) idx=((idx)&DISK_OFFSETMASK)+(disk2offs);

int loader_atarixl_detectgame(unsigned char* diskbuf,int* disk1offs,int* disk2offs)
{
	int d1,d2;
	int found;
	int i;
	unsigned char tmp[256];

	d1=*disk1offs;
	d2=*disk2offs;
	// the game code always starts with the same instruction 49FA FFFE. 
	// in each game release, this is at a different postion within the
	// floppy disks. this can be used to determine which game it is.
	// since the game code has been scrambled, it needs to be descrambled first.

	// first, assume that the first argument was also the first floppy disk
	found=-1;
	for (i=0;i<GAMENUM && found==-1;i++)
	{
		unsigned char lc;
		lc=0xff;
		loader_common_descramble(&diskbuf[d1+(DISK_OFFSETMASK&loader_atarixl_cGameInfo[i].offs_code1)],tmp,0,&lc,0);
		if (tmp[ 0]==0x49 && tmp[ 1]==0xfa && tmp[ 2]==0xff && tmp[ 3]==0xfe) found=i;
		if (tmp[2+ 0]==0x49 && tmp[2+ 1]==0xfa && tmp[2+ 2]==0xff && tmp[2+ 3]==0xfe) found=i;
	}
	if (found!=-1) return found;

	// if this failed, try to swap the disks
	*disk1offs=d2;
	*disk2offs=d1;
	for (i=0;i<GAMENUM;i++)
	{
		unsigned char lc;
		lc=0xff;
		loader_common_descramble(&diskbuf[d2+(DISK_OFFSETMASK&loader_atarixl_cGameInfo[i].offs_code1)],tmp,0,&lc,0);
		if (tmp[ 0]==0x49 && tmp[ 1]==0xfa && tmp[ 2]==0xff && tmp[ 3]==0xfe) found=i;
		if (tmp[2+ 0]==0x49 && tmp[2+ 1]==0xfa && tmp[2+ 2]==0xff && tmp[2+ 3]==0xfe) found=i;
	}
	return found;
}

int loader_atarixl_mkmag(unsigned char* diskbuf,int disksize,int disk1offs,int disk2offs,unsigned char* magbuf,int* magbufsize,const tGameInfo *pGameInfo)
{
	int magidx;
	int code1size;
	int code2size;
	int string1size;
	int string2size;
	int dictsize;
	int huffmantreeidx;



	magidx=42;

	code1size=0;
	code2size=0;
	{
		int idx;
		unsigned char lc;
		int n;
		int rle;
		int codeleft;
		int pivot;

		codeleft=0x10000-0x100;
		rle=0;
		if (pGameInfo->version!=0) 
		{
			magidx-=2;
			rle=1;
		}

		pivot=0;
		lc=0xff;
		GETIDX(idx,pGameInfo->offs_code1,disk1offs,disk2offs);
		n=loader_common_descramble(&diskbuf[idx],&magbuf[magidx],pivot,&lc,rle);
		if (pGameInfo->version!=0)
		{
			codeleft=READ_INT16BE(magbuf,magidx);
		}
		code1size+=n;
		idx+=BLOCKSIZE;
		magidx+=n;
		while (codeleft>=BLOCKSIZE)
		{
			pivot=(pivot+1)%MAXPIVOT;
			n=loader_common_descramble(&diskbuf[idx],&magbuf[magidx],pivot,&lc,rle);
			codeleft-=BLOCKSIZE;
			idx+=BLOCKSIZE;
			magidx+=n;
			code1size+=n;
		}
		if (codeleft!=0)
		{
			codeleft=0x100-codeleft;
			code1size-=(codeleft+2);
			magidx-=codeleft;
		}
		GETIDX(idx,pGameInfo->offs_code2,disk1offs,disk2offs);
		codeleft=0x10000-code1size;
		while (codeleft>0)
		{
			pivot=(pivot+1)%MAXPIVOT;
			n=loader_common_descramble(&diskbuf[idx],&magbuf[magidx],pivot,&lc,0);
			codeleft-=BLOCKSIZE;
			idx+=BLOCKSIZE;
			magidx+=n;
			code2size+=n;
		}
	}


	// the strings are not scrambled. they are being copied over from the disk buffer into the .mag buffer.
	string1size=0;
	string2size=0;
	{
		int idx1;
		int idx2;
		int nxtdisk;
		int magidx0;


		magidx0=magidx;
		GETIDX(idx1,pGameInfo->offs_string1,disk1offs,disk2offs);
		GETIDX(idx2,pGameInfo->offs_string2,disk1offs,disk2offs);
		nxtdisk=disksize;
		if (idx1<disk1offs) nxtdisk=disk1offs;
		if (idx1<disk2offs) nxtdisk=disk2offs;

		while (idx1<idx2 && idx1<nxtdisk)
		{
			magbuf[magidx++]=diskbuf[idx1++];
			string1size++;
		}
		// TODO: string2 is waaay too big.
		nxtdisk=disksize;
		if (idx2<disk1offs) nxtdisk=disk1offs;
		if (idx2<disk2offs) nxtdisk=disk2offs;
		while (idx2<nxtdisk)
		{
			magbuf[magidx++]=diskbuf[idx2++];
			string2size++;
		}
		if (pGameInfo->version==0)
		{
			huffmantreeidx=string1size;
		} else {
			int i;
			huffmantreeidx=0;
			// the huffman tree starts with the sequence 01 02 03 ?? 05.

			for (i=magidx0;i<magidx-3 && huffmantreeidx==0;i++)
			{
				if (magbuf[i+0]==0x01 && magbuf[i+1]==0x02 && magbuf[i+2]==0x03 && magbuf[i+4]==0x05)
				{
					huffmantreeidx=i-magidx0;
				}
			}
		}
		if (string1size>=0x10000)
		{
			int x;
			x=string1size+string2size;
			string1size=0x10000;
			string2size=x-string1size;
		}
	}


	dictsize=0;
	if (pGameInfo->offs_dict!=0)
	{
		int n;
		int idx;
		int pivot;
		unsigned char lc;
		GETIDX(idx,pGameInfo->offs_dict,disk1offs,disk2offs);
		pivot=0;
		while (dictsize<8704)	// TODO: magic number
		{
			lc=0xff;
			n=loader_common_descramble(&diskbuf[idx],&magbuf[magidx],pivot,&lc,0);

			magidx+=n;
			dictsize+=n;
			pivot=(pivot+1)%MAXPIVOT;
			idx+=BLOCKSIZE;
		}
	}
	loader_common_addmagheader(magbuf,magidx,pGameInfo->version,code1size+code2size,string1size,string2size,dictsize,huffmantreeidx);
	*magbufsize=magidx;


	return LOADER_ATARIXL_OK;
}
int loader_atarixl_mkgfx(unsigned char* gfxbuf,int *gfxbufsize,int disk1offs,int disk2offs,const tGameInfo* pGameInfo)
{
	int i;
	int idx;
	int gfxidx;

	// i am lazy
	// just translate the pre-determined offsets into the gfx buffer index
	gfxidx=0;

	gfxbuf[gfxidx++]='M';
	gfxbuf[gfxidx++]='a';
	gfxbuf[gfxidx++]='P';
	gfxbuf[gfxidx++]='7';
	for (i=0;i<30;i++)
	{
		GETIDX(idx,pGameInfo->offs_pictures[i],disk1offs,disk2offs);
		WRITE_INT32BE(gfxbuf,gfxidx,idx);gfxidx+=4;
	}
	// that's it

	return LOADER_ATARIXL_OK;
}
int loader_atarixl(char* atarixlname,
	char* magbuf,int* magbufsize,
	char* gfxbuf,int* gfxbufsize,
	int nodoc)
{
	int disk1offs;
	int disk2offs;
	int disksize;
	int detectedgame;
	FILE *f;
	char* diskfile1;
	char* diskfile2;
	int i;

	diskfile1=atarixlname;
	diskfile2=atarixlname;
	for (i=0;i<strlen(atarixlname);i++)
	{
		if (atarixlname[i]==',')
		{
			diskfile2=&atarixlname[i+1];
			atarixlname[i]=0;
		}
	}


	disk1offs=256;	// leave some room at the beginning for the directory
	disk2offs=0;


	f=fopen(diskfile1,"rb");
	if (!f)
	{
		printf("unable to open [%s]. sorry\n",diskfile1);
		return LOADER_ATARIXL_NOK;
	}
	disksize=fread(&gfxbuf[disk1offs],sizeof(char),*gfxbufsize-disk1offs,f);
	if (disksize!=DISK_SIZE)
	{
		printf("[%s] does not look like an .ATR image. Sorry\n",diskfile1);
		return LOADER_ATARIXL_NOK;
	}
	fclose(f);
	disk2offs=disk1offs+disksize;

	f=fopen(diskfile2,"rb");
	if (!f)
	{
		printf("unable to open [%s]. sorry\n",diskfile2);
		return LOADER_ATARIXL_NOK;
	}
	disksize=fread(&gfxbuf[disk2offs],sizeof(char),*gfxbufsize-disk2offs,f);
	fclose(f);
	if (disksize!=DISK_SIZE)
	{
		printf("[%s] does not look like an .ATR image. Sorry\n",diskfile2);
		return LOADER_ATARIXL_NOK;
	}
	*gfxbufsize=disksize+disk2offs;

	////////////////////
	detectedgame=loader_atarixl_detectgame((unsigned char*)gfxbuf,&disk1offs,&disk2offs);
	if (detectedgame==-1)
	{
		printf("unable to detect the game. Sorry!\n");
		return LOADER_ATARIXL_NOK;
	}
	printf("Detected [%s]\n",loader_atarixl_cGameInfo[detectedgame].name);


	////////////////////
	if (loader_atarixl_mkmag((unsigned char*)gfxbuf,*gfxbufsize,disk1offs,disk2offs,(unsigned char*)magbuf,magbufsize,&loader_atarixl_cGameInfo[detectedgame])!=LOADER_ATARIXL_OK)
	{
		return LOADER_ATARIXL_NOK;
	}

	if (loader_atarixl_mkgfx((unsigned char*)gfxbuf,gfxbufsize,disk1offs,disk2offs,&loader_atarixl_cGameInfo[detectedgame])!=LOADER_ATARIXL_OK)
	{
		return LOADER_ATARIXL_NOK;
	}
	if (nodoc)
	{
		int i;
		unsigned char* ptr=(unsigned char*)&magbuf[0];
		for (i=0;i<*magbufsize-4;i++)
		{
			if (ptr[i+0]==0x62 && ptr[i+1]==0x02 && ptr[i+2]==0xa2 && ptr[i+3]==0x00) {ptr[i+0]=0x4e;ptr[i+1]=0x71;}
			if (ptr[i+0]==0xa4 && ptr[i+1]==0x06 && ptr[i+2]==0xaa && ptr[i+3]==0xdf) {ptr[i+0]=0x4e;ptr[i+1]=0x71;}
		}
	}



	return LOADER_ATARIXL_OK;
}


