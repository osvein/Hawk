#!/bin/awk -f
# hawk-naive - naive assembler for the educational Hack architecture

# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
#
# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# For more information, please refer to <http://unlicense.org>

BEGIN {
	FS = "[()@=;]";

	comptable["0"]	= 2688;	# 101010 << 6 (c6)
	comptable["1"]	= 4032;	# 111111 << 6 (c6)
	comptable["-1"]	= 3712;	# 111010 << 6 (c6)
	comptable["D"]	= 768;	# 001100 << 6 (c6)
	comptable["A"]	= 3072;	# 110000 << 6 (c6)
	comptable["!D"]	= 832;	# 001101 << 6 (c6)
	comptable["!A"]	= 3136;	# 110001 << 6 (c6)
	comptable["-D"]	= 960;	# 001111 << 6 (c6)
	comptable["-A"]	= 3264;	# 110011 << 6 (c6)
	comptable["D+1"]	= 1984;	# 011111 << 6 (c6)
	comptable["A+1"]	= 3520;	# 110111 << 6 (c6)
	comptable["D-1"]	= 896;	# 001110 << 6 (c6)
	comptable["A-1"]	= 3200;	# 110010 << 6 (c6)
	comptable["D+A"]	= 128;	# 000010 << 6 (c6)
	comptable["D-A"]	= 1216;	# 010011 << 6 (c6)
	comptable["A-D"]	= 448;	# 000111 << 6 (c6)
	comptable["D&A"]	= 0;	# 000000 << 6 (c6)
	comptable["D|A"]	= 1344;	# 010101 << 6 (c6)

	jumptable[""]	= 0; # 000
	jumptable["JGT"]	= 1; # 001
	jumptable["JEQ"]	= 2; # 010
	jumptable["JGE"]	= 3; # 011
	jumptable["JLT"]	= 4; # 100
	jumptable["JNE"]	= 5; # 101
	jumptable["JLE"]	= 6; # 110
	jumptable["JMP"]	= 7; # 111

	# incremented on first pass by lines that don't generate code
	# address = line - offset
	# initially 1 because line numbers start at 1 while addressing starts at 0
	line_address_offset = 1;

	# Predefined labels
	# general purpose registers (R0-R15)
	for (i = 0; i < 16; i++) {
		symbols["R" i] = i;
	}
	symbols["SP"]	= 0; # stack pointer
	symbols["LCL"]	= 1; # local variable pointer
	symbols["ARG"]	= 2; # argument variable pointer
	symbols["THIS"]	= 3; # object pointer
	symbols["THAT"]	= 4; # array pointer
	symbols["SCREEN"]	= 16384; # memory mapped screen (0x4000)
	symbols["KBD"]	= 24576; # memory mapped keybaord (0x6000)
}

NR == 1 { ARGV[ARGC++] = FILENAME; }

# Common for both passes
{
	sub("//.*", ""); # Remove comments
	gsub("[[:space:]]", ""); # Remove whitespace
	firstchar = substr($0, 1, 1);
}

$0 == ""
{
	line_address_offset++;
	next;
}

firstchar == "("
{
	if (NR == FNR) symbols[$2] = FNR - line_address_offset++;
	next;
}

NR != FNR
{
	if (firstchar == "@") {
		# A-instruction
		instruction = (($2 == $2 + 0) ? $2 : (($2 in symbols) ? symbols[$2] : (symbols[$2] = varaddr++)));
	} else {
		# C-instruction
		instruction = 57344; # 1110 0000 0000 0000
		if (!index($0, "=")) $0 = "=" $0;

		# dest field
		if (index($1, "A")) instruction += 32; # 1 << 5 (d1)
		if (index($1, "D")) instruction += 16; # 1 << 4 (d2)
		if (index($1, "M")) instruction += 8; # 1 << 3 (d3)

		# comp field
		if (sub($2, "M", "A")) instruction += 4096; # 1 << 12 (a)
		instruction += comptable[$2];

		# jump field
		instruction += jumptable[$3];
	}
	printf("%04X\n", instruction);
}
