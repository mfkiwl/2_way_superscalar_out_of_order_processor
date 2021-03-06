module sq_one_entry(
	input	clock,
	input	reset,
	
	input							sq_clean,
	input							sq_free_enable,
	
	//for instruction1
	input							sq_mem_in1,
	input	[63:0]					sq_pc_in1,
	input	[31:0]					sq_inst1_in,
	input	[63:0]					sq_inst1_rega,
	input							sq_inst1_rega_valid,
	input	[63:0] 					sq_opa_in1,      	// Operand a from Rename  data
	input	[63:0] 					sq_opb_in1,      	// Operand a from Rename  tag or data from prf
	input         					sq_opb_valid1,   	// Is Opb a tag or immediate data (READ THIS COMMENT) 
	input	[$clog2(`ROB_SIZE):0]	sq_rob_idx_in1,  	// The rob index of instruction 1
	input	[$clog2(`PRF_SIZE)-1:0]	sq_dest_idx1,

    //for instruction2
	input							sq_mem_in2,
	input	[63:0]					sq_pc_in2,
	input	[31:0]					sq_inst2_in,
	input	[63:0]					sq_inst2_rega,
	input							sq_inst2_rega_valid,
	input	[63:0] 					sq_opa_in2,      	// Operand a from Rename  data
	input	[63:0] 					sq_opb_in2,      	// Operand a from Rename  tag or data from prf
	input         					sq_opb_valid2,   	// Is Opb a tag or immediate data (READ THIS COMMENT) 
	input	[$clog2(`ROB_SIZE):0]	sq_rob_idx_in2,  	// The rob index of instruction 1
	input	[$clog2(`PRF_SIZE)-1:0]	sq_dest_idx2,
	
	//cdb
	input  [63:0]					sq_cdb1_in,     		// CDB bus from functional units 
	input  [$clog2(`PRF_SIZE)-1:0]  sq_cdb1_tag,    		// CDB tag bus from functional units 
	input							sq_cdb1_valid,  		// The data on the CDB is valid 
	input  [63:0]					sq_cdb2_in,     		// CDB bus from functional units 
	input  [$clog2(`PRF_SIZE)-1:0]  sq_cdb2_tag,    		// CDB tag bus from functional units 
	input							sq_cdb2_valid,  		// The data on the CDB is valid
	
	
	output logic							sq_is_available,
	output logic							sq_is_ready,
	output logic	[63:0]					sq_pc,
	output logic	[31:0]					sq_inst,
	output logic	[63:0]					sq_opa,
	output logic	[63:0]					sq_opb,
	output logic	[$clog2(`ROB_SIZE):0]	sq_rob_idx,
	output logic	[63:0]					sq_store_data,
	output logic	[$clog2(`PRF_SIZE)-1:0]	sq_dest_tag
);

	logic							inuse, next_inuse;
	logic	[63:0]					next_sq_pc;
	logic	[31:0]					next_sq_inst;
	logic	[63:0]					next_sq_opa;
	logic	[63:0]					next_sq_opb;
	logic							sq_addr_valid, next_sq_addr_valid;
	logic	[$clog2(`ROB_SIZE):0]	next_sq_rob_idx;
	logic	[63:0]					next_sq_store_data;
	logic	[$clog2(`PRF_SIZE)-1:0]	next_sq_dest_tag;
	logic							sq_store_data_valid, next_sq_store_data_valid;
	
	assign sq_is_available 	= ~inuse;
	assign sq_is_ready		= inuse && sq_addr_valid && sq_store_data; //(inuse || next_inuse) && (sq_addr_valid || next_sq_addr_valid);
	
	always_ff @(posedge clock) begin
		if(reset) begin
			inuse			<= #1 0;
			sq_pc			<= #1 0;
			sq_inst			<= #1 0;
			sq_opa 			<= #1 0;
			sq_opb 			<= #1 0;
			sq_addr_valid 	<= #1 0;
			sq_rob_idx 		<= #1 0;
			sq_store_data	<= #1 0;
			sq_dest_tag		<= #1 0;
		end
		else begin
			inuse			<= #1 next_inuse;
			sq_pc			<= #1 next_sq_pc;
			sq_inst			<= #1 next_sq_inst;
			sq_opa 			<= #1 next_sq_opa;
			sq_opb 			<= #1 next_sq_opb;
			sq_addr_valid 	<= #1 next_sq_addr_valid;
			sq_rob_idx 		<= #1 next_sq_rob_idx;
			sq_store_data	<= #1 next_sq_store_data;
			sq_dest_tag		<= #1 next_sq_dest_tag;
		end
	end

	always_comb begin
		next_inuse			= inuse;
		next_sq_pc			= sq_pc;
		next_sq_inst		= sq_inst;
		next_sq_opa			= sq_opa;
		next_sq_opb			= sq_opb;
		next_sq_addr_valid	= sq_addr_valid;
		next_sq_rob_idx 	= sq_rob_idx;
		next_sq_dest_tag	= sq_dest_tag;
		next_sq_store_data	= sq_store_data;
		next_sq_store_data_valid = sq_store_data_valid;
		if (sq_free_enable && sq_mem_in1) begin
			next_inuse			= 1;
			next_sq_pc			= sq_pc_in1;
			next_sq_inst		= sq_inst1_in;
			next_sq_opa			= sq_opa_in1;
			next_sq_opb			= sq_opb_in1;
			next_sq_addr_valid	= sq_opb_valid1;
			next_sq_rob_idx		= sq_rob_idx_in1;
			next_sq_store_data	= sq_inst1_rega;
			next_sq_store_data_valid = sq_inst1_rega_valid;
			next_sq_dest_tag	= sq_dest_idx1;
		end
		else if (sq_free_enable && sq_mem_in2) begin
			next_inuse			= 1;
			next_sq_pc			= sq_pc_in2;
			next_sq_inst		= sq_inst2_in;
			next_sq_opa			= sq_opa_in2;
			next_sq_opb			= sq_opb_in2;
			next_sq_addr_valid	= sq_opb_valid2;
			next_sq_rob_idx		= sq_rob_idx_in2;
			next_sq_store_data	= sq_inst2_rega;
			next_sq_store_data_valid = sq_inst2_rega_valid;
			next_sq_dest_tag	= sq_dest_idx2;
		end
		else if (sq_free_enable) begin
			next_inuse = 0;
		end
		else if (sq_mem_in1) begin
			next_inuse			= 1;
			next_sq_pc			= sq_pc_in1;
			next_sq_inst		= sq_inst1_in;
			next_sq_opa			= sq_opa_in1;
			next_sq_opb			= sq_opb_in1;
			next_sq_addr_valid	= sq_opb_valid1;
			next_sq_rob_idx		= sq_rob_idx_in1;
			next_sq_store_data	= sq_inst1_rega;
			next_sq_store_data_valid = sq_inst1_rega_valid;
			next_sq_dest_tag	= sq_dest_idx1;
		end
		else if (sq_mem_in2) begin
			next_inuse			= 1;
			next_sq_pc			= sq_pc_in2;
			next_sq_inst		= sq_inst2_in;
			next_sq_opa			= sq_opa_in2;
			next_sq_opb			= sq_opb_in2;
			next_sq_addr_valid	= sq_opb_valid2;
			next_sq_rob_idx		= sq_rob_idx_in2;
			next_sq_store_data	= sq_inst2_rega;
			next_sq_store_data_valid = sq_inst2_rega_valid;
			next_sq_dest_tag	= sq_dest_idx2;
		end
		else begin
			if (~sq_addr_valid && (sq_opb[$clog2(`PRF_SIZE)-1:0] == sq_cdb1_tag) && inuse && sq_cdb1_valid) begin
				next_sq_opb			= sq_cdb1_in;
				next_sq_addr_valid	= 1;
			end
			if (~sq_addr_valid && (sq_opb[$clog2(`PRF_SIZE)-1:0] == sq_cdb2_tag) && inuse && sq_cdb2_valid) begin
				next_sq_opb			= sq_cdb2_in;
				next_sq_addr_valid	= 1;
			end
			if (~sq_store_data_valid && (sq_store_data[$clog2(`PRF_SIZE)-1:0] == sq_cdb1_tag) && inuse && sq_cdb1_valid) begin
				next_sq_store_data			= sq_cdb1_in;
				next_sq_store_data_valid	= 1;
			end
			if (~sq_store_data_valid && (sq_store_data[$clog2(`PRF_SIZE)-1:0] == sq_cdb2_tag) && inuse && sq_cdb2_valid) begin
				next_sq_store_data			= sq_cdb2_in;
				next_sq_store_data_valid	= 1;
			end
		end
	end
endmodule
