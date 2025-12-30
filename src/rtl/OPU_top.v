//////////////////////////////////////////////////////////////////////////////////
// Company: DSMART
// Engineer: MYH
// 
// Create Date: 2025/12/10 
// Design Name: OPU_top
// Module Name: OPU_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module OPU_top (
  // control
  input iSysClk,
  input iRst_N,
  input [31:0] iOperation, // from eth clk to iSysClk
  input [31:0] iBatchNum,  // from eth clk to iSysClk

  // with dp2opu
  input dp2opu_done,
  input dp2opu_ready,
  input dp2opu_idle,
  output dp2opu_start,
  output [32:0] dp2opu_addr,
  output [15:0] length_r,

  output  stream_out_TREADY,
  input  stream_out_TVALID,
  input [127:0] stream_out_TDATA,

  // with opu2dp
  input opu2dp_done,
  input opu2dp_ready,
  input opu2dp_idle,
  output opu2dp_start,
  output [32:0] opu2dp_addr,
  output [15:0] length_w,

  input  stream_in_TVALID,
  output  stream_in_TREADY,
  output [127:0] stream_in_TDATA

);
//------------------------------------Wire and Reg--------------------------------------------//

// OpuStateCtrl Outputs
wire  oReady;
wire  oWgtConfigStart;
wire  oInferStart;
wire  [32:0]  oReadAddr;
wire  [32:0]  oWriteAddr;
wire  [15:0]  oLength_r;
wire  [15:0]  oLength_w;

// OpuDataDistribute Outputs
wire  [ 8:0]  oChipsReady;      
wire  [ 8:0]  oChipsDataValid;  
wire  [71:0]  oChipsData;

// NineOpuModelTop Outputs
wire  [ 8:0]  oResultValid;
wire  [ 8:0]  oResult;     




////////////////////////////////////////////////////////////////////////////////////////////////


//------------------------------------Instance--------------------------------------------//

// OpuStateCtrl.v
OpuStateCtrl  u_OpuStateCtrl (
  .iSysClk                 ( iSysClk           ),
  .iRst_N                  ( iRst_N            ),
  .iOperation              ( iOperation        ),
  .iBatchNum               ( iBatchNum         ),

  .oReady                  ( oReady            ),
  .oWgtConfigStart         ( oWgtConfigStart   ),
  .oInferStart             ( oInferStart       ),
  .oReadAddr               ( oReadAddr         ),
  .oWriteAddr              ( oWriteAddr        ),
  .length_r                ( oLength_r          ),
  .length_w                ( oLength_w          )
);

// OpuDataDistribute.v
OpuDataDistribute  u_OpuDataDistribute (
  .iSysClk                 ( iSysClk             ),
  .iRst_N                  ( iRst_N              ),
  .iWgtConfigStart         ( oWgtConfigStart     ),
  .iInferStart             ( oInferStart         ),
  .iReadAddr               ( oReadAddr           ),
  .iLength_r               ( oLength_r           ),
  .dp2opu_done             ( dp2opu_done         ),
  .dp2opu_ready            ( dp2opu_ready        ),
  .dp2opu_idle             ( dp2opu_idle         ),
  .stream_out_TREADY       ( stream_out_TREADY   ),


  .dp2opu_start            ( dp2opu_start        ),
  .dp2opu_addr             ( dp2opu_addr         ),
  .length_r                ( length_r            ),
  .stream_out_TVALID       ( stream_out_TVALID   ),
  .stream_out_TDATA        ( stream_out_TDATA    ),
  .iReady                  ( oChipsReady         ),
  .oDataValid              ( oChipsDataValid     ),
  .oData                   ( oChipsData          )
);

// NineOpuModelTop.v
NineOpuModelTop  u_NineOpuModelTop (
  .iSysClk                 ( iSysClk        ),
  .iRst_N                  ( iRst_N         ),
  .iData                   ( oChipsData     ),
  .iDataValid              ( oChipsDataValid),

  .oReady                  ( oChipsReady    ),
  .oResultValid            ( oResultValid   ),
  .oResult                 ( oResult        )
);

// OpuClassifyReturn.v
OpuClassifyReturn  u_OpuClassifyReturn (
  .iSysClk                 ( iSysClk            ),
  .iRst_N                  ( iRst_N             ),
  .iInferStart             ( oInferStart        ),
  .iWriteAddr              ( oWriteAddr         ),
  .iLength_w               ( oLength_w          ),
  .opu2dp_done             ( opu2dp_done        ),
  .opu2dp_ready            ( opu2dp_ready       ),
  .opu2dp_idle             ( opu2dp_idle        ),
  .stream_in_TVALID        ( stream_in_TVALID   ),

  .opu2dp_start            ( opu2dp_start       ),
  .opu2dp_addr             ( opu2dp_addr        ),
  .length_w                ( length_w           ),
  .stream_in_TREADY        ( stream_in_TREADY   ),
  .stream_in_TDATA         ( stream_in_TDATA    ),

  .iResultValid            ( oResultValid       ),
  .iResult                 ( oResult            )
);

////////////////////////////////////////////////////////////////////////////////////////////

endmodule