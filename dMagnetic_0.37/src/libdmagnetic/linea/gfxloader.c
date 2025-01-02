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

#include "vm68k_datatypes.h"
#include "vm68k_macros.h"
#include "gfxloader.h"
#include "linea.h"	// for the picture
#include <string.h>
#include <stdio.h>

int gfxloader_twice_as_wide(tdMagneticPicture *pPicture)
{
	int i;
	// make the picture wider
	for (i=pPicture->width*pPicture->height;i>=0;i--)
	{
		pPicture->pixels[2*i+0]=pPicture->pixels[i];
		pPicture->pixels[2*i+1]=pPicture->pixels[i];
	}
	pPicture->width*=2;

	return 0;

}

int gfxloader_gfx1(tVM68k_ubyte* gfxbuf,tVM68k_ulong gfxsize,int picnum,tdMagneticPicture* pPicture)
{
	int i;
	int retval;

	int picoffs;
	int width;
	int height;
	int tablesize;
	int datasize;

	int treeidx;
	int byteidx;
	unsigned char curpixel;
	unsigned char mask;
	unsigned char byte;
	unsigned char branch;
	int rle;

	pPicture->pictureType=PICTURE_DEFAULT;
	retval=0;
	picnum&=0xffff;
	picoffs=READ_INT32BE(gfxbuf,8+4*picnum);	// the .gfx file starts with the index pointers to the actual picture data.
	if (picoffs==0x00000000 || picoffs>gfxsize)
	{
		retval=-1;	// the picture number was not correct
		return retval;
	}

	// once the offset has been calculated, the actual picture data is as followed:
	// bytes 0..1: UNKNOWN
	// bytes 0x02..0x03: X1
	// bytes 0x04..0x05: X2
	// X2-X1=width
	// bytes 0x06..0x07: height
	// bytes 0x08..0x1b: UNKNOWN
	// bytes 0x1c..0x3b: palette.
	// bytes 0x3c..0x3d: size of the huffmann table
	// bytes 0x3e..0x41: size of the data bit stream
	// 
	// bytes 0x42+0x42+tablesize: huffmann decoding table
	// bytes 0x42+tablesize..0x42+tablesize+datasize: bitstream
	curpixel=0;
	width=READ_INT16BE(gfxbuf,picoffs+4)-READ_INT16BE(gfxbuf,picoffs+2);
	height=READ_INT16BE(gfxbuf,picoffs+6);
	// this particular graphics format has 3 bits per RGB channel
	for (i=0;i<16;i++)
	{
		unsigned short s;
		unsigned int red,green,blue;
		s=READ_INT16BE(gfxbuf,picoffs+0x1c+2*i);

		red	=(s>>8)&0xf;
		green	=(s>>4)&0xf;
		blue	=(s>>0)&0xf;

		red*=PICTURE_MAX_RGB_VALUE;green*=PICTURE_MAX_RGB_VALUE;blue*=PICTURE_MAX_RGB_VALUE;
		red/=7;green/=7;blue/=7;

		pPicture->palette[i]=(red<<(2*PICTURE_BITS_PER_RGB_CHANNEL))|(green<<(1*PICTURE_BITS_PER_RGB_CHANNEL))|blue;


	}
	tablesize=READ_INT16BE(gfxbuf,picoffs+0x3c);	// size of the huffmann table
	datasize =READ_INT32BE(gfxbuf,picoffs+0x3e);	// size of the bitstream

	if (datasize>gfxsize)	// probably not correct
	{
		return 1;
	}


	// the huffmann table contains links. if a bit in the stream is set, the upper 8 bits, otherwise the lower ones.
	// terminal symbols have bit 7 set.
	byteidx=picoffs+0x42+tablesize*2+2;
	mask=0x00;
	byte=0;
	rle=0;
	for (i=0;(i<height*width) && (byteidx<gfxsize);i++)
	{
		if (rle==0)
		{
			treeidx=tablesize;	// start at the end of the huffmann table
			do
			{
				unsigned char branch0;
				unsigned char branch1;
				if (mask==0x00)			// when a full byte has been read
				{
					if (byteidx<gfxsize)
					{
						byte=gfxbuf[byteidx];	// get the next byte
						byteidx++;
					}
					mask=0x80;			// the bitstream is being read MSB first
				}
				branch1=gfxbuf[picoffs+0x42+2*treeidx+0];	// the order of the branches is that first comes the branch when the bit is set =1
				branch0=gfxbuf[picoffs+0x42+2*treeidx+1];	// then comes the branch for when the bit is clear =0
				branch=(byte&mask)?branch1:branch0;		
				mask>>=1;					// the bitstream is being read MSB first
				if (!(branch&0x80))				// if the highest bit is clear
				{
					treeidx=branch;
				}
			}
			while ((branch&0x80)==0x00);	// bit 7 denotes a terminal symbol
			branch&=0x7f;	// remove bit 7.
			if (branch>=0x10)	// it bits 6..4 were set, the previous pixels are being repeated
			{
				rle=branch-0x10;
			} else {	// since there are only 16 possible pixels, this is it.
				curpixel=branch;
				rle=1;	// will become 0 in the next revelation.
			}
		}
		pPicture->pixels[i]=curpixel;
		rle--;
	}
	pPicture->height=height;
	pPicture->width=width;

	// the finishing touch: each line has to be XORed with the previous one.
	for (i=width;i<width*height;i++)
	{
		pPicture->pixels[i]^=pPicture->pixels[i-width];
	}
	return retval;

}

