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

#ifndef	VM68K_H
#define	VM68K_H


// the return value is =0, when everything is okay.
#define	VM68K_OK			0
#define	VM68K_NOK_UNKNOWN_INSTRUCTION	1
#define	VM68K_NOK_INVALID_PTR		-1
#define	VM68K_NOK_INVALID_PARAMETER	-2


// this function tells how much memory needs to be mallocated for the handle;
int vm68k_getsize(int* size);


// as the name suggests, pSharedMem is shared among the cores. it typically holds the game code.
int vm68k_init(void* hVM68k,int version);

int vm68k_singlestep(void *hVM68k,unsigned short opcode);

int vm68k_getNextOpcode(void* hVM68k,unsigned short* opcode);

int vm68k_getpSharedMem(void* hVM68k,void** pSharedMem,int* bytes);

int vm68k_getState(void* hVM68k,unsigned int* aregs,unsigned int* dregs,unsigned int *pcr,unsigned int* sr);

#endif
