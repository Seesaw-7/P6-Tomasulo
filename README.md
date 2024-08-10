# P6-Tomasulo

Course project for ECE4700J, Computer Architecture

Implementation of a Scalar Intel P6 Style (using Tomasulo Algorithm + ROB) Out-of-Order pipeline for VeriSimpleV using SystemVerilog.

## Success Tests
Test program 1:
00000000 <.text>:
   0: 00110113           addi x2,x2,1
   4: 002181b3           add x3,x3,x2
   8: 00820213           addi x4,x4,8 # 8 <_ebss-0x78>
   c: 00828293           addi x5,x5,8
  10: 00150513           addi x10,x10,1
  14: 01052593           slti x11,x10,16
  18: 00830313           addi x6,x6,8
  1c: 10500073           wfi

002181b300110113
0082829300820213
0105259300150513
1050007300830313
00000000000


Test program 2
00000000 <_start>:
   0: 00000093           addi x1,x0,0
   4: 00500113           addi x2,x0,5
   8: 00008463           beq x1,x0,10 <label>
   c: 00210133           add x2,x2,x2

00000010 <label>:
  10: 00110193           addi x3,x2,1

00000014 <loop>:
  14: 0000006f           jal x0,14 <loop>
 ...

0050011300000093
0021013300008463
0000006f00110193
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000


Test program 3
00000000 <_start>:
   0: 00100093           addi x1,x0,1
   4: 00500113           addi x2,x0,5
   8: 00008463           beq x1,x0,10 <label>
   c: 00210133           add x2,x2,x2

00000010 <label>:
  10: 00110193           addi x3,x2,1

00000014 <loop>:
  14: 0000006f           jal x0,14 <loop>
 ...

0050011300100093
0021013300008463
0000006f00110193
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000


Test program 4
00000000 <_start>:
   0: 00300093           addi x1,x0,3
   4: 00400113           addi x2,x0,4
   8: 022081b3           mul x3,x1,x2

0000000c <loop>:
   c: 0000006f           jal x0,c <loop>

0040011300300093
0000006f022081b3
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000


Test program 5
00000000 <.text>:
   0:	00100113          	addi	x2,x0,1
   4:	00300193          	addi	x3,x0,3
   8:	10000213          	addi	x4,x0,256
   c:	00222023          	sw	x2,0(x4) # 0 <_ebss-0x80>
  10:	00322223          	sw	x3,8(x4) # 4 <_ebss-0x7c>
  14:	00000013          	addi	x0,x0,0
  18:	00000013          	addi	x0,x0,0
  1c:	00110113          	addi	x2,x2,1
  20:	002181b3          	add	x3,x3,x2
  24:	00022283          	lw	x5,0(x4) # 0 <_ebss-0x80>
  28:	00422303          	lw	x6,8(x4) # 4 <_ebss-0x7c>
  2c:	00820213          	addi	x4,x4,8 # 8 <_ebss-0x78>
  30:	00150513          	addi	x10,x10,1
  34:	01052593          	slti	x11,x10,16
  38:	10500073          	wfi
	...

0030019300100113
0022202310000213
0000001300322423
0011011300000013
00022283002181b3
0082021300822303
0105259300150513
0000000010500073
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000


Test program 6
00000000 <.text>:
   0:	00100113          	addi	x2,x0,1
   4:	00300193          	addi	x3,x0,3
   8:	10000213          	addi	x4,x0,256
   c:	00222023          	sw	x2,0(x4) # 0 <_ebss-0x80>
  10:	00322223          	sw	x3,4(x4) # 4 <_ebss-0x7c>
  14:	00000013          	addi	x0,x0,0
  18:	00000013          	addi	x0,x0,0
  1c:	00110113          	addi	x2,x2,1
  20:	002181b3          	add	x3,x3,x2
  24:	00022283          	lw	x5,0(x4) # 0 <_ebss-0x80>
  28:	00422303          	lw	x6,4(x4) # 4 <_ebss-0x7c>
  2c:	00820213          	addi	x4,x4,8 # 8 <_ebss-0x78>
  30:	00150513          	addi	x10,x10,1
  34:	01052593          	slti	x11,x10,16
  38:	10500073          	wfi
	...

0030019300100113
0022202310000213
0000001300322223
0011011300000013
00022283002181b3
0082021300422303
0105259300150513
0000000010500073
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000


## Run

include/sys_defs.svh should be configured as a global header.

## Components Implemented

- Pre-Fetch Queue
- Map Table
- Dispatcher
- Reoder Buffer
- Register File
- Reservation Station
- Functional Units
  - Arithmetic and Logic Unit
  - Multiplier
  - Branch Target Unit
- Common Data Bus

## Components To Be Implemented

- Decoder
- Cache
- Load/Store Unit

## To Be Refactored

- sync ALU & BTU
- FUs carry ROB
- Early issue FUs && CDB Broadcast 4 values to 4 RSs

## Design Principals

- The Reservation Station ahead of the Integer Unit should have more entries
  - most instructions are simple arithmetics
  - in case no instructions in a smaller RS is ready

- One Multipliers
  - one multiplier has 8-cycle latency
  - but it is pipelined
  - and the bandwidth of CDB is single-value

  
