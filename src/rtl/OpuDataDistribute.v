//////////////////////////////////////////////////////////////////////////////////
// Company: DSMART
// Engineer: MYH
// 
// Create Date: 2025/12/10 
// Design Name: OPU_top
// Module Name: OpuDataDistribute
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

module OpuDataDistribute (
  // control
  input iSysClk,
  input iRst_N,

  // with OpuStateCtrl
  input iWgtConfigStart,
  input iInferStart,
  input [32:0] iReadAddr,
  input [15:0] iLength_r,

  output reg oDp2OpuHS, // handshake success PULSE signal
  //output reg oDataDistributeDone, // finish data distribute PUlSE signal
  output reg oWgtDataDistributeDone,
  output reg oActDataDistributeDone,


  // with top module
  input dp2opu_done,
  input dp2opu_ready,
  input dp2opu_idle,
  output dp2opu_start,
  output [32:0] dp2opu_addr,
  output [15:0] length_r,

  output     stream_out_TREADY,
  input      stream_out_TVALID,
  input [127:0] stream_out_TDATA,

  // with 9 OpuModelTop
  input  wire [ 8:0] iReady,            // 9个就绪信号
  output reg  [ 8:0] oDataValid,        // 9个数据有效信号
  output reg  [71:0] oData             // 9x8位数据，打包成72位总线


);


// important done signals
wire WgtDistributeDone;
wire ActDistributeDone;

// FSM state params
localparam P_IDLE        = 2'd0;
localparam P_WGT_CONFIG  = 2'd1;
localparam P_NET_INFER   = 2'd2;

reg [1:0] fsmCurState,fsmNxtState;

// state transition
always @(*) begin
  case (fsmCurState)
    P_IDLE:       fsmNxtState = (iWgtConfigStart)   ? P_WGT_CONFIG : ((iInferStart)? P_NET_INFER : P_IDLE) ;
    P_WGT_CONFIG: fsmNxtState = (WgtDistributeDone) ? P_IDLE       : P_WGT_CONFIG;
    P_NET_INFER:  fsmNxtState = (ActDistributeDone) ? P_IDLE       : P_NET_INFER ;
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


