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

// the purpose of this file is to read the D64 disk image files
// and to translate them into the .mag/.gfx format.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "loader_appleii.h"
#include "loader_common.h"
#include "configuration.h"
#include "vm68k_macros.h"

#define	PREAMBLE_SIZE	3
#define	EPILOGUE_SIZE	3
#define	ADDRBUF_SIZE	8
#define	DATABUF_SIZE	343

#define	MAXDISKS	3
#define	MAXTRACKS	35
#define	MAXSECTORS	16
#define	SECTORBYTES	256
#define	DSKTRACKSIZE	(MAXSECTORS*SECTORBYTES)
#define	DSKSIZE		(MAXTRACKS*MAXSECTORS*SECTORBYTES)
#define	NIBTRACKSIZE	(MAXSECTORS*416)	// TODO: why 416?



#define	GAME_PAWN	0
#define	GAME_GUILD	1
#define	GAME_JINXTER	2
#define	GAME_CORRUPTION	3
#define	MAXPICTURES	32




#define	WOZ_MAXQUARTERTRACKS	(4*MAXTRACKS)		// TODO: not sure what to do with this...
#define	WOZ_BLOCKSIZE		512			// the woz format has been designed to work on SD cards. So blocks are aligned to 512 to speed up processing


// the most important information, parsed from the WOZ header
typedef struct _tWozInfo
{
	int quarterTrack[WOZ_MAXQUARTERTRACKS];	// TODO: not sure what to do with this...
	int trackStart[WOZ_MAXQUARTERTRACKS];	// the block offset within the WOZ file
	int trackBits[WOZ_MAXQUARTERTRACKS];	// the number of bits for a track
	unsigned int crc32_expected;
} tWozInfo;