int gfxloader_gfx2(tVM68k_ubyte* gfxbuf,tVM68k_ulong gfxsize,char* picname,tdMagneticPicture* pPicture)
{
	int directorysize;
	int offset;
	//int length;
	int retval;
	int i;
	int j;
	int found;

	pPicture->width=0;
	pPicture->height=0;
	pPicture->pictureType=PICTURE_DEFAULT;	// only gfx3 offers halftone pictures
						// the gfx2 buffer starts with the magic value, and then a directory
	directorysize=READ_INT16BE(gfxbuf,4);

	retval=0;
	// step 1: find the correct filename
	found=0;
	offset=-1;
	for (i=0;i<directorysize && !found;i+=16)
	{
		// each entry in the directory is 16 bytes long. 8 bytes "filename", 4 bytes offset, 4 bytes length. filenames are 0-terminated.
		tVM68k_ubyte c1,c2;
		found=1;
		j=0;
		do
		{
			c1=gfxbuf[6+i+j];
			c2=picname[j];
			if ((c1&0x5f)!=(c2&0x5f)) found=0;	// compare, uppercase
			if ((c1&0x5f)==0) j=8;	// end of the entry reached.
			j++;
		} while (j<8 && found);
		if (found)
		{
			offset=READ_INT32BE(gfxbuf,i+6+8);		// this is the offset from the beginning of the gfxbuf
		}
	}
	// TODO: sanity check. is length-48==height*width/2?
	if (found && offset!=-1)
	{
		// each picture has the following format:
		// @0: 4 bytes UNKNOWN
		// @4..36 16*2 bytes palette
		// @38:      4 bytes data size (MIXED ENDIAN)
		// @42:      2 bytes width
		// @44:      2 bytes height
		// @48:      beginning of the bitmap block.
		// after the bitmap block is a magic field.
		// if it is !=0x5ed0, there is going to be an animation

		// the data format is as such: Each pixel consists of 4 bits:3210. in each line, 
		// the bits are lumped together, beginning with bit 0 of the first pixel, then 
		// bit 0 of the second pixel, then bit 0 of the third pixel and so on. (MSB first)
		// afterwards, the bit lump for bit 1 starts.
		//
		// 00000000111111112222222233333333
		// 00000000111111112222222233333333
		// 00000000111111112222222233333333
		// 00000000111111112222222233333333
		//
		int x,y;
		int idx0,idx1,idx2,idx3;
		int lumpsize;
		int datasize;
		int pixidx;

		for (i=0;i<16;i++)
		{
			unsigned short s;
			unsigned int red,green,blue;
			s=READ_INT16LE(gfxbuf,offset+4+2*i);

			red	=(s>>8)&0xf;
			green	=(s>>4)&0xf;
			blue	=(s>>0)&0xf;

			red*=PICTURE_MAX_RGB_VALUE;green*=PICTURE_MAX_RGB_VALUE;blue*=PICTURE_MAX_RGB_VALUE;
			red/=7;green/=7;blue/=7;

			pPicture->palette[i]=(red<<(2*PICTURE_BITS_PER_RGB_CHANNEL))|(green<<(1*PICTURE_BITS_PER_RGB_CHANNEL))|blue;
		}
		datasize=READ_INT32ME(gfxbuf,offset+38);
		pPicture->width=READ_INT16LE(gfxbuf,offset+42);
		pPicture->height=READ_INT16LE(gfxbuf,offset+44);

		if (pPicture->width>PICTURE_MAX_WIDTH)
		{
			retval=-1;
			return retval;
		}

		// animmagic=READ_INT16LE(gfx2buf,offset+48+data_size);
		lumpsize=datasize/pPicture->height/4;	// datasize=size of the picture. height: number of lines. thus: datasize/height=number of bytes per line. there are 4 lumps of bits per line.
		pixidx=0;
		for (y=0;y<pPicture->height;y++)
		{
			tVM68k_ubyte byte0,byte1,byte2,byte3;
			tVM68k_ubyte mask;
			idx0=y*4*lumpsize+offset+48;
			idx1=idx0+1*lumpsize;
			idx2=idx0+2*lumpsize;
			idx3=idx0+3*lumpsize;
			for (x=0;x<pPicture->width;x+=8)
			{
				tVM68k_ubyte p;
				byte0=gfxbuf[idx0++];
				byte1=gfxbuf[idx1++];
				byte2=gfxbuf[idx2++];
				byte3=gfxbuf[idx3++];
				mask=(1<<7);		// MSB FIRST
				for (i=0;i<8;i++)
				{
					p =(byte0&mask)?0x01:0;
					p|=(byte1&mask)?0x02:0;
					p|=(byte2&mask)?0x04:0;
					p|=(byte3&mask)?0x08:0;
					mask>>=1;
					if ((x+i)<pPicture->width)
					{
						pPicture->pixels[pixidx++]=p;
					}
				}
			}
		}
	} 


	return retval;
}


