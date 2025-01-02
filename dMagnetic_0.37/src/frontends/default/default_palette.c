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
#include "default_palette.h"
#include "dMagnetic.h"


/// this lookuptable has the following structure:
/// 4 bits substitute color, 3x4 bit RGB values.
/// this is a direct 1 <--> 1 conversion.
const unsigned short rgblut[]={
	0x0000,0x1400,0x3420,0x4004,0x5404,0x6044,0x7444,0x8222,0x9722,0xa272,0xb772,0xc227,0xd727,0xe277,0xf777,0x2121,
	0xb554,0x9654,0x6454,0xa452,0x4223,0x7455,0x2342,0x8333,0x1322,0x7443,0x2230,0xc456,0xe565,0x7555,0xb653,0x0110,
	0x4334,0xf666,0xe665,0x3553,0x1210,0x3432,0x2332,0xc444,0xa665,0x7332,0xb665,0xf775,0xb442,0x2232,0x6122,0xc223,
	0x8111,0x5212,0x4112,0xb631,0x3310,0x8211,0x1410,0x9520,0x2221,0x0100,0xb742,0xb740,0x9731,0x9620,0xa351,0xe454,
	0xb460,0x6343,0x2243,0xc354,0x0121,0xb443,0x3331,0x3332,0xf565,0x2341,0x8221,0x3321,0xa040,0xa450,0xb550,0x9763,
	0x1100,0x0111,0xb664,0x9754,0xb753,0x3642,0x1211,0x5433,0xc556,0xb552,0x3441,0x0011,0xe566,0xe344,0xf677,0x6233,
	0x4222,0x3221,0xe676,0xc445,0x0222,0x3543,0x0010,0x2120,0x5101,0xc667,0xb663,0x1311,0x9533,0x0001,0x6455,0x9655,
	0x1200,0x3110,0x4001,0x9543,0xd544,0x6011,0x9652,0xb764,0xc123,0xe234,0xc224,0x1542,0x6022,0x5323,0xc555,0x9432,
	0x3431,0x8110,0x9422,0xb520,0xc567,0xa352,0xe466,0x6344,0x7333,0x9433,0x2030,0x1510,0x2231,0xd704,0x2020,0xc005,
	0x9544,0x8433,0xa453,0x9322,0x3532,0x7665,0xa565,0x9733,0xf776,0xb765,0x4445,0x1432,0xb774,0x5322,0xa573,0xe563,
	0x3210,0xa673,0x9700,0xf675,0xf665,0xf555,0xf554,0xc334,0xe675,0xd766,0xa564,0x9775,0x7554,0x3440,0x8554,0x0333,
	0x0332,0xc335,0x1433,0xd655,0xd645,0x7544,0x1644,0xd755,0xb775,0x3443,0xc345,0xa342,0x8443,0xc236,0x1623,0x9743,
	0xb762,0x2151,0x5507,0xd606,0xd767,0xa675,0x8122,0xa343,0x0245,0x1402,0x4024,0xc245,0x6133,0x5313,0x5202,0xb630,
	0x4012,0xe345,0xc234,0xa332,0x3320
};
#define	RGBLUTSIZE	213
// another strategy would be to calculate the center of the clusters that make up the 16 colors.
const unsigned int rgbcenters[16]={0x0aa36cc2,0x217380c2,0x0f77049d,0x20f678b2,0x0c23cdb6,0x1b6249b6,0x107789c5,0x2799e638,0x16d57924,0x3487fd74,0x236c457f,0x366ba166,0x1be82eda,0x3ad81f1b,0x26dcbeda,0x36ce6323};
int default_findrgbcluster(int red,int green,int blue)
{
	int i;
	int closest=0;
	int mindelta=-1;
	int delta;
	int r0,r1,g0,g1,b0,b1;

	r0=red;
	g0=green;
	b0=blue;
#if 0
// if I ever want to calculate better rgb centers.
	{
		int rgbsums[16][3]={{0}};
		int colcnt[16]={0};
		for (i=0;i<RGBLUTSIZE;i++)
		{
			int col;
			col	=(rgblut[i]>>12)&0xf;
			red	=(rgblut[i]>> 8)&0xf;
			green	=(rgblut[i]>> 4)&0xf;
			blue	=(rgblut[i]>> 0)&0xf;

			rgbsums[col][0]+=red;
			rgbsums[col][1]+=green;
			rgbsums[col][2]+=blue;
			colcnt[col]+=7;
		}
		printf("const unsigned int rgbcenters[16]={");
		for (i=0;i<16;i++)
		{
			rgbsums[i][0]*=PICTURE_MAX_RGB_VALUE;
			rgbsums[i][1]*=PICTURE_MAX_RGB_VALUE;
			rgbsums[i][2]*=PICTURE_MAX_RGB_VALUE;

			rgbsums[i][0]/=(colcnt[i]);
			rgbsums[i][1]/=(colcnt[i]);
			rgbsums[i][2]/=(colcnt[i]);

			rgbcenters[i]=(rgbsums[i][0]<<20)|(rgbsums[i][1]<<10)|(rgbsums[i][2]);

			printf("0x%08x,",rgbcenters[i]);
		}
		printf("};\n");
	}
#endif
	for (i=0;i<16;i++)
	{
		r1=(rgbcenters[i]>>20)&0x3ff;
		g1=(rgbcenters[i]>>10)&0x3ff;
		b1=(rgbcenters[i]>> 0)&0x3ff;


		delta =(r0-r1)*(r0-r1);
		delta+=(g0-g1)*(g0-g1);
		delta+=(b0-b1)*(b0-b1);
		if (delta<mindelta || i==0)
		{
			closest=i;
			mindelta=delta;

		}

	}
	return closest;
}

