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

#include "dMagnetic.h"
#include "linea.h"
#include "vm68k.h"

#define	MAGIC	0x314159
typedef struct _tHandle
{
	unsigned int magic;
	void *hVM68k;
	int bytes_vm68k;
	void *hLineA;
	void *pMagBuf;
	int magbufsize;
	void *pGfxBuf;
	int gfxbufsize;
	int alignment;
	int version;
	unsigned short opcode;
} tHandle;

int dMagnetic_getsize(int* bytes,int alignment)
{
	int bytes_handle;
	int bytes_vm68k;
	int bytes_lineA;
	int retval;

	if (bytes==NULL)
	{
		fprintf(stderr,"ERROR: NULL pointer in dMagnetic_getSize\n");
		return DMAGNETIC_NOK_INVALID_PTR;
	}
	bytes_handle=sizeof(tHandle);

	retval=vm68k_getsize(&bytes_vm68k);
	if (retval)
	{
		fprintf(stderr,"ERROR: vm68k_getsize returned %d\n",retval);
		return retval;
	}

	retval=lineA_getsize(&bytes_lineA);
	if (retval)
	{
		fprintf(stderr,"ERROR: lineA_getsize returned %d\n",retval);
		return retval;
	}


	*bytes =bytes_handle+(alignment-(bytes_handle%alignment));
	*bytes+=bytes_vm68k+ (alignment-(bytes_vm68k %alignment));
	*bytes+=bytes_lineA+ (alignment-(bytes_lineA %alignment));

	return retval;
}

int dMagnetic_init(void* pHandle,int alignment,void* pMagBuf,int magsize,void* pGfxBuf,int gfxsize)
{
	tHandle *pThis=(tHandle*)pHandle;
	int retval;
	int bytes_handle;
	int bytes_vm68k;
	int bytes_lineA;
	int totalmem;
	int idx;

	void *pSharedMem;
	int bytes_shared;


	retval=DMAGNETIC_OK;

	// step 1: recalculate the actual size of the handle and the sections. 
	bytes_handle=sizeof(tHandle);
	retval|=vm68k_getsize(&bytes_vm68k);
	retval|=lineA_getsize(&bytes_lineA);
	if (retval)
	{
		fprintf(stderr,"ERROR: getsize returned %d\n",retval);
		return retval;
	}

	totalmem=0;
	totalmem+=bytes_handle;totalmem+=(alignment-(totalmem%alignment));
	totalmem+=bytes_vm68k; totalmem+=(alignment-(totalmem%alignment));
	totalmem+=bytes_lineA; totalmem+=(alignment-(totalmem%alignment));


	// step 2: let the init begin
	memset(pThis,0,totalmem);	// tabula rasa

	pThis->magic=MAGIC;
	idx=0;
	idx+=bytes_handle;idx+=(alignment-(idx%alignment));
	pThis->hVM68k=(void*)(&((unsigned char*)pHandle)[idx]);

	idx+=bytes_vm68k; idx+=(alignment-(idx%alignment));
	pThis->hLineA=(void*)(&((unsigned char*)pHandle)[idx]);

	idx+=bytes_lineA; idx+=(alignment-(idx%alignment));
	pThis->pMagBuf=pMagBuf;
	pThis->magbufsize=magsize;

	pThis->pGfxBuf=pGfxBuf;
	pThis->gfxbufsize=gfxsize;

	pThis->alignment=alignment;
	pThis->version=-1;	// nothing loaded yet

	if (idx>totalmem)
	{
		fprintf(stderr,"ERROR: Initializing memory\n");
		return DMAGNETIC_NOK;
	}


	retval|=vm68k_getpSharedMem(pThis->hVM68k,&pSharedMem,&bytes_shared);
	retval|=lineA_init(pThis->hLineA,pSharedMem,bytes_shared,pMagBuf,magsize,pGfxBuf,gfxsize);
	if (retval)
	{
		fprintf(stderr,"ERROR: lineA_init returned %d\n",retval);
		return retval;
	}
	retval=lineA_getVersion(pThis->hLineA,&pThis->version);
	if (retval)
	{
		fprintf(stderr,"ERROR: lineA_getversion returned %d\n",retval);
		return retval;
	}
	retval=vm68k_init(pThis->hVM68k,pThis->version);
	if (retval)
	{
		fprintf(stderr,"ERROR: vm68k_init returned %d\n",retval);
		return retval;
	}
	pThis->bytes_vm68k=bytes_vm68k;

	return retval;
}
int dMagnetic_getGameVersion(void* pHandle,int* version)
{
	tHandle* pThis=(tHandle*)pHandle;
	int retval;

	if (pThis->magic!=MAGIC)
	{
		return DMAGNETIC_NOK_INVALID_PARAM;
	}

	retval=lineA_getVersion(pThis->hLineA,version);
	return retval;
}
int dMagnetic_singleStep(void* pHandle)
{
	int retval;
	tHandle* pThis=(tHandle*)pHandle;

	pThis->opcode=0;
	retval=vm68k_getNextOpcode(pThis->hVM68k,&pThis->opcode);
	if (retval==VM68K_OK) retval=lineA_substitute_aliases(pThis->hLineA,&pThis->opcode);
	if (retval==LINEA_OK) retval=vm68k_singlestep(pThis->hVM68k,pThis->opcode);
	if (retval!=VM68K_OK) retval=lineA_singlestep(pThis->hLineA,pThis->hVM68k,pThis->opcode);
	if (retval!=LINEA_OK && retval!=LINEA_OK_QUIT && retval!=LINEA_OK_RESTART)
	{
		retval=DMAGNETIC_NOK_UNKNOWN_INSTRUCTION;
	}
	else if (retval==LINEA_OK_RESTART)
	{
		retval=DMAGNETIC_OK_RESTART;
	}
	else if (retval==LINEA_OK_QUIT)
	{
		retval=DMAGNETIC_OK_QUIT;
	}

	return retval;
}

