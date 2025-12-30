//////////////////////////////////////////////////////////////////////////////////
// Company: DSMART
// Engineer: MYH
// 
// Create Date: 2025/12/10 
// Design Name: OPU_top
// Module Name: OpuClassifyReturn
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

module OpuClassifyReturn (
  // control
  input iSysClk,
  input iRst_N,

  // with OpuStateCtrl
  input iInferStart,
  input [32:0] iWriteAddr,
  input [15:0] iLength_w,
  output reg  oResultReturnDone,

  // with other modules
  input opu2dp_done,
  input opu2dp_ready,
  input opu2dp_idle,
  output reg    opu2dp_start,
  output [32:0] opu2dp_addr,
  output [15:0] length_w,
  input  stream_in_TVALID,
  output  stream_in_TREADY,
  output [127:0] stream_in_TDATA,

  // with 9 OpuModelTop
  input [8:0] iResultValid,
  input [8:0] iResult
);

// FSM state params
localparam P_IDLE        = 2'd0;
localparam P_RES_OUT     = 2'd1;


reg [1:0] fsmCurState,fsmNxtState;

// state transition
always @(*) begin
  case (fsmCurState)
    P_IDLE:       fsmNxtState = (iInferStart      )? P_RES_OUT : P_IDLE;
    P_RES_OUT:    fsmNxtState = (oResultReturnDone)? P_IDLE    : P_RES_OUT;
    default:      fsmNxtState = P_IDLE; 
  endcase  
end 

// state transfer
always @(posedge iSysClk or negedge iRst_N) begin
  if(!iRst_N) begin
    fsmCurState <= P_IDLE;
  end else begin
    fsmCurState <= fsmNxtState;
  end
end

// recieve 9 OpuModelTops' outputs
reg [8:0] ResOutBuffer; // store result
reg [8:0] ResOutFlag;   // ->1 when result successfully outputs
wire      AllResOutSucc;

genvar OpuIndex;

generate
  for(OpuIndex=0;OpuIndex<9;OpuIndex=OpuIndex+1) begin:ResOutBufferWritingLoop
    always@(posedge iSysClk or negedge iRst_N) begin
      if(!iRst_N) begin
        ResOutBuffer[OpuIndex] <= 1'b0;
        ResOutFlag[OpuIndex]   <= 1'b0;
      end
      else if (fsmCurState == P_IDLE) begin
        // clear after outputs
        ResOutBuffer[OpuIndex] <= 1'b0;
        ResOutFlag[OpuIndex]   <= 1'b0;
      end
      else if (fsmCurState == P_RES_OUT && iResultValid[OpuIndex]==1) begin
        // wait and recieve corresponding outputs
        ResOutBuffer[OpuIndex] <= iResult[OpuIndex];
        ResOutFlag[OpuIndex]   <= 1'b1;
      end
    end

  end

endgenerate

assign AllResOutSucc = (ResOutFlag==9'b1_1111_1111); 



// output 
always@(posedge iSysClk or negedge iRst_N) begin
  if(!iRst_N) begin
    oResultReturnDone <= 1'b0;
  end
  else if (AllResOutSucc) begin
    oResultReturnDone <= 1'b1;
  end
  else begin
    oResultReturnDone <= 1'b0;
  end
end


// opu2dp control output
//// opu2dp_start
//// when all result is collected start outputs
always@(posedge iSysClk or negedge iRst_N) begin
  if(!iRst_N) begin
    opu2dp_start <= 1'b0;
  end
  else if (AllResOutSucc) begin
    opu2dp_start <= 1'b1;
  end
  else begin
    opu2dp_start <= 1'b0;
  end

end

assign opu2dp_addr = iWriteAddr;
assign length_w    = iLength_w ;

assign stream_in_TREADY = (AllResOutSucc)?1'b1:1'b0;

assign stream_in_TDATA  = {ResOutBuffer[7:0],ResOutBuffer[8],127'd0}; 

  
endmodule