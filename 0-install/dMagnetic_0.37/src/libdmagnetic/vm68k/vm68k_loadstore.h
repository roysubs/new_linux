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

#ifndef	VM68K_LOADSTORE_H
#define	VM68K_LOADSTORE_H

#include "vm68k_datatypes.h"
// some helper defines
#define DATAREGADDR(addr)	(-((addr)+ 1))
#define ADDRREGADDR(addr)	(-((addr)+10))

#define	VM68K_LEGAL_AM_DATAREG	(1<< 1)
#define	VM68K_LEGAL_AM_ADDRREG	(1<< 2)
#define	VM68K_LEGAL_AM_INDIR	(1<< 3)
#define	VM68K_LEGAL_AM_POSTINC	(1<< 4)
#define	VM68K_LEGAL_AM_PREDEC	(1<< 5)
#define	VM68K_LEGAL_AM_DISP16	(1<< 6)
#define	VM68K_LEGAL_AM_INDEX	(1<< 7)

#define	VM68K_LEGAL_AMX_W	(1<< 8)
#define	VM68K_LEGAL_AMX_L	(1<< 9)
#define	VM68K_LEGAL_AMX_DATA	(1<<10)
#define	VM68K_LEGAL_AMX_PC	(1<<11)
#define	VM68K_LEGAL_AMX_INDEX_PC (1<<12)

#define	VM68K_LEGAL_CONTROLALTERATEADDRESSING		(VM68K_LEGAL_AM_INDIR|VM68K_LEGAL_AM_DISP16|VM68K_LEGAL_AM_INDEX|VM68K_LEGAL_AMX_W|VM68K_LEGAL_AMX_L|VM68K_LEGAL_AMX_PC|VM68K_LEGAL_AMX_INDEX_PC)
#define	VM68K_LEGAL_CONTROLADDRESSING			(VM68K_LEGAL_AM_INDIR|VM68K_LEGAL_AM_DISP16|VM68K_LEGAL_AM_INDEX|VM68K_LEGAL_AMX_W|VM68K_LEGAL_AMX_L|VM68K_LEGAL_AMX_PC|VM68K_LEGAL_AMX_INDEX_PC)
#define	VM68K_LEGAL_DATAADDRESSING ( VM68K_LEGAL_AM_DATAREG| VM68K_LEGAL_AM_INDIR|	VM68K_LEGAL_AM_POSTINC| VM68K_LEGAL_AM_PREDEC| VM68K_LEGAL_AM_DISP16| VM68K_LEGAL_AM_INDEX| VM68K_LEGAL_AMX_W| VM68K_LEGAL_AMX_L| VM68K_LEGAL_AMX_DATA| VM68K_LEGAL_AMX_PC| VM68K_LEGAL_AMX_INDEX_PC )
#define	VM68K_LEGAL_ALL ( VM68K_LEGAL_AM_DATAREG| VM68K_LEGAL_AM_ADDRREG| VM68K_LEGAL_AM_INDIR|	VM68K_LEGAL_AM_POSTINC| VM68K_LEGAL_AM_PREDEC| VM68K_LEGAL_AM_DISP16| VM68K_LEGAL_AM_INDEX| VM68K_LEGAL_AMX_W| VM68K_LEGAL_AMX_L| VM68K_LEGAL_AMX_DATA| VM68K_LEGAL_AMX_PC| VM68K_LEGAL_AMX_INDEX_PC )
#define	VM68K_LEGAL_DATAALTERATE ( VM68K_LEGAL_AM_DATAREG|VM68K_LEGAL_AM_INDIR|VM68K_LEGAL_AM_POSTINC| VM68K_LEGAL_AM_PREDEC| VM68K_LEGAL_AM_DISP16| VM68K_LEGAL_AM_INDEX| VM68K_LEGAL_AMX_W| VM68K_LEGAL_AMX_L)
#define	VM68K_LEGAL_MEMORYALTERATE ( VM68K_LEGAL_AM_INDIR|VM68K_LEGAL_AM_POSTINC| VM68K_LEGAL_AM_PREDEC| VM68K_LEGAL_AM_DISP16| VM68K_LEGAL_AM_INDEX| VM68K_LEGAL_AMX_W| VM68K_LEGAL_AMX_L)
#define	VM68K_LEGAL_ALTERABLEADRESSING (VM68K_LEGAL_AM_DATAREG|VM68K_LEGAL_AM_ADDRREG|VM68K_LEGAL_AM_INDIR|VM68K_LEGAL_AM_POSTINC|VM68K_LEGAL_AM_PREDEC|VM68K_LEGAL_AM_DISP16|VM68K_LEGAL_AM_INDEX| VM68K_LEGAL_AMX_W|VM68K_LEGAL_AMX_L)



#define	FLAGC	(1<<0)
#define	FLAGV	(1<<1)
#define	FLAGZ	(1<<2)
#define	FLAGN	(1<<3)
#define	FLAGX	(1<<4)
#define	FLAGCZCLR	(1<<5)	// when set, the c and z flag are always cleared.

#define	FLAGS_ALL	(FLAGC|FLAGV|FLAGZ|FLAGN|FLAGX)
#define	FLAGS_LOGIC	(FLAGZ|FLAGN|FLAGCZCLR)

// this function is calculating the number of bytes for a datatype
int vm68k_getbytesize(tVM68k_types size);

// this function is translating the addressmode/registerpair into a memory address
int vm68k_resolve_ea(tVM68k* pVM68k,tVM68k_next *pNext,tVM68k_types size,
	tVM68k_addrmodes addrmode,tVM68k_ubyte reg,
	tVM68k_uword legal,tVM68k_slong* ea);

// this function is loading the operand
int vm68k_fetchoperand(tVM68k* pVM68k,tVM68k_bool extendsign,tVM68k_types size,tVM68k_slong ea,tVM68k_ulong* operand);

// this function is calculting the status flags
int vm68k_calculateflags(tVM68k_next* pNext,tVM68k_ubyte flagmask,tVM68k_types size,tVM68k_ulong operand1,tVM68k_ulong operand2,tVM68k_uint64 result);

int vm68k_calculateflags2(tVM68k_next* pNext,tVM68k_ubyte flagmask,tVM68k_instruction instruction,tVM68k_types datatype,tVM68k_ulong operand1,tVM68k_ulong operand2,tVM68k_uint64 result);

// this function is storing the result of the operation.
int vm68k_storeresult(tVM68k* pVM68k,tVM68k_next* pNext,tVM68k_types size,tVM68k_slong ea,tVM68k_ulong result);



#endif