int loader_appleii_woz_parseheader(unsigned char* pWozBuf,int wozsize,tWozInfo *pWozInfo)
{
	int idx;
	int len;
	unsigned char donemask;
	idx=0;
	donemask=0;
	while (idx<wozsize && donemask!=3)
	{
		if (memcmp(&pWozBuf[idx],"WOZ2",4)==0)
		{
			if (pWozBuf[idx+4]!=0xff || pWozBuf[idx+5]!=0xa || pWozBuf[idx+6]!=0xd || pWozBuf[idx+7]!=0xa)
			{
				fprintf(stderr,"       WOZ2 eader corruption? Expected FF 0A 0D 0A, got %02X %02X %02X %02X \n",pWozBuf[idx+4],pWozBuf[idx+5],pWozBuf[idx+6],pWozBuf[idx+7]);
				return -1;
			}
			pWozInfo->crc32_expected=READ_INT32BE(pWozBuf,idx+8);
			idx+=12;
		}
		else if (memcmp(&pWozBuf[idx],"INFO",4)==0)
		{
			len=READ_INT32LE(pWozBuf,idx+4);
			idx+=8;
			// skip the info chunk
			idx+=len;
		}
		else if (memcmp(&pWozBuf[idx],"TMAP",4)==0)
		{
			int i;
			len=READ_INT32LE(pWozBuf,idx+4);
			idx+=8;
			for (i=0;i<WOZ_MAXQUARTERTRACKS;i++)
			{
				unsigned char x;
				x=pWozBuf[idx+i];
				if (x>=0 && x<MAXTRACKS)
				{
					pWozInfo->quarterTrack[i]=x;
				}
			}
			idx+=len;
			donemask|=1;
		}
		else if (memcmp(&pWozBuf[idx],"TRKS",4)==0)
		{
			int i;
			int idx2;
			len=READ_INT32LE(pWozBuf,idx+4);
			idx+=8;
			idx2=idx;
			for (i=0;i<WOZ_MAXQUARTERTRACKS;i++)
			{
				pWozInfo->trackStart[i]=WOZ_BLOCKSIZE*READ_INT16LE(pWozBuf,idx2);idx2+=2;
				idx2+=2;		//skip the block count
				pWozInfo->trackBits[i]=READ_INT32LE(pWozBuf,idx2);idx2+=4;
			}
			idx+=len;
			donemask|=2;

		}
		else if (memcmp(&pWozBuf[idx],"META",4)==0)
		{
			len=READ_INT32LE(pWozBuf,idx+4);
			idx+=8;
			// skip the info chunk
			idx+=len;
		}
		else 
		{
			fprintf(stderr,"Unknown Tag in WOZ2 detected %02X %02X %02X %02X\n",pWozBuf[idx+0],pWozBuf[idx+1],pWozBuf[idx+2],pWozBuf[idx+3]);
			return -1;
		}
	}
	if (donemask!=3)
	{
		fprintf(stderr," Error parsing the WOZ header\n");
		return -1;
	}
	return 0;
}
// when the woz bit stream is synchronized, it can be interpreted as a nib stream.
int loader_appleii_woz_synchronize(unsigned char* trackbuf,unsigned char* wozbuf,int len)
{
	unsigned char byte;
	unsigned int reg;
	int addrcnt;
	int datacnt;
	int part_cnt;
	int outidx;
	int i;



	reg=0;
	byte=0;
	addrcnt=0;
	datacnt=0;
	part_cnt=0;
	outidx=0;
	for (i=0;i<NIBTRACKSIZE;i++) trackbuf[i]=0xff;	// initialize
	while (outidx<NIBTRACKSIZE && i<(len*2) && (part_cnt!=0 || addrcnt!=MAXSECTORS || datacnt!=MAXSECTORS))
	{
		int wozbyte;
		int wozbit;
		int bit;

		wozbyte=(i%len)/8;
		wozbit=(i%len)%8;
		bit=(wozbuf[wozbyte]>>(7-wozbit))&1;
		byte<<=1;
		byte|=bit;
		if (byte&0x80)	// byte is synchronized when the highest bit is set.
		{
			reg<<=8;
			reg|=((unsigned int)byte)&0xff;
			reg&=0x00ffffff;
			if (part_cnt==0)
			{
				if (reg==0xD5AA96)	// addr preamble found
				{
					addrcnt++;
					trackbuf[outidx++]=0xD5;		// write the preamble
					trackbuf[outidx++]=0xAA;
					trackbuf[outidx++]=0x96;
					part_cnt=ADDRBUF_SIZE+EPILOGUE_SIZE;	// collect 11 bytes 
				}
				if (reg==0xD5AAAD)	// data preamble found
				{
					datacnt++;
					trackbuf[outidx++]=0xD5;		// write the preamble
					trackbuf[outidx++]=0xAA;
					trackbuf[outidx++]=0xAD;
					part_cnt=DATABUF_SIZE+EPILOGUE_SIZE;	// collect 346 bytes
				}
			} else {
				trackbuf[outidx++]=byte;
				part_cnt--;
			}
			byte=0;
		}
		i++;
	}
	// at this point, the trackbuf contains the NIB stream, even though there is no padding between the sectors.
	// the nib decoder will be able to handle it, even though a physical drive might not be able to.
	return 0;
}

int loader_appleii_decode_addrbuf(unsigned char* pAddrBuf,unsigned char* volume,unsigned char* track,unsigned char* sector,unsigned char* checksum)
{
	const unsigned char loader_appleii_deinterleave[16]={ 0x0,0x7,0xe,0x6,0xd,0x5,0xc,0x4,0xb,0x3,0xa,0x2,0x9,0x1,0x8,0xf };
	int ridx;
	unsigned char x;
	unsigned char check;
	ridx=0;
	check=0;
#define	ROL(x)	((((x)&0x80)>>7|(x)<<1)&0xff)
	x=pAddrBuf[ridx++];x=ROL(x);x&=pAddrBuf[ridx++];*volume=x;check^=x;
	x=pAddrBuf[ridx++];x=ROL(x);x&=pAddrBuf[ridx++];*track=x;check^=x;
	x=pAddrBuf[ridx++];x=ROL(x);x&=pAddrBuf[ridx++];*sector=loader_appleii_deinterleave[x&0xf];check^=x;
	x=pAddrBuf[ridx++];x=ROL(x);x&=pAddrBuf[ridx++];*checksum=x;check^=x;
	if (check)
	{
		fprintf(stderr,"Warning. Checksum mismatch\n");
	}
	return check;
}

