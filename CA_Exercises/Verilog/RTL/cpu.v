//Module: CPU
//Function: CPU is the top design of the RISC-V processor

//Inputs:
//	clk: main clock
//	arst_n: reset 
// enable: Starts the execution
//	addr_ext: Address for reading/writing content to Instruction Memory
//	wen_ext: Write enable for Instruction Memory
// ren_ext: Read enable for Instruction Memory
//	wdata_ext: Write word for Instruction Memory
//	addr_ext_2: Address for reading/writing content to Data Memory
//	wen_ext_2: Write enable for Data Memory
// ren_ext_2: Read enable for Data Memory
//	wdata_ext_2: Write word for Data Memory

// Outputs:
//	rdata_ext: Read data from Instruction Memory
//	rdata_ext_2: Read data from Data Memory



module cpu(
		input  wire			  clk,
		input  wire         arst_n,
		input  wire         enable,
		input  wire	[63:0]  addr_ext,
		input  wire         wen_ext,
		input  wire         ren_ext,
		input  wire [31:0]  wdata_ext,
		input  wire	[63:0]  addr_ext_2,
		input  wire         wen_ext_2,
		input  wire         ren_ext_2,
		input  wire [63:0]  wdata_ext_2,
		
		output wire	[31:0]  rdata_ext,
		output wire	[63:0]  rdata_ext_2

   );

wire              zero_flag, ex_m_zero_flag;
wire [      63:0] branch_pc,updated_pc,current_pc,jump_pc, if_id_upc, id_ex_upc, ex_m_branch_pc, 				ex_m_jump_pc;
wire [      31:0] instruction, if_id_instruction;
wire [       1:0] alu_op;
wire [       3:0] alu_control;
wire              reg_dst,branch,mem_read,mem_2_reg,
                  mem_write,alu_src, reg_write, jump;
wire [       4:0] regfile_waddr;
wire [      63:0] regfile_wdata,mem_data, m_wb_mem_data, alu_out,ex_m_alu_out, m_wb_alu_out,
                  regfile_rdata_1,regfile_rdata_2, id_ex_rdata1, id_ex_rdata2, ex_m_rdata2,
                  alu_operand_2, alu_operand_1, alu_operand_2_im;

wire signed [63:0] immediate_extended, id_ex_immediate_extended;

//Pipelined control signal declarations
wire [2:0] cu_out_ex = {alu_op, alu_src};
wire [2:0] cu_out_m = {branch, mem_read, mem_write};
wire [1:0] cu_out_wb = {mem_2_reg, reg_write};
wire [2:0] id_ex_cu_out_ex;
wire [2:0] id_ex_cu_out_m, ex_m_cu_out_m;
wire [1:0] id_ex_cu_out_wb, ex_m_cu_out_wb, m_wb_cu_out_wb;

//Pipelined instruction signal declarations
wire [9:0] instruction30_12 = {if_id_instruction[31:25], if_id_instruction[14:12]}; //funct7 and funct3
wire [9:0] instruction24_15 = if_id_instruction[24:15]; //Rs1 and Rs2
wire [4:0] instruction11_7 = if_id_instruction[11:7]; //Rd
wire [9:0] id_ex_instruction30_12, id_ex_instruction24_15;
wire [4:0] id_ex_instruction11_7, ex_m_instruction11_7, m_wb_instruction11_7;

//Forwarding control signals
wire [1:0] fw1, fw2;

pc #(
   .DATA_W(64)
) program_counter (
   .clk       (clk       ),
   .arst_n    (arst_n    ),
   .branch_pc (ex_m_branch_pc),//pipelined branch_pc signal
   .jump_pc   (ex_m_jump_pc),//pipelined jump_pc signal
   .zero_flag (ex_m_zero_flag),//pipelined zero_flag signal
   .branch    (ex_m_cu_out_m[2]),//pipelined branch signal
   .jump      (jump      ),
   .current_pc(current_pc),
   .enable    (enable    ),
   .updated_pc(updated_pc)
);

/*****
* UPDATED PC SIGNAL PIPELINE REGISTERS
*****/

