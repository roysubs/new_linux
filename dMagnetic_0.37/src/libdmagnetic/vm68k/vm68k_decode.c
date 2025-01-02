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
#include "vm68k_datatypes.h"
#include "vm68k_decode.h"


// the purpose of this function is to perform a pattern matching to the instruction, and return the enumeration value.
// the more bits are constant, the higher should be the matche's priority.
tVM68k_instruction vm68k_decode(tVM68k_uword opcode)
{

	// instructions with 16 constant bits
	if ((opcode&0xffff)==0x023c) return VM68K_INST_ANDItoCCR;	//ANDItoCCR: 0000 0010 0011 1100 00000000dddddddd
	if ((opcode&0xffff)==0x027c) return VM68K_INST_ANDItoSR;	//ANDItoSR:  0000 0010 0111 1100 dddddddddddddddd
	if ((opcode&0xffff)==0x0A3C) return VM68K_INST_EORItoCCR;	//EORItoCCR: 0000 1010 0011 1100 00000000dddddddd
	if ((opcode&0xffff)==0x0A7C) return VM68K_INST_EORItoSR;	//EORItoSR:  0000 1010 0111 1100 dddddddddddddddd
	if ((opcode&0xffff)==0x4AFC) return VM68K_INST_ILLEGAL;		//ILLEGAL:   0100 1010 1111 1100
	if ((opcode&0xffff)==0x4E71) return VM68K_INST_NOP;
	if ((opcode&0xffff)==0x003C) return VM68K_INST_ORItoCCR;	//ORItoCCR:  0000 0000 0011 1100 00000000dddddddd
	if ((opcode&0xffff)==0x007C) return VM68K_INST_ORItoSR;		//ORItoSR:   0000 0000 0111 1100 dddddddddddddddd
	if ((opcode&0xffff)==0x4E70) return VM68K_INST_RESET;		//RESET:     0100 1110 0111 0000
	if ((opcode&0xffff)==0x4E73) return VM68K_INST_RTE;		//RTE:       0100 1110 0111 0011
	if ((opcode&0xffff)==0x4E77) return VM68K_INST_RTR;		//RTR:       0100 1110 0111 0111
	if ((opcode&0xffff)==0x4E75) return VM68K_INST_RTS;		//RTS:       0100 1110 0111 0101
	if ((opcode&0xffff)==0x4E72) return VM68K_INST_STOP;		//STOP:      0100 1110 0111 0010 iiiiiiiiiiiiiiii
	if ((opcode&0xffff)==0x4E76) return VM68K_INST_TRAPV;		//TRAPV:     0100 1110 0111 0110



	// instructions with 13 constant bits
	if ((opcode&0xfff8)==0x4E50) return VM68K_INST_LINK;		//LINK:      0100 1110 0101 0yyy dddddddddddddddd
	if ((opcode&0xfff8)==0x4840) return VM68K_INST_SWAP;		//SWAP:      0100 1000 0100 0yyy
	if ((opcode&0xfff8)==0x4E58) return VM68K_INST_UNLK;		//UNLK:      0100 1110 0101 1yyy

	// instructions with 12 constant bits
	if ((opcode&0xfff0)==0x4E40) return VM68K_INST_TRAP;		//TRAP:      0100 1110 0100 vvvv
	if ((opcode&0xfff0)==0x4E60) return VM68K_INST_MOVEUSP;		//MOVE USP:  0100 1110 0110 dyyy

	// instructions with 10 constant bits
	if ((opcode&0xffc0)==0x0800) return VM68K_INST_BTSTB;		//BTST.B:    0000 1000 00mm myyy 0000 0000 bbbb bbbb
	if ((opcode&0xffc0)==0x0840) return VM68K_INST_BCHGB;		//BCHG.B:    0000 1000 01mm myyy
	if ((opcode&0xffc0)==0x0880) return VM68K_INST_BCLRI;		//BCLRI:     0000 1000 10mm myyy
	if ((opcode&0xffc0)==0x08C0) return VM68K_INST_BSETB;		//BSET.B:    0000 1000 11mm myyy

	if ((opcode&0xffc0)==0x44C0) return VM68K_INST_MOVEtoCCR;	//MOVEtoCCR: 0100 0100 11mm myyy
	if ((opcode&0xffc0)==0x40C0) return VM68K_INST_MOVEfromSR;	//MOVEfromSR:0100 0000 11mm myyy
	if ((opcode&0xffc0)==0x46C0) return VM68K_INST_MOVEtoSR;	//MOVEtoSR:  0100 0110 11mm myyy
	if ((opcode&0xffc0)==0x4840) return VM68K_INST_PEA;		//PEA:       0100 1000 01mm myyy
	if ((opcode&0xffc0)==0x4AC0) return VM68K_INST_TAS;		//TAS:       0100 1010 11mm myyy
	if ((opcode&0xffC0)==0x4EC0) return VM68K_INST_JMP;		//JMP:       0100 1110 11mm myyy
	if ((opcode&0xffC0)==0x4E80) return VM68K_INST_JSR;		//JSR:       0100 1110 10mm myyy
	if ((opcode&0xfe38)==0x4800) return VM68K_INST_EXT;		//EXT:       0100 100o oo00 0yyy

	// instructions with 9 constant bits
	if ((opcode&0xf0f8)==0x50C8) return VM68K_INST_DBcc;		//DBcc:      0101 CCCC 1100 1yyy
	if ((opcode&0xf1f0)==0xC100) return VM68K_INST_ABCD;		//ABCD:      1100 xxx1 0000 myyy 
	if ((opcode&0xf1f0)==0x8100) return VM68K_INST_SBCD;		//SBCD:      1000 xxx1 0000 ryyy
	if ((opcode&0xff80)==0x4880) return VM68K_INST_MOVEMregtomem;	//MOVEM:     0100 1000 1smm myyy	// reg to mem
	if ((opcode&0xff80)==0x4C80) return VM68K_INST_MOVEMmemtoreg;	//MOVEM:     0100 1100 1smm myyy	// mem to reg
	if ((opcode&0xf1C0)==0x01C0) return VM68K_INST_BSET;		//BSET:      0000 xxx1 11mm myyy

	// instructions with 8 constant bits
	if ((opcode&0xff00)==0x4200) return VM68K_INST_CLR;		//CLR:       0100 0010 ssmm myyy
	if ((opcode&0xff00)==0x0C00) return VM68K_INST_CMPI;		//CMPI:      0000 1100 ssmm myyy
	if ((opcode&0xff00)==0x0A00) return VM68K_INST_EORI;		//EORI:      0000 1010 ssmm myyy
	if ((opcode&0xff00)==0x0600) return VM68K_INST_ADDI;		//ADDI:      0000 0110 ssmm myyy
	if ((opcode&0xff00)==0x0200) return VM68K_INST_ANDI;		//ANDI:      0000 0010 ssmm myyy
	if ((opcode&0xff00)==0x0000) return VM68K_INST_ORI;		//ORI:       0000 0000 ssmm myyy
	if ((opcode&0xff00)==0x4400) return VM68K_INST_NEG;		//NEG:       0100 0100 ssmm myyy
	if ((opcode&0xff00)==0x4000) return VM68K_INST_NEGX;		//NEGX:      0100 0000 ssmm myyy
	if ((opcode&0xff00)==0x4600) return VM68K_INST_NOT;		//NOT:       0100 0110 ssmm myyy
	if ((opcode&0xff00)==0x0400) return VM68K_INST_SUBI;		//SUBI:      0000 0100 ssmm myyy
	if ((opcode&0xff00)==0x4A00) return VM68K_INST_TST; 		//TST:       0100 1010 ssmm myyy
	if ((opcode&0xf0C0)==0xD0C0) return VM68K_INST_ADDA;		//ADDA:      1101 rrrs 11mm myyy	// IMPORTANT! THIS HAS TO COME BEFORE ADDX!
	if ((opcode&0xf130)==0xD100) return VM68K_INST_ADDX;		//ADDX:      1101 xxx1 ss00 myyy	// s=00,01,10=ADDX. 11=ADDA!!
	if ((opcode&0xf130)==0xC100) return VM68K_INST_EXG;		//EXG:       1100 xxx1 oo00 oyyy
	if ((opcode&0xf0C0)==0x90C0) return VM68K_INST_SUBA;		//SUBA:      1001 xxxo 11mm myyy	// probably the same problem as ADDA/ADDX.
	if ((opcode&0xf130)==0x9100) return VM68K_INST_SUBX;		//SUBX:      1001 yyy1 ss00 ryyy
	if ((opcode&0xf0C0)==0xB0C0) return VM68K_INST_CMPA;		//CMPA:      1011 xxxo 11mm myyy	/// IMPORANT! THIS HAS TO COME BEFORE CMPM!
	if ((opcode&0xf138)==0xb108) return VM68K_INST_CMPM;		//CMPM:      1011 xxx1 ss00 1yyy

	// instructions with 7 constant bits
	if ((opcode&0xf1c0)==0x0140) return VM68K_INST_BCHG;		//BCHG:      0000 rrr1 01mm myyy
	if ((opcode&0xf1c0)==0x0180) return VM68K_INST_BCLR;		//BCLR:      0000 xxx1 10mm myyy
	if ((opcode&0xf1C0)==0x0100) return VM68K_INST_BTST;		//BTST:      0000 xxx1 00mm myyy
	if ((opcode&0xf1C0)==0x81C0) return VM68K_INST_DIVS;		//DIVS:      1000 xxx1 11mm myyy
	if ((opcode&0xf1C0)==0x80C0) return VM68K_INST_DIVU;		//DIVU:      1000 xxx0 11mm myyy
	if ((opcode&0xf1C0)==0xC1C0) return VM68K_INST_MULS;		//MULS:      1100 xxx1 11mm myyy
	if ((opcode&0xf1C0)==0xC0C0) return VM68K_INST_MULU;		//MULU:      1100 xxx0 11mm myyy 
	if ((opcode&0xf1C0)==0x41C0) return VM68K_INST_LEA;		//LEA:       0100 xxx1 11mm myyy
	if ((opcode&0xf038)==0x0008) return VM68K_INST_MOVEP;		//MOVEP:     0000 xxxo oo00 1yyy dddddddddddddddd

	// instructions with 6 constant bits
	if ((opcode&0xf018)==0xe018) return VM68K_INST_ROL_ROR;		//ROL/ROR:   1110 cccd ssl1 1yyy
	if ((opcode&0xf018)==0xe010) return VM68K_INST_ROXL_ROXR;	//ROXL/ROXR: 1110 cccd ssl1 0yyy
	if ((opcode&0xf0c0)==0x50C0) return VM68K_INST_SCC;		//SCC:       0101 CCCC 11mm myyy
	if ((opcode&0xf140)==0x4100) return VM68K_INST_CHK;		//CHK:       0100 xxx1 s0mm myyy
	if ((opcode&0xf018)==0xE008) return VM68K_INST_LSL_LSR; 	//LSL/LSR:   1110 cccd ssl0 1yyy 
	if ((opcode&0xf018)==0xE000) return VM68K_INST_ASL_ASR; 	//ASL/ASR:   1110 cccd ssl0 0yyy 

	// instructions with 5 constant bits
	if ((opcode&0xf100)==0x5000) return VM68K_INST_ADDQ;		//ADDQ:      0101 ddd0 ssmm myyy
	if ((opcode&0xf100)==0xb100) return VM68K_INST_EOR;		//EOR:       1011 xxx1 oomm myyy 
	if ((opcode&0xf100)==0x7000) return VM68K_INST_MOVEQ;		//MOVEQ:     0111 xxx0 dddd dddd
	if ((opcode&0xf000)==0x9000) return VM68K_INST_SUB;		//SUB:       1001 xxx0 oomm myyy
	if ((opcode&0xf100)==0x5100) return VM68K_INST_SUBQ;		//SUBQ:      0101 ddd1 ssmm myyy
	if ((opcode&0xC1C0)==0x0040) return VM68K_INST_MOVEA;		//MOVEA:     00ss xxx0 01mm myyy 

	// instructions with 4 constant bits
	//
	if ((opcode&0xf000)==0xD000) return VM68K_INST_ADD;		//ADD:	     1101 rrro oomm myyy
	if ((opcode&0xf000)==0xC000) return VM68K_INST_AND;		//AND:       1100 xxxo oomm myyy
	if ((opcode&0xf000)==0x6000) return VM68K_INST_BCC;		//BCC:       0110 CCCC dddd dddd
	if ((opcode&0xf000)==0xB000) return VM68K_INST_CMP;		//CMP:       1011 xxx0 oomm myyy
	if ((opcode&0xf000)==0x8000) return VM68K_INST_OR;		//OR:        1000 xxxo oomm myyy

	// instructions with 2 constant bits
	if ((opcode&0xc000)==0x0000) return VM68K_INST_MOVE;		//MOVE:      00ss xxxm mmMM Myyy




	return VM68K_INST_UNKNOWN;
}
#ifdef	 DEBUG_PRINT
void vm68k_get_instructionname(tVM68k_instruction instruction,char* name)
{
	#define	INSTFOUND(x)  case x: snprintf(name,64,#x); break;
	switch(instruction)
	{
		default:
			snprintf(name,64,"???");
			break;
		INSTFOUND(VM68K_INST_UNKNOWN)
		INSTFOUND(VM68K_INST_ABCD)
		INSTFOUND(VM68K_INST_ADD)
		INSTFOUND(VM68K_INST_ADDA)
		INSTFOUND(VM68K_INST_ADDI)
		INSTFOUND(VM68K_INST_ADDQ)
		INSTFOUND(VM68K_INST_ADDX)
		INSTFOUND(VM68K_INST_AND)
		INSTFOUND(VM68K_INST_ANDI)
		INSTFOUND(VM68K_INST_ANDItoCCR)
		INSTFOUND(VM68K_INST_ANDItoSR)
		INSTFOUND(VM68K_INST_ASL_ASR)
		INSTFOUND(VM68K_INST_BCC)
		INSTFOUND(VM68K_INST_BCHG)
		INSTFOUND(VM68K_INST_BCHGB)
		INSTFOUND(VM68K_INST_BCLR)
		INSTFOUND(VM68K_INST_BCLRI)
		INSTFOUND(VM68K_INST_BRA)
		INSTFOUND(VM68K_INST_BSET)
		INSTFOUND(VM68K_INST_BSETB)
		//INSTFOUND(VM68K_INST_BSR)
		INSTFOUND(VM68K_INST_BTST)
		INSTFOUND(VM68K_INST_BTSTB)
		INSTFOUND(VM68K_INST_CHK)
		INSTFOUND(VM68K_INST_CLR)
		INSTFOUND(VM68K_INST_CMP)
		INSTFOUND(VM68K_INST_CMPA)
		INSTFOUND(VM68K_INST_CMPI)
		INSTFOUND(VM68K_INST_CMPM)
		INSTFOUND(VM68K_INST_DBcc)
		INSTFOUND(VM68K_INST_DIVS)
		INSTFOUND(VM68K_INST_DIVU)
		INSTFOUND(VM68K_INST_EOR)
		INSTFOUND(VM68K_INST_EORI)
		INSTFOUND(VM68K_INST_EORItoCCR)
		INSTFOUND(VM68K_INST_EORItoSR)
		INSTFOUND(VM68K_INST_EXG)
		INSTFOUND(VM68K_INST_EXT)
		INSTFOUND(VM68K_INST_ILLEGAL)
		INSTFOUND(VM68K_INST_JMP)
		INSTFOUND(VM68K_INST_JSR)
		INSTFOUND(VM68K_INST_LEA)
		INSTFOUND(VM68K_INST_LINK)
		INSTFOUND(VM68K_INST_LSL_LSR)
		INSTFOUND(VM68K_INST_MOVE)
		INSTFOUND(VM68K_INST_MOVEA)
		INSTFOUND(VM68K_INST_MOVEtoCCR)
		INSTFOUND(VM68K_INST_MOVEfromSR)
		INSTFOUND(VM68K_INST_MOVEtoSR)
		INSTFOUND(VM68K_INST_MOVEUSP)
		INSTFOUND(VM68K_INST_MOVEMregtomem)
		INSTFOUND(VM68K_INST_MOVEMmemtoreg)
		INSTFOUND(VM68K_INST_MOVEP)
		INSTFOUND(VM68K_INST_MOVEQ)
		INSTFOUND(VM68K_INST_MULS)
		INSTFOUND(VM68K_INST_MULU)
		INSTFOUND(VM68K_INST_NBCD)
		INSTFOUND(VM68K_INST_NEG)
		INSTFOUND(VM68K_INST_NEGX)
		INSTFOUND(VM68K_INST_NOP)
		INSTFOUND(VM68K_INST_NOT)
		INSTFOUND(VM68K_INST_OR)
		INSTFOUND(VM68K_INST_ORI)
		INSTFOUND(VM68K_INST_ORItoCCR)
		INSTFOUND(VM68K_INST_ORItoSR)
		INSTFOUND(VM68K_INST_PEA)
		INSTFOUND(VM68K_INST_RESET)
		INSTFOUND(VM68K_INST_ROL_ROR)
		INSTFOUND(VM68K_INST_ROXL_ROXR)
		INSTFOUND(VM68K_INST_RTE)
		INSTFOUND(VM68K_INST_RTR)
		INSTFOUND(VM68K_INST_RTS)
		INSTFOUND(VM68K_INST_SBCD)
		INSTFOUND(VM68K_INST_SCC)
		INSTFOUND(VM68K_INST_STOP)
		INSTFOUND(VM68K_INST_SUB)
		INSTFOUND(VM68K_INST_SUBA)
		INSTFOUND(VM68K_INST_SUBI)
		INSTFOUND(VM68K_INST_SUBQ)
		INSTFOUND(VM68K_INST_SUBX)
		INSTFOUND(VM68K_INST_SWAP)
		INSTFOUND(VM68K_INST_TAS)
		INSTFOUND(VM68K_INST_TRAP)
		INSTFOUND(VM68K_INST_TRAPV)
		INSTFOUND(VM68K_INST_TST)
		INSTFOUND(VM68K_INST_UNLK)
	}

}
#endif
