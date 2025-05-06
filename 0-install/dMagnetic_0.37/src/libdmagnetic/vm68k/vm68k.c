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

#include "vm68k_datatypes.h"
#include "vm68k_decode.h"
#include "vm68k_loadstore.h"
#include "vm68k_macros.h"
#include "vm68k.h"

#define	MAGICVALUE		0x564A3638	// "VM68"

tVM68k_bool vm68k_checkcondition(tVM68k* pVM68k,tVM68k_ubyte condition)
{               
#define	CFLAG(pVM68k)	((((pVM68k)->sr)>>0)&1)
#define	VFLAG(pVM68k)	((((pVM68k)->sr)>>1)&1)
#define	ZFLAG(pVM68k)	((((pVM68k)->sr)>>2)&1)
#define	NFLAG(pVM68k)	((((pVM68k)->sr)>>3)&1)
#define	XFLAG(pVM68k)	((((pVM68k)->sr)>>4)&1)

	tVM68k_bool     condtrue;
	switch(condition)
	{
		case  0: condtrue=1;break;
		case  1: condtrue=0;break;
		case  2: //BHI high 0010 /C | /Z
			 condtrue=!(CFLAG(pVM68k)|ZFLAG(pVM68k));
			 break; 
		case  3: //LS low or same 0011 C & Z
			 condtrue= (CFLAG(pVM68k)|ZFLAG(pVM68k));
			 break; 
		case  4://BCC carry clear 0100 /C
			 condtrue=!(CFLAG(pVM68k)); 
			 break; 
		case  5://BCS carry set 0101 C
			 condtrue= (CFLAG(pVM68k));
			 break;
		case  6://BNE not equal 0110 /Z
			 condtrue=!(ZFLAG(pVM68k));
			 break;
		case  7://BEQ equal 0111 Z
			 condtrue= (ZFLAG(pVM68k));
			 break;
		case  8://BVC overflow clear 1000 /V
			 condtrue=!(VFLAG(pVM68k));
			 break;
		case  9://BVS overflow set 1001 V 
			 condtrue= (VFLAG(pVM68k));
			 break;
		case 10://BPL plus 1010 /N
			 condtrue=!(NFLAG(pVM68k));
			 break;
		case 11://BMI minus 1011 N
			 condtrue= (NFLAG(pVM68k));
			 break;
		case 12://BGE greater or equal 1100 (N & V) | (/N & /V), N and V are both set or both clear
			 condtrue=!((NFLAG(pVM68k)^VFLAG(pVM68k)));
			 break;
		case 13://BLT less than  1101 (N & /V) | (/N & V), N and V are either set or clear
			 condtrue= ((NFLAG(pVM68k)^VFLAG(pVM68k)));
			 break;
		case 14://BGT greater than 1110 (N & V & /Z) | (/N & /V & /Z)
			 condtrue=!ZFLAG(pVM68k)&!((NFLAG(pVM68k)^VFLAG(pVM68k)));
			 break;
		case 15://BLE less or equal 1111 
			 condtrue=ZFLAG(pVM68k)|((NFLAG(pVM68k)^VFLAG(pVM68k)));
			 break;
		default:
			 condtrue=0;
			 break;
	}
	return condtrue;
}




int vm68k_getsize(int* size)
{
	if (size==NULL) return VM68K_NOK_INVALID_PTR;

	*size=sizeof(tVM68k);
	return	VM68K_OK;
}

