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

#ifndef	VM68K_MACROS_H
#define	VM68K_MACROS_H
#include "vm68k_datatypes.h"
// the gfx2 format introduced MIXED ENDIAN. 
#define READ_INT32ME(ptr,idx)   (\
		(((tVM68k_ulong)((ptr)[((idx)+1)])&0xff)<<24)   |\
		(((tVM68k_ulong)((ptr)[((idx)+0)])&0xff)<<16)   |\
		(((tVM68k_ulong)((ptr)[((idx)+3)])&0xff)<< 8)   |\
		(((tVM68k_ulong)((ptr)[((idx)+2)])&0xff)<< 0)   |\
		0)


#define	READ_INT32BE(ptr,idx)	(\
		(((tVM68k_ulong)((ptr)[((idx)+0)])&0xff)<<24)	|\
		(((tVM68k_ulong)((ptr)[((idx)+1)])&0xff)<<16)	|\
		(((tVM68k_ulong)((ptr)[((idx)+2)])&0xff)<< 8)	|\
		(((tVM68k_ulong)((ptr)[((idx)+3)])&0xff)<< 0)	|\
		0)
#define	READ_INT16BE(ptr,idx)	(\
		(((tVM68k_ulong)((ptr)[((idx)+0)])&0xff)<< 8)	|\
		(((tVM68k_ulong)((ptr)[((idx)+1)])&0xff)<< 0)	|\
		0)
#define	READ_INT8BE(ptr,idx)	(\
		(((tVM68k_ulong)((ptr)[((idx)+0)])&0xff)<< 0)	|\
		0)

#define	READ_INT32LE(ptr,idx)	(\
		(((unsigned int)((ptr)[((idx)+3)])&0xff)<<24)	|\
		(((unsigned int)((ptr)[((idx)+2)])&0xff)<<16)	|\
		(((unsigned int)((ptr)[((idx)+1)])&0xff)<< 8)	|\
		(((unsigned int)((ptr)[((idx)+0)])&0xff)<< 0)	|\
		0)
#define	READ_INT16LE(ptr,idx)	(\
		(((unsigned int)((ptr)[((idx)+1)])&0xff)<< 8)	|\
		(((unsigned int)((ptr)[((idx)+0)])&0xff)<< 0)	|\
		0)
#define	READ_INT8LE(ptr,idx)	(\
		(((unsigned int)((ptr)[((idx)+0)])&0xff)<< 0)	|\
		0)


#define	WRITE_INT32BE(ptr,idx,val) {\
	(ptr)[(idx)+3]=((tVM68k_ubyte)((val)>> 0)&0xff);	\
	(ptr)[(idx)+2]=((tVM68k_ubyte)((val)>> 8)&0xff);	\
	(ptr)[(idx)+1]=((tVM68k_ubyte)((val)>>16)&0xff);	\
	(ptr)[(idx)+0]=((tVM68k_ubyte)((val)>>24)&0xff);	\
}
#define	WRITE_INT16BE(ptr,idx,val) {\
	(ptr)[(idx)+1]=((tVM68k_ubyte)((val)>> 0)&0xff);	\
	(ptr)[(idx)+0]=((tVM68k_ubyte)((val)>> 8)&0xff);	\
}
#define	WRITE_INT8BE(ptr,idx,val) {\
	(ptr)[(idx)+0]=((tVM68k_ubyte)((val)>> 0)&0xff);	\
}

#define	WRITE_INT32LE(ptr,idx,val) {\
	(ptr)[(idx)+0]=((unsigned char)((val)>> 0)&0xff);	\
	(ptr)[(idx)+1]=((unsigned char)((val)>> 8)&0xff);	\
	(ptr)[(idx)+2]=((unsigned char)((val)>>16)&0xff);	\
	(ptr)[(idx)+3]=((unsigned char)((val)>>24)&0xff);	\
}
#define	WRITE_INT16LE(ptr,idx,val) {\
	(ptr)[(idx)+0]=((unsigned char)((val)>> 0)&0xff);	\
	(ptr)[(idx)+1]=((unsigned char)((val)>> 8)&0xff);	\
}
#define	WRITE_INT8LE(ptr,idx,val) {\
	(ptr)[(idx)+0]=((unsigned char)((val)>> 0)&0xff);	\
}