int gfxloader_gfx3(tVM68k_ubyte* gfxbuf,tVM68k_ulong gfxsize,int picnum,tdMagneticPicture* pPicture)
{
	//  0.. 3: 4 bytes "MaP3"
	//  4.. 8: 4 bytes length of index
	//  8..11: 4 bytes length of disk1.pix
	// 11..15: 4 bytes length of disk2.pix
	// then the index
	// then the disk1.pix data
	// then the disk2.pix data
	int retval;
	int offs1;
	int offs2;
	int offset;
	int indexoffs,indexlen;
	int disk1offs,disk1len;
	int disk2offs;
	int i,n;

	int huffsize;
	int treeidx;
	int byteidx;
	int unhufcnt;
	int pixelcnt;
	int state;

	unsigned char mask;
	unsigned char byte;
	unsigned int unpackedsize;
	int max_stipple;
	unsigned char pl_lut[128]={0};	// lookup table for left pixels
	unsigned char pr_lut[128]={0};	// lookup table for right pixels
	unsigned char xorbuf[PICTURE_MAX_WIDTH*2]={0};	// ring buffer, to perform an XOR over two lines of stipples
	unsigned char rgbbuf[16]={0};		// RGB values are 6 bits wide. 2 bits red, 2 bits green, 2 bits blue. 
	unsigned char last_stipple;
	int state_cnt;
	int height,width;
	if (!gfxsize) return 0;		// there is no picture data available. nothing to do.

	picnum&=0xffff;
	pPicture->pictureType=PICTURE_HALFTONE;	// this format offers half tones.

	indexlen=READ_INT32BE(gfxbuf, 4);
	disk1len=READ_INT32BE(gfxbuf, 8);
	//	disk2len=READ_INT32BE(gfxbuf,12);

	indexoffs=16;
	disk1offs=indexoffs+indexlen;
	disk2offs=disk1offs+disk1len;

	retval=0;

	// step 1: find the offset of the picture within the index.
	// the way it is stored is that the offsets within disk1 are stored in the first half,
	// and the offsets for disk2 are in the second half.
	// in case the offset is -1, it must be in the other one.
	offs1=(tVM68k_slong)READ_INT32LE(gfxbuf,indexoffs+picnum*4);
	offs2=(tVM68k_slong)READ_INT32LE(gfxbuf,indexoffs+indexlen/2+picnum*4);
	if (picnum!=30 && offs1!=-1 && offs2!=-1) offs2=-1;	// in case one picture is stored on both disks, prefer the first one.

	if (picnum==30 && offs1==-1 && offs2==-1) offs1=0;	// special case: the title screen for the GUILD of thieves is the first picture in DISK1.PIX
	if (offs1!=-1) offset=offs1+disk1offs;			// in case the index was found in the first half, use disk1
	else if (offs2!=-1) offset=offs2+disk2offs;		// in case the index was found in the second half, use disk2
	else return -1;	///  otherwise: ERROR



	if (offset>gfxsize) 	// this is MYTH: there is only a single image file.
	{
		offset=offs1;
	}

	// the picture is stored in layers.
	// the first layer is a huffmann table.
	// this unpacks the second layer, which contains repitions
	// and a "stipple" table. from this, the actual pixels are being 
	// calculated.

	huffsize=gfxbuf[offset+0];
	unpackedsize=READ_INT16BE(gfxbuf,offset+huffsize+1);
	unpackedsize*=4;
	unpackedsize+=3;
	unpackedsize&=0xffff;	// it was designed for 16 bit machines.

	pixelcnt=-1;
	unhufcnt=0;
	state=0;
	treeidx=0;
	mask=0;
	byteidx=offset+huffsize+2+1;	// the beginning of the bitstream starts after the huffmann table and the unpackedsize
	byte=0;
	width=0;
	height=0;
	memset(xorbuf,0,sizeof(xorbuf));	// initialize the xor buffer with 0
	state_cnt=0;
	max_stipple=last_stipple=0;

	while (unhufcnt<unpackedsize && (pixelcnt<(2*width*height)) && byteidx<gfxsize)
	{
		// first layer: the bytes for the unhuf buf are stored as a bitstream, which are used to traverse a huffmann table.
		unsigned char branch1,branch0,branch;
		if (mask==0)
		{
			byte=gfxbuf[byteidx];
			byteidx++;
			mask=0x80;			// MSB first
		}
		branch1=gfxbuf[offset+1+treeidx*2+0];
		branch0=gfxbuf[offset+1+treeidx*2+1];
		branch=(byte&mask)?branch1:branch0;
		mask>>=1;				// MSB first.
		if (branch&0x80)		// leaves have the highest bit set. terminal symbols only have 7 bit.
		{
			treeidx=0;
			branch&=0x7f;	// terminal symbols have 7 bit
					//
					//
					// the second layer begins here
			switch (state)
			{
				case 0:	// first state: the ID should be "0x77"
					if (branch!=0x77)	return -1;	// illegal format
					state=1;
					break;
				case 1: // second byte is the number of "stipples"
					max_stipple=branch;
					state=2;
					break;
				case 2:	// width, stored as 2*6 bit Big Endian
					width<<=6;	// 2*6 bit. big endian;
					width|=branch&0x3f;
					state_cnt++;
					if (state_cnt==2)	state=3;
					break;
				case 3:	// height, stored as 2*6 bit Big Endian
					height<<=6;	// 2*6 bit. big endian;
					height|=branch&0x3f;
					state_cnt++;
					if (state_cnt==4)
					{
						if (height<=0 || width<=0) 	return -2;	// error in decoding the height and the width
						pixelcnt=0;
						state_cnt=0;
						state=4;
					}
					break;
				case 4:	// rgb values
					rgbbuf[state_cnt++]=branch;
					if (state_cnt==16) 
					{
						state_cnt=0;
						state=5;
					}
					break;
				case 5:	// lookup-table to retrieve the left pixel value from the stipple
					pl_lut[state_cnt++]=branch;
					if (state_cnt==max_stipple)
					{
						state_cnt=0;
						state=6;
					}
					break;
				case 6:	// lookup-table to retrieve the right pixel value from the stipple
					pr_lut[state_cnt++]=branch;
					if (state_cnt==max_stipple)
					{
						last_stipple=0;
						state_cnt=0;
						state=7;
					}
					break;
				case 7:
				case 8:
					// now for the stipple table
					// this is actually a third layer of encoding.
					// it contains terminal symbols [0... max_stipple)
					// 
					// if the symbol is <max_stipple, it is a terminal symbol, a stipple
					// if the symbol is =max_stipple, it means that the next byte is being escaped
					// if the symbol is >max_stipple, it means that the previous symbol is being repeated.
					n=0;
					if (state==8)	// this character has been "escaped"
					{
						state=7;
						n=1;
						last_stipple=branch;
					}
					else if (branch<max_stipple)
					{
						last_stipple=branch;	// store this symbol for the next repeat instruction
						n=1;
					} else {
						if (branch==max_stipple)	// "escape" the NEXT symbol. use it, even though it might be >=max_stipple.
						{			// this is necessary for the XOR operation.
							state=8;
							n=0;
						} else if (branch>max_stipple) 
						{
							n=branch-max_stipple;	// repeat the previous stipple
							branch=last_stipple;
						}
					}
					for (i=0;i<n;i++)
					{
						unsigned char x;
						xorbuf[state_cnt]^=branch;			// descramble the symbols
						x=xorbuf[state_cnt];
						state_cnt=(state_cnt+1)%(2*width);
						pPicture->pixels[pixelcnt++]=pl_lut[x];
						pPicture->pixels[pixelcnt++]=pr_lut[x];
					}
					break;
			}
		} else {
			treeidx=branch;	// non terminal -> traverse the tree further down
		}
	}
	pPicture->height=height;
	pPicture->width=width*2;
	// scale up the RGB values to 10bit per channel
	for (i=0;i<16;i++)
	{
		unsigned char halftonelut[4]={0,2,5,7};
		unsigned int red,green,blue;




		red  =(rgbbuf[i]>>4)&0x3;
		green=(rgbbuf[i]>>2)&0x3;
		blue =(rgbbuf[i]>>0)&0x3;

		red	=(halftonelut[red]*PICTURE_MAX_RGB_VALUE)/7;
		green	=(halftonelut[green]*PICTURE_MAX_RGB_VALUE)/7;
		blue	=(halftonelut[blue]*PICTURE_MAX_RGB_VALUE)/7;


		pPicture->palette[i]=(red<<(2*PICTURE_BITS_PER_RGB_CHANNEL))|(green<<(1*PICTURE_BITS_PER_RGB_CHANNEL))|blue;

	}


	return retval;
}

