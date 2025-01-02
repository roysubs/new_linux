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

#define	MAXMAGSIZE	 184000	// the largest .mag file has 183915 bytes (wonder.mag)
#define	MAXGFXSIZE	2540000 // the largest .gfx file has 2534110 bytes (wonder.gfx)
#define	ALIGNMENT	64	// influences how memory is allocated internally

int cb_output(void* context,char* headline,char* text,char* picname)
{
	printf("\x1b[1;37;41m  headline: [%s]\x1b[0m\n",headline);
	printf("\x1b[1;37;44m  picture: %s\x1b[0m\n",picname);
	printf("text: [%s]\n",text);
	return 0;
}
int cb_input(void* context,int* len,char* string)
{
	printf("\x1b[0;30;46m\n");
	if (feof(stdin)) exit(0);
	if (fgets(string,256,stdin)==NULL) exit(0);
	*len=strlen(string);
	printf("\x1b[0m\n");
	return 0;
}
int cb_picture(void* context,tdMagneticPicture* picture,char* picname,int mode)
{
	int i;
	printf("\x1b[1;37;42m  picture %s >> width:%d height:%d\x1b[0m\n",picname,picture->width,picture->height);
#if 0
	for (i=0;i<picture->height*picture->width;i++)
	{
		if (i%(picture->width)==0) printf("\n");
		printf("%x",picture->pixels[i]);
	}
	printf("\n");
#endif
	return 0;
}
int main(int argc,char** argv)
{
	int magsize;
	int gfxsize;
	void* handle;
	unsigned char* magbuf;
	unsigned char* gfxbuf;
	int bytes;
	int retval;
	FILE *f;
	tdMagneticPicture* picture;

	if (argc!=3)
	{
		printf("please run with %s INPUT.mag INPUT.gfx\n",argv[0]);
		return 1;
	}

	printf("allocating %d bytes for the mag buffer\n",MAXMAGSIZE);
	magbuf=malloc(MAXMAGSIZE);
	printf("allocating %d bytes for the gfx buffer\n",MAXGFXSIZE);
	gfxbuf=malloc(MAXGFXSIZE);
	dMagnetic_getsize(&bytes,ALIGNMENT);
	printf("allocating %d bytes for the engine\n",bytes);
	handle=malloc(bytes);
	printf("allocating %d bytes for the pictures\n",sizeof(tdMagneticPicture));
	picture=malloc(sizeof(tdMagneticPicture));

	do
	{
		f=fopen(argv[1],"rb");
		magsize=fread(magbuf,sizeof(char),MAXMAGSIZE,f);
		fclose(f);

		f=fopen(argv[2],"rb");
		gfxsize=fread(gfxbuf,sizeof(char),MAXGFXSIZE,f);
		fclose(f);

		dMagnetic_init(handle,ALIGNMENT,magbuf,magsize,gfxbuf,gfxsize);	// initialize the virtual machine
		dMagnetic_setCBnewOutput(handle,cb_output,NULL);	// set the callback for output
		dMagnetic_setCBinputString(handle,cb_input,NULL);	// set the callback for input
		dMagnetic_setCBdrawPicture(handle,cb_picture,NULL,picture);	// set the callback for drawing pictures
#if 1
		retval=dMagnetic_run(handle);	// run the virtual machine	
#else 
		dMagnetic_dumppics(handle);	// decode all the pictures
		do
		{
			int i;
			tdMagneticVMstate vmState;
		
			retval=dMagnetic_singleStep(handle);	// perform one command at a time
			dMagnetic_getVMstate(handle,&vmState);	// read the state of the VM. to print it.
			printf("\x1b[1;33m %04x PCR:%08x SR:%02x ",vmState.lastOpcode,vmState.pcr,vmState.sr);
			for (i=0;i<8;i++) printf("A%d:%08x ",i,vmState.aregs[i]);
			for (i=0;i<8;i++) printf("D%d:%08x ",i,vmState.dregs[i]);
			printf("\x1b[0m\n");
		} while (retval==DMAGNETIC_OK);
#endif
	} while (retval==DMAGNETIC_OK_RESTART);
	free(picture);
	free(handle);
	free(gfxbuf);
	free(magbuf);
	
	return retval;	
}
