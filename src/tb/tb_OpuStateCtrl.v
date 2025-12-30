//////////////////////////////////////////////////////////////////////////////////
// Company: DSMART
// Engineer: MYH
// 
// Create Date: 2025/12/23 
// Design Name: OPU_top
// Module Name: tb_OpuStateCtrl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// TB for OpuStateCtrl
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module tb_OpuStateCtrl;
  // 参数定义
  parameter CLK_PERIOD = 10;      // 100MHz 时钟
  integer   InferIndex;

  // OpuStateCtrl Inputs
  reg   iSysClk;
  reg   iRst_N;
  reg   [31:0]  iOperation;
  reg   [31:0]  iBatchNum;
  reg   iDDRbusy;
  reg   iDp2OpuHS;
  reg   iWgtDataDistributeDone;
  reg   iActDataDistributeDone;
  reg   iOpu2DpHS;
  reg   iResultReturnDone;

  // OpuStateCtrl Outputs
  wire  oReady;
  wire  oWgtConfigStart;
  wire  oInferStart;
  wire  [32:0]  oReadAddr;
  wire  [32:0]  oWriteAddr;
  wire  [15:0]  length_r;
  wire  [15:0]  length_w;


  OpuStateCtrl  u_OpuStateCtrl (
      .iSysClk                 ( iSysClk               ),
      .iRst_N                  ( iRst_N                ),
      .iOperation              ( iOperation            ),
      .iBatchNum               ( iBatchNum             ),
      .iDDRbusy                ( iDDRbusy              ),
      .iDp2OpuHS               ( iDp2OpuHS             ),
      .iActDataDistributeDone  ( iActDataDistributeDone   ),
      .iWgtDataDistributeDone  ( iWgtDataDistributeDone   ),
      .iOpu2DpHS               ( iOpu2DpHS             ),
      .iResultReturnDone       ( iResultReturnDone     ),

      .oReady                  ( oReady                ),
      .oWgtConfigStart         ( oWgtConfigStart       ),
      .oInferStart             ( oInferStart           ),
      .oReadAddr               ( oReadAddr             ),
      .oWriteAddr              ( oWriteAddr            ),
      .length_r                ( length_r              ),
      .length_w                ( length_w              )
  );

  initial begin
      iSysClk <= 0;
      forever #(CLK_PERIOD/2) iSysClk <= ~iSysClk;
  end

  initial begin
      iRst_N <= 0;
      iOperation             <= {{5'b00000},27'b0}; //IDLE
      iBatchNum              <= 32'd500;
      iDDRbusy               <= 1'b0;
      iDp2OpuHS              <= 1'b0;
      iWgtDataDistributeDone <= 1'b0;
      iActDataDistributeDone <= 1'b0;
      iOpu2DpHS              <= 1'b0;
      iResultReturnDone      <= 1'b0;

      repeat(50)@(posedge iSysClk);
      iRst_N <= 1;

      repeat(80)@(posedge iSysClk);
      // Test WGT config
      iOperation <= {{5'b00010},27'b0}; //WGT config
      repeat(1)@(posedge iSysClk) iOperation <= {{5'b00000},27'b0}; //WGT config
      iBatchNum              <= 32'd500;
      iDp2OpuHS              <= 1'b0;
      iWgtDataDistributeDone <= 1'b0;
      iActDataDistributeDone <= 1'b0;
      iOpu2DpHS              <= 1'b0;
      iResultReturnDone      <= 1'b0;
      

      repeat(10)@(posedge iSysClk);
      iWgtDataDistributeDone <= 1'b1;
      repeat(1)@(posedge iSysClk);
      iWgtDataDistributeDone <= 1'b0;
      

      repeat(20)@(posedge iSysClk);
      // Test Net Infer
  
      for(InferIndex=0;InferIndex<500;InferIndex=InferIndex+1) begin
        repeat(50)@(posedge iSysClk);
          NetInferTest();
      end

      repeat(100000)@(posedge iSysClk);
      $finish;
  end

task NetInferTest();
  // Test Net Infer
  begin
    iOperation             <= {{5'b00100},27'b0}; //Net Infer
    repeat(1)@(posedge iSysClk);
    iOperation <= {{5'b00000},27'b0}; //WGT config
    iBatchNum              <= 32'd500;
    iDp2OpuHS              <= 1'b0;
    iWgtDataDistributeDone <= 1'b0;
    iActDataDistributeDone <= 1'b0;
    iOpu2DpHS              <= 1'b0;

    repeat(50)@(posedge iSysClk);
    iActDataDistributeDone <= 1'b1;
    repeat(1)@(posedge iSysClk);
    iActDataDistributeDone <= 1'b0;

    repeat(100)@(posedge iSysClk);
    iResultReturnDone      <= 1'b1;
    repeat(1)@(posedge iSysClk);
    iResultReturnDone <= 1'b0; //WGT config
    
  end

endtask




endmodule

