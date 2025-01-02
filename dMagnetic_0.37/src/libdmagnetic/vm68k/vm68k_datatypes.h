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

#ifndef	VM68K_DATATYPES_H
#define	VM68K_DATATYPES_H
// the purpose of this file is to provide the shared datatypes needed for the virtual machine
#ifdef __sgi__
typedef	unsigned char		tVM68k_bool;
typedef	unsigned char		tVM68k_ubyte;
typedef	unsigned short		tVM68k_uword;
typedef	unsigned int		tVM68k_ulong;
typedef	unsigned long long	tVM68k_uint64;

typedef	signed char		tVM68k_sbyte;
typedef	signed short		tVM68k_sword;
typedef	signed int		tVM68k_slong;
typedef	signed long long	tVM68k_sint64;


#else
#include <stdint.h>


// first of all: the standard data types.
typedef	uint_least8_t	tVM68k_bool;
typedef	uint_least8_t	tVM68k_ubyte;
typedef	uint_least16_t	tVM68k_uword;
typedef	uint_least32_t	tVM68k_ulong;
typedef	uint_least64_t	tVM68k_uint64;


typedef	int_least8_t	tVM68k_sbyte;
typedef	int_least16_t	tVM68k_sword;
typedef	int_least32_t	tVM68k_slong;
typedef	int_least64_t	tVM68k_sint64;
#endif



// then a couple of enumerations. to make the sourcecode a little bit easier to read.
typedef enum _tVM68k_types {VM68K_BYTE=0,VM68K_WORD=1,VM68K_LONG=2,VM68K_UNKNOWN=3} tVM68k_types;
typedef enum _tVM68k_addrmodes {	VM68K_AM_DATAREG=0,		// Dn
					VM68K_AM_ADDRREG=1,		// An
					VM68K_AM_INDIR=2,		// (An)
					VM68K_AM_POSTINC=3,		// (An)+
					VM68K_AM_PREDEC=4,		// -(An)
					VM68K_AM_DISP16=5,		// (d16,An)
					VM68K_AM_INDEX=6,		// (d8,An,Xn)
					VM68K_AM_EXT=7} 
		tVM68k_addrmodes;
typedef	enum _tVM68k_addrmode_ext {	VM68K_AMX_W=0,			// (xxx),W
					VM68K_AMX_L=1,			// (xxx),L
					VM68K_AMX_data=4,		// #<data>
					VM68K_AMX_PC=2,			// (d16,PC)
					VM68K_AMX_INDEX_PC=3} 		// (d8,PC,Xn)
					tVM68k_addrmode_ext;

// the internal structures
////// this structure holds the state after the instruction has been decoded.
typedef	struct _tVM68k_next
{
	tVM68k_ulong	pcr;	// program counter
	tVM68k_bool	override_sr;
	tVM68k_uword	sr;
	tVM68k_bool	cflag;
	tVM68k_bool	vflag;
	tVM68k_bool	zflag;
	tVM68k_bool	nflag;
	tVM68k_bool	xflag;
					// bit 0..4: CVZNX
	tVM68k_ulong	a[8];	// address register
	tVM68k_ulong	d[8];	// data register

	////// memory queue
	tVM68k_types	mem_size;
	tVM68k_ulong	mem_addr[16];
	tVM68k_ulong	mem_value[16];
	tVM68k_ubyte	mem_we;

} tVM68k_next;

// virtual machine state. This is being saved as "advanced" savegame, so make sure it does not contain any pointers.
typedef	struct _tVM68k
{
	tVM68k_ulong	magic;	// just so that the functions can identify a handle as this particular data structure
	tVM68k_ulong	pcr;	// program counter
	tVM68k_uword	sr;	// status register.
					// bit 0..4: CVZNX
	tVM68k_ulong	a[8];	// address register
	tVM68k_ulong	d[8];	// data register
	tVM68k_ubyte	memory[98304];
	tVM68k_ulong	memsize;	// TODO: check for violations.

	/////// VERSION PATCH
	tVM68k_ubyte	version;	// game version. not the interpreter version
} tVM68k;


#endif