// the gfx4 format is used to handle the pictures from the Magnetic Windows system.
// just like the gfx2, it starts with a directory. 6 byte picname, 4 bytes (little endian) offset, 4 bytes (little endian) length.
// at the offset, the picture is being comprised of the tree (type 7) and image (type 6) from the Magnetic Windows resource files.
// the tree is ALWAYS 609 bytes long. The size of the image varies.
//
// the huffmann tree uses 9 bits to encode 8 bits: the first 32 bytes are a bitmask (MSB first). Then the branches/symbols follow. 
// if the bit from the bitmask is set, it is a terminal symbol.
// 0x00...0x1f:  LEFTMASK		(0)
// 0x20...0x11f: LEFTBRANCH
// 0x120..0x13f: RIGHTMASK		(1)
// 0x140..0x23f: RIGHTBRANCH
// Byte 0x240    escape character (for run level encoding)
// Byte 0x241...0x250: EGA palette
// Byte 0x251...0x260: EGA palette pairs
//
//
// the image data looks like this:
// 0x00..0x03: magic header
// 0x04..0x23: 16x2 bytes RGB values (4 bits per channel, little endian, 0x0rgb)
// 0x24..0x25: width
// 0x26..0x27: height
// 0x28..0x29: transparency placeholder
// 0x2a..0x2b: size
// 0x2c......: bit stream. MSB first. when the bit is set (=1), follow the RIGHT branch.
//
// the run level encoding is signalled by the escape character from the tree (byte 0x240).
// in case the next character is 0xff, it actually an honest escape character.
// if any other value follows, it is the repeat num.
// the character AFTER that one is being repeated (4+repeat) number of times.
//
// each symbol is 8 bits large, 4 bits are the pixel. CAREFUL: bits 0..3 are the left, bits 4..7 are the right pixel
// in case the width is not divisible by 2, bits 4..7 are being ignored.
//
// the xor is being performed line by line.
//
// note that the end of the image comes BEFORE the end of the bitstream. (due to a bug in the encoder)
int gfxloader_gfx4(tVM68k_ubyte* gfxbuf,tVM68k_ulong gfxsize,char* picname,tdMagneticPicture* pPicture,int egamode)
{
#define	SIZEOFTREE	609
	int directorysize;
	int retval;
	int found;
	int i;
	int offset,length;
	int offset_vanilla,length_vanilla;
	int offset_ega,length_ega;
	int offset_anim,length_anim;
	int j;
	pPicture->width=0;
	pPicture->height=0;
	pPicture->pictureType=PICTURE_DEFAULT;
	// the gfx4 buffer starts with the magic value, and then a directory
	retval=0;
	found=0;
	directorysize=READ_INT16BE(gfxbuf,4);
	offset_ega=offset_anim=offset_vanilla=-1;
	length_ega=length_anim=length_vanilla=-1;
	for (i=0;i<directorysize && !found;i+=14)
	{
		tVM68k_ubyte c1,c2;
		found=1;
		j=0;
		do
		{
			c1=gfxbuf[6+i+j];
			c2=picname[j];
			if ((c1&0x5f)!=(c2&0x5f)) found=0;
			if ((c1&0x5f)==0) j=6;	// end of entry reached.
			j++;
		} while (j<6 && found);
		if (found)
		{
			int ega;
			int stillimage;
#define	STILLMAGIC	0x00005ed0
			const unsigned short egapalette[16]={0x000,0x005,0x050,0x055, 0x500,0x505,0x550,0x555, 0x222,0x007,0x070,0x077, 0x700,0x707,0x770,0x777};
			offset=READ_INT32LE(gfxbuf,i+6+6);
			length=READ_INT32LE(gfxbuf,i+6+10);

			// check if the image is not the ega image, and it is not an animation background.

			// the EGA images have a specific RGB palette
			// if not, it is not a EGA image
			ega=16;
			for (j=0;j<16;j++)
			{
				if (READ_INT16LE(gfxbuf,offset+SIZEOFTREE+4+2*j)!=egapalette[j]) ega--;
			}
			ega=(ega>=15);

			stillimage=1;
			if (READ_INT32LE(gfxbuf,offset+length-4)!=STILLMAGIC) stillimage=0;		// if they do not, it is an animation
			found=0;
			if (!ega && stillimage)
			{
				offset_vanilla=offset;
				length_vanilla=length;
			}

			if (ega) 
			{
				offset_ega=offset;
				length_ega=length;
			}
			if (!stillimage)
			{
				offset_anim=offset;
				length_anim=length;
			}
		}
	}
	// in case the image was not found
	offset=-1;
	length=-1;
	if (offset==-1)
	{
		offset=offset_vanilla;
		length=length_vanilla;
	}
	if (offset==-1)
	{
		offset=offset_anim;
		length=length_anim;
	}
	if (offset==-1 || egamode)
	{
		offset=offset_ega;
		length=length_ega;
	}
	if (offset!=-1 && length!=-1) found=1;

	if (found)
	{
		int treestart;
		int picstart;
		int size;
		int treeidx;
		int repnum;
		int rlestate;	// for the run length encoding. state 0: if not the escape char, output. otherwise -> state 1. in state 1, if the symbol is 0xff, the output is the escapechar. otherwise, the repition number (sans 4) -> state 4. in state 4, repeat the symbol
		tVM68k_ubyte escapechar;
		tVM68k_ubyte byte;
		tVM68k_ubyte mask;
		treestart=offset+0;
		picstart=offset+SIZEOFTREE;


		// byte 0x240 in the tree is the escape symbol for the run level encoding
		escapechar=gfxbuf[treestart+0x240];
		// bytes 0x04..0x23: RGB values
		for (i=0;i<16;i++)
		{
			unsigned short s;
			unsigned int red,green,blue;
			s=READ_INT16LE(gfxbuf,picstart+0x4+i*2);

			red	=(s>>8)&0xf;
			green	=(s>>4)&0xf;
			blue	=(s>>0)&0xf;

			red*=PICTURE_MAX_RGB_VALUE;green*=PICTURE_MAX_RGB_VALUE;blue*=PICTURE_MAX_RGB_VALUE;
			red/=7;green/=7;blue/=7;




			pPicture->palette[i]=(red<<(2*PICTURE_BITS_PER_RGB_CHANNEL))|(green<<(1*PICTURE_BITS_PER_RGB_CHANNEL))|blue;

		}
		// bytes 0x24,0x25= width
		// bytes 0x26,0x27= height
		pPicture->width=READ_INT16LE(gfxbuf,picstart+0x24);
		pPicture->height=READ_INT16LE(gfxbuf,picstart+0x26);
		if (pPicture->width>PICTURE_MAX_WIDTH)
		{
			retval=-1;
			return retval;
		}

		// bytes 0x2a,0x2b= size of the bitstream (in bytes)
		size=READ_INT16LE(gfxbuf,picstart+0x2a);
		j=0;
		treeidx=0;
		mask=0;byte=0;
		i=0;
		rlestate=0;
		repnum=1;

		// i is counting up the bytes in the bitstream.
		// j is counting up the pixels of the image
		while (((i<(length-SIZEOFTREE) && i<size ) || mask ) && j<(pPicture->width*pPicture->height))
		{
			tVM68k_ubyte term0,term1,term;
			tVM68k_ubyte branch0,branch1,branch;
			// the bitmask is denoting (MSB first) if an entry is a terminal symbol (=1) or a branch (=0)
			term0=gfxbuf[treestart+0x00 +treeidx/8]&(0x80>>(treeidx%8));
			term1=gfxbuf[treestart+0x120+treeidx/8]&(0x80>>(treeidx%8));

			// the entry in the table could either be a branch or a terminal symbol
			branch0=gfxbuf[treestart+0x20 +treeidx];
			branch1=gfxbuf[treestart+0x140+treeidx];

			if (mask==0)
			{
				mask=0x80;
				byte=gfxbuf[picstart+i+0x2c];
				i++;
			}

			term  =(byte&mask)?  term1:term0;
			branch=(byte&mask)?branch1:branch0;
			mask>>=1;


			if (term)
			{
				if (rlestate==0)
				{
					if (branch==escapechar) 
					{
						rlestate=1;
					} else {
						repnum=1;
					}
				} else if (rlestate==1) {
					if (branch==0xff)
					{
						branch=escapechar;
						repnum=1;
						rlestate=0;
					} else {
						repnum=branch+4;	// this form of RLE makes sense when the same byte was repeated 4 or more times in the source picture
						rlestate=2;
					}
				} else if (rlestate==2) {
					rlestate=0;	// the current entry is a terminal symbol, which is going to be repeated
				}
				if (rlestate==0)
				{
					while (repnum && j<(pPicture->width*pPicture->height))
					{
						// the lower 4 bits are the LEFT pixel
						pPicture->pixels[j]=branch&0xf;
						j++;
						// one byte holds two pixels. but when the width is not divisible by 2, drop the remaining nibble.
						if (j%pPicture->width) // the higher 4 bits are the RIGHT pixel; but only if it is not outside the scope of the image.
						{
							pPicture->pixels[j]=(branch>>4)&0xf;	// the higher 4 bytes are the RIGHT pixel
							j++;
						}
						repnum--;
					}
				}
				treeidx=0;	// go back to the start;
			} else {	// not a terminal symbol. keep following the branches
				treeidx=branch;
			}
		}
		// the finishing touch: XOR each line with the previous one
		for (i=pPicture->width;i<pPicture->height*pPicture->width;i++)
		{
			pPicture->pixels[i]^=pPicture->pixels[i-pPicture->width];
		}
	}


	return retval;
}