// handshake with DataProcessor
//// Further use Vivado BRAM IP to work as a data buffer storing Wgt or Act
reg [128-1:0] TempDataBuffer [`WgtDataLength-1:0];  
reg [15:0] wTempDataAddr;
reg [15:0] rTempDataAddr;

always @ (posedge iSysClk or negedge iRst_N) begin
  if (!iRst_N) begin
    wTempDataAddr <= 'b0;
  end
  else if (fsmCurState == P_IDLE) begin                           //感觉这行改成==
    // when get into WGT_CONFIG or NET_INFER
    wTempDataAddr <= 'b0;
  end
  else if (stream_out_TREADY && stream_out_TVALID) begin
    wTempDataAddr <= wTempDataAddr + 1'b1;
  end 
end


always @ (posedge iSysClk or negedge iRst_N) begin
  if (stream_out_TREADY && stream_out_TVALID) begin
    TempDataBuffer[wTempDataAddr] <= stream_out_TDATA; 
  end
end

// TempDataBuffer 128bit -> every OPU_top's 8bit interface
reg  [3:0] SingleSendCNT;
wire [127:0] SendData128b;


always @(posedge iSysClk or negedge iRst_N) begin
  if (!iRst_N) begin
    SingleSendCNT <= 'b0;
  end
  else if ((fsmCurState!=P_IDLE) && (iReady==9'b1_1111_1111)) begin            //感觉此处添加一个条件，wTempDataAddr ！= 0 ，可以保证读数的时候存储不为空
    SingleSendCNT <= SingleSendCNT + 1'b1;
  end
  else if (SingleSendCNT == 4'd15) begin
    SingleSendCNT <= 'b0;
  end
end

assign SendData128b = TempDataBuffer[rTempDataAddr];

always @(posedge iSysClk or negedge iRst_N) begin
  if (!iRst_N) begin
    rTempDataAddr <= 'b0;
  end
  else if ((fsmCurState == P_WGT_CONFIG)&&(rTempDataAddr==`WgtDataLength-1)&&(SingleSendCNT == 4'd15)) begin
    rTempDataAddr <= 'b0;
  end
  else if ((fsmCurState == P_NET_INFER)&&(rTempDataAddr==`SampleDataLength-1)&&(SingleSendCNT == 4'd15)) begin
    rTempDataAddr <= 'b0;
  end
  else if (SingleSendCNT == 4'd15) begin
  // all 128bit data has been transfered to opu_top(s)
  rTempDataAddr <= rTempDataAddr + 1'b1;
  end
end

// Act Data tranfer
// 给每个OPU依次发送所有的激励值！！！
reg [3:0] ActTransOpuIndex; // means which opu is receiving Act Data

// always @(posedge iSysClk or negedge iRst_N) begin                            //感觉每个条件都改为（192的整数倍减一）&& SingleSendCNT==15
//   if (!iRst_N) begin
//     ActTransOpuIndex <= 'b0;
//   end
//   else if (rTempDataAddr==16'd192) begin
//     ActTransOpuIndex <= 4'd1;
//   end
//   else if (rTempDataAddr==16'd384) begin
//     ActTransOpuIndex <= 4'd2;
//   end
//   else if (rTempDataAddr==16'd576) begin
//     ActTransOpuIndex <= 4'd3;
//   end
//   else if (rTempDataAddr==16'd768) begin
//     ActTransOpuIndex <= 4'd4;
//   end
//   else if (rTempDataAddr==16'd960) begin
//     ActTransOpuIndex <= 4'd5;
//   end
//   else if (rTempDataAddr==16'd1152) begin
//     ActTransOpuIndex <= 4'd6;
//   end
//   else if (rTempDataAddr==16'd1344) begin
//     ActTransOpuIndex <= 4'd7;
//   end
//   else if (rTempDataAddr==16'd1536) begin
//     ActTransOpuIndex <= 4'd8;
//   end
//   else if (rTempDataAddr>=16'd1728) begin
//     ActTransOpuIndex <= 4'd0;
//   end
// end

always @(posedge iSysClk or negedge iRst_N) begin                            
  if (!iRst_N) begin
    ActTransOpuIndex <= 'b0;
  end
  else if ((rTempDataAddr == 16'd191) && (SingleSendCNT == 4'd15)) begin
    ActTransOpuIndex <= 4'd1;
  end
  else if ((rTempDataAddr == 16'd383) && (SingleSendCNT == 4'd15)) begin
    ActTransOpuIndex <= 4'd2;
  end
  else if ((rTempDataAddr == 16'd575) && (SingleSendCNT == 4'd15)) begin
    ActTransOpuIndex <= 4'd3;
  end
  else if ((rTempDataAddr == 16'd767) && (SingleSendCNT == 4'd15)) begin
    ActTransOpuIndex <= 4'd4;
  end
  else if ((rTempDataAddr == 16'd959) && (SingleSendCNT == 4'd15)) begin
    ActTransOpuIndex <= 4'd5;
  end
  else if ((rTempDataAddr == 16'd1151) && (SingleSendCNT == 4'd15)) begin
    ActTransOpuIndex <= 4'd6;
  end
  else if ((rTempDataAddr == 16'd1343) && (SingleSendCNT == 4'd15)) begin
    ActTransOpuIndex <= 4'd7;
  end
  else if ((rTempDataAddr == 16'd1535) && (SingleSendCNT == 4'd15)) begin
    ActTransOpuIndex <= 4'd8;
  end
  else if (rTempDataAddr >= 16'd1728) begin
    ActTransOpuIndex <= 4'd0;
  end
end

// handshake with 9 OPUs


always @(posedge iSysClk or negedge iRst_N) begin
  if(!iRst_N) begin
    oData <= 'b0;
  end
  else if ((fsmCurState==P_WGT_CONFIG) && (iReady==9'b1_1111_1111)) begin              //改成9？ 感觉应该配合128行wTempDataAddr ！= 0 
    // when all OPU_tops are ready, send them equal data
    case (SingleSendCNT)
      4'd0:    oData <= {9{SendData128b[    7:0]}};
      4'd1:    oData <= {9{SendData128b[   15:8]}};
      4'd2:    oData <= {9{SendData128b[  23:16]}};
      4'd3:    oData <= {9{SendData128b[  31:24]}};
      4'd4:    oData <= {9{SendData128b[  39:32]}};
      4'd5:    oData <= {9{SendData128b[  47:40]}};
      4'd6:    oData <= {9{SendData128b[  55:48]}};
      4'd7:    oData <= {9{SendData128b[  63:56]}};
      4'd8:    oData <= {9{SendData128b[  71:64]}};
      4'd9:    oData <= {9{SendData128b[  79:72]}};
      4'd10:   oData <= {9{SendData128b[  87:80]}};
      4'd11:   oData <= {9{SendData128b[  95:88]}};
      4'd12:   oData <= {9{SendData128b[ 103:96]}};
      4'd13:   oData <= {9{SendData128b[111:104]}};
      4'd14:   oData <= {9{SendData128b[119:112]}};
      4'd15:   oData <= {9{SendData128b[127:120]}};
      default: oData <= 'b0;
    endcase

    oDataValid <= {9{1'b1}};                                          //感觉oDataValid信号需要有发完数据归零的逻辑。
  end
  else if ((fsmCurState==P_NET_INFER)&& (iReady==9'b1_1111_1111)) begin
    case (SingleSendCNT)
      4'd0:    oData <= {9{SendData128b[    7:0]}};
      4'd1:    oData <= {9{SendData128b[   15:8]}};
      4'd2:    oData <= {9{SendData128b[  23:16]}};
      4'd3:    oData <= {9{SendData128b[  31:24]}};
      4'd4:    oData <= {9{SendData128b[  39:32]}};
      4'd5:    oData <= {9{SendData128b[  47:40]}};
      4'd6:    oData <= {9{SendData128b[  55:48]}};
      4'd7:    oData <= {9{SendData128b[  63:56]}};
      4'd8:    oData <= {9{SendData128b[  71:64]}};
      4'd9:    oData <= {9{SendData128b[  79:72]}};
      4'd10:   oData <= {9{SendData128b[  87:80]}};
      4'd11:   oData <= {9{SendData128b[  95:88]}};
      4'd12:   oData <= {9{SendData128b[ 103:96]}};
      4'd13:   oData <= {9{SendData128b[111:104]}};
      4'd14:   oData <= {9{SendData128b[119:112]}};
      4'd15:   oData <= {9{SendData128b[127:120]}};
      default: oData <= 'b0;
    endcase
    
    oDataValid = (9'b0_0000_0001 << (ActTransOpuIndex));
  end
end


// dp2opu control output
//// dp2opu_start 
//// when fsm get into wgt_config or net_infer state, output 1 pulse
wire dp2opu_start_level;
reg  dp2opu_start_level_d1;

assign dp2opu_start_level = (fsmCurState!=P_IDLE);

always @(posedge iSysClk or negedge iRst_N) begin
  if (!iRst_N) begin
    dp2opu_start_level_d1 <= 'b0;
  end
  else begin
    dp2opu_start_level_d1 <= dp2opu_start_level;
  end
end

assign dp2opu_start = (~dp2opu_start_level_d1) & dp2opu_start_level;


assign dp2opu_addr = iReadAddr;
assign length_r    = iLength_r;

assign stream_out_TREADY = (fsmCurState!=P_IDLE)? 1'b1 : 1'b0;

always @(posedge iSysClk or negedge iRst_N) begin
  if (!iRst_N) begin
    oDp2OpuHS <= 1'b0;
  end
  else if (dp2opu_start) begin
    oDp2OpuHS <= 1'b1;
  end
  else begin
    oDp2OpuHS <= 1'b0;
  end
end


// done signal for WGT config or Net_infer
assign ActDistributeDone = ((fsmCurState == P_NET_INFER) &&(rTempDataAddr==`SampleDataLength-1)&&(SingleSendCNT == 4'd15));
assign WgtDistributeDone = ((fsmCurState == P_WGT_CONFIG)&&(rTempDataAddr==`WgtDataLength-1)   &&(SingleSendCNT == 4'd15));

always @ (*) begin
  oActDataDistributeDone = ActDistributeDone;
  oWgtDataDistributeDone = WgtDistributeDone;
end
  
endmodule
