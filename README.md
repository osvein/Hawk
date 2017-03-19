# Hawk
Strict and verbose Hack assembler written in POSIX-compliant AWK

Hack is an educational computer architecture designed for [the Nand2Tetris courses](http://nand2tetris.org).
The assembly language for the Hack architecture is described in [chapter 6 of The Elements of Computing Systems](http://nand2tetris.org/chapters/chapter%2006.pdf),
the book accompanying the courses.

## Usage
Hawk processes its input in two passes. This enables it to expand label symbols
prior to their definition, as described in the book. However, this also means
that the input file must be passed twice:

	$ ./hawk.awk Prog.asm Prog.asm

Due to lack of bitwise operators in POSIX AWK, Hawk outputs instructions as
ASCII encoded hexadecimals, rather than the ASCII encoded binary format
described by the book. The format from the book can be achieved by piping the
output into bc:

    $ ./hawk.awk Prog.asm Prog.asm | cat <(echo "ibase=16;obase=2") - | bc | awk '{printf("%016d\n",$0)}'

The last awk command can also be modified to split the output every 4 bits for
readability:

    $ ./hawk.awk Prog.asm Prog.asm | cat <(echo "ibase=16;obase=2") - | bc | awk '{$0=sprintf("%016d",$0);gsub(".{4}","& ")}'
