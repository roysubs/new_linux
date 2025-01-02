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

#ifndef	VM68K_DECODE_H
#define	VM68K_DECODE_H
//#define	DEBUG_PRINT
#include "vm68k_datatypes.h"


// this data structure makes the decoding process easier to read.
typedef	enum _tVM68k_instruction
{
VM68K_INST_UNKNOWN=0,
VM68K_INST_ABCD,	//1100xxx10000myyy
 VM68K_INST_ADD,	//1101 rrro oomm myyy
 VM68K_INST_ADDA,	//1101 rrro oomm myyy
 VM68K_INST_ADDI,	//0000 0110 ssmm myyy
 VM68K_INST_ADDQ,	//0101 ddd0 ssmm myyy
 VM68K_INST_ADDX,	//1101 xxx1 ss00 myyy
 VM68K_INST_AND,	//1100 xxxo oomm myyy
 VM68K_INST_ANDI,	//0000 0010 ssmm myyy
 VM68K_INST_ANDItoCCR,	//0000 0010 0011 1100 00000000dddddddd
 VM68K_INST_ANDItoSR,	//0000 0010 0111 1100 dddddddddddddddd
 VM68K_INST_ASL_ASR,	//1110 cccd ssl0 0yyy
 VM68K_INST_BCC,	//0110 CCCC dddd dddd
 VM68K_INST_BCHG,	//0000 xxx1 01mm myyy
 VM68K_INST_BCHGB,	//0000 1000 10mm myyy
 VM68K_INST_BCLR,	//0000 xxx1 10mm myyy
 VM68K_INST_BCLRI,	//0000xxx110mmmyyy
 VM68K_INST_BRA,	//0110 0000 dddd dddd
 VM68K_INST_BSET,	//0000 xxx1 11mm myyy
 VM68K_INST_BSETB,	//0000 1000 11mm myyy
// VM68K_INST_BSR,		//01100001dddddddd
 VM68K_INST_BTST,	//0000 xxx1 00mm myyy
 VM68K_INST_BTSTB,	//0000 1000 00mm myyy
VM68K_INST_CHK,		//0100xxxss0mmmyyy
 VM68K_INST_CLR,	//0100 0010 ssmm myyy
 VM68K_INST_CMP,	//1011 xxxo oomm myyy
 VM68K_INST_CMPA,	//1011 xxxo oomm myyy
 VM68K_INST_CMPI,	//0000 1100 ssmm myyy
 VM68K_INST_CMPM,	//1011 xxx1 ss00 1yyy
 VM68K_INST_DBcc,	//0101 CCCC 1100 1yyy
VM68K_INST_DIVS,	//1000xxx111mmmyyy
VM68K_INST_DIVU,	//1000xxx011mmmyyy
 VM68K_INST_EOR,	//1011 xxxo oomm myyy
 VM68K_INST_EORI,	//0000 1010 ssmm myyy
 VM68K_INST_EORItoCCR,	//0000 1010 0011 1100 00000000dddddddd
 VM68K_INST_EORItoSR,	//0000 1010 0111 1100 dddddddddddddddd
 VM68K_INST_EXG,	//1100 xxx1 oooo oyyy
 VM68K_INST_EXT,	//0100 100o oo00 0yyy
VM68K_INST_ILLEGAL,	//0100101011111100
 VM68K_INST_JMP,	//0100 1110 11mm myyy
 VM68K_INST_JSR,	//0100 1110 10mm myyy
 VM68K_INST_LEA,	//0100 xxx1 11mm myyy
VM68K_INST_LINK,	//0100111001010yyydddddddddddddddd
 VM68K_INST_LSL_LSR,	//1110 cccd ssl0 1yyy
 VM68K_INST_MOVE,	//00ss xxxm mmMM Myyy
 VM68K_INST_MOVEA,	//00ss xxx0 01mm myyy
 VM68K_INST_MOVEtoCCR,	//0100010011mmmyyy
 VM68K_INST_MOVEfromSR,	//0100000011mmmyyy
 VM68K_INST_MOVEtoSR,	//0100011011mmmyyy
VM68K_INST_MOVEUSP,	//010011100110dyyy
 VM68K_INST_MOVEMregtomem,	//0100 1d00 1smm myyy
 VM68K_INST_MOVEMmemtoreg,	//0100 1d00 1smm myyy
VM68K_INST_MOVEP,	//0000xxxooo001yyydddddddddddddddd
 VM68K_INST_MOVEQ,	//0111xxx0dddddddd
VM68K_INST_MULS,	//1100xxx111mmmyyy
VM68K_INST_MULU,	//1100xxx011mmmyyy!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
VM68K_INST_NBCD,	//1100xxx011mmmyyy!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
 VM68K_INST_NEG,	//0100 0100 ssmm myyy
 VM68K_INST_NEGX,	//0100 0000 ssmm myyy
 VM68K_INST_NOP,	//0100 1110 0111 0001
 VM68K_INST_NOT,	//0100 0110 ssmm myyy
 VM68K_INST_OR,		//1000 xxxo oomm myyy
 VM68K_INST_ORI,	//0000 0000 ssmm myyy
 VM68K_INST_ORItoCCR,	//0000 0000 0011 1100 00000000dddddddd
 VM68K_INST_ORItoSR,	//0000 0000 0111 1100 dddddddddddddddd
 VM68K_INST_PEA,	//0100 1000 01mm myyy
VM68K_INST_RESET,	//0100111001110000
 VM68K_INST_ROL_ROR,	//1110 cccd ssl1 1yyy
 VM68K_INST_ROXL_ROXR,	//1110 cccd ssl1 0yyy
VM68K_INST_RTE,		//0100 1110 0111 0011
VM68K_INST_RTR,		//0100 1110 0111 0111
 VM68K_INST_RTS,	//0100 1110 0111 0101
VM68K_INST_SBCD,	//1000xxx10000ryyy
 VM68K_INST_SCC,	//0101 CCCC 11mm myyy
VM68K_INST_STOP,	//0100111001110010iiiiiiiiiiiiiiii
 VM68K_INST_SUB,	//1001 xxxo oomm myyy
 VM68K_INST_SUBA,	//1001 xxxo oomm myyy
 VM68K_INST_SUBI,	//0000 0100 ssmm myyy
 VM68K_INST_SUBQ,	//0101 ddd1 ssmm myyy
 VM68K_INST_SUBX,	//1001 yyy1 ss00 ryyy
VM68K_INST_SWAP,	//0100100001000yyy
VM68K_INST_TAS,		//0100101011mmmyyy
VM68K_INST_TRAP,	//010011100100vvvv
VM68K_INST_TRAPV,	//0100111001110110
 VM68K_INST_TST,	//0100 1010 ssmm myyy
VM68K_INST_UNLK,	//0100111001011yyy
} tVM68k_instruction;



// opcodes are 16 bit values, this function translates them into an easier-to-handle enumeration.
tVM68k_instruction vm68k_decode(tVM68k_uword opcode);

#ifdef	DEBUG_PRINT
// this function is for translating the enumeration into something human-readable.
void vm68k_get_instructionname(tVM68k_instruction instruction,char* name);
#endif

#endif