int dMagnetic_run(void* pHandle)
{
	tHandle* pThis=(tHandle*)pHandle;
	int retval;

	if (pThis->magic!=MAGIC)
	{
		return DMAGNETIC_NOK_INVALID_PARAM;
	}

	lineA_showTitleScreen(pThis->hLineA);	// some versions of the game have a title screen
	do
	{
		retval=dMagnetic_singleStep(pHandle);
	} while (retval==DMAGNETIC_OK);

	return retval;
}
int dMagnetic_getVM(void* pHandle,void** pVM,int* vmsize)
{
	tHandle* pThis=(tHandle*)pHandle;
	int retval;

	retval=DMAGNETIC_OK;
	if (pThis->magic!=MAGIC)
	{
		return DMAGNETIC_NOK_INVALID_PARAM;
	}


	*pVM=pThis->hVM68k;
	*vmsize=pThis->bytes_vm68k;
	return retval;
}
int dMagnetic_getVMstate(void* pHandle,tdMagneticVMstate *pVMstate)
{
	tHandle* pThis=(tHandle*)pHandle;
	int retval;

	retval=DMAGNETIC_OK;
	if (pThis->magic!=MAGIC)
	{
		return DMAGNETIC_NOK_INVALID_PARAM;
	}

	pVMstate->lastOpcode=pThis->opcode;
	retval|=vm68k_getState(pThis->hVM68k,pVMstate->aregs,pVMstate->dregs,&(pVMstate->pcr),&(pVMstate->sr));
	retval|=vm68k_getpSharedMem(pThis->hVM68k,&(pVMstate->pMem),&(pVMstate->memsize));
	return retval;
}
////////////
int dMagnetic_configrandom(void* pHandle,char random_mode,unsigned int random_seed)
{
	tHandle* pThis=(tHandle*)pHandle;
	int retval;

	retval=DMAGNETIC_OK;
	if (pThis->magic!=MAGIC)
	{
		return DMAGNETIC_NOK_INVALID_PARAM;
	}

	retval|=lineA_configrandom(pThis->hLineA,random_mode,random_seed);
	return retval;

}
int dMagnetic_setEGAMode(void* pHandle,int egamode)
{
	tHandle* pThis=(tHandle*)pHandle;
	int retval;

	retval=DMAGNETIC_OK;
	if (pThis->magic!=MAGIC)
	{
		return DMAGNETIC_NOK_INVALID_PARAM;
	}
	retval|=lineA_setEGAMode(pThis->hLineA,egamode);

	return retval;

}
int dMagnetic_dumppics(void* pHandle)
{
	tHandle* pThis=(tHandle*)pHandle;
	int retval;

	retval=DMAGNETIC_OK;
	if (pThis->magic!=MAGIC)
	{
		return DMAGNETIC_NOK_INVALID_PARAM;
	}
	retval|=lineA_dumppics(pThis->hLineA);
	return retval;
}

int dMagnetic_setCBnewOutput(void* pHandle,cbLineANewOutput pCB,void* context)
{
	tHandle* pThis=(tHandle*)pHandle;
	int retval;

	retval=DMAGNETIC_OK;
	if (pThis->magic!=MAGIC)
	{
		return DMAGNETIC_NOK_INVALID_PARAM;
	}

	retval|=lineA_setCBnewOutput(pThis->hLineA,pCB,context);
	return retval;

}

int dMagnetic_setCBinputString(void* pHandle,cbLineAInputString pCB,void* context)
{
	tHandle* pThis=(tHandle*)pHandle;
	int retval;

	retval=DMAGNETIC_OK;
	if (pThis->magic!=MAGIC)
	{
		return DMAGNETIC_NOK_INVALID_PARAM;
	}

	retval|=lineA_setCBinputString(pThis->hLineA,pCB,context);
	return retval;
}
int dMagnetic_setCBdrawPicture(void* pHandle,cbLineADrawPicture pCB,void* context,tdMagneticPicture *pPicture)
{
	tHandle* pThis=(tHandle*)pHandle;
	int retval;

	retval=DMAGNETIC_OK;
	if (pThis->magic!=MAGIC)
	{
		return DMAGNETIC_NOK_INVALID_PARAM;
	}

	retval|=lineA_setCBdrawPicture(pThis->hLineA,pCB,context,pPicture);
	return retval;
}
int dMagnetic_setCBsaveGame(void* pHandle,cbLineASaveGame pCB,void* context)
{
	tHandle* pThis=(tHandle*)pHandle;
	int retval;

	retval=DMAGNETIC_OK;
	if (pThis->magic!=MAGIC)
	{
		return DMAGNETIC_NOK_INVALID_PARAM;
	}

	retval|=lineA_setCBsaveGame(pThis->hLineA,pCB,context);
	return retval;
}
int dMagnetic_setCBloadGame(void* pHandle,cbLineALoadGame pCB,void* context)
{
	tHandle* pThis=(tHandle*)pHandle;
	int retval;

	retval=DMAGNETIC_OK;
	if (pThis->magic!=MAGIC)
	{
		return DMAGNETIC_NOK_INVALID_PARAM;
	}

	retval|=lineA_setCBloadGame(pThis->hLineA,pCB,context);
	return retval;
}