// the Commodore C64 pictures
// The c64 pictures consist of two parts: the bitmap and the colour map. essentially, each 8x8 block can be rendered with 4 colours. 
// 2 of them are fixed, the others are determined by the colourmap.
int gfxloader_gfx5(unsigned char* gfxbuf,int gfxsize,int version,int picnum,tdMagneticPicture* pPicture)
{
#define	C64_PICWIDTH			160
#define	C64_PICHEIGHT			152
#define	C64_PIXELPERBYTE		(8/2)
#define	C64_BYTES_BITMAP		(C64_PICWIDTH*C64_PICHEIGHT/C64_PIXELPERBYTE)
#define	C64_BYTES_BITMAP_PAWN		((C64_PICWIDTH*C64_PICHEIGHT/C64_PIXELPERBYTE)+64)	// THE Pawn had a little bit padding
#define	C64_BYTES_COLOURMAP_V0		380		// 
#define	C64_BYTES_COLOURMAP_V1		(2*C64_BYTES_COLOURMAP_V0)
#define	C64_BYTES_COLOURMAP_HIGH	760
#define	C64_MAXBYTES_PICTURE_V0		(C64_BYTES_BITMAP+C64_BYTES_COLOURMAP_V0+C64_BYTES_COLOURMAP_HIGH)
#define	C64_MAXBYTES_PICTURE_V1		(C64_BYTES_BITMAP+C64_BYTES_COLOURMAP_V1+C64_BYTES_COLOURMAP_HIGH)
#define	C64_MAXBYTES_PICTURE		C64_MAXBYTES_PICTURE_V1
#define	C64_BYTES_IN_BITMAP		(C64_PICWIDTH*C64_PICHEIGHT/C64_PIXELPERBYTE)
//	unsigned char tmpbuf[C64_MAXBYTES_PICTURE];	// maximum size for a picture. plus room for the threebuf
	unsigned char *tmpbuf=(unsigned char*)&(pPicture->pixels[C64_PICWIDTH*C64_PICHEIGHT]);
	unsigned char colour[4]={0};
	int format;
	int i;
	int picoffs;
	int retval;
	// approximation of the fixed C64 palette with 10bit RGB values
	const unsigned int gfx5_rgbvalues[16]={
		0x00000000,	// black
		0x3fffffff,	// white
		0x205330e0,	// red
		0x1d5ceb22,	// cyan

		0x2393c25d,	// violet
		0x159ac934,	// green
		0x0b82c26d,	// blue
		0x3b6f19c5,	// yellow

		0x239500a4,	// orange
		0x15538000,	// brown
		0x3126c5c5,	// light red
		0x1284a128,	// grey 1

		0x1ed7b5ed,	// grey 2
		0x2a5ffe7d,	// light green
		0x1c16d7ae,	// light blue
		0x2cab2aca};	// grey 3

	for (i=0;i<16;i++)
	{
		pPicture->palette[i]=gfx5_rgbvalues[i];
	}

	retval=0;
	picoffs=READ_INT32BE(gfxbuf,4+4*picnum);
	if (picoffs<=0x00000000 || picoffs>gfxsize)
	{
		retval=-1;	// the picture number was not correct
		return retval;
	} 


	pPicture->width=C64_PICWIDTH;
	pPicture->height=C64_PICHEIGHT;
	pPicture->pictureType=PICTURE_C64;	// only gfx3 offers halftone pictures
	format=0;

	///////////// dehuff /////////////
	{
		int outcnt;
		int expected;
		int treeidx;
		int bitcnt;
		int byteidx;
		int threecnt;
		int rlenum;
		int rlecnt;
		unsigned char rlebuf[256]={0};
		unsigned char threebuf[3]={0};
		unsigned char* ptr;
		unsigned char byte=0;
		unsigned char rlechar;

		treeidx=0;
		expected=C64_BYTES_BITMAP;
		outcnt=-1;
		bitcnt=0;
		ptr=&gfxbuf[picoffs];
		byteidx=1+(ptr[0]+1)*2;	// the first byte is the size of the huffmann tree. After the huffmann tree, the bit stream starts.
		threecnt=0;
		rlechar=0;

		rlenum=0;
		rlecnt=0;

		while (outcnt<expected)
		{
			unsigned char branch1,branch0,branch;
			if (bitcnt==0)
			{
				bitcnt=8;
				byte=ptr[byteidx++];
			}
			branch1=ptr[2*treeidx+1];
			branch0=ptr[2*treeidx+2];
			branch=(byte&0x80)?branch1:branch0;
			byte<<=1;bitcnt--;
			if (branch&0x80)
			{
				treeidx=branch&0x7f;
			} else {
				treeidx=0;
				if (threecnt==3)
				{
					int i;
					threecnt=0;
					for (i=0;i<3;i++) 
					{
						threebuf[i]|=((branch<<2)&0xc0);
						branch<<=2;
					}
					if (outcnt==-1)
					{
						outcnt=0;
						if (version==0) 	// PAWN specific
						{
							colour[0]=threebuf[0]&0xf;	// for when the bitmask is 00
							colour[3]=threebuf[1]&0xf;	// for when the bitmask is 11
							rlenum=threebuf[2];
							expected=C64_BYTES_BITMAP_PAWN+C64_BYTES_COLOURMAP_HIGH;
						} else {
							format=threebuf[0];
							if (threebuf[0]==0x00)
							{
								expected=C64_MAXBYTES_PICTURE_V0;	// after the bitmask comes the colourmap
								rlenum=0;
								rlecnt=0;
								rlechar=tmpbuf[outcnt++]=threebuf[2];
							} else {
								colour[0]=threebuf[1]&0xf;	// for when the bitmask is 00
								colour[3]=threebuf[1]&0xf;	// for when the bitmask is 11
								expected=C64_MAXBYTES_PICTURE_V1;	// after the bitmask comes the colourmap
								rlecnt=0;
								rlenum=threebuf[2];
							}
						}
					} else {
						for (i=0;i<3;i++)
						{
							if (rlecnt<rlenum) 
							{
								rlebuf[rlecnt++]=threebuf[i];
							} else {
								int j;
								int rle;
								rle=0;
								for (j=0;j<rlecnt;j++)
								{
									if (rlebuf[j]==threebuf[i]) rle=(j+1);
								}
								if (rle)
								{
									for (j=0;j<rle;j++)
									{
										if (outcnt<expected) tmpbuf[outcnt++]=rlechar;
									}
								} else {
									if (outcnt<expected) rlechar=tmpbuf[outcnt++]=threebuf[i];
								}
							}
						}
					}
				} else {
					threebuf[threecnt++]=branch;
				}
			}
		}
	}

	///////////// render the picture ///////////////
	// the bitmap consists of 4 pixels per byte.
	// the pixels are ordered as rows, so the 2 bytes A=aabbccdd B=eeffgghh are being rendered as
	// aaee
	// bbff
	// ccgg
	// ddhh
	{
		int colidx;
		int maskidx;
		int x,y;
		int i,j;
		
		int screenram_idx;
		int colourram_idx;

		x=0;
		y=0;

		if (version==0)
		{
			screenram_idx=C64_BYTES_BITMAP_PAWN;
			colourram_idx=-1;
		} else {
			screenram_idx=C64_BYTES_BITMAP+((format==0x00)?C64_BYTES_COLOURMAP_V0:C64_BYTES_COLOURMAP_V1);
			colourram_idx=C64_BYTES_BITMAP;
		}
		for (maskidx=0,colidx=0;maskidx<C64_BYTES_IN_BITMAP;maskidx+=8,colidx++)
		{
			// prepare everything for rendering a 4x8 block
			colour[1]=(tmpbuf[screenram_idx+colidx]>>4)&0xf;
			colour[2]=(tmpbuf[screenram_idx+colidx]>>0)&0xf;
			if (version!=0)
			{
				if (format==0x00)
				{
					colour[3]=tmpbuf[colourram_idx+colidx/2];
					if ((colidx%2)==0)
					{
						colour[3]>>=4;
					}
				} else {
					colour[3]=tmpbuf[colourram_idx+colidx];
				}
				colour[3]&=0xf;
			}


			for (i=0;i<8;i++)
			{
				int y2;
				unsigned char mask;
				y2=y+i;
				mask=tmpbuf[maskidx+i];
				for (j=0;j<4;j++)
				{
					int x2;
					unsigned char col;
					x2=x+j;
					col=colour[(mask>>6)&0x3];
					pPicture->pixels[x2+y2*(pPicture->width)]=col;
					mask<<=2;
				}
			}
			x+=4;
			if (x==C64_PICWIDTH) 
			{
				x=0;
				y+=8;
			}
		}
	}
	retval|=gfxloader_twice_as_wide(pPicture);
	return retval;
}
// the Amstrad CPC pictures
int gfxloader_gfx6(unsigned char* gfxbuf,int gfxsize,int picnum,tdMagneticPicture* pPicture)
{
	const unsigned char gfx6_codebook[16]={0x00,0x40,0x04,0x44,0x10,0x50,0x14,0x54,0x01,0x41,0x05,0x45,0x11,0x51,0x15,0x55};
	// approximation of the fixed CPC palette with 10bit RGB values
	const unsigned int gfx6_rgbvalues[27]={
		0x00000000,0x00000201,0x000003ff,
		0x20100000,0x20100201,0x201003ff,
		0x3ff00000,0x3ff00201,0x3ff003ff,

		0x00080400,0x00080601,0x000807ff,
		0x20180400,0x20180601,0x201807ff,
		0x3ff80400,0x3ff80601,0x3ff807ff,

		0x000ffc00,0x000ffe01,0x000fffff,
		0x201ffc00,0x201ffe01,0x201fffff,
		0x3ffffc00,0x3ffffe01,0x3fffffff
	};

	int i;
	int paletteidx;
	int outidx;
	unsigned char byte;
	unsigned char mask;
	unsigned char symbol;
	unsigned char code;
	int bitidx;
	int toggle;
	int picoffs; 
	int treeidx;
	int retval;


	retval=0;
	// find the index within the gfx buffer
	picoffs=READ_INT32BE(gfxbuf,4+picnum*4);
	if (picoffs==0x00000000 || picoffs>gfxsize)
	{
		retval=-1;	// the picture number was not correct
		return retval;
	} 


	treeidx=0;
	pPicture->height=152;	// the size is always the same
	pPicture->width =160;
	paletteidx=0;
	outidx=0;
	byte=0;
	bitidx=picoffs+1+(gfxbuf[picoffs]+1)*2;
	mask=0;
	pPicture->palette[paletteidx++]=gfx6_rgbvalues[ 0];  // black
	pPicture->palette[paletteidx++]=gfx6_rgbvalues[26];  // bright white
	symbol=0;
	code=0;
	toggle=0;
	while ((outidx<(pPicture->height*pPicture->width))&& (bitidx<gfxsize||mask))
	{
		unsigned char branch1,branch0;
		unsigned char branch;

		if (mask==0x00)
		{
			byte=gfxbuf[bitidx++];
			mask=0x80;
		}

		branch1=gfxbuf[picoffs+1+2*treeidx];
		branch0=gfxbuf[picoffs+2+2*treeidx];
		branch=(byte&mask)?branch1:branch0;
		mask>>=1;
		if (branch&0x80)
		{
			treeidx=0;
			branch&=0x7f;
			if (paletteidx<16)      // the first two colours are fixed. and the rest comes from the first 14 terminal symbols
			{
				pPicture->palette[paletteidx++]=gfx6_rgbvalues[branch];	// one of them
			} else {
				int loopcnt;
				loopcnt=1;
				if (branch&0x70)	// if bits 6..4 are set, it is a loop. it determines how often the previous code is being repeated
				{
					loopcnt=branch-0x10;
				} else {	// otherwise, it is a code 
					code=gfx6_codebook[branch];
				}
				for (i=0;i<loopcnt && outidx<(pPicture->height*pPicture->width);i++)
				{
					// the symbol is being combined from two codes
					symbol<<=1;
					symbol|=code;

					toggle=1-toggle;
					// when the symbol is finished
					if (toggle==0)
					{
						unsigned char p0;
						unsigned char p1;
						// the images are Amstrad Mode 0 pictures. Which means that the pixel bits are being interleaved in one byte.
						p0 =((symbol>>7)&0x1)<<0;
						p0|=((symbol>>3)&0x1)<<1;
						p0|=((symbol>>5)&0x1)<<2;
						p0|=((symbol>>1)&0x1)<<3;

						p1 =((symbol>>6)&0x1)<<0;
						p1|=((symbol>>2)&0x1)<<1;
						p1|=((symbol>>4)&0x1)<<2;
						p1|=((symbol>>0)&0x1)<<3;
						// at this point, the two pixels have been separated
						pPicture->pixels[outidx++]=p0;
						pPicture->pixels[outidx++]=p1;

						// prepare the next symbol
						symbol=0;
					}
				}
			}
		} else {
			treeidx=branch;
		}
	}
	// descramble the picture over two lines
	for (i=2*pPicture->width;i<pPicture->width*pPicture->height;i++)
	{
		pPicture->pixels[i]^=pPicture->pixels[i-2*pPicture->width];
	}

	retval|=gfxloader_twice_as_wide(pPicture);
	return retval;
}

