#!/bin/awk -f
# Assembler for the educational Hack architecture

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
	FS = "[@\\(\\)]";
	regex_constant	= "[[:digit:]]+";
	regex_symbol	= "[_[:alpha:]\\.\\$:][_[:alnum:]\\.\\$:]*";
	regex_labeldef	= "^\\(" regex_symbol "\\)$";
	regex_aconstant	= "^@" regex_constant "$";
	regex_asymbol	= "^@" regex_symbol "$";

	err_ofs	= ": ";
	err_ors	= ORS;
	err_prefix	= "%s:%d";
	err_error	= err_prefix err_ofs "Error";
	err_label_redefined	= err_error err_ofs "label symbol `%s' redefined";
	err_invalid_instruction	= err_error err_ofs "invalid %c-instruction `%s'";
	err_out_of_range	= err_invalid_instruction err_ofs "constant `%d' out of range";
	err_invalid_field	= err_invalid_instruction err_ofs "invalid %s field `%s'";
	err_missing_field	= err_invalid_instruction err_ofs "missing %s field";
	err_empty_field	= err_invalid_instruction err_ofs "empty %s field";

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

	# incremented by lines that don't generate code
	# address = line - offset
	# initially 1 because line numbers start at 1 while addressing starts at 0
	line_address_offset = 1;

	# Predefined labels
	# general purpose registers (R0-R15)
	for (variable = 0; variable < 16; variable++) {
		symbols["R" i] = i;
	}
	symbols["SP"]	= 0; # stack pointer
	symbols["LCL"]	= 1; # local variable pointer
	symbols["ARG"]	= 2; # argument variable pointer
	symbols["THIS"]	= 3; # object pointer
	symbols["THAT"]	= 4; # array pointer
	symbols["SCREEN"]	= 16384; # memory mapped screen (0x4000)
	symbols["KBD"]	= 24576; # memory mapped keybaord (0x6000)

	errorcount = 0;
}

# Common for both passes
{
	gsub("([[:space:]]|//.*)", ""); # Remove whitespace and comments
}

# First pass (create label symbol table)
NR == FNR {
	if ($0 == "") {
		# empty line, doesn't generate code
		line_address_offset++;
	}
	else if (match($0, regex_labeldef)) {
		# label symbol definition, doesn't generate code
		if ($2 in symbols) {
			printf(err_label_redefined err_ors, FILENAME, FNR, $2) >> "/dev/stderr";
			if (errorcount < 126) errorcount++;
		}
		symbols[$2] = FNR - line_address_offset++;
	}
}

# Second pass
NR != FNR {
	if ($0 == "" || match($0, regex_labeldef)) {
		# comment, label symbol definition or empty line, doesn't generate code
		next;
	}
	else if (substr($0, 1, 1) == "@") {
		# A-instruction
		instruction = 0;

		if (match($0, regex_aconstant)) {
			instruction = $1;
		}
		else if (match($0, regex_asymbol)) {
			instruction = ($1 in symbols) ? symbols[$1] : (symbols[$1] = variable++);
		}
		else {
			printf(err_invalid_instruction err_ors, FILENAME, FNR, "A", $0) >> "/dev/stderr";
			if (errorcount < 126) errorcount++;
		}

		if (instruction >= 32768) { # 1000 0000 0000 0000
			printf(err_out_of_range err_ors, FILENAME, FNR, "A", $0, instruction) >> "/dev/stderr";
			if (errorcount < 126) errorcount++;
		}
	}
	else {
		# C-instruction
		instruction = 57344; # 1110 0000 0000 0000

		if (!match($0, "^(.*=)?.*(;.*)?$")) {
			# this line is so messed up there's no point in trying to figure out
			# what's wrong with it
			printf(err_invalid_instruction err_ors, FILENAME, FNR, "C", $0) >> "/dev/stderr";
			if (errorcount < 126) errorcount++;
			print "1110""0000""0000""000";
			next;
		}

		eqindex = index($0, "=");
		scindex = index($0, ";");

		# there's no way = and ; is in the same place, so the only case in which
		# their indices will be equal is if neither is present (i.e. index()
		# returns 0), which is the case we're trying to catch and handle
		if (eqindex == scindex) {
			printf(err_missing_field err_ors, FILENAME, FNR, "C", $0, "dest or jump") >> "/dev/stderr";
			if (errorcount < 126) errorcount++;
		}

		# dest field
		if (eqindex) {
			dest = substr($0, 1, eqindex - 1);
			if (dest == "") {
				printf(err_empty_field err_ors, FILENAME, FNR, "C", $0, "dest") >> "/dev/stderr";
				if (errorcount < 126) errorcount++;
			}
			else if (!match(dest, "^A?M?D?$")) {
				printf(err_invalid_field err_ors, FILENAME, FNR, "C", $0, "dest", dest) >> "/dev/stderr";
				if (errorcount < 126) errorcount++;
				dest = "";
			}
		}
		if (index(dest, "A")) {
			instruction += 32; # 1 << 5 (d1)
		}
		if (index(dest, "D")) {
			instruction += 16; # 1 << 4 (d2)
		}
		if (index(dest, "M")) {
			instruction += 8; # 1 << 3 (d3)
		}

		# comp field
		comp = scindex ? substr($0, eqindex + 1, scindex - eqindex - 1) : substr($0, eqindex + 1);
		if (comp == "") {
			printf(err_missing_field err_ors, FILENAME, FNR, "C", $0, "comp") >> "/dev/stderr";
			if (errorcount < 126) errorcount++;
		}
		else {
			a = index(comp, "M");
			if (a) {
				instruction += 4096; # 1 << 12 (a)
			}

			compindex = a ? sub("M", "A", comp) : comp;
			if (compindex in comptable) {
				instruction += comptable[compindex];
			}
			else {
				printf(err_invalid_field err_ors, FILENAME, FNR, "C", $0, "comp", comp) >> "/dev/stderr";
				if (errorcount < 126) errorcount++;
			}
		}

		# jump field
		if (scindex) {
			jump = substr($0, scindex + 1);
			if (jump == "") {
				printf(err_empty_field err_ors, FILENAME, FNR, "C", $0, "jump") >> "/dev/stderr";
				if (errorcount < 126) errorcount++;
			}
		}
		if (jump in jumptable) {
			instruction += jumptable[jump];
		}
		else {
			printf(err_invalid_field err_ors, FILENAME, FNR, "C", $0, "jump", jump) >> "/dev/stderr";
			if (errorcount < 126) errorcount++;
		}
	}

	printf("%04X\n", instruction);
}

END {
	if (errorcount > 0) exit(retval);
}
