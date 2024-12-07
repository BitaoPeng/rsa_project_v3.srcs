
module tb_mem #(
  parameter AWIDTH =   14, // Address width
  parameter CWIDTH =    8, // Column width (1 Byte)
  parameter CCOUNT =  128, // Number of columns
  parameter DWIDTH = 1024  // Data width, (CWIDTH * CCOUNT)
  ) (

  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME BRAM_CTRL, MEM_SIZE 16384, MEM_WIDTH 1024, MEM_ECC NONE, MASTER_TYPE BRAM_CTRL, READ_WRITE_MODE READ_WRITE" *)
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 brama CLK" *)
  input  wire              bram_clk_a    ,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 brama RST" *)
  input  wire              bram_rst_a    ,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 brama EN" *)
  input  wire              bram_en_a     ,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 brama ADDR" *)
  input  wire [AWIDTH-1:0] bram_addr_a   ,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 brama WE" *)
  input  wire [CCOUNT-1:0] bram_we_a     ,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 brama DIN" *)
  input  wire [DWIDTH-1:0] bram_wrdata_a ,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 brama DOUT" *)
  output reg  [DWIDTH-1:0] bram_rddata_a ,

  // Port B
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME BRAM_CTRL, MEM_SIZE 16384, MEM_WIDTH 1024, MEM_ECC NONE, MASTER_TYPE BRAM_CTRL, READ_WRITE_MODE READ_WRITE" *)
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 bramb CLK" *)
  input  wire              bram_clk_b    ,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 bramb RST" *)
  input  wire              bram_rst_b    ,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 bramb EN" *)
  input  wire              bram_en_b     ,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 bramb ADDR" *)
  input  wire [AWIDTH-1:0] bram_addr_b   ,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 bramb WE" *)
  input  wire [CCOUNT-1:0] bram_we_b     ,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 bramb DIN" *)
  input  wire [DWIDTH-1:0] bram_wrdata_b ,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 bramb DOUT" *)
  output reg  [DWIDTH-1:0] bram_rddata_b
);

  reg [DWIDTH-1:0] mem [1<<(AWIDTH)-1:0]; // Memory Declaration

  integer i;

  // RAM : Both READ and WRITE have a latency of one

  always @ (posedge bram_clk_a)
    for(i = 0;i<CCOUNT;i=i+1)
      if(bram_we_a[i])
        mem[bram_addr_a][i*CWIDTH +: CWIDTH] <= bram_wrdata_a[i*CWIDTH +: CWIDTH];

  reg [DWIDTH-1:0] bram_rddata_a_r;
  always @ (posedge bram_clk_a)
    if(~|bram_we_a)
      bram_rddata_a_r <= mem[bram_addr_a];

  always @ (*)
    bram_rddata_a <= bram_rddata_a_r;

  /////////////////////

  always @ (posedge bram_clk_b)
    for(i = 0;i<CCOUNT;i=i+1)
      if(bram_we_b[i])
        mem[bram_addr_b][i*CWIDTH +: CWIDTH] <= bram_wrdata_b[i*CWIDTH +: CWIDTH];

  reg [DWIDTH-1:0] bram_rddata_b_r;
  always @ (posedge bram_clk_b)
    if(~|bram_we_b)
      bram_rddata_b_r <= mem[bram_addr_b];

  always @ (*)
    bram_rddata_b <= bram_rddata_b_r;


endmodule