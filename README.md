# P6-Tomasulo

Course project for ECE4700J, Computer Architecture

Implementation of a Scalar Intel P6 Style (using Tomasulo Algorithm + ROB) Out-of-Order pipeline for VeriSimpleV using SystemVerilog.

## Run

include/sys_defs.svh should be configured as a global header.

## Components Implemented

- Renaming Unit
- Reservation Station
- Register File

## Design Principals

- The Reservation Station ahead of the Integer Unit should have more entries
  - most instructions are simple arithmetics
  - in case no instructions in a smaller RS is ready

- Two 
  
  