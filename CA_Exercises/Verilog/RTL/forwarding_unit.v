// module: Forwarding unit
// Function: Controls if ALU result gets forwarded

module forwarding_unit(
      input  wire [9:0] id_ex_rs1_2,
      input  wire [4:0] ex_m_rd,
      input  wire [4:0] m_wb_rd,
      input  wire [1:0]	ex_m_cu_out_wb,
      input  wire [1:0]	m_wb_cu_out_wb,
      output reg  [1:0] fw1,
      output reg  [1:0] fw2
   );

	wire [4:0] id_ex_rs1 = id_ex_rs1_2[19:15];
	wire [4:0] id_ex_rs2 = id_ex_rs1_2[24:20];
	wire ex_m_reg_write = ex_m_cu_out_wb[0];
	wire m_wb_reg_write = m_wb_cu_out_wb[0];

	always@(*)begin
		//Default: no forwarding
		fw1 = 2'b00;
		fw2 = 2'b00;

		//Check for EX hazard
		if(ex_m_reg_write && (ex_m_rd != 5'b0) && (ex_m_rd == id_ex_rs1)) fw1 = 2'b10;
		if(ex_m_reg_write && (ex_m_rd != 5'b0) && (ex_m_rd == id_ex_rs2)) fw2 = 2'b10;

		//Check for MEM hazard
		if(m_wb_reg_write && (m_wb_rd != 5'b0) && (m_wb_rd == id_ex_rs1)) fw1 = 2'b01;
		if(m_wb_reg_write && (m_wb_rd != 5'b0) && (m_wb_rd == id_ex_rs2)) fw2 = 2'b01;	
	end
   
endmodule
