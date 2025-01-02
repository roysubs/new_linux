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
#ifndef DMAGNETIC_H
#define	DMAGNETIC_H

// return values of the functions
#define	DMAGNETIC_OK	0
#define	DMAGNETIC_OK_QUIT	28844
#define	DMAGNETIC_OK_RESTART	28816
#define	DMAGNETIC_NOK_UNKNOWN_INSTRUCTION	1
#define	DMAGNETIC_NOK_INVALID_PTR		-1
#define	DMAGNETIC_NOK_INVALID_PARAM		-2
#define	DMAGNETIC_NOK				-23

// defines and data structures for the pictures
#define	PICTURE_BITS_PER_RGB_CHANNEL	10
#define	PICTURE_MAX_RGB_VALUE		((1<<PICTURE_BITS_PER_RGB_CHANNEL)-1)
#define	PICTURE_GET_RED(p)		(((p)>>(2*PICTURE_BITS_PER_RGB_CHANNEL))&PICTURE_MAX_RGB_VALUE)
#define	PICTURE_GET_GREEN(p)		(((p)>>(1*PICTURE_BITS_PER_RGB_CHANNEL))&PICTURE_MAX_RGB_VALUE)
#define	PICTURE_GET_BLUE(p)		(((p)>>(0*PICTURE_BITS_PER_RGB_CHANNEL))&PICTURE_MAX_RGB_VALUE)

#define	PICTURE_MAX_WIDTH		640	// title screen of "Fish!"
#define	PICTURE_MAX_HEIGHT		350	// title screen of "Fish!"
#define	PICTURE_MAX_PIXELS		(PICTURE_MAX_WIDTH*PICTURE_MAX_HEIGHT)

typedef	enum _eDmagneticPictureType
{
	PICTURE_DEFAULT,
	PICTURE_HALFTONE,
	PICTURE_C64
} eDmagneticPictureType;
typedef	struct _tdMagneticPicture
{
	unsigned int palette[16];
	int height;
	int width;
	char pixels[PICTURE_MAX_PIXELS];
	eDmagneticPictureType pictureType;
} tdMagneticPicture;

// callback pointers.
typedef int (*cbLineANewOutput)(void* context,char* headline,char* text,char* picname);
typedef int (*cbLineAInputString)(void* context,int* len,char* string);
typedef int (*cbLineADrawPicture)(void* context,tdMagneticPicture* picture,char* picname,int mode);
typedef int (*cbLineASaveGame)(void* context,char* filename,void* ptr,int len);
typedef int (*cbLineALoadGame)(void* context,char* filename,void* ptr,int len);


// interface functions/ 
int dMagnetic_getsize(int* bytes,int alignment);
int dMagnetic_init(void* pHandle,int alignment,void* pMagBuf,int magsize,void* pGfxBuf,int gfxsize);
int dMagnetic_getGameVersion(void* pHandle,int* version);
int dMagnetic_run(void* pHandle);



// config calls
int dMagnetic_configrandom(void* pHandle,char random_mode,unsigned int random_seed);
int dMagnetic_setEGAMode(void* pHandle,int egamode);



int dMagnetic_setCBnewOutput(void* pHandle,cbLineANewOutput pCB,void* context);
int dMagnetic_setCBinputString(void* pHandle,cbLineAInputString pCB,void* context);
int dMagnetic_setCBdrawPicture(void* pHandle,cbLineADrawPicture pCB,void* context,tdMagneticPicture *pPicture);
int dMagnetic_setCBsaveGame(void* pHandle,cbLineASaveGame pCB,void* context);
int dMagnetic_setCBloadGame(void* pHandle,cbLineALoadGame pCB,void* context);


// spoiler alert...
int dMagnetic_dumppics(void* pHandle);



// for debugging purposes
typedef struct _tdMagneticVMstate
{
	unsigned int pcr;
	unsigned int sr;
	unsigned int aregs[8];
	unsigned int dregs[8];
	unsigned short lastOpcode;
	void* pMem;
	int memsize;
} tdMagneticVMstate;

int dMagnetic_singleStep(void* pHandle);
int dMagnetic_getVM(void* pHandle,void** pVM,int* vmsize);
int dMagnetic_getVMstate(void* pHandle,tdMagneticVMstate *pVMstate);


#endif