int loader_appleii_decodenibtrack(unsigned char* pTrackBuf,int track,unsigned char* pDskBuf)
{
#define	PREAMBLESIZE	3
#define	DECODEROFFS	0x96
#define	SECTORLSB	86
	const	unsigned char loader_appleii_addr_preamble[PREAMBLESIZE]={0xD5,0xAA,0x96};
	const	unsigned char loader_appleii_data_preamble[PREAMBLESIZE]={0xD5,0xAA,0xAD};
	//const	unsigned char loader_appleii_epilog[PREAMBLESIZE]={0xDE,0xAA,0xEB};

	const	unsigned char loader_appleii_translatetab[106]={
		0x00,0x01,0xFF,0xFF,0x02,0x03,0xFF,0x04,
		0x05,0x06,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
		0x07,0x08,0xFF,0xFF,0xFF,0x09,0x0A,0x0B,
		0x0C,0x0D,0xFF,0xFF,0x0E,0x0F,0x10,0x11,
		0x12,0x13,0xFF,0x14,0x15,0x16,0x17,0x18,
		0x19,0x1A,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
		0xFF,0xFF,0xFF,0xFF,0xFF,0x1B,0xFF,0x1C,
		0x1D,0x1E,0xFF,0xFF,0xFF,0x1F,0xFF,0xFF,
		0x20,0x21,0xFF,0x22,0x23,0x24,0x25,0x26,
		0x27,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x29,
		0x2A,0x2B,0xFF,0x2C,0x2D,0x2E,0x2F,0x30,
		0x31,0x32,0xFF,0xFF,0x33,0x34,0x35,0x36,
		0x37,0x38,0xFF,0x39,0x3A,0x3B,0x3C,0x3D,
		0x3E,0x3F};


	unsigned char addr_track=0;
	unsigned char addr_sector=0;
	unsigned char addr_volume=0;
	unsigned char addr_checksum=0;
	int volumeid;
	int ridx;
	int state;

	volumeid=-1;
	ridx=0;
	state=0;
	while (ridx<(NIBTRACKSIZE+SECTORBYTES+SECTORLSB+1+9*PREAMBLESIZE))
	{
		switch(state)
		{
			case 0:		// find the ADDR preamble
				{
					if ( pTrackBuf[(ridx+0)%NIBTRACKSIZE]==loader_appleii_addr_preamble[0] && pTrackBuf[(ridx+1)%NIBTRACKSIZE]==loader_appleii_addr_preamble[1] && pTrackBuf[(ridx+2)%NIBTRACKSIZE]==loader_appleii_addr_preamble[2])
					{
						ridx+=PREAMBLE_SIZE;
						state=1;
					} else ridx++;
				}
				break;
			case 1:		// decode the ADDR data
				{
					unsigned char addrbuf[ADDRBUF_SIZE];
					int i;
					for (i=0;i<ADDRBUF_SIZE;i++)
					{
						addrbuf[i]=pTrackBuf[(ridx++)%NIBTRACKSIZE];
					}
					loader_appleii_decode_addrbuf(addrbuf,&addr_volume,&addr_track,&addr_sector,&addr_checksum);
					if (volumeid==-1 || volumeid==addr_volume)
					{
						volumeid=addr_volume;
					} else {
						printf("volumeid mismatch\n");
						return -1;
					}
					if (addr_track!=track)
					{
						printf("track mismatch %d vs %d\n",addr_track,track);
						return -1;
					}
					ridx+=PREAMBLESIZE;	// skip over the epilogue
					state=2;	// start looking for data
				}
				break;
			case 2:		// find the DATA preamble
				{
					if ( pTrackBuf[(ridx+0)%NIBTRACKSIZE]==loader_appleii_data_preamble[0] && pTrackBuf[(ridx+1)%NIBTRACKSIZE]==loader_appleii_data_preamble[1] && pTrackBuf[(ridx+2)%NIBTRACKSIZE]==loader_appleii_data_preamble[2])
					{
						ridx+=PREAMBLE_SIZE;
						state=3;
					} else ridx++;
				}
				break;
			case 3:		// decode the DATA
				{
					unsigned char lsbbuf[SECTORLSB];
					unsigned char accu;
					int j;
					accu=0;
					for (j=0;j<SECTORLSB;j++)
					{
						accu^=loader_appleii_translatetab[pTrackBuf[ridx%NIBTRACKSIZE]-DECODEROFFS];
						lsbbuf[j]=accu;
						ridx++;
					}
					for (j=0;j<SECTORBYTES;j++)
					{
						int widx;
						accu^=loader_appleii_translatetab[pTrackBuf[ridx%NIBTRACKSIZE]-DECODEROFFS];
						widx=j+SECTORBYTES*addr_sector;
						pDskBuf[widx]=accu;
						pDskBuf[widx]<<=1;pDskBuf[widx]|=(1&lsbbuf[j%SECTORLSB]);lsbbuf[j%SECTORLSB]>>=1;
						pDskBuf[widx]<<=1;pDskBuf[widx]|=(1&lsbbuf[j%SECTORLSB]);lsbbuf[j%SECTORLSB]>>=1;
						ridx++;
					}
					ridx+=PREAMBLESIZE;	// skip over the epilogue
					state=0;		// search for the next ADDR preamble
				}
				break;
		}

	}
	return volumeid;
}

