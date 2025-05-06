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

// the purpose of this file is to read the resource files from the
// Magnetic Windows releases, and transform them into the .mag/.gfx format.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "loader_common.h"
#include "loader_mw.h"
#include "configuration.h"
#include "vm68k_macros.h"

// the purpose of this function is to use the naming of the "???one.rsc" file as a blueprint.
int loader_mw_substituteTwoRsc(char* two_rsc,int num,char* output)
{
	int i;
	int l;
	int onestart;
	int uppercase;
	char *names[12]={"zero","one","two","three","four","five","six","seven","eight","nine","title.vga","title.ega"};

	l=strlen(two_rsc);
	onestart=-1;
	uppercase=0;
	for (i=0;i<l-4;i++)
	{
		if (two_rsc[i+0]=='t'  && two_rsc[i+1]=='w' && two_rsc[i+2]=='o' && two_rsc[i+3]=='.') {onestart=i;uppercase=0;}
		if (two_rsc[i+0]=='T'  && two_rsc[i+1]=='W' && two_rsc[i+2]=='O' && two_rsc[i+3]=='.') {onestart=i;uppercase=1;}
	}
	if (onestart==-1 || num>=12 || num<0) return 0;
	memcpy(output,two_rsc,strlen(two_rsc));
	memcpy(&output[onestart],&names[num][0],strlen(names[num])+1);
	if (uppercase)
	{
		for (i=0;i<strlen(names[num]);i++) if (output[onestart+i]!='.') output[onestart+i]&=0x5f;
	}
	if (num<10)
	{
		memcpy(&output[onestart+strlen(names[num])],&two_rsc[onestart+3],strlen(two_rsc)-onestart+4);
	}

	return 1;
}
// the purpose of this function is to determine the file sizes of each individual .rsc file.
int loader_mw_collectSizes(char* two_rsc,int* sizes,char* gfxbuf)
{
	int i;
	FILE *f;
	char filename[1024];
	int sum;
	sum=0;
	for (i=0;i<10;i++)
	{
		loader_mw_substituteTwoRsc(two_rsc,i,filename);
		f=fopen(filename,"rb");
		sizes[i]=0;
		if (f)
		{
			while (!feof(f))
			{
				sizes[i]+=fread(gfxbuf,sizeof(char),1024,f);
				sum+=sizes[i];
			}
			fclose(f);
		}
	}
	return sum;
}
// the purpose of this function is to read n bytes from the resource files.
int loader_mw_readresource(char* two_rsc,int* sizes,int offset,char* buf,int n)
{
	int i;
	int sum;
	int firstresource;
	int resoffs;
	int bidx;
	char filename[1024];
	sum=0;
	resoffs=0;
	firstresource=-1;
	for (i=0;i<10;i++)
	{
		if (sum<=offset)
		{
			resoffs=offset-sum;
			firstresource=i;
		}
		sum+=sizes[i];
	}
	if (firstresource==-1) return 0;
	bidx=0;
	// in case the resource is spread out over multiple .rsc files, loop
	while (bidx<n && firstresource<10)
	{
		FILE *f;
		loader_mw_substituteTwoRsc(two_rsc,firstresource,filename);

		f=fopen(filename,"rb");
		if (f)
		{
			fseek(f,resoffs,SEEK_SET);
			bidx+=fread(&buf[bidx],sizeof(char),n-bidx,f);
			fclose(f);
		}
		firstresource++;	// next iteration: the next file
		resoffs=0;	// in the next file, the continuation of the resource starts at the beginning.
	}
	return 1;
}
int loader_mw_mkgfx(char* two_rsc,int* sizes,char* gfxbuf,int* bytes)
{
	int diroffset;
	int direntries;
	int imagecnt;
	int outidx;
	int diridx;
	int i;
	int j;
	char tmpbuf[18];
#define	NAMELENGTH	6	// length of the "file" names in the resource file
#define	DIRENTRYSIZE	(NAMELENGTH+4+4)	// name=6 bytes. offset=4 bytes. length=4 bytes
#define	HEADERSIZE	(4+2)	// "MaP4"+2 bytes for the number of entries
#define	MARGIN		4	// a little bit of extra space
#define	MAXIMAGES	256	// actually 226, but who's counting..
	typedef struct _tImageEntry
	{
		char name[NAMELENGTH+1];
		int offset6;
		int offset7;
		int length6;
		int length7;
	} tImageEntry;
	int entrynum;
	int gfxsize0;
	gfxsize0=*bytes;
	tImageEntry	imageEntries[MAXIMAGES];

	memset(imageEntries,0,sizeof(imageEntries));
	entrynum=0;

	// step one: find the directory. it is stored in the very first 4 bytes.
	loader_mw_readresource(two_rsc,sizes,0,gfxbuf,4);
	diroffset=READ_INT32LE(gfxbuf,0);
	loader_mw_readresource(two_rsc,sizes,diroffset,gfxbuf,2);diroffset+=2;
	direntries=READ_INT16LE(gfxbuf,0);
	imagecnt=0;
	// step two: count the image files
	gfxbuf[0]='M';gfxbuf[1]='a';gfxbuf[2]='P';gfxbuf[3]='4';

	// go through all the directory entries.
	// collect the images.
	// 
	// images are spread out over two "files": type 7, which is the huffman tree. and type 6, which is the bitstream. both of them have the same name.
	for (i=0;i<direntries;i++)
	{
		//int unknown;
		char name[NAMELENGTH+1];
		int type;
		int offset;
		int length;

		loader_mw_readresource(two_rsc,sizes,diroffset,tmpbuf,18);diroffset+=18;
		//unknown=READ_INT16LE(tmpbuf,0);	// intentionally left in
		offset=READ_INT32LE(tmpbuf,2);
		length=READ_INT32LE(tmpbuf,6);
		for (j=0;j<NAMELENGTH;j++) name[j]=tmpbuf[10+j];
		name[NAMELENGTH]=0;
		type=READ_INT16LE(tmpbuf,16);
		if (type==6 || type==7)	// either the tree or an image
		{
			int found;
			// see if there is an entry with the same name, but the other half of the data
			found=-1;
			for (j=0;j<entrynum && found==-1;j++)
			{
				if (strncmp(name,imageEntries[j].name,NAMELENGTH+1)==0) found=j;
			}
			if (found==-1) found=entrynum++;	// the name has not been found before. create a new entry
			if (entrynum==(MAXIMAGES+1))		// too many image files found
			{
				fprintf(stderr,"Too many image files found.\n");
				return 0;
			}
			memcpy(imageEntries[found].name,name,NAMELENGTH+1);	// the name is the same. so it does not matter if it is being overwritten
			if (type==6)	// store the information regarding the image
			{
				imageEntries[found].offset6=offset;
				imageEntries[found].length6=length;
				imagecnt++;
			}
			if (type==7)	// store the tree
			{
				imageEntries[found].offset7=offset;
				imageEntries[found].length7=length;	// always 609 bytes
			}
		}
	}

	diridx=6;
	// copy the information from the resource file into the gfxbuf container. leave room for the title screens (if they are available
	outidx=(imagecnt+1+2)*(DIRENTRYSIZE)+HEADERSIZE+MARGIN;
	for (i=0;i<entrynum;i++)
	{
		//		int unknown;
		if (imageEntries[i].length7!=609 || imageEntries[i].length6==0) 
		{
			fprintf(stderr,"illegal resource file found.\n");
			return 0;
		}
		for (j=0;j<NAMELENGTH;j++) gfxbuf[diridx++]=imageEntries[i].name[j];
		WRITE_INT32LE(gfxbuf,diridx,outidx);diridx+=4;  // offset within the new mag file
		WRITE_INT32LE(gfxbuf,diridx,imageEntries[i].length7+imageEntries[i].length6);diridx+=4; // length within the new mag file
		// the size of the tree is fixed. Thus,it can be stored together with the bit stream 
		loader_mw_readresource(two_rsc,sizes,imageEntries[i].offset7,&gfxbuf[outidx],imageEntries[i].length7);outidx+=imageEntries[i].length7;      // first the tree (ALWAYS 609 bytes)
		loader_mw_readresource(two_rsc,sizes,imageEntries[i].offset6,&gfxbuf[outidx],imageEntries[i].length6);outidx+=imageEntries[i].length6;      // then the palette/size/width/height and bitstream
	}
	{
		char filename[1024];
		FILE *f;
		int i,j;
		int len;
		char *names[2]={"titlev","titlee"};
		for (i=0;i<2;i++)
		{
			loader_mw_substituteTwoRsc(two_rsc,i+10,filename);
			f=fopen(filename,"rb");
			if (f)
			{
				len=fread(&gfxbuf[outidx],sizeof(char),gfxsize0-outidx,f);
				fclose(f);
				for (j=0;j<NAMELENGTH;j++) gfxbuf[diridx++]=names[i][j];
				WRITE_INT32LE(gfxbuf,diridx,outidx);diridx+=4;  // offset within the new mag file
				WRITE_INT32LE(gfxbuf,diridx,len);diridx+=4; // length within the new mag file
				outidx+=len;
				imagecnt++;
			}
		}
	}

	// and the finishing touch
	WRITE_INT32LE(gfxbuf,diridx,0x23232323);//diridx+=MARGIN;
	WRITE_INT32LE(gfxbuf,outidx,0x42424242);outidx+=4;
	diridx=4;
	WRITE_INT16LE(gfxbuf,diridx,imagecnt);

	*bytes=outidx;
	return 1;
}
int loader_mw_mkmag(char* two_rsc,int* sizes,char* magbuf,int* bytes)
{
	int diroffset;
	int direntries;
	int codesize=0;
	int text1size=0;
	int text2size=0;
	int dictsize=0;
	//int undosize=0;
	//int undopc=0;
	int wtabsize=0;

	int codeoffs=0;
	int textoffs=0;
	int dictoffs=0;
	int wtaboffs=0;
	int magidx;
	int wonderland=0;

	int i;


	// step one: find the directory. it is stored in the very first 4 bytes.
	loader_mw_readresource(two_rsc,sizes,0,magbuf,4);
	diroffset=READ_INT32LE(magbuf,0);
	loader_mw_readresource(two_rsc,sizes,diroffset,magbuf,2);diroffset+=2;
	direntries=READ_INT16LE(magbuf,0);
	// step two: count the image files
	codeoffs=textoffs=dictoffs=wtaboffs=-1;
	for (i=0;i<direntries;i++)
	{
//		int unknown;
		int offset;
		int length;
		char name[7];
		int type;
		int j;
		char tmpbuf[18];
		loader_mw_readresource(two_rsc,sizes,diroffset,tmpbuf,18);diroffset+=18;
//		unknown=READ_INT16LE(tmpbuf,0);
		offset=READ_INT32LE(tmpbuf,2);
		length=READ_INT32LE(tmpbuf,6);
		for (j=0;j<6;j++) name[j]=tmpbuf[10+j];
		name[6]=0;
		type=READ_INT16LE(tmpbuf,16);

		if (type==4)
		{
			if (strncmp(name,"code",4)==0) wonderland=1;
			// the interesting files are ?code, ?text, ?index and ?wtab. for the games other than wonderland, there is a prefix. 
			if (strncmp(name,"code",4)==0  || strncmp(&name[1],"code",4)==0)  {codeoffs=offset;codesize=length;}
			if (strncmp(name,"text",4)==0  || strncmp(&name[1],"text",4)==0)  {textoffs=offset;text1size=length;}
			if (strncmp(name,"index",5)==0 || strncmp(&name[1],"index",5)==0) {dictoffs=offset;dictsize=length;}
			if (strncmp(name,"wtab",4)==0  || strncmp(&name[1],"wtab",4)==0)  {wtaboffs=offset;wtabsize=length;}
		}
	}
	if (codeoffs==-1 || textoffs==-1 || dictoffs==-1 || wtaboffs==-1) return 0;



	magidx=42;
	loader_mw_readresource(two_rsc,sizes,codeoffs,&magbuf[magidx],codesize);    
	magidx+=codesize;
	loader_mw_readresource(two_rsc,sizes,textoffs,&magbuf[magidx],text1size);   magidx+=text1size;
	loader_mw_readresource(two_rsc,sizes,dictoffs,&magbuf[magidx],dictsize);    magidx+=dictsize;
	loader_mw_readresource(two_rsc,sizes,wtaboffs,&magbuf[magidx],wtabsize);    magidx+=wtabsize;
	// finishing patch
	if (wonderland)
	{
		if (READ_INT16BE(magbuf,0x67a2)==0xa62c)
		{
			magbuf[0x67a2]=0x4e;
			magbuf[0x67a3]=0x75;
		}
	}

	if (text1size>0x10000) text2size=text1size+dictsize-0x10000; else text2size=text1size+dictsize-0xe000;
	loader_common_addmagheader((unsigned char*)magbuf,magidx,4,codesize,(text1size>=0x10000)?0x10000:0xe000,text2size,wtabsize,text1size);
	*bytes=magidx;

	return 1;
}


int loader_magneticwindows(char* two_rsc,
		char *magbuf,int* magsize,
		char* gfxbuf,int* gfxsize)
{
	int bytes;
	int sizes[10]={0};
	printf("Pondering...\n");
	if (!loader_mw_collectSizes(two_rsc,sizes,gfxbuf))
	{
		fprintf(stderr,"unable to find resource files\n");
		fprintf(stderr," please make sure that they are named TWO.RSC\n");
		fprintf(stderr," CTWO.RSC or something similar.\n");
		return 1;
	}
	if (loader_mw_mkmag(two_rsc,sizes,magbuf,&bytes))
	{
		*magsize=bytes;
		loader_mw_mkgfx(two_rsc,sizes,gfxbuf,gfxsize);
	} else {
		*magsize=0;
		*gfxsize=0;
	}
	return 0;
}



