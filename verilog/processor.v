//////////////////////////////////////////////////////////////////////////
//																		//
//   Modulename :  processor.v                                          //
//                                                                      //
//  Description :  														//
//                                                        				//
//                                                       				//
//////////////////////////////////////////////////////////////////////////

module processor(
//input
    input         clock,                    // System clock
    input         reset,                    // System reset
    input [3:0]   mem2proc_response,        // Tag from memory about current request
    input [63:0]  mem2proc_data,            // Data coming back from memory
    input [3:0]   mem2proc_tag,              // Tag from memory about current reply

    output logic [1:0]  proc2mem_command,    // command sent to memory
    output logic [63:0] proc2mem_addr,      // Address sent to memory
    output logic [63:0] proc2mem_data,      // Data sent to memory

    output logic [3:0]  pipeline_completed_insts,
    output ERROR_CODE   pipeline_error_status,
    output logic [4:0]  pipeline_commit_wr_idx,
    output logic [63:0] pipeline_commit_wr_data,
    output logic        pipeline_commit_wr_en,
    output logic [63:0] pipeline_commit_NPC,


    // testing hooks (these must be exported so we can test
    // the synthesized version) data is tested by looking at
    // the final values in memory

//output
    // Outputs from IF-Stage 
    output logic [63:0] if_NPC_out,
    output logic [31:0] if_IR_out,
    output logic        if_valid_inst_out,

    // Outputs from IF/ID Pipeline Register
    output logic [63:0] if_id_NPC,
    output logic [31:0] if_id_IR,
    output logic        if_id_valid_inst,


    // Outputs from ID/EX Pipeline Register
    output logic [63:0] id_ex_NPC,
    output logic [31:0] id_ex_IR,
    output logic        id_ex_valid_inst,


    // Outputs from EX/MEM Pipeline Register
    output logic [63:0] ex_mem_NPC,
    output logic [31:0] ex_mem_IR,
    output logic        ex_mem_valid_inst,


    // Outputs from MEM/WB Pipeline Register
    output logic [63:0] mem_wb_NPC,
    output logic [31:0] mem_wb_IR,
    output logic        mem_wb_valid_inst
);
//rat output
logic [$clog2(`PRF_SIZE)-1:0]	RAT1_PRF_opa_idx1;
logic [$clog2(`PRF_SIZE)-1:0]	RAT1_PRF_opb_idx1;
logic [$clog2(`PRF_SIZE)-1:0]	RAT1_PRF_opa_idx2;
logic [$clog2(`PRF_SIZE)-1:0]	RAT1_PRF_opb_idx2;

logic [$clog2(`PRF_SIZE)-1:0]	RAT2_PRF_opa_idx1;
logic [$clog2(`PRF_SIZE)-1:0]	RAT2_PRF_opb_idx1;
logic [$clog2(`PRF_SIZE)-1:0]	RAT2_PRF_opa_idx2;
logic [$clog2(`PRF_SIZE)-1:0]	RAT2_PRF_opb_idx2;

logic	RAT1_PRF_allocate_req1;
logic	RAT1_PRF_allocate_req2;
logic	RAT2_PRF_allocate_req1;
logic	RAT2_PRF_allocate_req2;

//prf output
logic	PRF_RAT1_rename_valid1;
logic	PRF_RAT1_rename_valid1;
logic	PRF_RAT2_rename_valid2;
logic	PRF_RAT2_rename_valid2;

logic [$clog2(`PRF_SIZE)-1:0]	PRF_RAT1_rename_idx1;
logic [$clog2(`PRF_SIZE)-1:0]	PRF_RAT1_rename_idx2;
logic [$clog2(`PRF_SIZE)-1:0]	PRF_RAT2_rename_idx1;
logic [$clog2(`PRF_SIZE)-1:0]	PRF_RAT2_rename_idx2;

logic [63:0]	PRF_RS_inst1_opa;
logic [63:0]	PRF_RS_inst1_opb;
logic [63:0]	PRF_RS_inst2_opa;
logic [63:0]	PRF_RS_inst2_opb;
logic			PRF_RS_inst1_opa_valid;
logic			PRF_RS_inst1_opb_valid;
logic			PRF_RS_inst2_opa_valid;
logic			PRF_RS_inst2_opb_valid;