int loader_appleii_mkgfx(unsigned char *gfxbuf,int* gfxsize,int gameid,int diskcnt,int *pDskOffs)
{
#define	PICTURE_HOTFIX1		0x80000000
#define	PICTURE_HOTFIX2		0x40000000
#define	PICTURE_HOTFIX3		0x20000000
#define	PICTURENUM		26
#define	CODESECTIONS		5
#define	TOTALSECTIONS		(PICTURENUM+CODESECTIONS)

	unsigned int hotfix1=(1<<1)|(1<< 7);
	unsigned int hotfix2=(1<<2)|(1<<13);
	unsigned int hotfix3=(1<<16);

	if (gameid!=GAME_CORRUPTION)
	{
		*gfxsize=0;
		return 0;
	}
	if (diskcnt!=MAXDISKS)
	{
		fprintf(stderr,"wrong number of floppy disks\n");
		return -1;
	}
	*gfxsize=4+4*32+diskcnt*DSKSIZE;
	{
		unsigned char mask;
		unsigned char byte;
#define	UNHUFFSTART	0x00a00
#define	DIR_START	0x997
#define	DIR_END		0x9d5

		int outidx;
		int tracks[MAXPICTURES]={0};
		int sectors[MAXPICTURES]={0};
		int i;
		int cnt;
		int unhuffsize;
		unsigned char terminal;
		int treeoffs;
		int bitidx;
		int unhuffoffs;
		int treeidx=0;
		outidx=0;
		cnt=0;

		unhuffoffs=4+4*MAXPICTURES+pDskOffs[0]+UNHUFFSTART;
		terminal=0;
		unhuffsize=READ_INT16LE(gfxbuf,unhuffoffs);
		treeoffs=unhuffoffs+2;
		bitidx=treeoffs+16+16;
		treeidx=0;
		mask=0;
		byte=0;
		while (outidx<unhuffsize || mask)
		{
			unsigned char branch1,branch0;
			unsigned char branch;

			if (mask==0x00)
			{
				mask=0x80;
				byte=gfxbuf[bitidx++];
			}

			branch1=gfxbuf[treeoffs+ 0+treeidx];
			branch0=gfxbuf[treeoffs+16+treeidx];
			branch=(byte&mask)?branch1:branch0;
			mask>>=1;

			if (branch&0x80)
			{
				treeidx=branch&0xf;
			} else {
				treeidx=0;
				terminal<<=4;
				terminal|=(branch&0xf);
				terminal&=0xff;
				if (outidx>=(DIR_START*2) && outidx<=(DIR_END*2) && ((outidx&1)==1))
				{
					if (cnt<TOTALSECTIONS) tracks[cnt]=terminal;
					else {
						sectors[cnt-TOTALSECTIONS]=terminal;
					}
					cnt++;
				}
				outidx++;
			}
		}
		// read the locations of the pictures. skip over the code sections
		for (i=0;i<PICTURENUM;i++)
		{
			unsigned int offs;
			offs=4+MAXPICTURES*4;


			offs+=((tracks[i+CODESECTIONS]&0x1f)<<12);
			offs+=(sectors[i+CODESECTIONS]<<8);
			if (tracks[i+CODESECTIONS]&0x80) offs+=pDskOffs[2];		// picture is on disk 3
			else if (tracks[i+CODESECTIONS]&0x40) offs+=pDskOffs[1];	// picture is on disk 2
			else offs+=pDskOffs[0];						// picture is on disk 1

			if (hotfix1&1) offs|=PICTURE_HOTFIX1;
			if (hotfix2&1) offs|=PICTURE_HOTFIX2;
			if (hotfix3&1) offs|=PICTURE_HOTFIX3;
			hotfix1>>=1;
			hotfix2>>=1;
			hotfix3>>=1;
			WRITE_INT32BE(gfxbuf,4+i*4,offs);
		}

	}


	gfxbuf[0]='M';gfxbuf[1]='a';gfxbuf[2]='P';gfxbuf[3]='8';

	return 0;
}
typedef	 struct _tSection
{
	int track;
	int sector;
	int disk;
	int len;
	int scrambled;
	int rle;
} tSection;
int loader_appleii_readsection(unsigned char* pOut,tSection section,unsigned char* pDskBuf,int diskcnt,int* pDskOffs,int pivot)
{
	int idx;
	int outidx;
	int firstsector;
	int rle;
	int rlecutoff=DSKSIZE;
	unsigned char tmp[SECTORBYTES];
	unsigned char lc;
	int i;

	rle=section.rle;
	outidx=0;
	firstsector=1;
	idx=(section.track*MAXSECTORS+section.sector)*SECTORBYTES+pDskOffs[section.disk];
	lc=0xff;

	while (outidx<section.len)
	{
		int ridx;
		int removeendmarker;
		memcpy(tmp,&pDskBuf[idx],SECTORBYTES);
		idx+=SECTORBYTES;
		ridx=0;
		removeendmarker=0;
		if (section.scrambled)
		{
			loader_common_descramble(tmp,tmp,pivot,NULL,0);
			pivot=(pivot+1)%8;
			if (firstsector && rle)
			{
				rlecutoff=READ_INT16BE(tmp,0);
				ridx=2;
				firstsector=0;
			}
		}
		for (;ridx<SECTORBYTES;ridx++)
		{
			unsigned char c;
			int n;
			c=tmp[ridx];
			if (lc!=0 || !rle)
			{
				n=1;
				lc=c;
			} else {
				lc=c;
				n=c-1;
				c=0;
			}
			for (i=0;i<n;i++)
			{
				pOut[outidx++]=c;
			}
			rlecutoff--;
			if (rle && rlecutoff==0)
			{
				rle=0;
				removeendmarker=1;
			}
		}
		if (removeendmarker==1)
		{
			outidx-=4;	// remove the last 4 bytes
		}
	}
	if (outidx>section.len) outidx=section.len;

	return outidx;
}
int loader_appleii_mkmag(unsigned char* magbuf,int* magsize,int gameid,unsigned char* pDskBuf,int diskcnt,int* pDskOffs)
{
	int magidx;
	int codesize;
	int stringidx0;
	int string1size;
	int string2size;
	int dictsize;
	int huffmantreeidx;
	int i;
	typedef	 struct _tGameInfo
	{
		int name_track;
		int name_sector;
		tSection code_section;
		tSection code2_section;
		int pivot_code2;
		tSection string1_section;
		tSection string2_section;
		tSection dict_section;
		int version;
		char gamename[21];
	} tGameInfo;

	const tGameInfo loader_appleii_gameInfo[4]={
		{.gamename="The Pawn",
			.version=0,
			.name_track=0x01,
			.name_sector=0x0, 
			.code_section	={.track=0x04,.sector=0x0,.disk= 0,.len=65536,.scrambled=1,.rle=0},
			.code2_section	={.track=  -1,.sector= -1,.disk=-1,.len=   -1,.scrambled=0,.rle=0},
			.pivot_code2=-1,
			.string1_section={.track=0x12,.sector=0x0,.disk= 0,.len=49152,.scrambled=0,.rle=0},
			.string2_section={.track=0x1e,.sector=0x0,.disk= 0,.len= 2816,.scrambled=0,.rle=0},
			.dict_section	={.track=  -1,.sector= -1,.disk=-1,.len=    0,.scrambled=0,.rle=0}
		},
		{.gamename="The Guild of Thieves",
			.version=1,
			.name_track=0x00,
			.name_sector=0x9, 
			.code_section	={.track=0x03,.sector=0x9,.disk= 0,.len=65536,.scrambled=1,.rle=1},
			.code2_section	={.track=  -1,.sector= -1,.disk=-1,.len=   -1,.scrambled=0,.rle=0},
			.pivot_code2=-1,
			.string1_section={.track=0x12,.sector=0xb,.disk= 0,.len=61696,.scrambled=0,.rle=0},
			.string2_section={.track=0x21,.sector=0xc,.disk= 0,.len= 3584,.scrambled=0,.rle=0},
			.dict_section	={.track=  -1,.sector= -1,.disk=-1,.len=    0,.scrambled=0,.rle=0}
		},
		{.gamename="Jinxter",
			.version=2,
			.name_track=0x00,
			.name_sector=0x9, 
			.code_section	={.track=0x08,.sector=0x2,.disk= 0,.len=13056,.scrambled=1,.rle=1},
			.code2_section	={.track=0x00,.sector=0x0,.disk= 1,.len=52480,.scrambled=1,.rle=0},
			.pivot_code2=7,
			.string1_section={.track=0x0c,.sector=0xc,.disk= 1,.len= 57344,.scrambled=0,.rle=0},
			.string2_section={.track=0x1a,.sector=0xc,.disk= 1,.len= 24832,.scrambled=0,.rle=0},
			.dict_section	={.track=0x06,.sector=0x0,.disk= 0,.len=  8704,.scrambled=1,.rle=0}
		},
		{.gamename="Corruption",
			.version=3,
			.name_track=0x00,
			.name_sector=0x9, 
			.code_section	={.track=0x04,.sector=0x0,.disk= 0,.len=16896,.scrambled=1,.rle=0},
			.code2_section	={.track=0x00,.sector=0x0,.disk= 1,.len=48640,.scrambled=1,.rle=0},
			.pivot_code2=2,
			.string1_section={.track=0x0b,.sector=0xe,.disk= 1,.len= 57344,.scrambled=0,.rle=0},
			.string2_section={.track=0x19,.sector=0xe,.disk= 1,.len= 37120,.scrambled=0,.rle=0},
			.dict_section	={.track=0x08,.sector=0x2,.disk= 0,.len=  7680,.scrambled=1,.rle=0}
		}
	};
	{
		int offs;
		int i;
		unsigned char c;
		printf("Detected '%s'\n",loader_appleii_gameInfo[gameid].gamename);
		offs=(loader_appleii_gameInfo[gameid].name_track*MAXSECTORS+loader_appleii_gameInfo[gameid].name_sector)*SECTORBYTES;
		offs+=3;
		i=0;
		c=0;
		printf("[");
		while (i<0x2c && c!=0xa9)
		{
			c=pDskBuf[pDskOffs[0]+offs];
			i++;
			offs++;
			if (c>=' ' && c<127) printf("%c",c);
		}
		printf("]\n");
	}

	magidx=42;
	codesize=loader_appleii_readsection(&magbuf[magidx],loader_appleii_gameInfo[gameid].code_section,pDskBuf,diskcnt,pDskOffs,0);
	codesize+=loader_appleii_readsection(&magbuf[magidx+codesize],loader_appleii_gameInfo[gameid].code2_section,pDskBuf,diskcnt,pDskOffs,loader_appleii_gameInfo[gameid].pivot_code2);
	magidx+=codesize;

	stringidx0=magidx;
	string1size=loader_appleii_readsection(&magbuf[magidx],loader_appleii_gameInfo[gameid].string1_section,pDskBuf,diskcnt,pDskOffs,0);
	magidx+=string1size;
	string2size=loader_appleii_readsection(&magbuf[magidx],loader_appleii_gameInfo[gameid].string2_section,pDskBuf,diskcnt,pDskOffs,0);
	magidx+=string2size;
	dictsize=loader_appleii_readsection(&magbuf[magidx],loader_appleii_gameInfo[gameid].dict_section,pDskBuf,diskcnt,pDskOffs,0);
	magidx+=dictsize;


	{
		int j;
		int matchcnt;
		huffmantreeidx=0;
		for (i=string1size;i<string1size+string2size-6 && huffmantreeidx==0;i++)
		{
			matchcnt=0;
			for (j=0;j<6;j++)
			{
				if (magbuf[stringidx0+i+j]==(j+1)) matchcnt++;
			}
			if (matchcnt>=4)
			{
				huffmantreeidx=i;
			}
		}
	}

	if (gameid==GAME_CORRUPTION) for (i=0x212a;i<0x232a;i++) magbuf[i]=0;	// finishing touches on corruption

	loader_common_addmagheader(magbuf,magidx,loader_appleii_gameInfo[gameid].version,codesize,string1size,string2size,dictsize,huffmantreeidx);
	*magsize=magidx;
	return 0;

}