//IF_ID Pipeline register for the updated_pc signal
reg_arstn_en#(
   .DATA_W    (64)
)signal_pipeline_IF_ID_UPC(
   .clk       (clk	 ),
   .arst_n    (arst_n	 ),
   .din       (updated_pc),
   .en        (enable	 ),
   .dout      (if_id_upc )
);

//ID_EX Pipeline register for the if_id_upc signal
reg_arstn_en#(
   .DATA_W    (64)
)signal_pipeline_ID_EX_UPC(
   .clk       (clk	 ),
   .arst_n    (arst_n	 ),
   .din       (if_id_upc),
   .en        (enable	 ),
   .dout      (id_ex_upc )
);

sram_BW32 #(
   .ADDR_W(9 )
) instruction_memory(
   .clk      (clk           ),
   .addr     (current_pc    ),
   .wen      (1'b0          ),
   .ren      (1'b1          ),
   .wdata    (32'b0         ),
   .rdata    (instruction   ),   
   .addr_ext (addr_ext      ),
   .wen_ext  (wen_ext       ), 
   .ren_ext  (ren_ext       ),
   .wdata_ext(wdata_ext     ),
   .rdata_ext(rdata_ext     )
);

/*****
* INSTRUCTION SIGNAL PIPELINE REGISTERS
*****/

//IF_ID Pipeline register for the instruction signal
reg_arstn_en#(
   .DATA_W    (32)
)signal_pipeline_IF_ID_instruction(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (instruction      ),
   .en        (enable	        ),
   .dout      (if_id_instruction)
);

//ID_EX Pipeline register for the instruction[24-15] signal (Rs1 and Rs2)
reg_arstn_en#(
   .DATA_W    (10)
)signal_pipeline_ID_EX_instruction24_15(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (instruction24_15),
   .en        (enable	        ),
   .dout      (id_ex_instruction24_15)
);

//ID_EX Pipeline register for the instruction[31-25, 14-12] signal (funct7 and funct3)
reg_arstn_en#(
   .DATA_W    (10)
)signal_pipeline_ID_EX_instruction30_12(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (instruction30_12),
   .en        (enable	        ),
   .dout      (id_ex_instruction30_12)
);

//ID_EX Pipeline register for the instruction[11-7] signal (Rd)
reg_arstn_en#(
   .DATA_W    (5)
)signal_pipeline_ID_EX_instruction11_7(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (instruction11_7),
   .en        (enable	        ),
   .dout      (id_ex_instruction11_7)
);

//EX_M Pipeline register for the instruction[11-7] signal
reg_arstn_en#(
   .DATA_W    (5)
)signal_pipeline_EX_M_instruction11_7(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (id_ex_instruction11_7),
   .en        (enable	        ),
   .dout      (ex_m_instruction11_7)
);

//M_WB Pipeline register for the instruction[11-7] signal
reg_arstn_en#(
   .DATA_W    (5)
)signal_pipeline_M_WB_instruction11_7(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (ex_m_instruction11_7),
   .en        (enable	        ),
   .dout      (m_wb_instruction11_7)
);

sram_BW64 #(
   .ADDR_W(10)
) data_memory(
   .clk      (clk            ),
   .addr     (ex_m_alu_out    ),//pipelined alu_out signal
   .wen      (ex_m_cu_out_m[0]),//pipelined mem_write signal
   .ren      (ex_m_cu_out_m[1]),//pipelined mem_read signal
   .wdata    (ex_m_rdata2     ),//pipelined regfile_rdata_2 signal
   .rdata    (mem_data       ),   
   .addr_ext (addr_ext_2     ),
   .wen_ext  (wen_ext_2      ),
   .ren_ext  (ren_ext_2      ),
   .wdata_ext(wdata_ext_2    ),
   .rdata_ext(rdata_ext_2    )
);

//M_WB Pipeline register for the mem_data signal
reg_arstn_en#(
   .DATA_W    (64)
)signal_pipeline_M_WB_mem_data(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (mem_data ),
   .en        (enable	        ),
   .dout      (m_wb_mem_data )
);

