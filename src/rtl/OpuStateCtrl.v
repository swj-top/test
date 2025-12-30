//////////////////////////////////////////////////////////////////////////////////
// Company: DSMART
// Engineer: MYH
// 
// Create Date: 2025/12/10 
// Design Name: OPU_top
// Module Name: OpuStateCtrl
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
`include "../define/OPU_top_define.v"

module OpuStateCtrl (
  // control
  input iSysClk,
  input iRst_N,
  input [31:0] iOperation, 
  input [31:0] iBatchNum,  

  // DDR
  input iDDRbusy,

  // with other modules
  input  iDp2OpuHS, // handshake success of OpuDataDistribute with dp
  input  iWgtDataDistributeDone,
  input  iActDataDistributeDone,
  input  iOpu2DpHS, // handshake success of OpuClassifyReturn with dp
  input  iResultReturnDone,

  output reg oReady,
  output reg oWgtConfigStart,
  output reg oInferStart,
  output reg [32:0] oReadAddr,
  output reg [32:0] oWriteAddr,
  output reg [15:0] length_r,
  output reg [15:0] length_w

);

// important ctrl signal
wire iDataDistributeDone;
assign iDataDistributeDone = iWgtDataDistributeDone | iActDataDistributeDone;


// OpuTop state params
// NEED TO figure out BIT DESIGN of iOperation[31:27] !!!!
localparam P_IDLE_BIT     = 4'h0;
localparam P_WGT_BIT      = 4'h1;
localparam P_CAL_BIT      = 4'h2;

// FSM state params
localparam P_IDLE        = 2'd0;
localparam P_WGT_CONFIG  = 2'd1;
localparam P_NET_INFER   = 2'd2;

reg [1:0] fsmCurState,fsmNxtState;

// Add CNT for Net Inference Addr control (max 500 figs)
// usually there is only 1 time WGT config

reg [8:0]  NetInferCNT;
reg [32:0] ReadAddrSum;
reg [8:0] ResReturnCNT;

always @(posedge iSysClk or negedge iRst_N ) begin
  if (!iRst_N) begin
    NetInferCNT <= 'd0;
  end
  else if (iActDataDistributeDone) begin
    NetInferCNT <= NetInferCNT + 1'b1;
  end
  else if ((NetInferCNT == 33'd499)&&iActDataDistributeDone) begin
    NetInferCNT <= 'd0;
  end
end

always @(posedge iSysClk or negedge iRst_N ) begin
  if (!iRst_N) begin
    ReadAddrSum <= 'd0;
  end
  else if (iActDataDistributeDone) begin
    ReadAddrSum <= ReadAddrSum + `SampleBlockByteSize;
  end
  else if ((NetInferCNT == 33'd499)&&iActDataDistributeDone) begin
    ReadAddrSum <= 'd0;
  end
end


always @(posedge iSysClk or negedge iRst_N ) begin
  if (!iRst_N) begin
    ResReturnCNT <= 'd0;
  end
  else if (iResultReturnDone) begin
   ResReturnCNT <= ResReturnCNT + 1'b1;
  end
  else if (ResReturnCNT == 33'd499 && iActDataDistributeDone ) begin
   ResReturnCNT <= 'd0;
  end
end




// OPU state ctrl
reg  [31:0] iBatchNumReg;
reg  [31:0] iOperationReg;
wire [ 4:0] OpuState;

always @ (posedge iSysClk or negedge iRst_N) begin
  if(!iRst_N) begin
    iBatchNumReg <= 32'b0;
  end else begin
    iBatchNumReg <= iBatchNum;
  end
end

always @ (posedge iSysClk or negedge iRst_N) begin
  if(!iRst_N) begin
    iOperationReg <= 32'b0;
  end else begin
    iOperationReg <= iOperation;
  end
end

assign OpuState = iOperationReg[31:27];






// state transition
always @(*) begin
  case (fsmCurState)
    P_IDLE:       fsmNxtState = (OpuState[P_WGT_BIT] && (~iDDRbusy))?  P_WGT_CONFIG  :  ((OpuState[P_CAL_BIT] && (~iDDRbusy))?  P_NET_INFER : P_IDLE);
    P_WGT_CONFIG: fsmNxtState = (iDataDistributeDone)?  P_IDLE        :  P_WGT_CONFIG; 
    P_NET_INFER:  fsmNxtState = (iDataDistributeDone)?  P_IDLE        :  P_NET_INFER; 
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

// output ctrl
always @(*) begin
  case (fsmCurState)
    P_IDLE:begin
      oReady          = 1'b1;
      oWgtConfigStart = 1'b0;
      oInferStart     = 1'b0;
      oReadAddr       = 33'b0;
      oWriteAddr      = 33'b0;
      length_r        = 12'b0;
      length_w        = 12'b0;
    end
    P_WGT_CONFIG:begin
      oReady          = 1'b0;
      oWgtConfigStart = 1'b1;
      oInferStart     = 1'b0;
      oReadAddr       = `WgtBaseAddr;
      oWriteAddr      = 33'b0;
      length_r        = `WgtDataLength;
      length_w        = 12'b0;
    end
    P_NET_INFER:begin
      oReady          = 1'b0;
      oWgtConfigStart = 1'b0;
      oInferStart     = 1'b1;
      oReadAddr       = `SampleActBaseAddr+ReadAddrSum;
      oWriteAddr      = `OpuResultBaseAddr+(ResReturnCNT<<1);
      length_r        = `SampleDataLength;
      length_w        = `OpuResultLength;

    end
    default:begin
    // WRONG CASE!!!
      oReady          = 1'b0;
      oWgtConfigStart = 1'b0;
      oInferStart     = 1'b0;
      oReadAddr       = 33'b0;
      oWriteAddr      = 33'b0;
      length_r        = 12'b0;
      length_w        = 12'b0;
    end 
  endcase
end


  
endmodule