// Atari XL
int gfxloader_gfx7(unsigned char* gfxbuf,int gfxsize,int picnum,tdMagneticPicture* pPicture)
{
	int retval;
	int picoffs;
	int idx;
	unsigned char mask;
	unsigned char byte;
	unsigned char treesize;
	int treeidx;
	int treeoffs;
	int state;
	int rgbcnt;
	int rlenum;
	int rlecnt;
	unsigned char lc;
	unsigned char rlebuf[256];
	unsigned char threebuf[3];
	int threecnt;
	int pixcnt;
	int rlerep;
	int i;
	int blackcnt;

	retval=0;
	picoffs=READ_INT32BE(gfxbuf,4+4*picnum);
	if (picoffs==0x00000000 || picoffs>gfxsize)
	{
		retval=-1;
		return retval;
	}
	treesize=gfxbuf[picoffs];
	byte=0;
	mask=0;
	treeidx=0;
	treeoffs=picoffs+1;
	//		idx=idx+treesize*2+3;
	idx=picoffs+treesize*2+3;
	threecnt=0;
	rlenum=0;
	rlecnt=0;
	rgbcnt=0;
	pixcnt=0;
	state=0;

	pPicture->width=160;	// the original images were stored as 160x152 pixels. However, they look better when being scaled up to 320x152
	pPicture->height=152;

	blackcnt=0;
	lc=0;
	while (idx<gfxsize && pixcnt<pPicture->width*pPicture->height && state!=3)
	{
		unsigned char branch1,branch0,branch;
		if (mask==0)
		{
			byte=gfxbuf[idx++];
			mask=0x80;
		}
		branch1=gfxbuf[treeoffs+treeidx*2+0];
		branch0=gfxbuf[treeoffs+treeidx*2+1];
		branch=(byte&mask)?branch1:branch0;
		mask>>=1;

		if (branch&0x80)
		{
			treeidx=branch&0x7f;
		} else {
			treeidx=0;
			if (threecnt!=3)
			{
				threebuf[threecnt++]=branch;

			} else {
				int j;
				for (i=0;i<threecnt;i++)
				{
					unsigned char c;
					unsigned int rgb;
					c=threebuf[i]|((branch<<2)&0xc0);branch<<=2;
					switch (state)
					{
						case 0:	// collect rgb values
							{
#define	NUM_BASECOLOURS	16
#define	NUM_BRIGHTNESSLEVELS	16
								// the way atari colors work is by packing a basecolor and the brightness within a byte.
								// the upper 4 bits are the color.
								// the lower 4 bits are the brightness
								// what I am doing is to interpolate between the darkest and the brightest rgb values I found.

								unsigned int red_dark,green_dark,blue_dark;
								unsigned int red_bright,green_bright,blue_bright;
								int r,g,b;
								int basecolor;
								int brightness;
								const unsigned int gfx7_ataripalette[NUM_BASECOLOURS][2]=	// RGB values (10 bit)
								{
									{0x00000000,0x3e6f9be6},
									{0x10420000,0x3ffffeaa},
									{0x11419010,0x3ffe6aae},
									{0x1751f030,0x3ffdab42},
									{0x12817000,0x3ffcab7a},
									{0x124000d8,0x3ffcab7a},
									{0x120031b1,0x39ab6bff},
									{0x0141e205,0x336d3bff},
									{0x02c071e5,0x34ed1bff},
									{0x07429169,0x302ebbff},
									{0x0004b165,0x31ef6bff},
									{0x00048000,0x336fff36},
									{0x05840000,0x2f2ffe69},
									{0x0b035000,0x3caffeae},
									{0x1183a024,0x3f6f3afa},
									{0x1001a008,0x3ffdaa59}
								};
								basecolor=(c>>4)&0xf;
								brightness=(c>>0)&0xf;

								red_dark	=(gfx7_ataripalette[basecolor][0]>>(2*PICTURE_BITS_PER_RGB_CHANNEL))&0x3ff;
								green_dark	=(gfx7_ataripalette[basecolor][0]>>(1*PICTURE_BITS_PER_RGB_CHANNEL))&0x3ff;
								blue_dark	=(gfx7_ataripalette[basecolor][0]>>(0*PICTURE_BITS_PER_RGB_CHANNEL))&0x3ff;

								red_bright	=(gfx7_ataripalette[basecolor][1]>>(2*PICTURE_BITS_PER_RGB_CHANNEL))&0x3ff;
								green_bright	=(gfx7_ataripalette[basecolor][1]>>(1*PICTURE_BITS_PER_RGB_CHANNEL))&0x3ff;
								blue_bright	=(gfx7_ataripalette[basecolor][1]>>(0*PICTURE_BITS_PER_RGB_CHANNEL))&0x3ff;

								r=red_dark	+((red_bright	-red_dark)*brightness)/NUM_BRIGHTNESSLEVELS;
								g=green_dark	+((green_bright	-green_dark)*brightness)/NUM_BRIGHTNESSLEVELS;
								b=blue_dark	+((blue_bright	-blue_dark)*brightness)/NUM_BRIGHTNESSLEVELS;




								rgb=(r<<(2*PICTURE_BITS_PER_RGB_CHANNEL))|(g<<(1*PICTURE_BITS_PER_RGB_CHANNEL))|b;


							}
							pPicture->palette[rgbcnt++]=rgb;
							if (c==0) blackcnt++;
							if (rgbcnt==NUM_BASECOLOURS) 
							{
								if (treesize==0x3e) state=1; else state=2;
								if (blackcnt<12) state=3;
							}
							break;
						case 1:	// rle lookup table
							if (rlenum==0) 
							{
								rlenum=c;
								rlecnt=0;
								if (rlenum==128 || rlenum==1) rlenum=0;
							} else {
								rlebuf[rlecnt++]=c;
							}
							if (rlenum==rlecnt) state=2;
							break;
						case 2:	// and the pixel information
							rlerep=0;
							for (j=0;j<rlecnt;j++)
							{
								if (c==rlebuf[j]) rlerep=j+1;
							}
							if (rlerep==0) {lc=c;rlerep=1;}
							for (j=0;j<rlerep;j++)
							{
								pPicture->pixels[pixcnt++]=(lc>>6)&0x3;
								pPicture->pixels[pixcnt++]=(lc>>4)&0x3;
								pPicture->pixels[pixcnt++]=(lc>>2)&0x3;
								pPicture->pixels[pixcnt++]=(lc>>0)&0x3;
							}
							break;
					}
				}
				threecnt=0;
			}

		}
	}
	if (rlenum!=0)
	{
		for (i=pPicture->width*2;i<pixcnt;i++)	// descramble over 2 lines
		{
			pPicture->pixels[i]^=pPicture->pixels[i-pPicture->width*2];
		}
	}

	retval|=gfxloader_twice_as_wide(pPicture);

	return retval;


}
// Apple II picture loader
int gfxloader_gfx8(unsigned char* gfxbuf,int gfxsize,int picnum,tdMagneticPicture* pPicture)
{
#define PICTURE_HOTFIX1         0x80000000
#define PICTURE_HOTFIX2         0x40000000
#define PICTURE_HOTFIX3         0x20000000
#define	APPLE2_COLOURS		16

#define	SIZE_AUX_MEM		8192
#define SIZE_MAIN_MEM		8192
#define	APPLE_II_WIDTH		140
#define	APPLE_II_HEIGHT		(192-32)
#define	BITS_PER_SYMBOL		7
#define	PIXELS_PER_WHATEVER	7	// 4 terminal symbols result in 7 pixels
#define	SYMBOLS_PER_LINE	(APPLE_II_WIDTH/BITS_PER_SYMBOL)


	// approximation of the fixed Apple II palette with 10 bit RGB values
	const unsigned int gfx8_apple2_palette[APPLE2_COLOURS]={// 10 bit per channel
		0x00000000,	// black
		0x1814e2f6,	// dark blue
		0x000a3581,	// dark green
		0x050cfbf6,	// medium blue

		0x1817240c,	// brown
		0x2719c671,	// dark grey
		0x050f58f0,	// light green
		0x1c9fff42,	// aquamarin

		0x38e1e181,	// deep red
		0x3ff443f6,	// purple
		0x2719c671,	// light grey
		0x342c3bff,	// light blue

		0x3ff6a4f0,	// orange
		0x3ffa0742,	// pink
		0x342dda35,	// yellow
		0x3fffffff	// white
	};
	int retval=0;
	int i=0;
	unsigned int picoffs=0;
	unsigned int treeoffs=0;
	int hotfix=0;
	int outidx=0;
	int treeidx=0;
	unsigned char lastterm=0;
	unsigned char mask=0;
	unsigned char byte=0;
	int bitidx=0;
	int oidx=0;
	unsigned int pixreg=0;
	int colcnt=0;
	int linecnt=0;

	retval=0;
	picoffs=READ_INT32BE(gfxbuf,4*picnum+4);
	treeoffs=picoffs;
	if (picoffs==0x0000000)
	{
		retval=-1;
		return retval;
	}


	for (i=0;i<APPLE2_COLOURS;i++)
	{
		pPicture->palette[i]=gfx8_apple2_palette[i];
	}
	pPicture->height=APPLE_II_HEIGHT;
	pPicture->width=APPLE_II_WIDTH;
	for (i=0;i<pPicture->height*pPicture->width;i++)
	{
		pPicture->pixels[i]=0;
	}
	hotfix=(treeoffs&0xe0000000);
	if (hotfix==PICTURE_HOTFIX1) hotfix=-1;
	if (hotfix==PICTURE_HOTFIX2) hotfix= 1;
	if (hotfix==PICTURE_HOTFIX3) hotfix= 2;
	treeoffs&=0x1ffffff;
	treeoffs+=1;

	if (treeoffs>gfxsize)
	{
		retval=-1;
		return retval;
	}

	// step 1: unhuffing with the RLE
	outidx=0;
	treeidx=0;
	bitidx=treeoffs+gfxbuf[treeoffs-1]+2+hotfix;

	lastterm=1;
	mask=0;
	byte=0;

	// at the unhuffptr, there is now the content which would have
	// been written into the Apple II Videoram at $2000.
	// the first 8192 bytes are the AUX memory bank.
	// the second 8192 bytes are the MAIN memory bank

	oidx=0;
	colcnt=0;
	linecnt=0;

	while (outidx<(SIZE_AUX_MEM+SIZE_MAIN_MEM) && bitidx<=gfxsize)
	{
		unsigned char branch1,branch0;
		unsigned char branch=0;

		if (mask==0)
		{
			mask=0x80;
			byte=gfxbuf[bitidx++];
		}
		branch1=gfxbuf[treeoffs+0+2*treeidx];
		branch0=gfxbuf[treeoffs+1+2*treeidx];
		branch=(byte&mask)?branch1:branch0;mask>>=1;
		if (branch&0x80)
		{
			unsigned char terminal;
			int n;
			terminal=branch&0x7f;
			if (lastterm==0 && outidx>3)
			{
				n=terminal-1;
				terminal=0;
				lastterm=1;
			} else {
				n=1;
				lastterm=terminal;
			}
			for (i=0;i<n && outidx<(SIZE_AUX_MEM+SIZE_MAIN_MEM);i++)
			{
				// 4*7 bit terminal symbols make up 7 pixels (4 Bit each)
				// however, they are spread out over 2 memory banks: AUX and MAIN memory.
				// mmmmmmmAAAAAAAmmmmmmmAAAAAAA
				if (!(outidx&1))
				{
					pixreg=terminal;
				} else {
					pixreg|=((unsigned int)terminal)<<(2*BITS_PER_SYMBOL);
					if (outidx>=SIZE_AUX_MEM)	// are we already in the MAIN memory?
					{			// the first 8192 output bytes were meant for the AUX memory
						pixreg<<=BITS_PER_SYMBOL;	// in MAIN memory, the other bits are written
					}
					if (colcnt==SYMBOLS_PER_LINE)		// at the end of the line
					{
						colcnt=0;
						linecnt++;
						if ((linecnt&3)==3)	// every 4th line does not exist
						{
							linecnt++;
							colcnt-=4;      // skip 4 terminal words
						}
						// calculate the line address
						oidx =((linecnt>>0)&0x3)<<6;            // bit 0,1 --> bit 6,7
						oidx|=((linecnt>>2)&0x7)<<3;            // bit 2,3,4 --> bit 3,4,5
						oidx|=((linecnt>>5)&0x7)<<0;            // bit 5,6,7 --> bit 0,1,2

						// line->linear buffer
						oidx*=pPicture->width;
					}

					if (colcnt>=0)
					{
						// the pixel information is spread out over AUX and MAIN memory.
						// 4*7=28 bits are used to store 7 pixels.
						// the bits are being read LSB  first, but only 7 bits of a byte are being used.
						// 
						// A0..A6 are the bits from the first byte in the AUX memory. Starting at 0x0000
						// B0..B6 are the bits from the second byte in the AUX memory.
						// M0..M6 are the bits from the first byte in the MAIN memory. Starting at 0x2000
						// N0..N6 are the bits from the second byte in the MAIN memory.
						pPicture->pixels[oidx+ 0]|=(pixreg&0xf);pixreg>>=4;	// A0 A1 A2 A3
						pPicture->pixels[oidx+ 1]|=(pixreg&0xf);pixreg>>=4;	// A4 A5 A6 M0
						pPicture->pixels[oidx+ 2]|=(pixreg&0xf);pixreg>>=4;	// M1 M2 M3 M4
						pPicture->pixels[oidx+ 3]|=(pixreg&0xf);pixreg>>=4;	// M5 M6 B0 B1
						pPicture->pixels[oidx+ 4]|=(pixreg&0xf);pixreg>>=4;	// B2 B3 B4 B5
						pPicture->pixels[oidx+ 5]|=(pixreg&0xf);pixreg>>=4;	// B6 N0 N1 N2
						pPicture->pixels[oidx+ 6]|=(pixreg&0xf);pixreg>>=4;	// N3 N4 N5 N6

						oidx+=PIXELS_PER_WHATEVER;
					}
					colcnt++;
				}
				outidx++;
				if (outidx==SIZE_AUX_MEM)
				{
					linecnt=0;
					colcnt=0;
					oidx=0;
				}
			}
			treeidx=0;
		} else {
			treeidx=branch;
		}
	}
	retval|=gfxloader_twice_as_wide(pPicture);
	return retval;
}


