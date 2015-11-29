module dcache_mem(
	input 											clock,
	input											reset,
	// input from dcache_controller.v
	input [`INDEX_SIZE-1:0]							index_in,
	input [`TAG_SIZE-1:0]     						tag_in,
	input											read_enable,
	input											write_enable,
	input [`DCACHE_BLOCK_SIZE-1:0] 					write_data_in,
	input [3:0]										mem_response,
	input [3:0]										mem_tag,
	input 											store_to_memory_enable,							
	
	// input from mem.v
	input [`DCACHE_BLOCK_SIZE-1:0]  				load_data_in,
	
	// output to mem.v
	output logic[`DCACHE_BLOCK_SIZE-1:0] 			store_data_out,
	
	// output to dcache_controller.v
	output logic									data_is_valid,
	output logic									data_is_dirty,
	output logic									data_is_miss,
	output logic [`DCACHE_BLOCK_SIZE-1:0]			read_data_out
	);
	
	// internal registers
	logic [`INDEX_SIZE-1:0][`DCACHE_WAY-1:0][`DCACHE_BLOCK_SIZE-1:0]	internal_data;
	logic [`INDEX_SIZE-1:0][`DCACHE_WAY-1:0][`DCACHE_BLOCK_SIZE-1:0]	internal_data_in;
	logic [`INDEX_SIZE-1:0][`DCACHE_WAY-1:0][`TAG_SIZE-1:0] 			internal_tag;
	logic [`INDEX_SIZE-1:0][`DCACHE_WAY-1:0][`TAG_SIZE-1:0] 			internal_tag_in;
		
	logic [`INDEX_SIZE-1:0][`DCACHE_WAY-1:0]							internal_valid;
	logic [`INDEX_SIZE-1:0][`DCACHE_WAY-1:0]							internal_valid_in;
	logic [`INDEX_SIZE-1:0][`DCACHE_WAY-1:0]							internal_dirty;
	logic [`INDEX_SIZE-1:0][`DCACHE_WAY-1:0]							internal_dirty_in;
	
	logic [`INDEX_SIZE-1:0][`DCACHE_WAY-1:0][3:0]						internal_response;
	logic [`INDEX_SIZE-1:0][`DCACHE_WAY-1:0][3:0]						internal_response_in;
	
	// to record if it is a load or a store instruction
	logic [`INDEX_SIZE-1:0][`DCACHE_WAY-1:0]							internal_load_inst;
	logic [`INDEX_SIZE-1:0][`DCACHE_WAY-1:0]							internal_load_inst_in;
	logic [`INDEX_SIZE-1:0][`DCACHE_WAY-1:0]							internal_store_inst;
	logic [`INDEX_SIZE-1:0][`DCACHE_WAY-1:0]							internal_store_inst_in;
	
	// for LRU
	logic [`INDEX_SIZE-1:0]												internal_way;
	logic [`INDEX_SIZE-1:0]												internal_way_next;
					
	
	always_ff@(posedge clock)
	begin
		if (reset)
		begin
			internal_data 		<= `SD 0;
			internal_tag  		<= `SD 0;
			internal_valid		<= `SD 0;
			internal_dirty  	<= `SD 0;
			internal_response	<= `SD 0;
			internal_way		<= `SD 0;
			internal_load_inst	<= `SD 0;
			internal_store_inst <= `SD 0;
		end
		else
		begin
			internal_data 		<= `SD internal_data_in;
			internal_tag  		<= `SD internal_tag_in;
			internal_valid		<= `SD internal_valid_in;
			internal_dirty 	 	<= `SD internal_dirty_in;
			internal_response	<= `SD internal_response_in;
			internal_way		<= `SD internal_way_next;
			internal_load_inst	<= `SD internal_load_inst_in;
			internal_store_inst <= `SD internal_store_inst_in;
		end
	end
	
	
	always_comb
	begin	
		// load from memory
		for (int i; i<`INDEX_SIZE; i++)
		begin
			for (int j; j<`DCACHE_WAY; j++)
			begin
				if (mem_tag == internal_response[i][j]) && (mem_tag!=0) && (internal_load_inst[i][j])
				begin
					internal_data_in[i][j] 			= load_data_in;
					internal_valid_in[i][j]			= 1'b1;
					internal_dirty_in[i][j]			= 1'b0;
					read_data_out					= load_data_in;
					break;
				end
				else if (mem_tag == internal_response[i][j]) && (mem_tag!=0) && (internal_store_inst[i][j])
				begin
					internal_data_in[i][j] 			= write_data_in;
					internal_valid_in[i][j]			= 1'b1;
					internal_dirty_in[i][j]			= 1'b1;
					read_data_out					= 0;
				end
				else
				begin
					internal_data_in[i][j] 			= internal_data[i][j];
					internal_valid_in[i][j]			= internal_valid[i][j];
					internal_dirty_in[i][j]			= internal_dirty[i][j];
					read_data_out					= 0;
				end
			end
		end
		
		// store to memory
		if (store_to_memory_enable)
		begin
			for (int i; i<`INDEX_SIZE; i++)
			begin
				if (index_in==i)
				begin
					for (int j; j<`DCACHE_WAY; j++)
					begin
						if (internal_way==j)
						begin
							store_data_out 			= internal_data[i][j];
							internal_valid_in[i][j] = 1'b0;
							break;
						end
						else
						begin
							store_data_out 			= 0;
							internal_valid_in[i][j] = internal_valid[i][j];
						end
					end
					break;
				end
				else
				begin
					store_data_out 					= 0;
					internal_valid_in[i]			= internal_valid[i];
				end
			end
		end	 
	
		// for read
		if (read_enable)
		begin
			// is data miss?
			for (int i; i<`INDEX_SIZE; i++)
			begin
				if (read_index==i) 
				begin
					for (int j; j<`DCACHE_WAY; j++)
					begin
						if (tag_in==internal_tag[i][j]) && (internal_valid[i][j])
						begin
							read_data_out 		  	= internal_data[i][j];
							internal_way_next[i]	= ~internal_way[i];
							data_is_valid 		  	= 1'b1;
							data_is_miss  		  	= 1'b0;
							break;
						end
						else
						begin
							read_data_out 		  	= 0;
							internal_way_next[i]	= internal_way[i];
							data_is_valid 		  	= 1'b0;
							data_is_miss  		  	= 1'b1;
						end
					end
					break;
				end //((read_index==i) && (tag_in==internal_tag[i]))
				else
				begin
					read_data_out			  	  	= 0;
					internal_way_next				= internal_way;
					read_data_valid			  	  	= 1'b0;
					data_is_miss  		  		  	= 1'b1;
				end
			end //if (read_index==i) 
			
			// if miss, is it dirty?
			if (data_is_miss)
			begin
				for (int i; i<`INDEX_SIZE; i++)
				begin
					if (read_index == i) 
					begin
						if (internal_way[i]==0)&&(internal_dirty[i][0])
						begin
							internal_response_in[i][0]	= 0; //?
							internal_tag_in[i][0]		= internal_tag[i][0];
							data_is_dirty			  	= 1'b1;
							internal_load_inst_in[i][0]	= 1'b1;
							internal_store_inst_in[i][0]= 1'b0;
							break;
						end
						else if (internal_way[i]==1)&&(internal_dirty[i][1])
						begin
							internal_response_in[i][1]	= 0; //?
							internal_tag_in[i][1]		= internal_tag[i][1];
							data_is_dirty			  	= 1'b1;
							internal_load_inst_in[i][1]	= 1'b1;
							internal_store_inst_in[i][1]= 1'b0;
							break;
						end
						else if (internal_way[i]==0)&&(!internal_dirty[i][0])
						begin
							internal_response_in[i][0]	= mem_response;
							internal_tag_in[i][1]		= tag_in;
							data_is_dirty			  	= 1'b0;
							internal_load_inst_in[i][0]	= 1'b1;
							internal_store_inst_in[i][0]= 1'b0;
							break;
						end
						else
						begin
							internal_response_in[i][1]	= mem_response;
							internal_tag_in[i][1]		= tag_in;
							data_is_dirty			  	= 1'b0;
							internal_load_inst_in[i][1]	= 1'b1;
							internal_store_inst_in[i][1]= 1'b0;
							break;
						end
					end
					else
					begin
						internal_response_in[i]			= internal_response[i];
						internal_tag_in[i]				= internal_tag[i];
						data_is_dirty			  	  	= 1'b0;
						internal_load_inst_in[i]		= internal_load_inst[i];
						internal_store_inst_in[i]		= internal_store_inst[i];
					end
				end
			end
			else 
			begin
				internal_response_in					= internal_response;
				internal_tag_in							= internal_tag;
				data_is_dirty					        = 1'b0;
				internal_load_inst_in					= internal_load_inst;
				internal_store_inst_in					= internal_store_inst;
			end
		end //for (int i; i<`INDEX_SIZE; i++)
		
		// for write
		else if (write_enable)
		begin
			for (int i; i<`INDEX_SIZE; i++)
			begin
				if (write_index==i)
				begin
					for (int j; j<`DCACHE_WAY; j++)
					begin
						if (tag_in==internal_tag[i][j]) && (internal_valid[i][j])
						begin
							internal_data_in[i][j] 	= write_data_in;
							internal_tag_in[i][j]	= tag_in;
							internal_dirty_in[i][j] = 1'b1;
							internal_way_next[i]	= ~internal_way[i];
							data_is_valid 		    = 1'b1;
							data_is_miss  		  	= 1'b0;
							break;
						end
						else
						begin
							internal_data_in[i][j]	= internal_data[i][j];
							internal_tag_in[i][j]	= internal_tag[i][j];
							internal_dirty_in[i][j] = internal_dirty[i][j];
							internal_way_next[i]	= internal_way[i];
							data_is_valid 		 	= 1'b0;
							data_is_miss  		 	= 1'b1;
						end
					end
					break;
				end
				else
				begin
					internal_data_in[i]      	    = internal_data[i];
					internal_tag_in[i]			    = internal_tag[i];
					internal_way_next[i]			= internal_way[i];
					internal_dirty_in[i]	 		= internal_dirty[i];
					data_is_valid 		            = 1'b0;
					data_is_miss  		  		    = 1'b1;
				end
			end
			
			if (data_is_miss)
			begin
				for (int i; i<`INDEX_SIZE; i++)
				begin
					if (write_index == i) 
					begin
						if ((internal_way==0) && (internal_dirty[i][0])) 
						begin
							internal_response_in[i][0]	= 0; //?
							internal_tag_in[i][0]		= internal_tag[i][0];
							data_is_dirty			  	= 1'b1;
							internal_load_inst_in[i][0]	= 1'b0;
							internal_store_inst_in[i][0]= 1'b1;
							break;
						end
						else if ((internal_way==1) && (internal_dirty[i][1]))
						begin
							internal_response_in[i][1]	= 0; //?
							internal_tag_in[i][1]		= internal_tag[i][1];
							data_is_dirty			  	= 1'b1;
							internal_load_inst_in[i][1]	= 1'b0;
							internal_store_inst_in[i][1]= 1'b1;
							break;
						end
						else if ((internal_way==0) && (!internal_dirty[i][0]))
						begin
							internal_response_in[i][0]	= mem_response;
							internal_tag_in[i][0]		= tag_in;
							data_is_dirty			  	= 1'b0;
							internal_load_inst_in[i][0]	= 1'b0;
							internal_store_inst_in[i][0]= 1'b1;
							break;
						end
						else
						begin
							internal_response_in[i][1]	= mem_response;
							internal_tag_in[i][1]		= tag_in;
							data_is_dirty			  	= 1'b0;
							internal_load_inst_in[i][1]	= 1'b0;
							internal_store_inst_in[i][1]= 1'b1;
							break;
						end
					end
					else
					begin
						internal_response_in[i]			= internal_response[i];
						internal_tag_in[i]				= internal_tag[i];
						data_is_dirty			  	  	= 1'b0;
						internal_load_inst_in[i]		= internal_load_inst[i];
						internal_store_inst_in[i]		= internal_store_inst[i];
					end
				end
			end
			else 
			begin
				internal_response_in					= internal_response;
				internal_tag_in							= internal_tag;
				data_is_dirty					        = 1'b0;
				internal_load_inst_in					= internal_load_inst;
				internal_store_inst_in					= internal_store_inst;
			end
		end
	end
endmodule
