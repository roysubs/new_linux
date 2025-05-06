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
#include "vm68k.h"
#include "vm68k_decode.h"
#include "vm68k_datatypes.h"
#include "vm68k_macros.h"
#include "vm68k_loadstore.h"




int vm68k_getbytesize(tVM68k_types size)
{
	switch(size)
	{
		case VM68K_BYTE: return 1;break;
		case VM68K_WORD: return 2;break;
		case VM68K_LONG: return 4;break;
		default: return 0;
	}
	return 0;
}
// the way addresses are stored here is that memory addresses are >=0. <=0 addresses the registers.

int vm68k_resolve_ea(tVM68k* pVM68k,tVM68k_next *pNext,tVM68k_types size,
	tVM68k_addrmodes addrmode,tVM68k_ubyte reg,
	tVM68k_uword legal,tVM68k_slong* ea)
{
	tVM68k_sbyte bytesize;
	int retval;
	retval=VM68K_NOK_UNKNOWN_INSTRUCTION;
	bytesize=vm68k_getbytesize(size);
	if (addrmode==VM68K_AM_EXT)
	{
		switch ((tVM68k_addrmode_ext)reg)
		{
			case VM68K_AMX_W:	if (legal&VM68K_LEGAL_AMX_W) 
						{
							*ea=(tVM68k_sword)READEXTENSIONWORD(pVM68k,pNext);
							retval=VM68K_OK;
						}
						break;
			case VM68K_AMX_L:	if (legal&VM68K_LEGAL_AMX_L) 
						{
							*ea=(tVM68k_slong)READEXTENSIONLONG(pVM68k,pNext);
							retval=VM68K_OK;
						}
						break;
			case  VM68K_AMX_data:	if (legal&VM68K_LEGAL_AMX_DATA)
						{ 
							*ea=pNext->pcr;
							retval=VM68K_OK;
							switch (size)
							{
								case VM68K_BYTE: *ea+=1;pNext->pcr+=2;break;
								case VM68K_WORD: pNext->pcr+=2;break;
								case VM68K_LONG: pNext->pcr+=4;break;
								default: retval=VM68K_NOK_UNKNOWN_INSTRUCTION;
							}
						}
						break;
			case VM68K_AMX_PC: if (legal&VM68K_LEGAL_AMX_PC)
					   {
						   *ea=READEXTENSIONWORD(pVM68k,pNext);
						   *ea=(tVM68k_sword)(*ea)+pVM68k->pcr;
						   retval=VM68K_OK;
					   }
					   break;
			case VM68K_AMX_INDEX_PC: if (legal&VM68K_LEGAL_AMX_INDEX_PC)
					     {
						     *ea=READEXTENSIONWORD(pVM68k,pNext);
						     *ea=*ea+pVM68k->pcr;
						     *ea=*ea+pVM68k->a[reg]*bytesize;	// TODO: data or addrreg?
						     retval=VM68K_NOK_UNKNOWN_INSTRUCTION;	// TODO: lets decide when we stumble upon this mode
					     }
					     break;
		}
	} else {
		switch (addrmode)
		{
			case VM68K_AM_DATAREG:	if (legal&VM68K_LEGAL_AM_DATAREG)
						{
							*ea=DATAREGADDR(reg);
							retval=VM68K_OK;
						}
						break;
			case VM68K_AM_ADDRREG:	if (legal&VM68K_LEGAL_AM_ADDRREG)
						{
							*ea=ADDRREGADDR(reg);
							retval=VM68K_OK;
						}
						break;
			case VM68K_AM_INDIR:	if (legal&VM68K_LEGAL_AM_INDIR)
						{
							*ea=(pVM68k->a[reg])%pVM68k->memsize;
							retval=VM68K_OK;
						}
						break;
			case VM68K_AM_POSTINC:	if (legal&VM68K_LEGAL_AM_POSTINC)
						{
							*ea=pVM68k->a[reg];
							pNext->a[reg]+=bytesize;
							retval=VM68K_OK;
						}
						break;
			case VM68K_AM_PREDEC:	if (legal&VM68K_LEGAL_AM_PREDEC)
						{
							pNext->a[reg]-=bytesize;
							*ea=pNext->a[reg];
							retval=VM68K_OK;
						}
						break;
			case VM68K_AM_DISP16:	if (legal&VM68K_LEGAL_AM_DISP16)
						{
							*ea=(tVM68k_sword)READEXTENSIONWORD(pVM68k,pNext);
							*ea=(*ea)+pVM68k->a[reg];
							retval=VM68K_OK;
						}
						break;
			case VM68K_AM_INDEX:	if (legal&VM68K_LEGAL_AM_INDEX)
						{
							tVM68k_uword extword;
							// bit 15: =0 data, =1 addr reg
							// bit 14..12: regnum
							// bit 11: =0 index register is a signed word
							//         =1 index register is a signed long
							// bit 10..8: UNKNOWN
							// bit 7..0: displacement, signed byte
							tVM68k_ubyte regX;
							tVM68k_sbyte displacement1;
							tVM68k_slong displacement2l;
							tVM68k_sword displacement2w;

							extword=(tVM68k_uword)READEXTENSIONWORD(pVM68k,pNext);
							regX=(extword>>12)&0x7;
							displacement1=(extword&0xff);
							if ((extword>>15)&1)
							{
								displacement2l=pVM68k->a[regX];
								displacement2w=(pVM68k->a[regX]&0xffff);
							} else {
								displacement2l=pVM68k->d[regX];
								displacement2w=(pVM68k->d[regX]&0xffff);
							}
							*ea=displacement1+(((extword>>11)&1)?displacement2l:displacement2w);
							*ea=(*ea)+pVM68k->a[reg];
							retval=VM68K_OK;

						}
						break;
			default: retval=VM68K_NOK_INVALID_PTR;break;
		}
	}
	return retval;
}

