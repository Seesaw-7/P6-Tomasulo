# P6-Tomasulo

Course project for ECE4700J, Computer Architecture

Implementation of a Scalar Intel P6 Style (using Tomasulo Algorithm + ROB) Out-of-Order pipeline for VeriSimpleV using SystemVerilog.

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
  