control_unit control_unit(
   .opcode   (if_id_instruction[6:0]),
   .alu_op   (alu_op          ),
   .reg_dst  (reg_dst         ),
   .branch   (branch          ),
   .mem_read (mem_read        ),
   .mem_2_reg(mem_2_reg       ),
   .mem_write(mem_write       ),
   .alu_src  (alu_src         ),
   .reg_write(reg_write       ),
   .jump     (jump            )
);

/*****
* CONTROL SIGNAL PIPELINE REGISTERS
*****/

//ID_EX Pipeline register for the cu_out_ex signal
reg_arstn_en#(
   .DATA_W    (3)
)signal_pipeline_ID_EX_cu_out_ex(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (cu_out_ex        ),
   .en        (enable	        ),
   .dout      (id_ex_cu_out_ex  )
);

//ID_EX Pipeline register for the cu_out_m signal
reg_arstn_en#(
   .DATA_W    (3)
)signal_pipeline_ID_EX_cu_out_m(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (cu_out_m      ),
   .en        (enable	        ),
   .dout      (id_ex_cu_out_m)
);

//EX_M Pipeline register for the cu_out_m signal
reg_arstn_en#(
   .DATA_W    (3)
)signal_pipeline_EX_M_cu_out_m(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (id_ex_cu_out_m),
   .en        (enable	        ),
   .dout      (ex_m_cu_out_m)
);

//ID_EX Pipeline register for the cu_out_wb signal
reg_arstn_en#(
   .DATA_W    (2)
)signal_pipeline_ID_EX_cu_out_wb(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (cu_out_wb      ),
   .en        (enable	        ),
   .dout      (id_ex_cu_out_wb)
);

//EX_M Pipeline register for the cu_out_wb signal
reg_arstn_en#(
   .DATA_W    (2)
)signal_pipeline_EX_M_cu_out_wb(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (id_ex_cu_out_wb),
   .en        (enable	        ),
   .dout      (ex_m_cu_out_wb)
);

//M_WB Pipeline register for the cu_out_wb signal
reg_arstn_en#(
   .DATA_W    (2)
)signal_pipeline_M_WB_cu_out_wb(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (ex_m_cu_out_wb),
   .en        (enable	        ),
   .dout      (m_wb_cu_out_wb)
);

register_file #(
   .DATA_W(64)
) register_file(
   .clk      (clk               ),
   .arst_n   (arst_n            ),
   .reg_write(m_wb_cu_out_wb[0] ),//pipelined reg_write signal
   .raddr_1  (if_id_instruction[19:15]),
   .raddr_2  (if_id_instruction[24:20]),
   .waddr    (m_wb_instruction11_7),//pipelined imstruction[11:7] signal
   .wdata    (regfile_wdata),
   .rdata_1  (regfile_rdata_1   ),
   .rdata_2  (regfile_rdata_2   )
);

/*****
* REGISTER FILE SIGNAL PIPELINE REGISTERS
*****/

//ID_EX Pipeline register for the regfile_rdata1 signal
reg_arstn_en#(
   .DATA_W    (64)
)signal_pipeline_ID_EX_rdata1(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (regfile_rdata_1),
   .en        (enable	        ),
   .dout      (id_ex_rdata1)
);

//ID_EX Pipeline register for the regfile_rdata2 signal
reg_arstn_en#(
   .DATA_W    (64)
)signal_pipeline_ID_EX_rdata2(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (regfile_rdata_2),
   .en        (enable	        ),
   .dout      (id_ex_rdata2)
);

//EX_M Pipeline register for the regfile_rdata2 signal
reg_arstn_en#(
   .DATA_W    (64)
)signal_pipeline_EX_M_rdata2(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (id_ex_rdata2),
   .en        (enable	        ),
   .dout      (ex_m_rdata2)
);

immediate_extend_unit immediate_extend_u(
    .instruction         (if_id_instruction),
    .immediate_extended  (immediate_extended)
);

//ID_EX Pipeline register for the immediate_extended signal
reg_arstn_en#(
   .DATA_W    (64)
)signal_pipeline_ID_EX_immediate_extended(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (immediate_extended),
   .en        (enable	        ),
   .dout      (id_ex_immediate_extended)
);

