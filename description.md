# Description for All Modules

## pipeline

- all outputs are output directly from the stage register

### Fetch stage

- input: a set of instruction from cache / mem
- reg: a queue which stores instructions in order
- output: the first instruction of the queue

1. fetch instructions from cache / mem
2. store all instructions in order in the queue
3. combine each instruction with its PC ad NPC
4. output one instruction per cycle: if the queue is not empty, output the first instruction with valid bit 1; otherwise output with valid bit 0


**|> COMPONENTS**

prefetch_queue (module)
1. bind PC with insn in order
2. valid bits indicating whether insn in queue has been fetched successfully


### Dispatch Stage

- input: an instruction with a valid bit
- reg: four issue queue in RS
- output: issue queue entries
- components: decoder, dispatcher (with map table), part of rob

(dispatcher: all comb)
1. check whether the input instruction is valid: if valid, enable; otherwise disable
2. receive an instruction from fetch stage
3. receive a tag from rob and assign it to the instruction
4. check whether renaming is needed: if rd is r0, skip; otherwise send rob tag and rd to map_table_next
5. read src1 and src2 value location from map_table_curr
6. get src1 and src2 value from rob entries and regfile
7. output all the information needed for a RS entry

(renaming)
1. receive new (rd: rob tag) and add it to map_table_next
2. receive cdb broadcast and update the location of corresponding rob tag if existing
3. receive cdb retire and remove the mapping of corresponding rob tag if existing
4. flush map_table_curr when mispredict
5. synchronous update
6. 1 < 2 < 3, 4 = reset

(RS)
1. receive new instruction from dispatcher
2. store it in entry
3. receive value and tag from fu reg when it is ready (4 pairs)
4. replace corresponding value and ready bits
5. receive retire signal and retire rob tag
6. clear entry by rob tag
7. shift all the entries to the end (can be optimized)
8. (1,2), (5,6) < (6,7)
9. synchronous update


### Issue Stage
- input: issue queue entries
- reg: state register combined in RS module
- output: an entry

(RS)
1. RS select a ready insn from entries
2. RS select an insn such that if alu clear_tag is 1 && the insn will be ready with the dest tag of this clear insn ready
3. 1, 2 parallel
4. if has a ready insn, use the result of 1; otherwise use the result of 2


### Execute Stage
- input: instructions
- reg: stage register after fu
- output: fu value

(issue unit)
1. input an insn
2. receive the value from ALU reg. If there is value inside and it can make the insn ready, then continue; othersise not issue anytihing
3. check whether fu reg is empty. If it is empty, issue the instruction; otherwise check whether cdb pick this reg. If cdb pick it, then issue it; otherwise not issue anything.
4. send the issued insn tag to RS in dispatch stage to clear the insn.

(FU)
1. receive an insn
2. calculate the result; store insn tag, value tag and value in fu reg.

TODO: check how mult work




### Complete Stage
- input: instruction
- reg: rob entry
- output: instruction to retire

(cdb)
1. broadcast all ready buffer
2. cdb pick a ready buffer and pass the value and the insn tag to rob
3. the selection of priority is LSU > MULT > BTU > ALU

(rob)
1. receive a rob tag and a value
2. fill in the value and change the insn to ready
3. receive a commit signal and remove the committed insn
4. synchronous update




### Retire Stage
- input: instruction to retire
- reg: regfile
- output: NULL

(rob)
1. read the head from rob entries: if it is ready, commit; otherwise do nothing.
2. send the result to regfile
3. send commit pack to rob in complete stage
4. if commit mispredict, flush all the values in all regs in pipelie

(regfile)
1. receive value and location from rob
2. write in to it synchronously



## Prefetch Queue

## Decoder

```SystemVerilog
module decoder(

	//input valid_inst_in,  // ignore inst when low, outputs will
	                      // reflect noop (except valid_inst)
	//see sys_defs.svh for definition
	// input from IF_ID_PACKET if_packet
	input logic in_valid,
	input INST inst,
	input logic flush,
	input [`XLEN-1:0] in_pc,
	
	output logic csr_op,    // used for CSR operations, we only used this as 
	                        //a cheap way to get the return code out
	output logic halt,      // non-zero on a halt
	output logic illegal,    // non-zero on an illegal instruction
	// output logic valid_inst,  // for counting valid instructions executed
	//                         // and for making the fetch stage die on halts/
	//                         // keeping track of when to allow the next
	//                         // instruction out of fetch
	//                         // 0 for HALT and illegal instructions (die on halt)
	output DECODED_PACK decoded_pack
);

```

balabala

formalize the input and output of this module based on the description in ## pipeline
1. where to get input
2. flow from input to output
3. important point to check
4. how output will be used in other module



## Dispatcher
TODO: deal with halt from decoder



### map table