int gfxloader_unpackpic(tVM68k_ubyte* gfxbuf,tVM68k_ulong gfxsize,tVM68k_ubyte version,int picnum,char* picname,tdMagneticPicture* pPicture,int egamode)
{
	int retval;

	retval=0;
	picnum&=0x3f;	// there are no more than 30 pictures in each game. except Wonderland. 

	if (gfxbuf==NULL) return -1;
	if (gfxbuf[0]=='M' && gfxbuf[1]=='a' && gfxbuf[2]=='P' && pPicture!=NULL)
	{
		pPicture->width=pPicture->height=0;
		switch (gfxbuf[3])	// the header in the GFX files sets the format
		{

			case 'i':	retval=gfxloader_gfx1(gfxbuf,gfxsize,picnum,pPicture);break;		// standard .mag/gfx format
			case '2':	retval=gfxloader_gfx2(gfxbuf,gfxsize,picname,pPicture);break;		// taken from the magnetic windows .gfx files
			case '3':	retval=gfxloader_gfx3(gfxbuf,gfxsize,picnum,pPicture);break;		// ms dos
			case '4':	retval=gfxloader_gfx4(gfxbuf,gfxsize,picname,pPicture,egamode);break;	// read from magnetic windows resource files
			case '5':	retval=gfxloader_gfx5(gfxbuf,gfxsize,version,picnum,pPicture);break;	// C64
			case '6':	retval=gfxloader_gfx6(gfxbuf,gfxsize,picnum,pPicture);break;		// Amstrad CPC
			case '7':	retval=gfxloader_gfx7(gfxbuf,gfxsize,picnum,pPicture);break;		// AtariXL
			case '8':	retval=gfxloader_gfx8(gfxbuf,gfxsize,picnum,pPicture);break;		// Apple II
			default:
					break;
		}
	}
	return retval;
}