int vm68k_init(void* hVM68k,int version)
{
	tVM68k* pVM68k=(tVM68k*)hVM68k;
	if (hVM68k==NULL) return VM68K_NOK_INVALID_PTR;

	pVM68k->magic=MAGICVALUE;
	pVM68k->pcr=0;
	pVM68k->memsize=sizeof(pVM68k->memory);
	pVM68k->a[7]=pVM68k->memsize-4;		// The stack pointer goes to the end of the memory

	pVM68k->version=version;

	return	VM68K_OK;

}
int vm68k_singlestep(void *hVM68k,unsigned short opcode)
{
	tVM68k* pVM68k=(tVM68k*)hVM68k;
	tVM68k_instruction	instruction;
	tVM68k_ubyte		addrmode;
	tVM68k_ubyte		reg1,reg2;
	tVM68k_types		datatype;
	tVM68k_next		next;

	tVM68k_slong		ea;
	tVM68k_ulong		operand1,operand2;
	tVM68k_uint64		result;

	tVM68k_ubyte		condition;
	tVM68k_sword		displacement;
	tVM68k_bool		direction;

	int retval;
	int i;

	if (hVM68k==NULL) return VM68K_NOK_INVALID_PTR;
	if (pVM68k->magic!=MAGICVALUE) return VM68K_NOK_INVALID_PARAMETER;

	retval=VM68K_NOK_UNKNOWN_INSTRUCTION;

	instruction=vm68k_decode(opcode);
	// decode the opcode
	reg1=(opcode>>9)&0x7;
	addrmode=(opcode>>3)&0x7;
	reg2=(opcode>>0)&0x7;
	datatype=(tVM68k_types)(opcode>>6)&0x3;


	// branches
	condition=(opcode>>8)&0xf;
	displacement=(tVM68k_sword)((tVM68k_sbyte)(opcode&0xff));

	// alu operations
	direction=(opcode>>8)&0x1;

	INITNEXT(pVM68k,next);
	result=0;
	operand1=operand2=0;
	switch(instruction)
	{
		case VM68K_INST_TRAP:
			printf("\x1b[1;37;42mtrap #%d\n",opcode&0xf);
			for (i=0;i<16;i++)
			{
				printf(" ** trap %d stack %2d %08X \n",opcode&0xf,i,READ_INT32BE(pVM68k->memory,pVM68k->a[7]-i*4));
			}
			printf("\x1b[0m\n");
			retval=VM68K_OK;
			break;
		case VM68K_INST_MULU:
			retval=vm68k_resolve_ea(pVM68k,&next,VM68K_WORD,addrmode,reg2,VM68K_LEGAL_ALL,&ea);
			if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,0,VM68K_WORD,ea,&operand1);
			if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,0,VM68K_WORD,DATAREGADDR(reg1),&operand2);
			if (retval==VM68K_OK) result=((unsigned int)operand1&0xffff)*((unsigned short)operand2&0xffff);
			if (retval==VM68K_OK) retval=vm68k_calculateflags2(&next,FLAGS_ALL,instruction,VM68K_LONG,operand1,operand2,result);
			if (retval==VM68K_OK) retval=vm68k_storeresult(pVM68k,&next,VM68K_LONG,DATAREGADDR(reg1),result);
			break;
		case VM68K_INST_DIVU:
			// FIXME: division by 0?
			retval=vm68k_resolve_ea(pVM68k,&next,VM68K_WORD,addrmode,reg2,VM68K_LEGAL_ALL,&ea);
			if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,0,VM68K_WORD,ea,&operand1);
			if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,0,VM68K_WORD,DATAREGADDR(reg1),&operand2);
			// upper 16 bits are the remainder
			if (retval==VM68K_OK) result=(((unsigned int)operand1&0xffff)%((unsigned short)operand2&0xffff))<<16;
			// lower 16 bits are the quotient
			if (retval==VM68K_OK) result|=(((unsigned int)operand1&0xffff)/((unsigned short)operand2&0xffff))&0xffff;
			if (retval==VM68K_OK) retval=vm68k_calculateflags2(&next,FLAGS_ALL,instruction,VM68K_LONG,operand1,operand2,result);
			if (retval==VM68K_OK) retval=vm68k_storeresult(pVM68k,&next,VM68K_LONG,DATAREGADDR(reg1),result);
			break;
		case VM68K_INST_ADD:
		case VM68K_INST_CMP:
		case VM68K_INST_SUB:
			if (instruction==VM68K_INST_CMP) 
			{
				retval=vm68k_resolve_ea(pVM68k,&next,datatype,addrmode,reg2,VM68K_LEGAL_ALL,&ea);
			} else {
				retval=vm68k_resolve_ea(pVM68k,&next,datatype,addrmode,reg2,direction?VM68K_LEGAL_MEMORYALTERATE:VM68K_LEGAL_ALL,&ea);
			}
			if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,1,datatype,ea,&operand1);
			if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,1,datatype,DATAREGADDR(reg1),&operand2);
			if (instruction==VM68K_INST_SUB || instruction==VM68K_INST_CMP) 
			{
				if (direction)
				{
					result=operand1-operand2;
				} else {
					result=operand2-operand1;
				}
			} else {
				result=operand2+operand1;
			}
			if (retval==VM68K_OK) retval=vm68k_calculateflags2(&next,FLAGS_ALL,instruction,datatype,operand1,operand2,result);
			if (retval==VM68K_OK && instruction!=VM68K_INST_CMP) retval=vm68k_storeresult(pVM68k,&next,datatype,(direction)?ea:DATAREGADDR(reg1),result);
			break;
		case VM68K_INST_ADDA:
		case VM68K_INST_CMPA:
		case VM68K_INST_SUBA:
			if (datatype==VM68K_UNKNOWN)
			{
				tVM68k_types datatype2;
				tVM68k_types datatype3;
				datatype2=((opcode>>8)&1)?VM68K_LONG:VM68K_WORD;
				if (pVM68k->version==4) 
				{
					datatype3=VM68K_LONG;
				}
				else
				{
					datatype3=datatype2;
				}
				retval=vm68k_resolve_ea(pVM68k,&next,datatype2,addrmode,reg2,VM68K_LEGAL_ALL,&ea);
				if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,1,datatype2,ea,&operand1);
				if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,1,datatype3,ADDRREGADDR(reg1),&operand2);

				if (instruction==VM68K_INST_SUBA || instruction==VM68K_INST_CMPA) 
				{
					result=operand2-operand1;
				} else {
					result=operand2+operand1;
				}
				if (retval==VM68K_OK && instruction==VM68K_INST_CMPA) retval=vm68k_calculateflags2(&next,FLAGS_ALL,instruction,datatype2,operand2,operand1,result);
				if (retval==VM68K_OK && instruction!=VM68K_INST_CMPA) retval=vm68k_storeresult(pVM68k,&next,datatype3,ADDRREGADDR(reg1),result);
			}
			break;
		case VM68K_INST_ADDI:
		case VM68K_INST_CMPI:
		case VM68K_INST_SUBI:
			READEXTENSION(pVM68k,&next,datatype,operand1);
			retval=VM68K_OK;
			switch(datatype)
			{
				case VM68K_BYTE:	operand1=(tVM68k_slong)((tVM68k_sbyte)(operand1&      0xff));break;
				case VM68K_WORD:	operand1=(tVM68k_slong)((tVM68k_sword)(operand1&    0xffff));break;
				case VM68K_LONG:	operand1=(tVM68k_slong)((tVM68k_slong)(operand1&0xffffffff));break;
				default: retval=VM68K_NOK_UNKNOWN_INSTRUCTION;break;
			}
			if (retval==VM68K_OK) retval=vm68k_resolve_ea(pVM68k,&next,datatype,addrmode,reg2,VM68K_LEGAL_DATAALTERATE,&ea);
			if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,1,datatype,ea,&operand2);
			if (instruction==VM68K_INST_SUBI || instruction==VM68K_INST_CMPI) 
			{
				result=operand2-operand1;	// Checked 0c01
			} else {
				result=operand2+operand1;
			}
			if (retval==VM68K_OK) retval=vm68k_calculateflags2(&next,FLAGS_ALL,instruction,datatype,operand1,operand2,result);
			if (retval==VM68K_OK && instruction!=VM68K_INST_CMPI) retval=vm68k_storeresult(pVM68k,&next,datatype,ea,result);
			break;
		case VM68K_INST_ADDQ:
		case VM68K_INST_SUBQ:
			{
				tVM68k_sbyte quick;
				tVM68k_bool version3_workaround;
				retval=vm68k_resolve_ea(pVM68k,&next,datatype,addrmode,reg2,VM68K_LEGAL_ALTERABLEADRESSING,&ea);
				if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,1,datatype,ea,&operand2);
				quick=reg1;
				operand1=quick;
				if (operand1==0) operand1=8;
				if (instruction==VM68K_INST_SUBQ) 
				{
					result=operand2-operand1;
				} else {
					result=operand2+operand1;
				}
				version3_workaround=next.zflag;		// starting with version 3, the z-flag needed to be preserved. this was an inconsistency in the original engine, that just stuck.
				if (retval==VM68K_OK) retval=vm68k_calculateflags2(&next,FLAGS_ALL,instruction,datatype,operand1,operand2,result);
				if ((pVM68k->version>=3)  && (instruction==VM68K_INST_ADDQ)) next.zflag=version3_workaround;
				if (retval==VM68K_OK && instruction!=VM68K_INST_CMPI) retval=vm68k_storeresult(pVM68k,&next,datatype,ea,result);
			}
			break;
		case VM68K_INST_EXG:
			{
				tVM68k_sbyte	opmode;
				opmode=(opcode>>3)&0x1f;
				switch(opmode)
				{
					case 0x08:	next.d[reg1]=pVM68k->d[reg2];
							next.d[reg2]=pVM68k->d[reg1];break;	// 01000= data registers.
					case 0x09:	next.a[reg1]=pVM68k->a[reg2];
							next.a[reg2]=pVM68k->a[reg1];break;	// 01001= addr registers.
					case 0x11:	next.d[reg1]=pVM68k->a[reg2];
							next.a[reg2]=pVM68k->d[reg1];break;	// 10001= data +addr registers.
				}
				retval=VM68K_OK;
			}
			break;
		case VM68K_INST_MOVEQ:
			{
				tVM68k_types	datatype2;
				tVM68k_sbyte data;
				datatype2=VM68K_LONG;

				data=opcode&0xff;
				result=(tVM68k_slong)data;
				retval=vm68k_calculateflags(&next,FLAGS_LOGIC,datatype2,0,0,result);
				next.cflag=next.vflag=0;
				if (retval==VM68K_OK) retval=vm68k_storeresult(pVM68k,&next,datatype2,DATAREGADDR(reg1),result);
			}
			break;


		case VM68K_INST_AND:
		case VM68K_INST_EOR:
		case VM68K_INST_OR:
			// direction=1: <en>-Dn -> <ea>
			// direction=0: Dn-<ea> -> Dn
			if (instruction==VM68K_INST_EOR)	// TODO: is this really neessary?
			{
				retval=vm68k_resolve_ea(pVM68k,&next,datatype,addrmode,reg2,VM68K_LEGAL_ALL,&ea);
			}
			else
			{
				retval=vm68k_resolve_ea(pVM68k,&next,datatype,addrmode,reg2,direction?VM68K_LEGAL_MEMORYALTERATE:VM68K_LEGAL_ALL,&ea);
			}
			if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,0,datatype,ea,&operand2);
			if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,0,datatype,DATAREGADDR(reg1),&operand1);
			switch (instruction)
			{
				case VM68K_INST_AND:	result=operand1&operand2;break;
				case VM68K_INST_EOR:	result=operand1^operand2;break;
				case VM68K_INST_OR:	result=operand1|operand2;break;
				default: retval=VM68K_NOK_UNKNOWN_INSTRUCTION;break;
			}
			if (retval==VM68K_OK) retval=vm68k_calculateflags(&next,FLAGS_LOGIC,datatype,operand1,operand2,result);
			if (retval==VM68K_OK) retval=vm68k_storeresult(pVM68k,&next,datatype,(direction)?ea:DATAREGADDR(reg1),result);
			break;
		case VM68K_INST_ANDI:
		case VM68K_INST_EORI:
		case VM68K_INST_ORI:
			READEXTENSION(pVM68k,&next,datatype,operand1);
			retval=vm68k_resolve_ea(pVM68k,&next,datatype,addrmode,reg2,VM68K_LEGAL_DATAALTERATE,&ea);
			if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,0,datatype,ea,&operand2);
			switch (instruction)
			{
				case VM68K_INST_ANDI:result=operand1&operand2;break;
				case VM68K_INST_EORI:result=operand1^operand2;break;
				case VM68K_INST_ORI: result=operand1|operand2;break;
				default: retval=VM68K_NOK_UNKNOWN_INSTRUCTION;break;
			}
			if (retval==VM68K_OK) retval=vm68k_calculateflags(&next,FLAGS_LOGIC,datatype,operand1,operand2,result);
			if (retval==VM68K_OK) retval=vm68k_storeresult(pVM68k,&next,datatype,ea,result);

			break;
		case VM68K_INST_BCC:
			if (displacement==0) 
			{
				displacement=READEXTENSIONWORD(pVM68k,&next);
			}
			if (condition==1) 	// BSR
			{
				PUSHLONGTOSTACK(pVM68k,&next,(next.pcr));
			}
			if (vm68k_checkcondition(pVM68k,condition) || condition==1)
			{
				next.pcr=pVM68k->pcr+displacement;
			}
			retval=VM68K_OK;
			break;
		case VM68K_INST_MOVE:
		case VM68K_INST_MOVEA:
			{
				tVM68k_types	datatype2;
				tVM68k_ubyte	addrmode_dest;
				tVM68k_slong	ea_dest;
				datatype2=VM68K_UNKNOWN;
				retval=VM68K_OK;
				switch ((opcode>>12)&0x3)
				{
					case 1: datatype2=VM68K_BYTE;break;
					case 3: datatype2=VM68K_WORD;break;
					case 2: datatype2=VM68K_LONG;break;
					default: retval=VM68K_NOK_UNKNOWN_INSTRUCTION;
				}
				addrmode_dest=(opcode>>6)&0x7;
				if (retval==VM68K_OK) retval=vm68k_resolve_ea(pVM68k,&next,datatype2,addrmode,reg2,VM68K_LEGAL_ALL,&ea);
				if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,0,datatype2,ea,&operand2);


				// TODO: I had a problem here, when the addrmode was 7/4 and the size was BYTE. lets see what happens.
				if (retval==VM68K_OK) retval=vm68k_resolve_ea(pVM68k,&next,datatype2,addrmode_dest,reg1,(instruction==VM68K_INST_MOVE)?VM68K_LEGAL_DATAALTERATE:VM68K_LEGAL_ALL,&ea_dest);
				if (retval==VM68K_OK) result=operand2;
				if (retval==VM68K_OK && instruction!=VM68K_INST_MOVEA) retval=vm68k_calculateflags(&next,FLAGS_LOGIC,datatype2,0,operand2,result);

				if (retval==VM68K_OK) retval=vm68k_storeresult(pVM68k,&next,datatype2,ea_dest,result);
			}
			break;
		case VM68K_INST_NEG:
		case VM68K_INST_NEGX:
		case VM68K_INST_NOT:
			{
				retval=vm68k_resolve_ea(pVM68k,&next,datatype,addrmode,reg2,VM68K_LEGAL_DATAALTERATE,&ea);
				if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,1,datatype,ea,&operand2);
				result=(instruction==VM68K_INST_NOT)?(~operand2):(0-operand2);
				result=result-((instruction==VM68K_INST_NEGX)&next.xflag);
				operand1=0;
				if (retval==VM68K_OK) retval=vm68k_calculateflags(&next,FLAGS_LOGIC,datatype,operand1,operand2,result);
				if (retval==VM68K_OK) retval=vm68k_storeresult(pVM68k,&next,datatype,ea,result);

			}
			break;

		case VM68K_INST_JMP:
		case VM68K_INST_JSR:
			{
				tVM68k_types	datatype2;
				datatype2=VM68K_LONG;
				retval=vm68k_resolve_ea(pVM68k,&next,datatype2,addrmode,reg2,VM68K_LEGAL_CONTROLADDRESSING,&ea);
				operand2=ea;
				if (instruction==VM68K_INST_JSR && retval==VM68K_OK)
				{
					PUSHLONGTOSTACK(pVM68k,&next,(next.pcr));
				}
				// TODO: why this way?
				switch (addrmode)
				{
					case VM68K_AM_INDIR:
						next.pcr=operand2%pVM68k->memsize;
						break;
					default:
						next.pcr=operand2;	// wonderland
						break;
				}
			}
			break;
		case VM68K_INST_RTS:
			retval=VM68K_OK;
			POPLONGFROMSTACK(pVM68k,&next,next.pcr);
			break;
		case VM68K_INST_ANDItoSR:
		case VM68K_INST_EORItoSR:
		case VM68K_INST_ORItoSR:
		case VM68K_INST_ANDItoCCR:
		case VM68K_INST_EORItoCCR:
		case VM68K_INST_ORItoCCR:
			retval=VM68K_OK;
			operand2=READEXTENSIONWORD(pVM68k,&next);
			operand1=0xffff;
			switch (instruction)
			{
				case VM68K_INST_ANDItoCCR:	operand1&=0x1f;
				case VM68K_INST_ANDItoSR:	operand2&=next.sr;break;

				case VM68K_INST_EORItoCCR:	operand1&=0x1f;
				case VM68K_INST_EORItoSR:	operand2^=next.sr;break;

				case VM68K_INST_ORItoCCR:	operand1&=0x1f;
				case VM68K_INST_ORItoSR:	operand2|=next.sr;break;
				default: retval=VM68K_NOK_UNKNOWN_INSTRUCTION;break;
			}

			next.override_sr=1;
			next.sr&=~operand1;
			next.sr|=operand2;
			break;
		case VM68K_INST_MOVEfromSR:
			{
				tVM68k_types	datatype2;
				datatype2=VM68K_WORD;
				retval=vm68k_resolve_ea(pVM68k,&next,datatype2,addrmode,reg2,VM68K_LEGAL_DATAALTERATE,&ea);
				result=next.sr&0xffff;
				if (retval==VM68K_OK) retval=vm68k_storeresult(pVM68k,&next,datatype2,ea,result);
			}
			break;

		case VM68K_INST_MOVEtoCCR:
		case VM68K_INST_MOVEtoSR:
			{
				tVM68k_types	datatype2;
				datatype2=VM68K_WORD;
				retval=vm68k_resolve_ea(pVM68k,&next,datatype2,addrmode,reg2,VM68K_LEGAL_DATAADDRESSING,&ea);
				if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,0,datatype2,ea,&operand2);
				if (retval==VM68K_OK)
				{
					next.override_sr=1;
					next.sr=(instruction==VM68K_INST_MOVEtoCCR)?((next.sr&0xffe0)|(operand2&0x1f)):operand2;
				} 
			}
			break;
		case VM68K_INST_MOVEMregtomem:
			{
				tVM68k_types datatype2;
				tVM68k_uword bitmask=0;
				datatype2=((opcode>>6)&1)?VM68K_LONG:VM68K_WORD;
				retval=vm68k_resolve_ea(pVM68k,&next,datatype2,addrmode,reg2,VM68K_LEGAL_CONTROLALTERATEADDRESSING|VM68K_LEGAL_AM_PREDEC,&ea);
				// special case: the memory decrement should only be performed when the bitmask says so
				{
					for (i=0;i<8;i++) next.a[i]=pVM68k->a[i];
				}
				if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,0,datatype2,ea,&operand2);
				if (retval==VM68K_OK) {bitmask=READEXTENSIONWORD(pVM68k,&next);}
				if (retval==VM68K_OK)
				{
					for (i=0;i<8;i++)
					{
						if (bitmask&1)
						{
							// FIXME: technically not the stack.
							if (datatype2==VM68K_WORD) PUSHWORDTOSTACK(pVM68k,&next,pVM68k->a[7-i]);
							if (datatype2==VM68K_LONG) PUSHLONGTOSTACK(pVM68k,&next,pVM68k->a[7-i]);
						}
						bitmask>>=1;
					}
					for (i=0;i<8;i++)
					{
						if (bitmask&1)
						{
							// FIXME: technically not the stack.
							if (datatype2==VM68K_WORD) PUSHWORDTOSTACK(pVM68k,&next,pVM68k->d[7-i]);
							if (datatype2==VM68K_LONG) PUSHLONGTOSTACK(pVM68k,&next,pVM68k->d[7-i]);
						}
						bitmask>>=1;
					}
				}
			}
			break;
		case VM68K_INST_MOVEMmemtoreg:
			{
				tVM68k_types datatype2;
				tVM68k_uword bitmask=0;
				datatype2=((opcode>>6)&1)?VM68K_LONG:VM68K_WORD;
				retval=vm68k_resolve_ea(pVM68k,&next,datatype2,addrmode,reg2,VM68K_LEGAL_CONTROLADDRESSING|VM68K_LEGAL_AM_POSTINC,&ea);
				// special case: the memory increment should only be performed when the bitmask says so
				{
					for (i=0;i<8;i++) next.a[i]=pVM68k->a[i];
				}
				if (retval==VM68K_OK) {bitmask=READEXTENSIONWORD(pVM68k,&next);}
				if (retval==VM68K_OK)
				{
					for (i=0;i<8;i++)
					{
						if (bitmask&1)
						{
							// FIXME: not really the stack.
							if (datatype2==VM68K_WORD) 
							{
								POPWORDFROMSTACK(pVM68k,&next,next.d[i]);
							}
							if (datatype2==VM68K_LONG) 
							{
								POPLONGFROMSTACK(pVM68k,&next,next.d[i]);
							}
						}
						bitmask>>=1;
					}
					for (i=0;i<8;i++)
					{
						if (bitmask&1)
						{
							// FIXME: not really the stack.
							if (datatype2==VM68K_WORD) 
							{
								POPWORDFROMSTACK(pVM68k,&next,next.a[i]);
								next.a[i]&=0xffff;
							}
							if (datatype2==VM68K_LONG) 
							{
								POPLONGFROMSTACK(pVM68k,&next,next.a[i]);
							}
						}
						bitmask>>=1;
					}
				}
			}
			break;
		case VM68K_INST_EXT:
			{
				tVM68k_types datatype2=VM68K_UNKNOWN;
				switch ((opcode>>6)&0x3)
				{
					case 2:	datatype2=VM68K_WORD;break;
					case 3:	datatype2=VM68K_LONG;break;
				}
				switch (datatype2)
				{
					case VM68K_WORD:	result=(tVM68k_sword)((tVM68k_sbyte)(pVM68k->d[reg2]&  0xff));retval=VM68K_OK;
								result=((pVM68k->d[reg2])&0xffff0000)|(((tVM68k_ulong)result)&0xffff);
								break;
					case VM68K_LONG:	result=(tVM68k_slong)((tVM68k_sword)(pVM68k->d[reg2]&0xffff));retval=VM68K_OK;break;
					default: retval=VM68K_NOK_UNKNOWN_INSTRUCTION;break;
				}
				if (retval==VM68K_OK) retval=vm68k_calculateflags(&next,FLAGS_LOGIC,datatype2,0,0,result);
				if (retval==VM68K_OK) next.d[reg2]=result;
			}
			break;
		case VM68K_INST_PEA:
			retval=vm68k_resolve_ea(pVM68k,&next,VM68K_LONG,addrmode,reg2,VM68K_LEGAL_CONTROLADDRESSING,&ea);
			result=ea;
			if (retval==VM68K_OK) PUSHLONGTOSTACK(pVM68k,&next,result);
			break;
		case VM68K_INST_LEA:
			retval=vm68k_resolve_ea(pVM68k,&next,VM68K_LONG,addrmode,reg2,VM68K_LEGAL_CONTROLADDRESSING,&ea);
			result=ea%(pVM68k->memsize);
			if (retval==VM68K_OK) retval=vm68k_storeresult(pVM68k,&next,VM68K_LONG,ADDRREGADDR(reg1),result);
			break;
		case VM68K_INST_NOP:
			retval=VM68K_OK;
			break;
		case VM68K_INST_ASL_ASR:
		case VM68K_INST_LSL_LSR:
		case VM68K_INST_ROL_ROR:
		case VM68K_INST_ROXL_ROXR:
			{
				tVM68k_types datatype2;
				tVM68k_ubyte count;
				tVM68k_bool direction;
				tVM68k_bool msb;
				tVM68k_bool lsb;
				tVM68k_ubyte bitnum;
				direction=(opcode>>8)&1;	// 0=right. 1=left.
				bitnum=8;
				if (datatype==VM68K_UNKNOWN)	// memory shift
				{
					datatype2=VM68K_WORD;
					count=1;
					retval=vm68k_resolve_ea(pVM68k,&next,VM68K_LONG,addrmode,reg2,VM68K_LEGAL_MEMORYALTERATE,&ea);
				} else {
					datatype2=datatype;
					if ((opcode>>5)&1) 
					{
						count=pVM68k->d[reg1]%64; 
					}
					else // i/r=1 -> register. i/r=0 -> immedate
					{
						count=reg1;
						if (count==0) count=8;
					}
					retval=VM68K_OK;
					ea=DATAREGADDR(reg2);
				}
				if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,0,datatype,ea,&operand2);
				switch (datatype2)
				{
					case VM68K_BYTE: bitnum= 8;break;
					case VM68K_WORD: bitnum=16;break;
					case VM68K_LONG: bitnum=32;break;
					default: retval=VM68K_NOK_UNKNOWN_INSTRUCTION;break;
				}
				next.vflag=0;
				for (i=0;i<count;i++)
				{
					tVM68k_bool prevmsb;
					prevmsb=msb=(operand2>>(bitnum-1))&1;
					lsb=operand2&1;
					if (direction)	// left shift
					{
						operand2<<=1;
						switch (instruction)
						{
							case VM68K_INST_ASL_ASR:
							case VM68K_INST_LSL_LSR:	lsb=0;break;
							case VM68K_INST_ROL_ROR:	lsb=msb;break;
							case VM68K_INST_ROXL_ROXR:	lsb=next.xflag;break;
							default: retval=VM68K_NOK_UNKNOWN_INSTRUCTION;break;
						}
						operand2|=lsb;
						next.cflag=next.xflag=msb;
						// FIXME: reallY???
						if (instruction!=VM68K_INST_ASL_ASR) next.vflag|=(prevmsb^(operand2>>(bitnum-1)))&1;	// set overflow flag if the msb is changed at any time.
					} else {	/// right shift
						operand2>>=1;
						switch (instruction)
						{
							case VM68K_INST_ASL_ASR:	msb=msb&1;break;
							case VM68K_INST_LSL_LSR:	msb=0;break;
							case VM68K_INST_ROL_ROR:	msb=lsb;break;
							case VM68K_INST_ROXL_ROXR:	msb=next.xflag;break;
							default: retval=VM68K_NOK_UNKNOWN_INSTRUCTION;break;
						}
						operand2|=(msb<<(bitnum-1));
						next.cflag=next.xflag=lsb;

					}
				}
				result=operand2;
				if (retval==VM68K_OK) retval=vm68k_calculateflags(&next,FLAGN|FLAGZ,datatype2,0,operand2,result);
				if (retval==VM68K_OK) retval=vm68k_storeresult(pVM68k,&next,datatype2,ea,result);
			}
			break;
		case VM68K_INST_BCLR:
		case VM68K_INST_BCHG:
		case VM68K_INST_BSET:
		case VM68K_INST_BTST:
			{
				tVM68k_ubyte bitnum;
				tVM68k_types datatype2;
				if (addrmode==VM68K_AM_DATAREG)
				{
					datatype2=VM68K_LONG;
					bitnum=32;
				} else {
					datatype2=VM68K_BYTE;
					bitnum=8;
				}
				retval=vm68k_resolve_ea(pVM68k,&next,datatype2,addrmode,reg2,VM68K_LEGAL_DATAALTERATE,&ea);
				if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,0,datatype2,ea,&operand2);
				if (retval==VM68K_OK) 
				{
					operand1=(1<<(next.d[reg1]%bitnum));
					next.zflag=((operand2&operand1)==0);

					switch(instruction)
					{
						case VM68K_INST_BCLR: result=operand2&~operand1;break;
						case VM68K_INST_BCHG: result=operand2^ operand1;break;
						case VM68K_INST_BSET: result=operand2| operand1;break;
						default: 
								      result=0;
								      break;
					}
				}
				if (retval==VM68K_OK && instruction!=VM68K_INST_BTST) retval=vm68k_storeresult(pVM68k,&next,datatype2,ea,result);
			}
			break;
		case VM68K_INST_BCLRI:
		case VM68K_INST_BCHGB:
		case VM68K_INST_BSETB:
		case VM68K_INST_BTSTB:
			{
				tVM68k_uword bitnum;
				tVM68k_types datatype2;
				bitnum=READEXTENSIONWORD(pVM68k,&next);
				datatype2=((addrmode==VM68K_AM_DATAREG)||(addrmode==VM68K_AM_ADDRREG))?VM68K_LONG:VM68K_BYTE;
				retval=vm68k_resolve_ea(pVM68k,&next,datatype2,addrmode,reg2,VM68K_LEGAL_DATAALTERATE,&ea);
				if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,0,datatype2,ea,&operand2);
				if (retval==VM68K_OK)
				{
					operand1=(1<<(bitnum%32));
					next.zflag=((operand2&operand1)==0);
					switch (instruction)
					{
						case VM68K_INST_BCLRI:	result=operand2&~operand1;break;
						case VM68K_INST_BCHGB:	result=operand2^ operand1;break;
						case VM68K_INST_BSETB:	result=operand2| operand1;break;
						default:
									result=0;
									break;
					}
				}
				if (retval==VM68K_OK && instruction!=VM68K_INST_BTSTB) retval=vm68k_storeresult(pVM68k,&next,datatype2,ea,result);

			}
			break;
		case VM68K_INST_ADDX:
		case VM68K_INST_SUBX:
			{
				tVM68k_slong ea_dest;
				tVM68k_bool rm;

				rm=(opcode>>3)&1;
				retval=vm68k_resolve_ea(pVM68k,&next,datatype,(rm?VM68K_AM_PREDEC:VM68K_AM_DATAREG),reg2,VM68K_LEGAL_AM_PREDEC|VM68K_LEGAL_AM_DATAREG,&ea);
				if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,0,datatype,ea,&operand2);
				if (retval==VM68K_OK) retval=vm68k_resolve_ea(pVM68k,&next,datatype,(rm?VM68K_AM_PREDEC:VM68K_AM_DATAREG),reg1,VM68K_LEGAL_AM_PREDEC|VM68K_LEGAL_AM_DATAREG,&ea_dest);
				if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,0,datatype,ea,&operand1);
				if (retval==VM68K_OK) operand1+=next.xflag;

				if (retval==VM68K_OK) if (instruction==VM68K_INST_SUBX) operand1=-operand1;
				if (retval==VM68K_OK) result=operand1+operand2;
				if (retval==VM68K_OK) if (result!=0) next.zflag=0;	// special case
				if (retval==VM68K_OK) retval=vm68k_calculateflags(&next,FLAGS_ALL^FLAGZ,datatype,operand1,operand2,result);
				if (retval==VM68K_OK) retval=vm68k_storeresult(pVM68k,&next,datatype,ea,result);

			}
			break;
		case VM68K_INST_CMPM:
			{
				tVM68k_slong ea_dest;

				retval=vm68k_resolve_ea(pVM68k,&next,datatype,VM68K_AM_POSTINC,reg2,VM68K_LEGAL_AM_POSTINC,&ea);
				if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,1,datatype,ea,&operand2);
				if (retval==VM68K_OK) retval=vm68k_resolve_ea(pVM68k,&next,datatype,VM68K_AM_POSTINC,reg1,VM68K_LEGAL_AM_POSTINC,&ea_dest);
				if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,1,datatype,ea_dest,&operand1);
				if (retval==VM68K_OK) result=operand2-operand1;
				if (retval==VM68K_OK) retval=vm68k_calculateflags2(&next,FLAGS_ALL,instruction,datatype,operand1,operand2,result);
			}
			break;

		case VM68K_INST_CLR:
			{
				retval=vm68k_resolve_ea(pVM68k,&next,datatype,addrmode,reg2,VM68K_LEGAL_DATAALTERATE,&ea);
				result=0;
				if (retval==VM68K_OK) retval=vm68k_calculateflags(&next,FLAGS_LOGIC,datatype,0,0,result);
				if (retval==VM68K_OK) retval=vm68k_storeresult(pVM68k,&next,datatype,ea,result);

			}
			break;
		case VM68K_INST_DBcc:
			{
				retval=VM68K_OK;
				displacement=READEXTENSIONWORD(pVM68k,&next);
				if (!vm68k_checkcondition(pVM68k,condition))
				{
					next.d[reg2]&=0xffff0000;
					next.d[reg2]|=(pVM68k->d[reg2]-1)&0xffff;
					if ((tVM68k_sword)next.d[reg2]>=0) next.pcr=pVM68k->pcr+displacement; 
				}
			}
			break;
		case VM68K_INST_SWAP:
			{
				tVM68k_types datatype2;
				datatype2=VM68K_LONG;

				retval=vm68k_resolve_ea(pVM68k,&next,datatype2,VM68K_AM_DATAREG,reg2,VM68K_LEGAL_AM_DATAREG,&ea);
				if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,0,datatype2,ea,&operand2);
				if (retval==VM68K_OK) result=((operand2>>16)&0xffff)|((operand2&0xffff)<<16);
				if (retval==VM68K_OK) next.nflag=(result>>31)&1;
				if (retval==VM68K_OK) next.zflag=(result==0);
				next.cflag=0;
				next.vflag=0;
				if (retval==VM68K_OK) retval=vm68k_storeresult(pVM68k,&next,datatype2,ea,result);

			}
			break;
		case VM68K_INST_SCC:
			{
				tVM68k_types datatype2;
				datatype2=VM68K_BYTE;
				result=(vm68k_checkcondition(pVM68k,condition))?0xff:0x00;
				retval=vm68k_resolve_ea(pVM68k,&next,datatype2,addrmode,reg2,VM68K_LEGAL_DATAALTERATE,&ea);
				if (retval==VM68K_OK) retval=vm68k_storeresult(pVM68k,&next,datatype2,ea,result);
			}
			break;
		case VM68K_INST_TST:
			{
				retval=vm68k_resolve_ea(pVM68k,&next,datatype,addrmode,reg2,VM68K_LEGAL_DATAALTERATE,&ea);
				if (retval==VM68K_OK) retval=vm68k_fetchoperand(pVM68k,0,datatype,ea,&operand2);
				if (retval==VM68K_OK) result=operand2;
				if (retval==VM68K_OK) retval=vm68k_calculateflags(&next,FLAGS_LOGIC,datatype,0,0,result);

			}
			break;
		case VM68K_INST_UNKNOWN:
			retval=VM68K_NOK_UNKNOWN_INSTRUCTION;
			break;
		default:
			{
#ifdef	DEBUG_PRINT
				char tmp[64];
				vm68k_get_instructionname(instruction,tmp);
				printf("UNIMPLEMENTED opcode %04X = %s\n",opcode,tmp);
#else
				printf("UNIMPLEMENTED opcode %04X\n",opcode);
#endif
				retval=VM68K_NOK_UNKNOWN_INSTRUCTION;
			}
			break;
	}
	if (retval==VM68K_OK)
	{
		pVM68k->pcr=next.pcr;
		pVM68k->sr&=0xffe0;
		if (next.override_sr==1)
		{
			pVM68k->sr=next.sr;
		} else {
			pVM68k->sr|=(next.cflag)<<0;
			pVM68k->sr|=(next.vflag)<<1;
			pVM68k->sr|=(next.zflag)<<2;
			pVM68k->sr|=(next.nflag)<<3;
			pVM68k->sr|=(next.xflag)<<4;
		}
		for (i=0;i<8;i++)
		{
			pVM68k->a[i]=next.a[i];
			pVM68k->d[i]=next.d[i];
		}
		if (next.mem_we)
		{
			for (i=0;i<next.mem_we;i++)
			{
#ifdef	DEBUG_PRINT
				if (next.mem_size==VM68K_WORD) printf("\n\nMEMWRITE WORD %04X @ %04x\n",(next.mem_value[i])&0xffff,next.mem_addr[i]);
				if (next.mem_size==VM68K_LONG) printf("\n\nMEMWRITE LONG %08X @ %04x\n",next.mem_value[i],next.mem_addr[i]);
				fflush(stdout);
#endif
				switch(next.mem_size)
				{
					case 0:	WRITE_INT8BE(pVM68k->memory, next.mem_addr[i],next.mem_value[i]&      0xff);break;
					case 1:	WRITE_INT16BE(pVM68k->memory,next.mem_addr[i],next.mem_value[i]&    0xffff);break;
					case 2:	WRITE_INT32BE(pVM68k->memory,next.mem_addr[i],next.mem_value[i]&0xffffffff);break;
					default: retval=VM68K_NOK_UNKNOWN_INSTRUCTION;break;
				}
			}
		}
	} 

	return	retval;
}
int vm68k_getNextOpcode(void* hVM68k,unsigned short* opcode)
{

	tVM68k* pVM68k=(tVM68k*)hVM68k;
	if (hVM68k==NULL) return VM68K_NOK_INVALID_PTR;
	if (opcode==NULL) return VM68K_NOK_INVALID_PTR;
	if (pVM68k->magic!=MAGICVALUE) return VM68K_NOK_INVALID_PARAMETER;
	*opcode=READ_INT16BE(pVM68k->memory,pVM68k->pcr);
	pVM68k->pcr+=2;
#ifdef	DEBUG_PRINT
	{
		//static int pcrcnt[65536]={0};
		int i;
		char tmp[64];
		tVM68k_instruction inst;
		printf("\n\n\n");
		//printf("%d  ",pcrcnt[pVM68k->pcr]++);
		printf("pcr:%06x ",pVM68k->pcr);
		printf("INST:%04X ",*opcode);
		printf("CVZN:%d%d%d%d ", (pVM68k->sr>>0)&1,(pVM68k->sr>>1)&1,(pVM68k->sr>>2)&1,(pVM68k->sr>>3)&1);
		printf("D:");
		for (i=0;i<8;i++) 
		{
			printf("%08X:",pVM68k->d[i]);
		}
		printf(" A:");
		for (i=0;i<8;i++) 
		{
			printf("%08X:",pVM68k->a[i]);
		}

		{
			unsigned long long sum;
			sum=0;
			for (i=0;i<pVM68k->memsize;i++) sum+=READ_INT32BE(pVM68k->memory,i);
			printf("MEMSUM:%llX ",sum);
		}
		inst=vm68k_decode(*opcode);
		vm68k_get_instructionname(inst,tmp);
		printf(" --> %s\n",tmp);
		if (pVM68k->pcr<0x1c238) printf("\x1b[0m\n");
		fflush(stdout);
	}
#endif
	return VM68K_OK;
}

int vm68k_getpSharedMem(void* hVM68k,void** pSharedMem,int* bytes)
{
	tVM68k* pVM68k=(tVM68k*)hVM68k;
	*pSharedMem=(void*)&(pVM68k->memory[0]);
	*bytes=sizeof(pVM68k->memory);
	return VM68K_OK;

}

int vm68k_getState(void* hVM68k,unsigned int* aregs,unsigned int* dregs,unsigned int *pcr,unsigned int* sr)
{
	int i;
	tVM68k* pVM68k=(tVM68k*)hVM68k;
	for (i=0;i<8;i++)
	{
		aregs[i]=pVM68k->a[i];
		dregs[i]=pVM68k->d[i];
	}
	*pcr=pVM68k->pcr;
	*sr=pVM68k->sr;

	return VM68K_OK;
}