//rrat output
logic [`ARF_SIZE-1:0][$clog2(`PRF_SIZE)-1:0]		RRAT_RAT_mispredict_up_idx1;
logic [`ARF_SIZE-1:0][$clog2(`PRF_SIZE)-1:0]		RRAT_RAT_mispredict_up_idx2;
//rs output
logic [5:0][63:0]		RS_EX_opa;
logic [5:0][63:0]		RS_EX_opb;
logic [5:0][$clog2(`PRF_SIZE)-1:0]	RS_EX_dest_tag;
logic [5:0][$clog2(`ROB_SIZE)-1:0]	RS_EX_rob_idx;
logic [5:0][5:0]			RS_EX_op_type;
logic [5:0]					RS_EX_out_valid;
ALU_FUNC [5:0]				RS_EX_alu_func;

//ex output
logic [3:0]							EX_RS_fu_is_available;
logic [3:0][$clog2(`PRF_SIZE)-1:0]	EX_CDB_dest_tag,
logic [3:0][63:0]					EX_CDB_fu_result_out;
logic [3:0]							EX_CDB_fu_result_is_valid;

//ex success send to cdb
logic					adder1_send_in_success;
logic					adder2_send_in_success;
logic					mult1_send_in_success;
logic					mult2_send_in_success;

//cdb output
logic							cdb1_valid;
logic [63:0]					cdb1_value;
logic [$clog2(`PRF_SIZE)-1:0]	cdb1_tag;
logic							cdb2_valid;
logic [63:0]					cdb2_value;
logic [$clog2(`PRF_SIZE)-1:0]	cdb2_tag;

//////////////////////////////////
//								//
//			  PC				//
//								//
//////////////////////////////////
module if_stage pc(
//input
	.clock(clock),							// system clock
	.reset(reset), 							// system reset
	input 				thread1_branch_is_taken,
	input 				thread2_branch_is_taken,
	input [63:0]		thread1_target_pc,
	input [63:0]		thread2_target_pc,
	input         		rs_stall,		 				// when RS is full, we need to stop PC
	input	  			rob_stall,		 				// when RoB is full, we need to stop PC
	input				thread1_structure_hazard_stall,	// If data and instruction want to use memory at the same time
	input				thread2_structure_hazard_stall,	// If data and instruction want to use memory at the same time
	input [63:0]		Imem2proc_data,					// Data coming back from instruction-memory
	input			    Imem2proc_valid,				// 
	input				is_two_threads,		
//output
	output logic [63:0]	proc2Imem_addr,					// Address sent to Instruction memory
	output logic [63:0] next_PC_out,
	output logic [31:0] thread1_inst_out,
	output logic [31:0] thread2_inst_out,
	output logic	 	thread1_inst_is_valid,
	output logic	 	thread2_inst_is_valid
	);
//////////////////////////////////
//								//
//			Decoder				//
//								//
//////////////////////////////////

//////////////////////////////////
//								//
//			 RAT				//
//								//
//////////////////////////////////
module rat rat1(
//input
	.clock(clock),				// system clock
	.reset(reset),          	// system reset
	
	input	inst1_enable,	//high if inst can run
	input	inst2_enable,
	input	[$clog2(`ARF_SIZE)-1:0]	opa_ARF_idx1,	//we will use opa_ARF_idx to find PRF_idx
	input	[$clog2(`ARF_SIZE)-1:0]	opb_ARF_idx1,	//to find PRF_idx
	input	[$clog2(`ARF_SIZE)-1:0]	dest_ARF_idx1,	//the ARF index of dest reg
	input	dest_rename_sig1,	//if high, dest_reg need rename

	input	[$clog2(`ARF_SIZE)-1:0]	opa_ARF_idx2,	//we will use opa_ARF_idx to find PRF_idx
	input	[$clog2(`ARF_SIZE)-1:0]	opb_ARF_idx2,	//to find PRF_idx
	input	[$clog2(`ARF_SIZE)-1:0]	dest_ARF_idx2,	//the ARF index of dest reg
	input	dest_rename_sig2,	//if high, dest_reg need rename


	input	opa_valid_in1,	//if high opa_valid is immediate
	input	opb_valid_in1,
	input	opa_valid_in2,	//if high opa_valid is immediate
	input	opb_valid_in2,

	input	mispredict_sig1,	//indicate whether mispredict happened
	input	mispredict_sig2,	//indicate whether mispredict happened
	mispredict_up_idx(RRAT_RAT_mispredict_up_idx1),

	//Notion: valid1 and idx is the first PRF to use!!!!!!
	//Not for inst1!!!!!!!!!!
	.PRF_rename_valid1(PRF_RAT1_rename_valid1),							//we get valid signal from prf if the dest address has been request
	.PRF_rename_idx1(PRF_RAT1_rename_idx1),								//the PRF alocated for dest
	.PRF_rename_valid2(PRF_RAT1_rename_valid2),							//we get valid signal from prf if the dest address has been request
	.PRF_rename_idx2(PRF_RAT1_rename_idx2),								//the PRF alocated for dest
//output
	.opa_PRF_idx1(RAT1_PRF_opa_idx1),
	.opb_PRF_idx1(RAT1_PRF_opb_idx1),
	output	logic	request1,  //send to PRF indicate whether it need data
	.RAT_allo_halt1(RAT1_PRF_allocate_req1),
	//output	logic	opa_valid_out1,	//if high opa_valid is immediate
	//output	logic	opb_valid_out1,

	//output 2
	.opa_PRF_idx2(RAT1_PRF_opa_idx2),
	.opb_PRF_idx2(RAT1_PRF_opb_idx2),
	output	logic	request2,  //send to PRF indicate whether it need data
	.RAT_allo_halt2(RAT1_PRF_allocate_req2),
	//output	logic	opa_valid_out2,	//if high opa_valid is immediate
	//output	logic	opb_valid_out2,

	//output together
	output	logic	[`ARF_SIZE-1:0]	PRF_free_sig,
	.PRF_free_list()
	);
	