#define	INITNEXT(pVM68k,next)	\
	(next).pcr=(pVM68k)->pcr;	\
	(next).a[0]=(pVM68k)->a[0];	\
	(next).a[1]=(pVM68k)->a[1];	\
	(next).a[2]=(pVM68k)->a[2];	\
	(next).a[3]=(pVM68k)->a[3];	\
	(next).a[4]=(pVM68k)->a[4];	\
	(next).a[5]=(pVM68k)->a[5];	\
	(next).a[6]=(pVM68k)->a[6];	\
	(next).a[7]=(pVM68k)->a[7];	\
	(next).d[0]=(pVM68k)->d[0];	\
	(next).d[1]=(pVM68k)->d[1];	\
	(next).d[2]=(pVM68k)->d[2];	\
	(next).d[3]=(pVM68k)->d[3];	\
	(next).d[4]=(pVM68k)->d[4];	\
	(next).d[5]=(pVM68k)->d[5];	\
	(next).d[6]=(pVM68k)->d[6];	\
	(next).d[7]=(pVM68k)->d[7];	\
	(next).override_sr=0;		\
	(next).sr=((pVM68k)->sr);	\
	(next).cflag=((pVM68k)->sr>>0)&1;	\
	(next).vflag=((pVM68k)->sr>>1)&1;	\
	(next).zflag=((pVM68k)->sr>>2)&1;	\
	(next).nflag=((pVM68k)->sr>>3)&1;	\
	(next).xflag=((pVM68k)->sr>>4)&1;	\
	(next).mem_we=0;	\
	(next).mem_addr[0]=0;	\
	(next).mem_size=0;	\
	(next).mem_value[0]=0;


#define	WRITEFLAGS(pVM68k,transaction)	\
	(pVM68k)->sr|=(tVM68k_uword)((transaction).cflag)<<0;	\
	(pVM68k)->sr|=(tVM68k_uword)((transaction).vflag)<<1;	\
	(pVM68k)->sr|=(tVM68k_uword)((transaction).zflag)<<2;	\
	(pVM68k)->sr|=(tVM68k_uword)((transaction).nflag)<<3;	\
	(pVM68k)->sr|=(tVM68k_uword)((transaction).xflag)<<4;

#define	READEXTENSIONBYTE(pVM68k,pNext)	READ_INT8BE((pVM68k)->memory,(pNext)->pcr+1);(pNext)->pcr+=2;
#define	READEXTENSIONWORD(pVM68k,pNext)	READ_INT16BE((pVM68k)->memory,(pNext)->pcr);(pNext)->pcr+=2;
#define	READEXTENSIONLONG(pVM68k,pNext)	READ_INT32BE((pVM68k)->memory,(pNext)->pcr);(pNext)->pcr+=4;

#define	READEXTENSION(pVM68k,pNext,datatype,operand)	\
	switch (datatype)	\
{	\
	case VM68K_BYTE:	operand=READEXTENSIONBYTE(pVM68k,pNext);break;	\
	case VM68K_WORD:	operand=READEXTENSIONWORD(pVM68k,pNext);break;	\
	case VM68K_LONG:	operand=READEXTENSIONLONG(pVM68k,pNext);break;	\
	default:		operand=0;break;	\
}

#define	READSIGNEDEXTENSION(pVM68k,pNext,datatype,operand)	\
	switch (datatype)	\
{	\
	case VM68K_BYTE:	operand=READEXTENSIONBYTE(pVM68k,pNext);operand=(tVM68k_slong)((tVM68k_sbyte)((operand)&  0xff));break;	\
	case VM68K_WORD:	operand=READEXTENSIONBYTE(pVM68k,pNext);operand=(tVM68k_slong)((tVM68k_sword)((operand)&0xffff));break;	\
	case VM68K_LONG:	operand=READEXTENSIONLONG(pVM68k,pNext);break;	\
}

#define	PUSHWORDTOSTACK(pVM68k,pNext,x)	{(pNext)->a[7]-=2;(pNext)->mem_addr[(pNext)->mem_we]=(pNext)->a[7];(pNext)->mem_size=VM68K_WORD;(pNext)->mem_value[(pNext)->mem_we]=x;(pNext)->mem_we++;}
#define	PUSHLONGTOSTACK(pVM68k,pNext,x)	{(pNext)->a[7]-=4;(pNext)->mem_addr[(pNext)->mem_we]=(pNext)->a[7];(pNext)->mem_size=VM68K_LONG;(pNext)->mem_value[(pNext)->mem_we]=x;(pNext)->mem_we++;}

#define	POPWORDFROMSTACK(pVM68k,pNext,x)	{tVM68k_uword y;y=READ_INT16BE((pVM68k)->memory,(pNext)->a[7]);(pNext)->a[7]+=2;x=((x)&0xffff0000)|(y&0xffff);}
#define	POPLONGFROMSTACK(pVM68k,pNext,x)	{x=READ_INT32BE((pVM68k)->memory,(pNext)->a[7]);(pNext)->a[7]+=4;}


#endif
