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

// the purpose of this file is to provide a callback-fallback until proper
// user interfaces have been established. It will do ;)

#ifndef	LINEA_DEFAULT_CALLBACKS_H
#define	LINEA_DEFAULT_CALLBACKS_H
#include "dMagnetic.h"

#define	DEFAULT_OK	0
#define	DEFAULT_NOK	-1

// interface to the lineA
int default_cbNewOutput(void* context,char* headline,char* text,char* picname);
int default_cbInputString(void* context,int* len,char* string);
int default_cbDrawPicture(void* context,tdMagneticPicture* picture,char* picname,int mode);
int default_cbSaveGame(void* context,char* filename,void* ptr,int len);
int default_cbLoadGame(void* context,char* filename,void* ptr,int len);


// interface to the main application
int default_getsize(int* size);
// if there is a .ini-file, extract the section for this user interface. the same goes for the command line parameters
int default_open(void* hContext,FILE* f_inifile,int argc,char** argv);
int default_setEngine(void *hContext,void* hEngine);

extern const char *default_low_ansi_characters;
extern const char *default_monochrome_characters;
#endif