alu_control alu_ctrl(
   .func7       (id_ex_instruction30_12[9:3]),//pipelined signal of instruction[31:25]
   .func3          (id_ex_instruction30_12[2:0]),//pipelined signal of instruction[14:12]
   .alu_op         (id_ex_cu_out_ex[2:1]),
   .alu_control    (alu_control       )
);

//FORWARDING UNIT
forwarding_unit fw_unit(
   .id_ex_rs1_2 (id_ex_instruction24_15),
   .ex_m_rd (ex_m_instruction11_7),
   .m_wb_rd (m_wb_instruction11_7),
   .ex_m_cu_out_wb (x_m_cu_out_wb),
   .m_wb_cu_out_wb (m_wb_cu_out_wb),
   .fw1 (fw1),
   .fw2 (fw2)
);

mux_2 #(
   .DATA_W(64)
) alu_operand2_im_mux (
   .input_a (id_ex_immediate_extended),
   .input_b (id_ex_rdata2    ),//pipelined regfile_rdata_2 signal
   .select_a(id_ex_cu_out_ex[0]),
   .mux_out (alu_operand_2_im )
);

mux_3 #(
   .DATA_W(64)
) alu_operand1_mux (
   .input_a (ex_m_alu_out),
   .input_b (regfile_wdata),
   .input_c (id_ex_rdata1),//pipelined regfile_rdata_2 signal
   .select  (fw1),
   .mux_out (alu_operand_1     )
);

mux_3 #(
   .DATA_W(64)
) alu_operand2_mux (
   .input_a (ex_m_alu_out), //prior ALU result
   .input_b (regfile_wdata),//earlier ALU result
   .input_c (alu_operand_2_im), //register file
   .select  (fw2),
   .mux_out (alu_operand_2     )
);

alu#(
   .DATA_W(64)
) alu(
   .alu_in_0 (alu_operand_1 ),//pipelined regfile_rdata_1 signal
   .alu_in_1 (alu_operand_2   ),
   .alu_ctrl (alu_control     ),
   .alu_out  (alu_out         ),
   .zero_flag(zero_flag       ),
   .overflow (                )
);

//EX_M Pipeline register for the alu_out signal
reg_arstn_en#(
   .DATA_W    (64)
)signal_pipeline_EX_M_alu_out(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (alu_out),
   .en        (enable	        ),
   .dout      (ex_m_alu_out)
);

//M_WB Pipeline register for the alu_out signal
reg_arstn_en#(
   .DATA_W    (64)
)signal_pipeline_M_WB_alu_out(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (ex_m_alu_out),
   .en        (enable	        ),
   .dout      (m_wb_alu_out)
);

//EX_M Pipeline register for the zero_flag signal
reg_arstn_en#(
   .DATA_W    (1)
)signal_pipeline_EX_M_zero_flag(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (zero_flag),
   .en        (enable	        ),
   .dout      (ex_m_zero_flag)
);

mux_2 #(
   .DATA_W(64)
) regfile_data_mux (
   .input_a  (m_wb_mem_data),//pipelined mem_data signal
   .input_b  (m_wb_alu_out),//pipelined alu_out signal
   .select_a (m_wb_cu_out_wb[1]    ),//pipelined mem_2_reg signal
   .mux_out  (regfile_wdata)
);

branch_unit#(
   .DATA_W(64)
)branch_unit(
   .updated_pc         (id_ex_upc        ),
   .immediate_extended (id_ex_immediate_extended),
   .branch_pc          (branch_pc         ),
   .jump_pc            (jump_pc           )
);

//EX_M Pipeline register for the branch_pc signal
reg_arstn_en#(
   .DATA_W    (64)
)signal_pipeline_EX_M_branch_pc(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (branch_pc),
   .en        (enable	        ),
   .dout      (ex_m_branch_pc)
);

//EX_M Pipeline register for the jump_pc signal
reg_arstn_en#(
   .DATA_W    (64)
)signal_pipeline_EX_M_jump_pc(
   .clk       (clk	        ),
   .arst_n    (arst_n	        ),
   .din       (jump_pc),
   .en        (enable	        ),
   .dout      (ex_m_jump_pc)
);


endmodule