int default_palette(tdMagneticPicture* picture,unsigned char* maxplut)
{
	int i,j;
	int total;
	unsigned char ansicols[16][16];
	int numcols[16];
	int maxi;
	int maxcols;
#define	BITCNT(x)	(	\
	(((x)>>15)&1)+ (((x)>>14)&1)+ (((x)>>13)&1)+ (((x)>>12)&1)+	\
	(((x)>>11)&1)+ (((x)>>10)&1)+ (((x)>> 9)&1)+ (((x)>> 8)&1)+	\
	(((x)>> 7)&1)+ (((x)>> 6)&1)+ (((x)>> 5)&1)+ (((x)>> 4)&1)+	\
	(((x)>> 3)&1)+ (((x)>> 2)&1)+ (((x)>> 1)&1)+ (((x)>> 0)&1))
	// each rgb from the pictures has been assigned one or more alternative
	// ANSI colors. this method is searching for a combination of alternatives
	// that is most diverse.

	total=1;
	// step 1: collect the alternatives
	for (i=0;i<16;i++)
	{
		unsigned int rgb;
		rgb=picture->palette[i];

		{
			int red,green,blue;
			red=	PICTURE_GET_RED(rgb);
			green=	PICTURE_GET_GREEN(rgb);
			blue=	PICTURE_GET_BLUE(rgb);

			red*=7;green*=7;blue*=7;
			red+=(PICTURE_MAX_RGB_VALUE/2);
			green+=(PICTURE_MAX_RGB_VALUE/2);
			blue+=(PICTURE_MAX_RGB_VALUE/2);
			red/=PICTURE_MAX_RGB_VALUE;green/=PICTURE_MAX_RGB_VALUE;blue/=PICTURE_MAX_RGB_VALUE;

			rgb=(red<<8)|(green<<4)|blue;
		}

		numcols[i]=0;
		for (j=0;j<RGBLUTSIZE;j++)
		{
			if (rgb==(rgblut[j]&0xfff))
			{
				// the RGB lut does not have any doubles.
				// so if there is a match, i can remember it as an alternative.
				ansicols[i][numcols[i]++]=(rgblut[j]>>12)&0xf;
			}
		}
		// plan B: if there has been no direct match, make sure there is at least one alternative
		if (numcols[i]==0)
		{
			ansicols[i][numcols[i]++]=default_findrgbcluster(PICTURE_GET_RED(picture->palette[i]),PICTURE_GET_GREEN(picture->palette[i]),PICTURE_GET_BLUE(picture->palette[i]));
		}
		total*=numcols[i];
		if (total>=16777216) total=16777216;	// arbitrary upper limit. i do not want to do the "pondering..." for too long.
	}
	maxcols=0;
	maxi=0;
	// step 2: go through all the possible combinations and see which one is the most diverse.
	for (i=0;i<total;i++)
	{
		int idx;
		unsigned short mask;
		int bitcnt;
		idx=i;
		mask=0;
		for (j=0;j<16;j++)
		{
			unsigned char c;
			// so... each rgb color has a number of alternatives.
			// this is a way of going through all of them.
			c=ansicols[j][idx%numcols[j]];
			idx/=numcols[j];
			mask|=(1<<c);	//remember what ansi color is being used in this combination.
		}
		// evaluate the current combination
		bitcnt=BITCNT(mask);	// this is one way to do it
		if (bitcnt>maxcols)	// more colors in this combination-> more bits in the mask -> more diversity in the final picture.
		{
			maxcols=bitcnt;
			maxi=i;		// best combination so far.
		}
	}
	// at this point, maxi is the most diverse combination.
	// step 3: map it to the output palette
	for (i=0;i<16;i++)
	{
		maxplut[i]=ansicols[i][maxi%numcols[i]];
		maxi/=numcols[i];
	}

	return 0;

}