module rat rat2(
//input
	.clock(clock),				// system clock
	.reset(reset),          	// system reset
	
	input	inst1_enable,	//high if inst can run
	input	inst2_enable,
	input	[$clog2(`ARF_SIZE)-1:0]	opa_ARF_idx1,	//we will use opa_ARF_idx to find PRF_idx
	input	[$clog2(`ARF_SIZE)-1:0]	opb_ARF_idx1,	//to find PRF_idx
	input	[$clog2(`ARF_SIZE)-1:0]	dest_ARF_idx1,	//the ARF index of dest reg
	input	dest_rename_sig1,	//if high, dest_reg need rename

	input	[$clog2(`ARF_SIZE)-1:0]	opa_ARF_idx2,	//we will use opa_ARF_idx to find PRF_idx
	input	[$clog2(`ARF_SIZE)-1:0]	opb_ARF_idx2,	//to find PRF_idx
	input	[$clog2(`ARF_SIZE)-1:0]	dest_ARF_idx2,	//the ARF index of dest reg
	input	dest_rename_sig2,	//if high, dest_reg need rename


	input	opa_valid_in1,	//if high opa_valid is immediate
	input	opb_valid_in1,
	input	opa_valid_in2,	//if high opa_valid is immediate
	input	opb_valid_in2,

	input	mispredict_sig1,	//indicate whether mispredict happened
	input	mispredict_sig2,	//indicate whether mispredict happened
	.mispredict_up_idx(RRAT_RAT_mispredict_up_idx1),	//if mispredict happens, need to copy from rrat

	//Notion: valid1 and idx is the first PRF to use!!!!!!
	//Not for inst1!!!!!!!!!!
	.PRF_rename_valid1(PRF_RAT2_rename_valid1),							//we get valid signal from prf if the dest address has been request
	.PRF_rename_idx1(PRF_RAT2_rename_idx1),	//the PRF alocated for dest
	.PRF_rename_valid2(PRF_RAT2_rename_valid1),							//we get valid signal from prf if the dest address has been request
	.PRF_rename_idx2(PRF_RAT2_rename_idx2),	//the PRF alocated for dest
//output
	.opa_PRF_idx1(RAT2_PRF_opa_idx1),
	.opb_PRF_idx1(RAT2_PRF_opb_idx1),
	output	logic	request1,  //send to PRF indicate whether it need data
	.RAT_allo_halt1(RAT2_PRF_allocate_req1),
	//output	logic	opa_valid_out1,	//if high opa_valid is immediate
	//output	logic	opb_valid_out1,

	//output 2
	.opa_PRF_idx2(RAT2_PRF_opa_idx2),
	.opb_PRF_idx2(RAT2_PRF_opb_idx2),
	output	logic	request2,  //send to PRF indicate whether it need data
	.RAT_allo_halt2(RAT2_PRF_allocate_req2),
	//output	logic	opa_valid_out2,	//if high opa_valid is immediate
	//output	logic	opb_valid_out2,

	//output together
	output	logic	[`ARF_SIZE-1:0]	PRF_free_sig,
	PRF_free_list()
	);

//////////////////////////////////
//								//
//			 RRAT				//
//								//
//////////////////////////////////
module rrat rrat1(
	//input
	.clock(clock),				// system clock
	.reset(reset),          	// system reset 

	input				inst1_enable,
	input				inst2_enable,

	input [$clog2(`PRF_SIZE)-1:0]	RoB_PRF_idx1,
	input [$clog2(`ARF_SIZE)-1:0] 	RoB_ARF_idx1,
	input 				RoB_retire_in1,	//high when instruction retires
	input 				mispredict_sig1,

	input [$clog2(`PRF_SIZE)-1:0]	RoB_PRF_idx2,
	input [$clog2(`ARF_SIZE)-1:0] 	RoB_ARF_idx2,
	input 				RoB_retire_in2,	//high when instruction retires
	input 				mispredict_sig2,
//output
	output logic 							PRF_free_valid1,
	output logic [$clog2(`PRF_SIZE)-1:0]	PRF_free_idx1,
	output logic							PRF_free_valid2,
	output logic [$clog2(`PRF_SIZE)-1:0]	PRF_free_idx2,
	.mispredict_up_idx(RRAT_RAT_mispredict_up_idx1)

);

module rrat rrat2(
	//input
	.clock(clock),				// system clock
	.reset(reset),          	// system reset 

	input				inst1_enable,
	input				inst2_enable,

	input [$clog2(`PRF_SIZE)-1:0]	RoB_PRF_idx1,
	input [$clog2(`ARF_SIZE)-1:0] 	RoB_ARF_idx1,
	input 				RoB_retire_in1,	//high when instruction retires
	input 				mispredict_sig1,

	input [$clog2(`PRF_SIZE)-1:0]	RoB_PRF_idx2,
	input [$clog2(`ARF_SIZE)-1:0] 	RoB_ARF_idx2,
	input 				RoB_retire_in2,	//high when instruction retires
	input 				mispredict_sig2,
//output
	output logic 							PRF_free_valid1,
	output logic [$clog2(`PRF_SIZE)-1:0]	PRF_free_idx1,
	output logic 							PRF_free_valid2,
	output logic [$clog2(`PRF_SIZE)-1:0]	PRF_free_idx2,
	.mispredict_up_idx(RRAT_RAT_mispredict_up_idx2)

);

//////////////////////////////////
//								//
//			 PRF				//
//								//
//////////////////////////////////
module prf prf1(
//input
	.clock(clock),				// system clock
	.reset(reset),          	// system reset
	//cdb
	.cdb1_valid(cdb1_valid),
	.cdb1_tag(cdb1_tag),
	.cdb1_out(cdb1_value),
	.cdb2_valid(cdb2_valid),
	.cdb2_tag(cdb2_tag),
	.cdb2_out(cdb2_value),
	//rat
	.inst1_opa_prf_idx(RAT_PRF_opa_idx1),			// opa prf index of instruction1
	.inst1_opb_prf_idx(RAT_PRF_opb_idx1),			// opb prf index of instruction1
	.inst2_opa_prf_idx(RAT_PRF_opa_idx2),			// opa prf index of instruction2
	.inst2_opb_prf_idx(RAT_PRF_opb_idx2),			// opb prf index of instruction2

	.rat1_allocate_new_prf1(RAT1_PRF_allocate_req1),			// the request from rat1 for allocating a new prf entry
	.rat1_allocate_new_prf2(RAT1_PRF_allocate_req2),			// the request from rat1 for allocating a new prf entry
	.rat2_allocate_new_prf1(RAT2_PRF_allocate_req1),			// the request from rat2 for allocating a new prf entry
	.rat2_allocate_new_prf2(RAT2_PRF_allocate_req2),			// the request from rat2 for allocating a new prf entry

	input	[`PRF_SIZE-1:0]	rrat1_prf_free_list,			// when a branch is mispredict, RRAT1 gives a freelist to PRF
	input	[`PRF_SIZE-1:0]	rrat2_prf_free_list,			// when a branch is mispredict, RRAT2 gives a freelist to PRF
	input	[`PRF_SIZE-1:0]	rat1_prf_free_list,			// when a branch is mispredict, RAT1 gives a freelist to PRF
	input	[`PRF_SIZE-1:0]	rat2_prf_free_list,			// when a branch is mispredict, RAT2 gives a freelist to PRF
	input					rrat1_branch_mistaken_free_valid,	// when a branch is mispredict, RRAT1 gives out a signal enable PRF to free its register files
	input					rrat2_branch_mistaken_free_valid,	// when a branch is mispredict, RRAT2 gives out a signal enable PRF to free its register files

	input					rrat1_prf_free_valid,			// when an instruction retires from RRAT1, RRAT1 gives out a signal enable PRF to free its register. 
	input					rrat2_prf_free_valid,			// when an instruction retires from RRAT2, RRAT1 gives out a signal enable PRF to free its register.
	input	[$clog2(`PRF_SIZE)-1:0] 	rrat1_prf_free_idx,			// when an instruction retires from RRAT1, RRAT1 will free a PRF, and this is its index. 
	input	[$clog2(`PRF_SIZE)-1:0] 	rrat2_prf_free_idx,			// when an instruction retires from RRAT2, RRAT2 will free a PRF, and this is its index.
	//output
	rat1_prf1_rename_valid_out(PRF_RAT1_rename_valid1),		// when RAT1 asks the PRF to allocate a new entry, PRF should make sure the returned index is valid.
	rat1_prf2_rename_valid_out(PRF_RAT1_rename_valid2),		// when RAT1 asks the PRF to allocate a new entry, PRF should make sure the returned index is valid.
	rat2_prf1_rename_valid_out(PRF_RAT2_rename_valid1),		// when RAT2 asks the PRF to allocate a new entry, PRF should make sure the returned index is valid.
	rat2_prf2_rename_valid_out(PRF_RAT2_rename_valid2),		// when RAT2 asks the PRF to allocate a new entry, PRF should make sure the returned index is valid.
	.rat1_prf1_rename_idx_out(PRF_RAT1_rename_idx1),		// when RAT1 asks the PRF to allocate a new entry, PRF should return the index of this newly allocated entry.
	.rat1_prf2_rename_idx_out(PRF_RAT1_rename_idx2),		// when RAT1 asks the PRF to allocate a new entry, PRF should return the index of this newly allocated entry.
	.rat2_prf1_rename_idx_out(PRF_RAT2_rename_idx1),		// when RAT2 asks the PRF to allocate a new entry, PRF should return the index of this newly allocated entry.
	.rat2_prf2_rename_idx_out(PRF_RAT2_rename_idx2),		// when RAT2 asks the PRF to allocate a new entry, PRF should return the index of this newly allocated entry.

	.inst1_opa_prf_value(PRF_RS_inst1_opa),			// opa prf value of instruction1
	.inst1_opb_prf_value(PRF_RS_inst1_opb),			// opb prf value of instruction1
	.inst2_opa_prf_value(PRF_RS_inst2_opa),			// opa prf value of instruction2
	.inst2_opb_prf_value(PRF_RS_inst2_opb),			// opb prf value of instruction2

	.inst1_opa_valid(PRF_RS_inst1_opa_valid),			// whether opa load from prf of instruction1 is valid
	.inst1_opb_valid(PRF_RS_inst1_opb_valid),			// whether opb load from prf of instruction1 is valid
	.inst2_opa_valid(PRF_RS_inst2_opa_valid),			// whether opa load from prf of instruction2 is valid
	.inst2_opb_valid(PRF_RS_inst2_opb_valid),			// whether opa load from prf of instruction2 is valid

	//for debug
	//output logic	[`PRF_SIZE-1:0]		internal_assign_a_free_reg1,
	//output logic	[`PRF_SIZE-1:0]     internal_prf_available,
	//output logic 	[`PRF_SIZE-1:0]		internal_assign_a_free_reg2,
	//output logic 	[`PRF_SIZE-1:0]		internal_prf_available2,
	//output logic 	[`PRF_SIZE-1:0]		internal_free_this_entry
);

