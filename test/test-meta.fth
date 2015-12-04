\ -*- forth -*- Copyright 2004, 2013-2015 Lars Brinkhoff

\ This kernel, together with a target-specific nucleus, provides
\ everything needed to load and compile the rest of the system from
\ source code.  And not much else.  The kernel itself is compiled by
\ the metacompiler.

\ At a minimum, these 16 primitives must be provided by the nucleus:
\
\ Definitions:		dodoes exit
\ Control flow:		0branch
\ Literals:		(literal)
\ Memory access:	! @ c! c@
\ Aritmetic/logic:	+ nand
\ Return stack:		>r r>
\ I/O:			emit open-file read-file close-file

: noop ;

create jmpbuf         jmp_buf allot

variable dictionary_end

variable SP
variable RP

: cell    cell ; \ Metacompiler knows what to do.
: cell+   cell + ;

[undefined] sp@ [if]
: sp@   SP @ cell + ;
: sp!   SP ! ;
: rp@   RP @ cell + ;
\ rp! in core.fth
[then]

variable  temp
[undefined] drop [if]
: drop    temp ! ;
[then]
[undefined] 2drop [if]
: 2drop   drop drop ;
[then]
: 3drop   2drop drop ;

[undefined] r@ [if]
: r@   rp@ cell+ @ ;
[then]

[undefined] swap [if]
: swap   >r temp ! r> temp @ ;
[then]
[undefined] over [if]
: over   >r >r r@ r> temp ! r> temp @ ;
[then]
: rot    >r swap r> swap ;

[undefined] 2>r [if]
: 2>r   r> swap rot >r >r >r ;
[then]
: 2r>   r> r> r> rot >r swap ;


[undefined] dup [if]
: dup    sp@ @ ;
[then]
[undefined] 2dup [if]
: 2dup   over over ;
[then]
: 3dup   >r >r r@ over 2r> over >r rot swap r> ;
[undefined] ?dup [if]
: ?dup   dup if dup then ;
[then]

[undefined] nip [if]
: nip    swap drop ;
[then]

[undefined] invert [if]
: invert   -1 nand ;
[then]
[undefined] negate [if]
: negate   invert 1 + ;
[then]
[undefined] - [if]
: -        negate + ;
[then]

[undefined] branch [if]
: branch    r> @ >r ;
[then]
forward: <
: (+loop)   r> swap r> + r@ over >r < invert swap >r ;
: unloop    r> 2r> 2drop >r ;

[undefined] 1+ [if]
: 1+   1 + ;
[then]
[undefined] +! [if]
: +!   swap over @ + swap ! ;
[then]
[undefined] 0= [if]
: 0=   if 0 else -1 then ;
[then]
[undefined] = [if]
: =    - 0= ;
[then]
[undefined] <> [if]
: <>   = 0= ;
[then]

: min   2dup < if drop else nip then ;

: bounds   over + swap ;
: count    dup 1+ swap c@ ;

: i    r> r@ swap >r ;
: cr   10 emit ;
: type   ?dup if bounds do i c@ emit loop else drop then ;

