//////////////////////////////////////////////////////////////////////////////////
// Company: DSMART
// Engineer: MYH
// 
// Create Date: 2025/12/10 
// Design Name: OPU_top
// Module Name: NineOpuModelTop.v
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
module NineOpuModelTop (
  // control
  input iSysClk,
  input iRst_N, 

  // data interface
  input  [71:0]   iData,
  input  [ 8:0]   iDataValid,
  output [ 8:0]   oReady,
  output [ 8:0]   oResultValid,
  output [ 8:0]   oResult
);

  genvar id;
  generate
    for(id=0;id<9;id=id+1) begin:OpuModelInstance
      OpuModelTop U_OpuModel_Top(
        .iSysClk      (iSysClk           ),
        .iRst_N       (iRst_N            ),
        .iData        (iData[8*id+7:8*id]),
        .iDataValid   (iDataValid[id]    ),
        .oReady       (oReady[id]        ),
        .oResultValid (oResultValid[id]  ),
        .oResult      (oResult[id]       )
      );
    end
  endgenerate

endmodule