//////////////////////////////////
//								//
//			 ROB				//
//								//
//////////////////////////////////
module rob rob1(
//input
	.clock(clock),				// system clock
	.reset(reset),          	// system reset
	
	input							is_thread1,					//if it ==1, it is for thread1, else it is for thread 2
//instruction1 input
	input	[31:0]					inst1_pc_in,				//the pc of the instruction
	input	[4:0]					inst1_arn_dest_in,			//the arf number of the destinaion of the instruction
	input	[$clog2(`PRF_SIZE)-1:0] inst1_prn_dest_in,			//the prf number of the destination of this instruction
	input							inst1_is_branch_in,			//if this instruction is a branch
	input 							inst1_load_in,				//tell rob if instruction1 is valid

//instruction2 input
	input	[31:0]					inst2_pc_in,				//the pc of the instruction
	input	[4:0]					inst2_arn_dest_in,			//the arf number of the destinaion of the instruction
	input	[$clog2(`PRF_SIZE)-1:0] inst2_prn_dest_in,          //the prf number of the destination of this instruction
	input							inst2_is_branch_in,			//if this instruction is a branch
	input 							inst2_load_in,		       	//tell rob if instruction2 is valid
//when executed,for each function unit,  the number of rob need to know so we can set the if_executed to of the entry to be 1
	input	[5:0]							if_fu_executed,		//if the instruction in the first multiplyer has been executed
	input	[5:0][$clog2(`ROB_SIZE)-1:0]	fu_rob_idx,			//the rob number of the instruction in the first multiplyer
	input	[5:0]							fu_is_thread1,			//the rob number of the instruction in the first multiplyer
	input	[5:0]							mispredict_in,
//output
//after dispatching, we need to send rs the rob number we assigned to instruction1 and instruction2
	output	logic	[$clog2(`ROB_SIZE)-1:0]		inst1_rs_rob_idx_in,					//it is combinational logic so that the output is dealt with right after a
	output	logic	[$clog2(`ROB_SIZE)-1:0]		inst2_rs_rob_idx_in,					//instruction comes in, and then this signal is immediately sent to rs to
																						//store in rs
//when committed, the output of the first instrucion committed
	output	logic								commit1_is_branch_out,				       	//if this instruction is a branch
	output	logic								commit1_mispredict_out,				       	//if this instrucion is mispredicted
	output	logic	[4:0]						commit1_arn_dest_out,                       //the architected register number of the destination of this instruction
	output	logic	[$clog2(`PRF_SIZE)-1:0]		commit1_prn_dest_out,						//the prf number of the destination of this instruction
	output	logic								commit1_if_rename_out,				       	//if this entry is committed at this moment(tell RRAT)
	output	logic								commit1_valid,
	output	logic								commit1_is_thread1,
//when committed, the output of the second instruction committed
	output	logic								commit2_is_branch_out,						//if this instruction is a branch
	output	logic								commit2_mispredict_out,				       	//if this instrucion is mispredicted
	output	logic	[4:0]						commit2_arn_dest_out,						//the architected register number of the destination of this instruction
	output	logic	[$clog2(`PRF_SIZE)-1:0]		commit2_prn_dest_out,						//the prf number of the destination of this instruction
	output	logic								commit2_if_rename_out,				       	//if this entry is committed at this moment(tell RRAT)
	output	logic								commit2_valid,
	output	logic								commit2_is_thread1,
	output	logic								t1_is_full,
	output	logic								t2_is_full
);


//////////////////////////////////
//								//
//			  RS				//
//								//
//////////////////////////////////
module rs rs1(
//input
	.clock(clock),				// system clock
	.reset(reset),          	// system reset 

	input  [$clog2(`PRF_SIZE)-1:0]  	inst1_rs_dest_in,     	// The destination of this instruction
	input  [$clog2(`PRF_SIZE)-1:0]  	inst2_rs_dest_in,     	// The destination of this instruction
	//cdb input
	.rs_cdb1_in(cdb1_value),     	// CDB bus from functional units 
	.rs_cdb1_tag(cdb1_tag),    		// CDB tag bus from functional units 
	.rs_cdb1_valid(cdb1_valid),  	// The data on the CDB is valid 
	.rs_cdb2_in(cdb2_value),     	// CDB bus from functional units 
	.rs_cdb2_tag(cdb2_tag),    		// CDB tag bus from functional units 
	.rs_cdb2_valid(cdb2_valid),  	// The data on the CDB is valid 
	//for instruction1
	.inst1_rs_opa_in(PRF_RS_inst1_opa),      	// Operand a from Rename  
	.inst1_rs_opb_in(PRF_RS_inst1_opb),      	// Operand a from Rename 
	.inst1_rs_opa_valid(PRF_RS_inst1_opa_valid),   	// Is Opa a Tag or immediate data (READ THIS COMMENT) 
	.inst1_rs_opb_valid(PRF_RS_inst1_opb_valid),   	// Is Opb a tag or immediate data (READ THIS COMMENT) 
	input  [5:0]      			inst1_rs_op_type_in,  	// Instruction type from decoder
	input  ALU_FUNC				inst1_rs_alu_func,    	// ALU function type from decoder
	input  [$clog2(`ROB_SIZE)-1:0]       	inst1_rs_rob_idx_in,  	// The rob index of instruction 1
	input  		        		inst1_rs_load_in,     	// Signal from rename to flop opa/b /or signal to tell RS to load instruction in
	//for instruction2
	.inst2_rs_opa_in(PRF_RS_inst2_opa),      	// Operand a from Rename  
	.inst2_rs_opb_in(PRF_RS_inst2_opb),      	// Operand a from Rename 
	.inst2_rs_opa_valid(PRF_RS_inst2_opa_valid),   	// Is Opa a Tag or immediate data (READ THIS COMMENT) 
	.inst2_rs_opb_valid(PRF_RS_inst2_opb_valid),   	// Is Opb a tag or immediate data (READ THIS COMMENT) 
	input  [5:0]      			inst2_rs_op_type_in,  	// Instruction type from decoder
	input  ALU_FUNC				inst2_rs_alu_func,    	// ALU function type from decoder
	input  [$clog2(`ROB_SIZE)-1:0]       	inst2_rs_rob_idx_in,  	// The rob index of instruction 2
	input  		        		inst2_rs_load_in,     	// Signal from rename to flop opa/b /or signal to tell RS to load instruction in

	.fu_is_available(EX_RS_fu_is_available),			//0,2:mult1,2 1,3:ALU1,2 4:MEM1; from fu to rs, bugs lifan
//output
	.fu_rs_opa_out(RS_EX_opa),       	// This RS' opa 
	.fu_rs_opb_out(RS_EX_opb),       	// This RS' opb 
	output logic [5:0][$clog2(`PRF_SIZE)-1:0]	.fu_rs_dest_tag_out(RS_EX_dest_tag),  	// This RS' destination tag  
	output logic [5:0][$clog2(`ROB_SIZE)-1:0]	.fu_rs_rob_idx_out(RS_EX_rob_idx),   	// This RS' corresponding ROB index
	output logic [5:0][5:0]			.fu_rs_op_type_out(RS_EX_op_type)
	output logic [5:0]				.fu_rs_out_valid(RS_EX_out_valid),	// RS output is valid
	output ALU_FUNC [5:0]			.fu_alu_func_out(RS_EX_alu_func),

	output RS_FULL				rs_full			// RS is full now
);

//////////////////////////////////
//								//
//		   EX_stage				//
//								//
//////////////////////////////////
module ex_stage ex(
//input
	.clock(clock),				// system clock
	.reset(reset),          	// system reset 

    input  [3:0][63:0]			.fu_rs_opa_in(RS_EX_opa),		// register A value from reg file
    input  [3:0][63:0]			.fu_rs_opb_in(RS_EX_opa),		// register B value from reg file
    input  [3:0][$clog2(`PRF_SIZE)-1:0]	.fu_rs_dest_tag_in(RS_EX_dest_tag),
    input  [3:0][$clog2(`ROB_SIZE)-1:0]	.fu_rs_rob_idx_in(RS_EX_rob_idx),
    input  [3:0][5:0]  			.fu_rs_op_type_in(RS_EX_op_type),	// incoming instruction
    input  [3:0]				.fu_rs_valid_in(RS_EX_out_valid),
    ALU_FUNC [5:0]     			.fu_alu_func_in(RS_EX_alu_func),	// ALU function select from decoder

    //input          id_ex_cond_branch,   // is this a cond br? from decoder
    //input          id_ex_uncond_branch, // is this an uncond br? from decoder

    .adder1_send_in_success(adder1_send_in_success),
    .adder2_send_in_success(adder2_send_in_success),
    .mult1_send_in_success(mult1_send_in_success),
    .mult2_send_in_success(mult2_send_in_success),
//output
//ex_take_branch_out,  // is this a taken branch?
    .fu_cdb_dest_tag_out(EX_CDB_dest_tag),
    output logic [3:0][$clog2(`ROB_SIZE)-1:0]	fu_cdb_rob_idx_out,
    output logic [3:0][5:0]  			fu_cdb_op_type_out,	// incoming instruction
    output ALU_FUNC [3:0]				fu_alu_func_out,	// ALU function select from decoder
    .fu_result_out(EX_CDB_fu_result_out),
    .fu_result_is_valid(EX_CDB_fu_result_is_valid),	// 0,2: mult1,2; 1,3: adder1,2
    .fu_is_available(EX_RS_fu_is_available),	//0,2:mult1,2 1,3:ALU1,2 4:MEM1; from fu to rs

  );