\ Put the xt inside the definition of EXECUTE, overwriting the last noop.
[undefined] execute [if]
: execute   [ here cell + ] ['] noop ! then noop ;
[then]
: perform   @ execute ;

variable state

[undefined] 0< [if]
: 0<   [ 0 invert 1 rshift invert ] literal nand invert if -1 else 0 then ;
[then]
[undefined] or [if]
: or   invert swap invert nand ;
[then]
[undefined] xor [if]
: xor   2dup nand 1+ dup + + + ;
[then]
: <   2dup xor 0< if drop 0< else - 0< then ;

: cmove ( addr1 addr2 n -- )   ?dup if bounds do count i c! loop drop
   else 2drop then ;

: cabs   127 over < if 256 swap - then ;

0 value latestxt

include dictionary.fth

: lowercase? ( c -- flag )   dup [char] a < if drop 0 exit then [ char z 1+ ] literal < ;
: upcase ( c1 -- c2 )   dup lowercase? if [ char A char a - ] literal + then ;
: c<> ( c1 c2 -- flag )   upcase swap upcase <> ;

: name= ( ca1 u1 ca2 u2 -- flag )
   2>r r@ <> 2r> rot if 3drop 0 exit then
   bounds do
      dup c@ i c@ c<> if drop unloop 0 exit then
      1+
  loop drop -1 ;
: nt= ( ca u nt -- flag )   >name name= ;

: immediate?   c@ 127 swap < if 1 else -1 then ;

\ TODO: nt>string nt>interpret nt>compile
\ Forth83: >name >link body> name> link> n>link l>name

: traverse-wordlist ( wid xt -- ) ( xt: nt -- continue? )
   >r >body @ begin dup while
      r@ over >r execute r> swap
      while >nextxt
   repeat then r> 2drop ;

: ?nt>xt ( -1 ca u nt -- 0 xt i? 0 | -1 ca u -1 )
   3dup nt= if >r 3drop 0 r> dup immediate? 0
   else drop -1 then ;
: (find) ( ca u wl -- ca u 0 | xt 1 | xt -1 )
   2>r -1 swap 2r> ['] ?nt>xt traverse-wordlist rot if 0 then ;
: search-wordlist ( ca u wl -- 0 | xt 1 | xt -1 )
   (find) ?dup 0= if 2drop 0 then ;

[undefined] (sliteral) [if]
: (sliteral)   r> dup @ swap cell+ 2dup + aligned >r swap ;
[then]

defer abort
: undef ( a u -- )   ." Undefined: " type cr abort ;
: ?undef ( a u x -- a u )   if undef then ;

: literal   compile (literal) , ; immediate
: ?literal ( x -- )   state @ if [compile] literal then ;

defer number

\ Sorry about the long definition, but I didn't want to leave many
\ useless factors lying around.
: (number) ( a u -- )
   over c@ [char] - = dup >r if swap 1+ swap 1 - then
   0 rot rot
   begin dup while
      over c@ [char] 0 - -1 over < while dup 10 < while
      2>r 1+ swap dup dup + dup + + dup +  r> + swap r> 1 -
   repeat then drop then
   ?dup ?undef drop r> if negate then  ?literal ;

variable >in
variable input
: input@ ( u -- a )   cells input @ + ;
: 'source   0 input@ ;
: #source   1 input@ ;
: source#   2 input@ ;
: 'refill   3 input@ ;
: 'prompt   4 input@ ;
: source>   5 input@ ;
6 cells constant /input-source

create forth  2 cells allot
create compiler-words  2 cells allot
create included-files  2 cells allot
create context  9 cells allot


: r@+   r> r> dup cell+ >r @ swap >r ;
: search-context ( a u context -- a 0 | xt ? )   >r begin r@+ ?dup while
   (find) ?dup until else drop 0 then r> drop ;
: find-name ( a u -- a u 0 | xt ? )   swap over #name min context
   search-context ?dup if rot drop else swap 0 then ;

: source   'source @  #source @ ;
: source? ( -- flag )   >in @ source nip < ;
: <source ( -- char|-1 )   source >in @ dup rot = if
   2drop -1 else + c@  1 >in +! then ;

32 constant bl
: blank?   dup bl =  over 8 = or  over 9 = or  over 10 = or  swap 13 = or ;
: skip ( "<blanks>" -- )   begin source? while
   <source blank? 0= until -1 >in +! then ;
: parse-name ( "<blanks>name<blank>" -- a u )   skip  source drop >in @ +
   0 begin source? while 1+ <source blank? until 1 - then ;

: (previous)   ['] forth context ! ;

defer also
defer previous
defer catch

create interpreters  ' execute , ' number , ' execute ,
: ?exception   if cr ." Exception!" cr then ;
: interpret-xt   1+ cells  interpreters + @ catch ?exception ;

: [   0 state !  ['] execute interpreters !  previous ; immediate
: ]   1 state !  ['] compile, interpreters !
   also ['] compiler-words context ! ;

variable csp

: .latest   latestxt >name type ;
: ?bad   rot if type ."  definition: " .latest cr abort then 2drop ;
: !csp   csp @ s" Nested" ?bad  sp@ csp ! ;
: ?csp   sp@ csp @ <> s" Unbalanced" ?bad  0 csp ! ;

: (does>)   r> does! ;

\ If you change the definition of :, you also need to update the
\ offset to the runtime code in the metacompiler(s).
: :   parse-name header, 'dodoes , ] !csp  does> >r ;
: ;   reveal compile exit [compile] [ ?csp ; immediate

\ ----------------------------------------------------------------------

( Core extension words. )

: refill   0 >in !  0 #source !  'refill perform ;
: ?prompt    'prompt perform ;
: source-id   source# @ ;

256 constant /file

: file-refill   'source @ /file bounds do
      i 1 source-id read-file if 0 unloop exit then
      0= if source nip unloop exit then
      i c@ 10 = if leave then
      1 #source +!
   loop -1 ;

0 value file-source

: save-input   >in @ input @ 2 ;
: restore-input   drop input ! >in ! 0 ;

defer backtrace

: sigint   cr backtrace abort ;

\ ----------------------------------------------------------------------

( File Access words. )

: n>r   r> over >r swap begin ?dup while rot r> 2>r 1 - repeat >r ;
: nr>   r> r@ begin ?dup while 2r> >r rot rot 1 - repeat r> swap >r ;

\ These will be set in COLD, or by the metacompiler.
0 constant sp0
0 constant rp0
0 constant dp0

defer parsed
: (parsed) ( a u -- )   find-name interpret-xt ;
: ?stack   ; \ sp0 sp@ cell+ < abort" Stack underflow" ;
: interpret   begin parse-name dup while parsed ?stack repeat 2drop ;
: interpreting   begin refill while interpret ?prompt repeat ;

: 0source   'prompt !  'refill !  source# !  'source !  0 source> ! ;
: source, ( 'source sourceid refill prompt -- )
   input @ >r  here input !  /input-source allot  0source  r> input ! ;
: file,   0 0 ['] file-refill ['] noop source,  /file allot ;
: +file   here source> !  file, ;
: file>   source> @  ?dup if input ! else +file then ;
: alloc-file   file-source input ! begin 'source @ while file> repeat ;
: file-input ( fileid -- )   alloc-file  source# !  6 input@ 'source ! ;

: include-file ( fileid -- )   save-input n>r
   file-input interpreting  source-id close-file drop  0 'source !
   nr> restore-input abort" Bad restore-input" ;

\ : r/o   s" r" drop ;
: r/o   0 ;

: included   2dup align here >r  name,  r> included-files chain, 0 , 0 ,
   r/o open-file abort" Read error." include-file ;

: dummy-catch   execute 0 ;

defer quit

\ NOTE: THIS HAS TO BE THE LAST WORD IN THE FILE!
: warm
   ." lbForth" cr

   dp0 dp !

   ['] noop dup is backtrace is also
   ['] dummy-catch is catch
   ['] (number) is number
   ['] (parsed) is parsed
   ['] (previous) is previous
   ['] warm dup to latestxt forth !
   ['] forth current !
   here to file-source  file,

   0 forth cell+ !
   0 compiler-words !  ['] forth compiler-words cell+ !
   0 included-files !  ['] compiler-words included-files cell+ !
   ['] forth dup context ! context cell+ ! 0 context 2 cells + !

   [compile] [
   s" load.fth" included
   ." ok" cr
   quit ;
