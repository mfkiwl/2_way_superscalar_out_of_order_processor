/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  id_stage.v                                          //
//                                                                     //
//  Description :  instruction decode (ID) stage of the pipeline;      // 
//                 decode the instruction fetch register operands, and // 
//                 compute immediate operand (if applicable)           // 
//                                                                     //
/////////////////////////////////////////////////////////////////////////


//`timescale 1ns/100ps


  // Decode an instruction: given instruction bits IR produce the
  // appropriate datapath control signals.
  //
  // This is a *combinational* module (basically a PLA).
  //
module decoder(

    input [31:0] inst,
    input valid_inst_in,  // ignore inst when low, outputs will
                          // reflect noop (except valid_inst)

    output ALU_OPA_SELECT opa_select,
    output ALU_OPB_SELECT opb_select,
    output DEST_REG_SEL   dest_reg, // mux selects
    output ALU_FUNC       alu_func,
    output logic rd_mem, wr_mem, cond_branch, uncond_branch,
    output logic halt,      // non-zero on a halt
    output logic illegal,    // non-zero on an illegal instruction
    output logic valid_inst,  
    output logic        if_FBEQ// for counting valid instructions executed
                            // and for making the fetch stage die on halts/
                            // keeping track of when to allow the next
                            // instruction out of fetch
                            // 0 for HALT and illegal instructions (die on halt)

  );

  assign valid_inst = valid_inst_in & ~illegal;
  
  always_comb begin
    // default control values:
    // - valid instructions must override these defaults as necessary.
    //   opa_select, opb_select, and alu_func should be set explicitly.
    // - invalid instructions should clear valid_inst.
    // - These defaults are equivalent to a noop
    // * see sys_defs.vh for the constants used here
    opa_select = ALU_OPA_IS_REGA;
    opb_select = ALU_OPB_IS_REGB;
    alu_func = ALU_ADDQ;
    dest_reg = DEST_NONE;
    rd_mem = `FALSE;
    wr_mem = `FALSE;
    cond_branch = `FALSE;
    uncond_branch = `FALSE;
    halt = `FALSE;
    illegal = `FALSE;
    if_FBEQ =0;
    if(valid_inst_in) begin
      case ({inst[31:29], 3'b0})
        6'h0:
          case (inst[31:26])
            `PAL_INST:
              if (inst[25:0] == 26'h0555)
                halt = `TRUE;
              else
                illegal = `TRUE;
            default: illegal = `TRUE;
          endcase // case(inst[31:26])

        6'h10:
        begin
          opa_select = ALU_OPA_IS_REGA;
          opb_select = inst[12] ? ALU_OPB_IS_ALU_IMM : ALU_OPB_IS_REGB;
          dest_reg = DEST_IS_REGC;
          case (inst[31:26])
            `INTA_GRP:
              case (inst[11:5])
                `CMPULT_INST:  alu_func = ALU_CMPULT;
                `ADDQ_INST:    alu_func = ALU_ADDQ;
                `SUBQ_INST:    alu_func = ALU_SUBQ;
                `CMPEQ_INST:   alu_func = ALU_CMPEQ;
                `CMPULE_INST:  alu_func = ALU_CMPULE;
                `CMPLT_INST:   alu_func = ALU_CMPLT;
                `CMPLE_INST:   alu_func = ALU_CMPLE;
                default:       illegal = `TRUE;
              endcase // case(inst[11:5])
            `INTL_GRP:
              case (inst[11:5])
                `AND_INST:    alu_func = ALU_AND;
                `BIC_INST:    alu_func = ALU_BIC;
                `BIS_INST:    alu_func = ALU_BIS;
                `ORNOT_INST:  alu_func = ALU_ORNOT;
                `XOR_INST:    alu_func = ALU_XOR;
                `EQV_INST:    alu_func = ALU_EQV;
                default:      illegal = `TRUE;
              endcase // case(inst[11:5])
            `INTS_GRP:
              case (inst[11:5])
                `SRL_INST:  alu_func = ALU_SRL;
                `SLL_INST:  alu_func = ALU_SLL;
                `SRA_INST:  alu_func = ALU_SRA;
                default:    illegal = `TRUE;
              endcase // case(inst[11:5])
            `INTM_GRP:
              case (inst[11:5])
                `MULQ_INST:       alu_func = ALU_MULQ;
                default:          illegal = `TRUE;
              endcase // case(inst[11:5])
            `ITFP_GRP:       illegal = `TRUE;       // unimplemented
            `FLTV_GRP:       illegal = `TRUE;       // unimplemented
            `FLTI_GRP:       illegal = `TRUE;       // unimplemented
            `FLTL_GRP:       illegal = `TRUE;       // unimplemented
          endcase // case(inst[31:26])
        end

        6'h18:
          case (inst[31:26])
            `MISC_GRP:       illegal = `TRUE; // unimplemented
            `JSR_GRP:
            begin
              // JMP, JSR, RET, and JSR_CO have identical semantics
              opa_select = ALU_OPA_IS_NOT3;
              opb_select = ALU_OPB_IS_REGB;
              alu_func = ALU_AND; // clear low 2 bits (word-align)
              dest_reg = DEST_IS_REGA;
              uncond_branch = `TRUE;
            end
            `FTPI_GRP:       illegal = `TRUE;       // unimplemented
          endcase // case(inst[31:26])
         
        6'h08, 6'h20, 6'h28:
        begin
          opa_select = ALU_OPA_IS_MEM_DISP;
          opb_select = ALU_OPB_IS_REGB;
          alu_func = ALU_ADDQ;
          dest_reg = DEST_IS_REGA;
          case (inst[31:26])
            `LDA_INST:  /* defaults are OK */					//************************************************** need to change
		begin
		dest_reg = DEST_IS_REGA;					//**********changed
		opa_select = ALU_OPA_IS_MEM_DISP;
          	opb_select = ALU_OPB_IS_REGB;
		end
            `LDQ_INST, `LDQ_L_INST:
              begin
                rd_mem = `TRUE;
                dest_reg = DEST_IS_REGA;
              end // case: `LDQ_INST
            `STQ_INST, `STQ_C_INST:
              begin
                wr_mem = `TRUE;
                dest_reg = DEST_NONE;
              end // case: `STQ_INST
            default:       illegal = `TRUE;
          endcase // case(inst[31:26])
        end
      
        6'h30, 6'h38:
        begin
          opa_select = ALU_OPA_IS_NPC;
          opb_select = ALU_OPB_IS_BR_DISP;
          alu_func = ALU_ADDQ;
          case (inst[31:26])
            `FBLT_INST, `FBLE_INST,
            `FBNE_INST, `FBGE_INST, `FBGT_INST:
            begin
              // FP conditionals not implemented
              illegal = `TRUE;
            end
	    `FBEQ_INST:
	    begin
		if_FBEQ =1;
	        cond_branch = `TRUE;
	    end

            `BR_INST, `BSR_INST:
            begin
              dest_reg = DEST_IS_REGA;
              uncond_branch = `TRUE;
            end

            default:
              cond_branch = `TRUE; // all others are conditional
          endcase // case(inst[31:26])
        end
      endcase // case(inst[31:29] << 3)
    end // if(~valid_inst_in)
  end // always
     
endmodule // decoder


module id_stage(
             
				input         clock,                // system clock
				input         reset,                // system reset
				input  [31:0] if_id_IR1,             // incoming instruction1
				input  [31:0] if_id_IR2,             // incoming instruction2
				//input         wb_reg_wr_en_out,     // Reg write enable from WB Stage
				//input   [4:0] wb_reg_wr_idx_out,    // Reg write index from WB Stage
				//input  [63:0] wb_reg_wr_data_out,   // Reg write data from WB Stage
				input         if_id_valid_inst1,
				input         if_id_valid_inst2,
				input  [63:0] if_id_NPC_inst1,           // incoming instruction1 PC+4
				input  [63:0] if_id_NPC_inst2,           // incoming instruction2 PC+4

				 
				output logic [63:0] opa_mux_out1,          //instr1 opa and opb value or tag
			    output logic [63:0] opb_mux_out1,
				output logic  opa_mux_tag1,                //signal to indicate whether it is value or tag,true means value,faulse means tag
				output logic  opb_mux_tag1,
				output logic  [4:0] id_dest_reg_idx_out1,  // destination (writeback) register index
													       // (ZERO_REG if no writeback)
				 
				output logic [63:0] opa_mux_out2,          //instr2 opa and opb value or tag
				output logic [63:0] opb_mux_out2,
				output logic  opa_mux_tag2,                //signal to indicate whether it is value or tag
				output logic  opb_mux_tag2,
				output logic  [4:0] id_dest_reg_idx_out2,  // destination (writeback) register index


				output ALU_FUNC id_alu_func_out1,      // ALU function select (ALU_xxx *)
				output ALU_FUNC id_alu_func_out2,      // ALU function select (ALU_xxx *)
				output logic  [5:0] id_op_type_inst1,		// op type
				output logic  [5:0] id_op_type_inst2,
				output FU_SELECT id_op_select1,
				output FU_SELECT id_op_select2,

				output logic        id_rd_mem_out1,        // does inst read memory?
				output logic        id_wr_mem_out1,        // does inst write memory?
				//output logic        id_ldl_mem_out1,       // load-lock inst?
				//output logic        id_stc_mem_out1,       // store-conditional inst?
				output logic        id_cond_branch_out1,   // is inst a conditional branch?
				output logic        id_uncond_branch_out1, // is inst an unconditional branch 
													        // or jump?
				output logic        id_halt_out1,
				//output logic        id_cpuid_out1,         // get CPUID inst?
				output logic        id_illegal_out1,
				output logic        id_valid_inst_out1,     // is inst a valid instruction to be 
									        // counted for CPI calculations?
				output logic        id_rd_mem_out2,        // does inst read memory?
				output logic        id_wr_mem_out2,        // does inst write memory?
				//output logic        id_ldl_mem_out2,       // load-lock inst?
				//output logic        id_stc_mem_out2,       // store-conditional inst?
				output logic        id_cond_branch_out2,   // is inst a conditional branch?
				output logic        id_uncond_branch_out2, // is inst an unconditional branch 
											        		// or jump?
				output logic        id_halt_out2,
				//output logic        id_cpuid_out2,         // get CPUID inst?
				output logic        id_illegal_out2,
				output logic        id_valid_inst_out2,     // is inst a valid instruction to be
				output logic [4:0]  id_rega_inst1, 
				output logic [4:0]  id_rega_inst2,
				output logic        if_FBEQ1,
				output logic        if_FBEQ2
);
   
	DEST_REG_SEL dest_reg_select1;
	DEST_REG_SEL dest_reg_select2;
	ALU_OPA_SELECT id_opa_select_out1;
	ALU_OPB_SELECT id_opb_select_out1;
	ALU_OPA_SELECT id_opa_select_out2;
	ALU_OPB_SELECT id_opb_select_out2;

	// instruction fields read from IF/ID pipeline register
	//wire    [4:0] ra_idx1 = if_id_IR1[25:21];   // inst1 operand A register index
	wire    [4:0] id_regb_inst1 = if_id_IR1[20:16];   // inst1 operand B register index
	wire    [4:0] id_regc_inst1 = if_id_IR1[4:0];     // inst1 operand C register index
	
	//wire    [4:0] ra_idx2 = if_id_IR2[25:21];   // inst2 operand A register index
	wire    [4:0] id_regb_inst2 = if_id_IR2[20:16];   // inst2 operand B register index
	wire    [4:0] id_regc_inst2 = if_id_IR2[4:0];     // inst2 operand C register index
	
	wire [63:0] mem_disp1 = { {48{if_id_IR1[15]}}, if_id_IR1[15:0] };
	wire [63:0] br_disp1  = { {41{if_id_IR1[20]}}, if_id_IR1[20:0], 2'b00 };
	wire [63:0] alu_imm1  = { 56'b0, if_id_IR1[20:13] };
	
	wire [63:0] mem_disp2 = { {48{if_id_IR2[15]}}, if_id_IR2[15:0] };
	wire [63:0] br_disp2  = { {41{if_id_IR2[20]}}, if_id_IR2[20:0], 2'b00 };
	wire [63:0] alu_imm2  = { 56'b0, if_id_IR2[20:13] };

	assign id_op_type_inst1 = if_id_IR1[31:26];   //inst op type generate
	assign id_op_type_inst2 = if_id_IR2[31:26];

	assign id_rega_inst1 = if_id_IR1[25:21];
	assign id_rega_inst2 = if_id_IR2[25:21];

	//
	// ALU opA mux
	//
	always_comb
	begin
		case (id_opa_select_out1)
			ALU_OPA_IS_REGA: begin     
				opa_mux_out1 = {{59{1'b0}},id_rega_inst1};
				opa_mux_tag1 = `FALSE;
				end
			ALU_OPA_IS_MEM_DISP: begin
				opa_mux_out1 = mem_disp1;
				opa_mux_tag1 = `TRUE;
				end
			ALU_OPA_IS_NPC: begin
				opa_mux_out1 = if_id_NPC_inst1;
				opa_mux_tag1 = `TRUE;
				end
			ALU_OPA_IS_NOT3: begin
				opa_mux_out1 = ~64'h3;
				opa_mux_tag1 = `TRUE;
				end
		endcase
		case (id_opa_select_out2)
			ALU_OPA_IS_REGA: begin
				opa_mux_out2 = {{59{1'b0}},id_rega_inst2};
				opa_mux_tag2 = `FALSE;
				end
			ALU_OPA_IS_MEM_DISP: begin
				opa_mux_out2 = mem_disp2;
				opa_mux_tag2 = `TRUE;
				end
			ALU_OPA_IS_NPC: begin
				opa_mux_out2 = if_id_NPC_inst2;
				opa_mux_tag2 = `TRUE;
				end	
			ALU_OPA_IS_NOT3: begin
				opa_mux_out2 = ~64'h3;
				opa_mux_tag2 = `TRUE;
				end
		endcase
	end

	//
	// ALU opB mux
	//
	always_comb
	begin
		 // Default value, Set only because the case isnt full.  If you see this
		 // value on the output of the mux you have an invalid opb_select
		opb_mux_out1 = 64'hbaadbeefdeadbeef;
		opb_mux_out2 = 64'hbaadbeefdeadbeef;
		case (id_opb_select_out1)
			ALU_OPB_IS_REGB: begin
				opb_mux_out1 = {{59{1'b0}},id_regb_inst1};
				opb_mux_tag1 = `FALSE;
				end
			ALU_OPB_IS_ALU_IMM: begin
				opb_mux_out1 = alu_imm1;
				opb_mux_tag1 = `TRUE;
				end
			ALU_OPB_IS_BR_DISP: begin
				opb_mux_out1 = br_disp1;
				opb_mux_tag1 = `TRUE;
				end
			default: begin
				opb_mux_tag1 = `TRUE;
			end
		endcase
		case (id_opb_select_out2)
			ALU_OPB_IS_REGB: begin
				opb_mux_out2 = {{59{1'b0}},id_regb_inst2};
				opb_mux_tag2 = `FALSE;
				end
			ALU_OPB_IS_ALU_IMM: begin
				opb_mux_out2 = alu_imm2;
				opb_mux_tag2 = `TRUE;
				end
			ALU_OPB_IS_BR_DISP: begin
				opb_mux_out2 = br_disp2;
				opb_mux_tag2 = `TRUE;
				end
			default: begin
				opb_mux_tag2 = `TRUE;
			end
		endcase  
	end

	
	// instantiate the instruction decoder
	decoder decode_1 (// Input
					 .inst(if_id_IR1),
					 .valid_inst_in(if_id_valid_inst1),

					 // Outputs
					 .opa_select(id_opa_select_out1),
					 .opb_select(id_opb_select_out1),
					 .alu_func(id_alu_func_out1),
					 .dest_reg(dest_reg_select1),
					 .rd_mem(id_rd_mem_out1),
					 .wr_mem(id_wr_mem_out1),
					 //.ldl_mem(id_ldl_mem_out1),
					 //.stc_mem(id_stc_mem_out1),
					 .cond_branch(id_cond_branch_out1),
					 .uncond_branch(id_uncond_branch_out1),
					 .halt(id_halt_out1),
					 //.cpuid(id_cpuid_out1),
					 .illegal(id_illegal_out1),
					 .valid_inst(id_valid_inst_out1),
					 .if_FBEQ(if_FBEQ1)
					);

	decoder decode_2 (// Input
					 .inst(if_id_IR2),
					 .valid_inst_in(if_id_valid_inst2),

					 // Outputs
					 .opa_select(id_opa_select_out2),
					 .opb_select(id_opb_select_out2),
					 .alu_func(id_alu_func_out2),
					 .dest_reg(dest_reg_select2),
					 .rd_mem(id_rd_mem_out2),
					 .wr_mem(id_wr_mem_out2),
					 //.ldl_mem(id_ldl_mem_out2),
					 //.stc_mem(id_stc_mem_out2),
					 .cond_branch(id_cond_branch_out2),
					 .uncond_branch(id_uncond_branch_out2),
					 .halt(id_halt_out2),
					 //.cpuid(id_cpuid_out2),
					 .illegal(id_illegal_out2),
					 .valid_inst(id_valid_inst_out2),
					 .if_FBEQ(if_FBEQ2)
					);
	// mux to generate dest_reg_idx based on
	// the dest_reg_select output from decoder
	always_comb
	begin
		case (dest_reg_select1)
			DEST_IS_REGC: id_dest_reg_idx_out1 = id_regc_inst1;
			DEST_IS_REGA: id_dest_reg_idx_out1 = id_rega_inst1;
			DEST_NONE:    id_dest_reg_idx_out1 = `ZERO_REG;
			default:       id_dest_reg_idx_out1 = `ZERO_REG; 
		endcase
		case (dest_reg_select2)
			DEST_IS_REGC: id_dest_reg_idx_out2 = id_regc_inst2;
			DEST_IS_REGA: id_dest_reg_idx_out2 = id_rega_inst2;
			DEST_NONE:    id_dest_reg_idx_out2 = `ZERO_REG;
			default:       id_dest_reg_idx_out2 = `ZERO_REG; 
		endcase
	end

	always_comb
	begin
		case({id_op_type_inst1[5:3],3'b0})
			6'h08, 6'h20, 6'h28: id_op_select1 = USE_MEMORY;
			//6'h18, 6'h30, 6'h38: id_op_select1 = USE_BRANCH;
			default: begin
				if(id_alu_func_out1 == ALU_MULQ)
					id_op_select1 = USE_MULTIPLIER;
				else
					id_op_select1 = USE_ADDER;
				end
		endcase
		case({id_op_type_inst2[5:3],3'b0})
			6'h08, 6'h20, 6'h28: id_op_select2 = USE_MEMORY;
			//6'h18, 6'h30, 6'h38: id_op_select2 = USE_BRANCH;
			default: begin
				if(id_alu_func_out2 == ALU_MULQ)
					id_op_select2 = USE_MULTIPLIER;
				else
					id_op_select2 = USE_ADDER;
				end
		endcase	
		//$display("id_dest_reg_idx_out1:%h", id_dest_reg_idx_out1);
		//$display("id_dest_reg_idx_out2:%h", id_dest_reg_idx_out2);
	end
			
   
endmodule // module id_stage