//////////////////////////////////
//								//
//			 CDB				//
//								//
//////////////////////////////////
module cdb cdb1(
//input
	.mult1_result_ready(EX_CDB_fu_result_is_valid[0]),
	.mult1_result_in(EX_CDB_fu_result_out[0]),
	.mult1_dest_reg_idx(EX_CDB_dest_tag[0]),
	.adder1_result_ready(EX_CDB_fu_result_is_valid[1]),
	.adder1_result_in(EX_CDB_fu_result_out[1]),
	.adder1_dest_reg_idx(EX_CDB_dest_tag[1]),
	.mult2_result_ready(EX_CDB_fu_result_is_valid[2]),
	.mult2_result_in(EX_CDB_fu_result_out[2]),
	.mult2_dest_reg_idx(EX_CDB_dest_tag[2]),
	.adder2_result_ready(EX_CDB_fu_result_is_valid[3]),
	.adder2_result_in(EX_CDB_fu_result_out[3]),
	.adder2_dest_reg_idx(EX_CDB_dest_tag[3]),
	input  								memory1_result_ready,
	input  	[63:0]						memory1_result_in,
	input	[$clog2(`PRF_SIZE)-1:0]		memory1_dest_reg_idx,
	input  								memory2_result_ready,
	input  	[63:0]						memory2_result_in,
	input	[$clog2(`PRF_SIZE)-1:0]		memory2_dest_reg_idx,
//output	
	.cdb1_valid(cdb1_valid),
	.cdb1_tag(cdb1_tag),
	.cdb1_out(cdb1_value),
	.cdb2_valid(cdb2_valid),
	.cdb2_tag(cdb2_tag),
	.cdb2_out(cdb2_value),
	.adder1_send_in_success(adder1_send_in_success),
	.adder2_send_in_success(adder2_send_in_success),
	.mult1_send_in_success(mult1_send_in_success),
	.mult2_send_in_success(mult2_send_in_success),
	output 	logic				memory1_send_in_success,
	output 	logic				memory2_send_in_success
);
//////////////////////////////////
//								//
//			  LSQ				//
//								//
//////////////////////////////////

//////////////////////////////////
//								//
//			  MEM				//
//								//
//////////////////////////////////

endmodule