// the way addresses are stored here is that memory addresses are >=0. <=0 addresses the registers.
int vm68k_fetchoperand(tVM68k* pVM68k,tVM68k_bool extendsign,tVM68k_types size,tVM68k_slong ea,tVM68k_ulong* operand)
{
	int retval;
	tVM68k_ulong op;
	op=0;
	if (ea>=0)	// memory address
	{
		ea%=pVM68k->memsize;	// just to be safe...
		retval=VM68K_OK;
		switch (size)
		{
			case VM68K_BYTE: op= READ_INT8BE(pVM68k->memory,ea);break;
			case VM68K_WORD: op=READ_INT16BE(pVM68k->memory,ea);break;
			case VM68K_LONG: op=READ_INT32BE(pVM68k->memory,ea);break;
			default: retval=VM68K_NOK_INVALID_PTR;break;
		}
	} else {	// register address
		if (ea>=DATAREGADDR(7) && ea<=DATAREGADDR(0))
		{
			op=pVM68k->d[-ea+DATAREGADDR(0)];
			retval=VM68K_OK;
		}
		else if (ea>=ADDRREGADDR(7) && ea<=ADDRREGADDR(0))
		{
			op=pVM68k->a[-ea+ADDRREGADDR(0)];
			retval=VM68K_OK;
		}
		else retval=VM68K_NOK_UNKNOWN_INSTRUCTION;
	}
	switch (size)
	{
		case VM68K_BYTE: op&=  0xff;if (extendsign) op=(tVM68k_slong)((tVM68k_sbyte)op);break;
		case VM68K_WORD: op&=0xffff;if (extendsign) op=(tVM68k_slong)((tVM68k_sword)op);break;
		default: 
			break;
	}
	*operand=op;
	return retval;
}
int vm68k_calculateflags(tVM68k_next* pNext,tVM68k_ubyte flagmask,tVM68k_types size,tVM68k_ulong operand1,tVM68k_ulong operand2,tVM68k_uint64 result)
{
	tVM68k_ubyte msb;
	tVM68k_ulong mask;
	tVM68k_sint64 maxval,minval;
	tVM68k_sint64 res;
	int retval;

	retval=VM68K_OK;
	mask=0;
	msb=0;
	maxval=0;
	minval=0;
	res=0;
	switch (size)
	{
		case VM68K_BYTE:	msb= 8;mask=      0xff;maxval=      0x7fll;minval=      -0x80ll;res=((tVM68k_sint64)((tVM68k_sbyte)(result&      0xff)));break;
		case VM68K_WORD:	msb=16;mask=    0xffff;maxval=    0x7fffll;minval=    -0x8000ll;res=((tVM68k_sint64)((tVM68k_sbyte)(result&    0xffff)));break;
		case VM68K_LONG:	msb=32;mask=0xffffffff;maxval=0x7fffffffll;minval=-0x80000000ll;res=((tVM68k_sint64)((tVM68k_sbyte)(result&0xffffffff)));break;
		default: retval=VM68K_NOK_INVALID_PTR;break;
	}
	if (flagmask&FLAGC) pNext->cflag=((operand2^result)>>msb)&1;
	if (flagmask&FLAGZ) pNext->zflag=((result&mask)==0);
	if (flagmask&FLAGN) pNext->nflag=(result>>(msb-1))&1;
//	if (flagmask&FLAGV) pNext->vflag=((operand1^operand2^result)>>(msb-1))&1;
	//if (flagmask&FLAGV) pNext->vflag=((~(operand1^operand2)^result)>>(msb-1))&1;
	if (flagmask&FLAGV) pNext->vflag=((res>maxval)||(res<minval));
	if (flagmask&FLAGX) pNext->xflag=pNext->cflag;
	if (flagmask&FLAGCZCLR) {pNext->cflag=0;pNext->vflag=0;}

	return retval;
}
int vm68k_calculateflags2(tVM68k_next* pNext,tVM68k_ubyte flagmask,tVM68k_instruction instruction,tVM68k_types datatype,tVM68k_ulong operand1,tVM68k_ulong operand2,tVM68k_uint64 result)
{
	tVM68k_bool	msb1,msb2,msbres;
	int retval=VM68K_OK;
	msb1=msb2=msbres=0;
	switch(datatype)
	{
		case VM68K_BYTE:	msb1=(operand1>> 7)&1;msb2=(operand2>> 7)&1;msbres=(result>> 7)&1;break;
		case VM68K_WORD:	msb1=(operand1>>15)&1;msb2=(operand2>>15)&1;msbres=(result>>15)&1;break;
		case VM68K_LONG:	msb1=(operand1>>31)&1;msb2=(operand2>>31)&1;msbres=(result>>31)&1;break;
		default: retval=VM68K_NOK_INVALID_PTR;break;
	}
	pNext->zflag=(result==0);
	pNext->nflag=(msbres);
	switch (instruction)
	{
		case VM68K_INST_ADD:
		case VM68K_INST_ADDA:
		case VM68K_INST_ADDI:
		case VM68K_INST_ADDQ:
		case VM68K_INST_ADDX:
//              sr[0] <= (`Sm & `Dm) | (~`Rm & `Dm) | (`Sm & ~`Rm);
//              sr[1] <= (`Sm & `Dm & ~`Rm) | (~`Sm & ~`Dm & `Rm);
			pNext->cflag=(msb1&msb2)|((!msbres)&msb2)|(msb1&(!msbres));
			pNext->xflag=pNext->cflag;
			pNext->vflag=(msb1&msb2&(!msbres))|((!msb1)&(!msb2)&msbres);
			break;
		case VM68K_INST_SUB:
		case VM68K_INST_SUBA:
		case VM68K_INST_SUBI:
		case VM68K_INST_SUBQ:
		case VM68K_INST_SUBX:
//                   sr[0] <= (`Sm & ~`Dm) | (`Rm & ~`Dm) | (`Sm & `Rm);
//                   sr[1] <= (~`Sm & `Dm & ~`Rm) | (`Sm & ~`Dm & `Rm);
			pNext->cflag=(msb1&(!msb2))|(msbres&(!msb2))|(msb1&msbres);
			pNext->xflag=pNext->cflag;
			pNext->vflag=((!msb1)&msb2&(!msbres))|(msb1&(!msb2)&msbres);
			break;

		case VM68K_INST_CMP:
		case VM68K_INST_CMPA:
		case VM68K_INST_CMPI:
		case VM68K_INST_CMPM:
//                   sr[0] <= (`Sm & ~`Dm) | (`Rm & ~`Dm) | (`Sm & `Rm);
//                   sr[1] <= (~`Sm & `Dm & ~`Rm) | (`Sm & ~`Dm & `Rm);
			pNext->cflag=(msb1&(!msb2))|(msbres&(!msb2))|(msb1&msbres);
			pNext->vflag=((!msb1)&msb2&(!msbres))|(msb1&(!msb2)&msbres);
			break;

		case VM68K_INST_AND:
		case VM68K_INST_EOR:
		case VM68K_INST_OR:
		case VM68K_INST_ANDI:
		case VM68K_INST_EORI:
		case VM68K_INST_ORI:
		default:
			pNext->cflag=0;
			pNext->vflag=0;
			break;

	}
	return retval;
}
int vm68k_storeresult(tVM68k* pVM68k,tVM68k_next* pNext,tVM68k_types size,tVM68k_slong ea,tVM68k_ulong result)
{
	int retval;
	tVM68k_ulong uppermask;
	tVM68k_ulong lowermask;

	retval=VM68K_NOK_UNKNOWN_INSTRUCTION;
	switch (size)
	{
		case VM68K_BYTE:uppermask=0xffffff00;lowermask=~uppermask;break;
		case VM68K_WORD:uppermask=0xffff0000;lowermask=~uppermask;break;
		case VM68K_LONG:uppermask=0x00000000;lowermask=~uppermask;break;
		default: return 0;
	}
	if (ea>=0)	// memory address
	{
		retval=VM68K_OK;
		ea%=pVM68k->memsize;	// just to be safe...
		pNext->mem_size=size;
		pNext->mem_addr[pNext->mem_we]=ea;
		pNext->mem_value[pNext->mem_we]=result&lowermask;
		pNext->mem_we++;
	} else {	// register address
		if (ea>=DATAREGADDR(7) && ea<=DATAREGADDR(0))
		{
			int reg;
			reg=-ea+DATAREGADDR(0);
			pNext->d[reg]&=uppermask;
			pNext->d[reg]|=(result&lowermask);
			retval=VM68K_OK;
		}
		else if (ea>=ADDRREGADDR(7) && ea<=ADDRREGADDR(0))
		{
			int reg;
			reg=-ea+ADDRREGADDR(0);
			pNext->a[reg]&=uppermask;
			pNext->a[reg]|=(result&lowermask);
			retval=VM68K_OK;
		}
	}
	return retval;
}
