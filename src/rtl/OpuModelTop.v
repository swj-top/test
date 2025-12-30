//////////////////////////////////////////////////////////////////////////////////
// Company: DSMART
// Engineer: MYH
// 
// Create Date: 2025/12/10 
// Design Name: OPU_top
// Module Name: OpuModelTop.v
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
module OpuModelTop (
  // control
  input iSysClk,
  input iRst_N, 

  // data interface
  input [7:0] iData,
  input iDataValid,
  output oReady,
  output oResultValid,
  output oResult
);


wire oChipReady;
wire oChipDataValid;
wire [7:0] oChipData;

OpuChipModel  u_OpuChipModel (
    .iSysClk                 ( iSysClk      ),
    .iRst_N                  ( iRst_N       ),
    .iData                   ( iData        ),
    .iDataValid              ( iDataValid   ),

    .oPkFail                 (              ),
    .oReady                  ( oChipReady   ),
    .oDataValid              ( oChipDataValid),
    .oData                   ( oChipData    )
);

assign oReady       = oChipReady;
assign oResultValid = oChipDataValid;
assign oResult      = oChipData[0];
 

endmodule