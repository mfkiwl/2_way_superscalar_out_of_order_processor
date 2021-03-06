module Icache_controller(										//this is a 128 line direct mapped cashe with 128 lines
	input		clock,
	input 		reset,
	input	[3:0]	Imem2proc_response,
	input	[63:0]	Imem2proc_data,
	input	[3:0]	Imem2proc_tag,
	
	input	[63:0]	proc2Icashe_addr,								//the address of the current instrucion
	input	[63:0]	cachemem_data,
	input		cachemem_valid,
	
	output	logic	[1:0]	proc2Imem_command,
	output	logic	[63:0]	proc2Imem_addr,
	
	output	logic	[63:0]	Icache_data_out,
	output	logic		Icache_valid_out,
	
	output	logic	[6:0]	current_index,
	output	logic	[21:0]	current_tag,
	output	logic	[6:0]	last_index,
	output	logic	[21:0]	last_tag,
	output	logic		data_write_enable

);



	logic	[3:0]	current_mem_tag;
	logic		miss_outstanding;
	wire 	unanswered_miss;
	wire	changed_addr;
	wire 	update_mem_tag;

	assign	{current_tag,current_index} = proc2Icache_addr[31:3];					//for 128 lines direct mapped, we need 7 bits
													// for index, 3 bits for block offset, 	
													//the instruction is 32 bits, so we need tag to be 32-7-3=22bits
													//when an instruction comes, we can get the current_tag and current_index from
													//proc2Icache_addr, which is from IF_stage. the address of the current instrucion
																						

	assign	changed_addr = (current_index!=last_index) || (current_tag!=last_tag);			//if the address come from IF has changed(64 bits instructoin normally 2cycles a change)

	assign	Icache_data_out = cachemem_data;						//the output instruction to IF_stage comes from Icache
	assign	Icache_valid_out = cachemem_valid;							//so is the valid signal

	assign 	proc2Imem_addr = {proc2Icache_addr[63:3],3'b0};						//

				
	assign 	proc2Imem_command = (miss_outstanding && !changed_addr) ? `BUS_LOAD : `BUS_NONE;	//if before the last posedge, the i cache missed, and the address hasn't changed, so that we need to load from mem.v, it start after the posedge

	
	assign	data_write_enable = (current_mem_tag==Imem2proc_tag) && (current_mem_tag!=0);		//if we get data from mem.v, it match the current tag which the icache don't have , we need to put it in icache


	assign	update_mem_tag = changed_addr | miss_outstanding | data_write_enable;			//a control signal to tell whether we want to change the current_mem_tag

	
	assign	unanswered_miss = changed_addr ? !Icache_valid_out : miss_outstanding & (Imem2proc_response==0);	//if address has changed, then if I cache don't have the data, it will be 1
															//else unanswered miss equals imem has not reponse && the last cycle unanwered_miss==1
															//so unanswered_miss indicate that the request for instruction from icache or imem
															//has not been answered
	always @(posedge clock)
	begin
		if(reset)
		begin
			last_index	<= `SD -1;
			last_tag	<= `SD -1;
			current_mem_tag	<= `SD 0;
			miss_outstanding<= `SD 0;
		end
		else
		begin
			last_index	<= `SD current_index;
			last_tag	<= `SD current_tag;
			miss_outstanding<= `SD unanswered_miss;
			if(update_mem_tag)
				current_mem_tag	<= `SD Imem2proc_reponse;				//this signal  tracks the ID number for your transaction, so that , when the tag come back from mem, we can check if it is the tag we want!!!
		end

	end











endmodule
