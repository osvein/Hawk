# Hawk
Strict and verbose Hack assembler written in POSIX-compliant AWK

Hack is an educational computer architecture designed for [the Nand2Tetris courses](http://nand2tetris.org).
The assembly language for the Hack architecture is described in [chapter 6 of The Elements of Computing Systems](http://nand2tetris.org/chapters/chapter%2006.pdf),
the book accompanying the courses.

## Usage
Hawk will assemble the contents of the first file specified on the command line:

    $ ./hawk.awk Prog.asm

Each invocation of Hawk can assemble only one assembly.

## Caveats
### Standard input
Hawk processes an assembly in two passes. This enables it to expand label
symbols prior to their definition, as described in the book. Unfortunately,
this means that if Hawk is to read assembly from standard input, the assembly
must be passed twice:

    $ { cat Prog.asm; cat Prog.asm } | ./hawk.awk

Note that `cat` (or whatever program you're trying to pipe into Hawk) must be
invoked twice (i.e. `cat Prog.asm Prog.asm` won't do) for Hawk to be able to
tell the two passes apart (with an EOF). Therefore, passing assembly through
standard input should be avoided. Instead, the output of the command you're
trying to pipe into Hawk should be redirected to a file that can be passed to
Hawk on the command line:

    $ cat Prog.asm > Prog.tmp && ./hawk.awk Prog.tmp

(`cat Prog.asm` in the above examples is just a placeholder for whatever
you're trying to pipe into Hawk. `cat` should never be used this way.)

### Output format
Due to lack of bitwise operators in POSIX AWK, Hawk outputs instructions as
ASCII encoded hexadecimals, rather than the ASCII encoded binary format
described by the book. The format from the book can be achieved by piping the
output into bc:

    $ { echo "ibase=F;obase=2"; ./hawk.awk Prog.asm } | bc | awk '{printf("%016d\n",$0)}'

The last awk command can also be modified to split the output every 4 bits for
readability (but this is incompatible with the format described in the book):

    $ { echo "ibase=F;obase=2"; ./hawk.awk Prog.asm } | bc | awk '{$0=sprintf("%016d",$0); gsub(".{4}","& ")}'