int loader_appleii(char *appleiiname,
			char *magbuf,int* magsize,
			char *gfxbuf,int* gfxsize,
			int nodoc)
{
	unsigned char* pDskBuf;
	char filename[1024];
	unsigned char trackbuf[NIBTRACKSIZE]={0};
	int i,l;
	int j;
	int diskcnt;
	int volumeids[MAXDISKS]={0};
	int dskidx;
	int gameid;
	int diskoffs[MAXDISKS]={0};
	tWozInfo wozInfo;
	int retval;
	FILE *f;

#define	SIZE_NIBIMAGE	232960
#define	SIZE_2MGIMAGE	143424
#define	SIZE_DSKIMAGE	143360

	pDskBuf=(unsigned char*)&gfxbuf[4+MAXPICTURES*4];
	l=strlen(appleiiname);
	j=0;
	diskcnt=0;
	dskidx=0;
	for (i=0;i<l+1 && diskcnt<MAXDISKS;i++)
	{
		if (appleiiname[i]!=',') filename[j++]=appleiiname[i];
		filename[j]=0;

		if (appleiiname[i]==',' || appleiiname[i]==0)
		{
			int n;
			int filesize;
			f=fopen(filename,"rb");
			if (!f)
			{
				fprintf(stderr,"Unable to open [%s]\n",filename);
				return -1;
			}
			fseek(f,0L,SEEK_END);
			filesize=ftell(f);
			fseek(f,0L,SEEK_SET);
			n=0;
			if (filesize==SIZE_NIBIMAGE)
			{
				for (j=0;j<MAXTRACKS;j++)
				{
					n+=fread(trackbuf,sizeof(char),NIBTRACKSIZE,f);
					volumeids[diskcnt]=loader_appleii_decodenibtrack(trackbuf,j,&pDskBuf[dskidx]);
					dskidx+=MAXSECTORS*SECTORBYTES;
				}
			}
			else if (filesize==SIZE_2MGIMAGE)
			{
				n+=fread(&pDskBuf[dskidx],sizeof(char),0x40,f);	// read in the header. https://apple2.org.za/gswv/a2zine/Docs/DiskImage_2MG_Info.txt
				volumeids[diskcnt]=pDskBuf[dskidx+0x10];	// according to my observations, this is where the volume ID is
				n+=fread(&pDskBuf[dskidx],sizeof(char),DSKSIZE,f);
				dskidx+=DSKSIZE;
			}
			else
			{
				n+=fread(&pDskBuf[dskidx],sizeof(char),filesize,f);	// read in the full file. maybe it is a .WOZ?
				if (pDskBuf[dskidx+0]=='W' && pDskBuf[dskidx+1]=='O' && pDskBuf[dskidx+2]=='Z' && pDskBuf[dskidx+3]=='2')
				{

					int dskidx0;
					// the file is a .woz file, basically an unsynchronized .nib file with a header.
					// the idea is to synchronize the tracks and treat it as a NIB file.

					// first, the wo header needs to be parsed, to find the tracks within the diskfile
					if (loader_appleii_woz_parseheader(&pDskBuf[dskidx],filesize,&wozInfo))
					{
						return -1;
					}
					// at this point, the header information has been read. the tracks can be found, and the translation from WOZ to DSK can be written into the DskBuf (inplace)
					dskidx0=dskidx;
					for (j=0;j<MAXTRACKS;j++)
					{
						int start;
						int len;
						int quarterTrack;

						quarterTrack=j;//wozInfo.quarterTrack[j];
						start=wozInfo.trackStart[quarterTrack];
						len=wozInfo.trackBits[quarterTrack];

						if (start)
						{
							loader_appleii_woz_synchronize(trackbuf,&pDskBuf[dskidx0+start],len);
							volumeids[diskcnt]=loader_appleii_decodenibtrack(trackbuf,j,&pDskBuf[dskidx]);
						}
						dskidx+=MAXSECTORS*SECTORBYTES;
					}


				} else {
					fprintf(stderr,"Unexpected filesize %d bytes.\n",filesize);
					return -1;
				}
			}
			fclose(f);
			printf("read %d bytes from [%s]. Volume ID [%02X]\n",n,filename,volumeids[diskcnt]);
			diskcnt++;
			j=0;
		}
	}
	gameid=-1;

	for (i=0;i<diskcnt;i++)
	{
		int newgameid;
		int disknum;

		disknum=-1;
		switch(volumeids[i])
		{
			case 0x68:	newgameid=GAME_PAWN;		disknum=volumeids[i]-0x68;break;
			case 0x69:	newgameid=GAME_GUILD;		disknum=volumeids[i]-0x69;break;
			case 0x70:
			case 0x71:	newgameid=GAME_JINXTER;		disknum=volumeids[i]-0x70;break;
			case 0x72:
			case 0x73:
			case 0x74:	newgameid=GAME_CORRUPTION;	disknum=volumeids[i]-0x72;break;
			default:
					return disknum;
		}
		if (gameid==-1 || gameid==newgameid) gameid=newgameid;
		else {
			fprintf(stderr,"Game detection ambiguous\n");
			return -1;
		}
		if (disknum>=0 && disknum<MAXDISKS)
		{
			diskoffs[disknum]=i*DSKSIZE;
		}
	}
	if (gameid==-1)
	{
		fprintf(stderr,"Unable to detect the game\n");
		return -1;
	}


	retval=loader_appleii_mkmag((unsigned char*)magbuf,magsize,gameid,pDskBuf,diskcnt,diskoffs);	// since the memory for the gfx buffer includes the dskbuf, this is enough
	retval|=loader_appleii_mkgfx((unsigned char*)gfxbuf,gfxsize,gameid,diskcnt,diskoffs);	// since the memory for the gfx buffer includes the dskbuf, this is enough
	if (nodoc)
	{
		int i;
		unsigned char* ptr=(unsigned char*)&magbuf[0];
		for (i=0;i<*magsize-4;i++)
		{
			if (ptr[i+0]==0x62 && ptr[i+1]==0x02 && ptr[i+2]==0xa2 && ptr[i+3]==0x00) {ptr[i+0]=0x4e;ptr[i+1]=0x71;}
			if (ptr[i+0]==0xa4 && ptr[i+1]==0x06 && ptr[i+2]==0xaa && ptr[i+3]==0xdf) {ptr[i+0]=0x4e;ptr[i+1]=0x71;}
		}
	}
	return retval;
}


