//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  rat.v                                       	        //
//                                                                      //
//   Description :                                                      //
//                                                                      //
//                                                                      // 
//                                                                      //
//                                                                      // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////
module rat(
	//input
	input	reset,	//reset signal
	input	clock,	//the clock
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

	input	mispredict_sig1,	//indicate weather mispredict happened
	input	mispredict_sig2,	//indicate weather mispredict happened
	input	[`ARF_SIZE-1:0]	[$clog2(`PRF_SIZE)-1:0]	mispredict_up_idx,	//if mispredict happens, need to copy from rrat

	//Notion: valid1 and idx is the first PRF to use!!!!!!
	//Not for inst1!!!!!!!!!!
	input	PRF_rename_valid1,	//we get valid signal from prf if the dest address has been request
	input	[$clog2(`PRF_SIZE)-1:0]	PRF_rename_idx1,	//the PRF alocated for dest
	input	PRF_rename_valid2,	//we get valid signal from prf if the dest address has been request
	input	[$clog2(`PRF_SIZE)-1:0]	PRF_rename_idx2,	//the PRF alocated for dest


	//output 1
	output	logic	[$clog2(`PRF_SIZE)-1:0]	opa_PRF_idx1,
	output	logic	[$clog2(`PRF_SIZE)-1:0]	opb_PRF_idx1,
	output	logic	request1,  //send to PRF indicate weather it need data
	output	logic	RAT_allo_halt1,
	output	logic	opa_valid_out1,	//if high opa_valid is immediate
	output	logic	opb_valid_out1,

	//output 2
	output	logic	[$clog2(`PRF_SIZE)-1:0]	opa_PRF_idx2,
	output	logic	[$clog2(`PRF_SIZE)-1:0]	opb_PRF_idx2,
	output	logic	request2,  //send to PRF indicate weather it need data
	output	logic	RAT_allo_halt2,
	output	logic	opa_valid_out2,	//if high opa_valid is immediate
	output	logic	opb_valid_out2,

	//output together
	output	logic	[`ARF_SIZE-1:0]	PRF_free_sig,
	output	logic	[`ARF_SIZE-1:0]	[$clog2(`PRF_SIZE)-1:0] PRF_free_list
	);

	logic	[`ARF_SIZE-1:0]	[$clog2(`PRF_SIZE)-1:0] rat_reg, n_rat_reg;

	logic	[`ARF_SIZE-1:0]	n_PRF_free_sig;
	logic	[`ARF_SIZE-1:0]	[$clog2(`PRF_SIZE)-1:0] n_PRF_free_list;

	logic	[$clog2(`PRF_SIZE)-1:0]	n_opa_PRF_idx1, n_opa_PRF_idx2;
	logic	[$clog2(`PRF_SIZE)-1:0]	n_opb_PRF_idx1, n_opb_PRF_idx2;
	logic	n_opa_valid_out1, n_opa_valid_out2;	//if high opa_valid is immediate
	logic	n_opb_valid_out1, n_opb_valid_out2;
	logic	inst1_rename;
	logic	inst2_rename;
	//logic	[$clog2(`ARF_SIZE)-1:0]	i;

assign inst1_rename = PRF_rename_valid1 & dest_rename_sig1 & inst1_enable;
assign inst2_rename = (PRF_rename_valid2 & dest_rename_sig2) | (PRF_rename_valid1 & ~inst1_rename & dest_rename_sig2) & inst2_enable;

	always_ff @(posedge clock) begin
	if(reset) begin
		rat_reg 		<= #1 0;
		PRF_free_sig            <= #1 0;
		PRF_free_list           <= #1 0;

		opa_valid_out1          <= #1 0;
		opb_valid_out1          <= #1 0;
		opa_PRF_idx1            <= #1 0;
		opb_PRF_idx1            <= #1 0;

		opa_valid_out2          <= #1 0;
		opb_valid_out2          <= #1 0;
		opa_PRF_idx2            <= #1 0;
		opb_PRF_idx2            <= #1 0;
	  	end
	else begin
		rat_reg 		<= #1 n_rat_reg;
		PRF_free_sig            <= #1 n_PRF_free_sig;
		PRF_free_list           <= #1 n_PRF_free_list;

		opa_valid_out1          <= #1 n_opa_valid_out1;
		opb_valid_out1          <= #1 n_opb_valid_out1;
		opa_PRF_idx1            <= #1 n_opa_PRF_idx1;
		opb_PRF_idx1            <= #1 n_opb_PRF_idx1;

		opa_valid_out2          <= #1 n_opa_valid_out2;
		opb_valid_out2          <= #1 n_opb_valid_out2;
		opa_PRF_idx2            <= #1 n_opa_PRF_idx2;
		opb_PRF_idx2            <= #1 n_opb_PRF_idx2;
		end
	end //always_ff

	always_comb begin
	  if(reset) begin
	  	n_PRF_free_sig 		= 0;
	  	n_PRF_free_list 	= 0;

	  	n_opa_PRF_idx1 		= 0;
	  	n_opb_PRF_idx1 		= 0;
	  	request1 			= 0;
	  	RAT_allo_halt1 		= 0;  
	  	n_opa_valid_out1 	= 0;
	   	n_opb_valid_out1 	= 0;

	  	n_opa_PRF_idx2 		= 0;
	  	n_opb_PRF_idx2 		= 0;
	  	request2 			= 0;
	  	RAT_allo_halt2 		= 0;  
	  	n_opa_valid_out2 	= 0;
	   	n_opb_valid_out2 	= 0;
	  end
	  else if(mispredict_sig1|mispredict_sig2) begin
	    	n_PRF_free_sig		= 0;
	    	n_PRF_free_list 	= 0;
	  	for(int i=0; i<`ARF_SIZE; i++) begin
	  		n_PRF_free_sig[i] = !(rat_reg[i] == mispredict_up_idx[i]);	//indicate RAT_idx of i has been overwrite
	  		n_PRF_free_list[i]= (rat_reg[i] == mispredict_up_idx[i])? 0:rat_reg[i];  //indicate the PRF_idx to be free
	  		n_rat_reg[i] 	= mispredict_up_idx[i];  //copy from rrat
	  	end //for
	  	request1 			= 0;
	  	RAT_allo_halt1 		= 0;
	  	n_opa_PRF_idx1 		= 0;
	  	n_opb_PRF_idx1 		= 0;
	  	n_opa_valid_out1 	= 0;
	    n_opb_valid_out1 	= 0;

	  	request2 			= 0;
	  	RAT_allo_halt2 		= 0;
	  	n_opa_PRF_idx2 		= 0;
	  	n_opb_PRF_idx2 		= 0;
	  	n_opa_valid_out2 	= 0;
	    n_opb_valid_out2 	= 0;

	  end //else
	  else if(~inst1_rename && ~inst2_rename) begin
	  	n_PRF_free_sig 		= 0;
	  	n_PRF_free_list 	= 0;
	  	n_rat_reg 			= rat_reg;

    	n_opa_PRF_idx1 		= 0;
	  	n_opb_PRF_idx1 		= 0;
	  	RAT_allo_halt1 		= ~PRF_rename_valid1 && dest_rename_sig1;  //if don't need rename, halt=0;
	  	n_opa_valid_out1	= (~PRF_rename_valid1 && dest_rename_sig1)?0:opa_valid_in1;
	   	n_opb_valid_out1	= (~PRF_rename_valid1 && dest_rename_sig1)?0:opb_valid_in1;

	    n_opa_PRF_idx2 		= 0;
	  	n_opb_PRF_idx2 		= 0;
	  	RAT_allo_halt2 		= ~PRF_rename_valid2 && dest_rename_sig2;  //if don't need rename, halt=0;
	  	n_opa_valid_out2	= (~PRF_rename_valid2 && dest_rename_sig2)?0:opa_valid_in2;
	   	n_opb_valid_out2	= (~PRF_rename_valid2 && dest_rename_sig2)?0:opb_valid_in2;

	  	request1 			= 0;
	  	request2 			= 0;
	  end //else

	  else if(inst1_rename && ~inst2_rename) begin
	  	n_PRF_free_sig 	= 0;
	  	n_PRF_free_list = 0;
	  	n_rat_reg 	= rat_reg;

	    	for(int i=0; i<`ARF_SIZE; i++) begin
			if(i==dest_ARF_idx1) begin
	    		n_rat_reg[i] 	= PRF_rename_idx1;
	    		break;
			end
			else begin
				n_rat_reg[i]	= rat_reg[i];
			end //else
		end  //for

		n_opa_PRF_idx1 	= (opa_valid_in1) ? 0:rat_reg[opa_ARF_idx1];  //opa request prf
		n_opb_PRF_idx1 	= (opb_valid_in1) ? 0:rat_reg[opb_ARF_idx1];
		RAT_allo_halt1 	= 0;
		n_opa_valid_out1= opa_valid_in1;
		n_opb_valid_out1= opb_valid_in1;

	    	n_opa_PRF_idx2 	= 0;
	  	n_opb_PRF_idx2 	= 0;
	  	RAT_allo_halt2 	= ~PRF_rename_valid2 && dest_rename_sig2;  //if don't need rename, halt=0;
	  	n_opa_valid_out2= 0;
	   	n_opb_valid_out2= 0;

		request1 	= 1;
	  	request2 	= 0;
	  end //else

	  else if(~inst1_rename && inst2_rename) begin
	  	n_PRF_free_sig 	= 0;
	  	n_PRF_free_list = 0;
	  	n_rat_reg 	= rat_reg;

	    	for(int i=0; i<`ARF_SIZE; i++) begin
			if(i==dest_ARF_idx2) begin
	    		n_rat_reg[i] 	= PRF_rename_idx1;
	    		break;
			end
			else begin
				n_rat_reg[i]	= rat_reg[i];
			end //else
		end  //for

		n_opa_PRF_idx2 	= (opa_valid_in2) ? 0:rat_reg[opa_ARF_idx2];  //opa request prf
		n_opb_PRF_idx2 	= (opb_valid_in2) ? 0:rat_reg[opb_ARF_idx2];
		RAT_allo_halt2 	= 0;
		n_opa_valid_out2= opa_valid_in2;
		n_opb_valid_out2= opb_valid_in2;

	    	n_opa_PRF_idx1 	= 0;
	  	n_opb_PRF_idx1 	= 0;
	  	RAT_allo_halt1 	= 0;  //if inst can be renamed, then inst 1 must not halt
	  	n_opa_valid_out1= 0;
	   	n_opb_valid_out1= 0;

	  	request1 	= 1;
		request2 	= 0;
	  end //else

	  else	begin //we can allocate PRF1 and PRF2
	  	n_PRF_free_sig 	= 0;
	  	n_PRF_free_list = 0;
	
		for(int i=0; i<`ARF_SIZE; i++) begin
			if(i==dest_ARF_idx1) begin
	    		n_rat_reg[i] 	= PRF_rename_idx1;
	    		break;
			end
			else begin
				n_rat_reg[i]	= rat_reg[i];
			end //else
		end  //for

		for(int i=0; i<`ARF_SIZE; i++) begin
			if(i==dest_ARF_idx2) begin
	    		n_rat_reg[i] 	= PRF_rename_idx2;
	    		break;
			end
			else begin
				n_rat_reg[i]	= rat_reg[i];
			end //else
		end  //for

		n_opa_PRF_idx1 	= (opa_valid_in1) ? 0:rat_reg[opa_ARF_idx1];  //opa request prf
		n_opb_PRF_idx1 	= (opb_valid_in1) ? 0:rat_reg[opb_ARF_idx1];
		RAT_allo_halt1 	= 0;
		n_opa_valid_out1= opa_valid_in1;
		n_opb_valid_out1= opb_valid_in1;

		n_opa_PRF_idx2 	= (opa_valid_in2) ? 0:
				(dest_ARF_idx1 == opa_ARF_idx2)? PRF_rename_idx1:rat_reg[opa_ARF_idx2];  //opa request prf
		n_opb_PRF_idx2 	= (opb_valid_in2) ? 0:
				(dest_ARF_idx1 == opb_ARF_idx2)? PRF_rename_idx1:rat_reg[opb_ARF_idx2];
		RAT_allo_halt2 	= 0;
		n_opa_valid_out2= opa_valid_in2;
		n_opb_valid_out2= opb_valid_in2;

	  	request1 	= 1;
		request2 	= 1;

	  end //else

	end  //always_comb
endmodule


	
