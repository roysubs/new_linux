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
#include <string.h>
#include "configuration.h"

int retrievefromini(FILE *f,char* section,char* entry,char* retstring,int retstringspace)
{
	char line[1024];
	int i;
	int j;
	int l,ls,le;
	char lc;
	int state;
	int found;
	found=0;
	state=0;	// state 0: search for the [section]
			// state 1: search for the entry=
			// state 2: done
	if (!f)	// no .ini file?
	{
		return found;		// nothing to find in here!
	}
	ls=strlen(section);
	le=strlen(entry);
	fseek(f,0,SEEK_SET);
	do
	{
		if (fgets(line,sizeof(line),f)==NULL) return 0;
		l=strlen(line);
		j=0;
		lc=0;
		// reduce the line: remove spaces, unless they are escaped.
		for (i=0;i<l;i++)
		{
			char c;
			c=line[i];
			if (lc=='\\' && c>=32)	// escaped
			{
				line[j++]=c;	// keep this character
			}
			else if (c==';' || c<32)
			{
				line[j++]=0;	// terminate the line here
			}
			else if (c>32 && c!='\\')
			{
				line[j++]=c;
			}
			lc=c;
		}
		line[j]=0;
		l=strlen(line);
		if (l)
		{
			if (line[0]=='[' && state==0) // this is a section, see if it is a match.
			{
				int match;
				match=(ls==l);	// cannot be a match
				for (i=0;i<l && match;i++)
				{
					if ((line[i]&0x5f)!=(section[i]&0x5f)) match=0;	// upper case search
				}
				if (match) 
				{
					state=1;		// start looking for the entry
				}
			}
			else if (line[0]=='[' && state==1)	// this is a section, the search is over
			{
				state=2;
			}
			else if (state==1)
			{
				int match;
				int i;
				match=0;
				if (l>le && line[le]=='=') match=1;

				for (i=0;i<le && match;i++)
				{
					if ((line[i]&0x5f)!=(entry[i]&0x5f)) match=0;	// upper case search
				}
				if (match && retstringspace>(l-le)) 
				{
					memcpy(retstring,&line[le+1],l-le);
					found=1;
				}
			}
		}
	}
	while (!feof(f) && state!=2 && !found);
	return found;
}
int retrievefromcommandline(int argc,char** argv,char* parameter, char* retstring,int retstringspace)
{
	int i;
	int found;
	found=0;
	for (i=0;i<argc;i++)
	{
		if (strlen(argv[i])==strlen(parameter))
		{
			if (strncmp(argv[i],parameter,strlen(parameter))==0) 
			{
				found=1;
				if (retstring!=NULL)
				{
					if (i==(argc-1)) found=-1;
					else {
						if (retstringspace>strlen(argv[i+1]))
						{
							memcpy(retstring,argv[i+1],strlen(argv[i+1])+1);
						} else found=-2;
					}
				}
			}
		}
	}
	return found;
}

