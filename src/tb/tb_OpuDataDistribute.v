`timescale 1ns/1ps

`include "../define/OPU_top_define.v"

module tb_OpuDataDistribute();

// ====================== 1. 时钟/复位信号生成 ======================
reg         iSysClk;
reg         iRst_N;

// 时钟参数：100MHz（周期10ns）
parameter CLK_PERIOD = 10;

initial begin
    iSysClk = 1'b0;
    forever #(CLK_PERIOD/2) iSysClk = ~iSysClk;
end

// 复位：低复位，初始保持5个时钟周期
initial begin
    iRst_N = 1'b1;
    #(CLK_PERIOD/2);
    iRst_N = 1'b0;
    #(CLK_PERIOD*5);
    iRst_N = 1'b1;
end

// ====================== 2. DUT输入信号定义 ======================
// 控制信号（来自OpuStateCtrl）
reg         iWgtConfigStart;
reg         iInferStart;
reg [32:0]  iReadAddr;
reg [15:0]  iLength_r;

// 与top模块交互信号
reg         dp2opu_done;
reg         dp2opu_ready;
reg         dp2opu_idle;
reg         stream_out_TVALID;
reg [127:0] stream_out_TDATA;

// 9路OPU模拟信号
reg [8:0]   iReady;

// ====================== 3. DUT输出信号定义 ======================
wire        oDp2OpuHS;
wire        oWgtDataDistributeDone;
wire        oActDataDistributeDone;
wire        dp2opu_start;
wire [32:0] dp2opu_addr;
wire [15:0] length_r;
wire        stream_out_TREADY;
wire [8:0]  oDataValid;
wire [71:0] oData;

// ====================== 4. 内部监测/比对信号 ======================
// reg [127:0] exp_data [0:`WgtDataLength-1];  // 预期数据缓存
// reg [7:0]   exp_8bit_data;                  // 预期8bit数据
// reg [3:0]   exp_single_send_cnt;            // 预期SingleSendCNT
// reg [3:0]   exp_act_opu_index;              // 预期ActTransOpuIndex
reg         verify_flag;                    // 验证结果标志：1=通过，0=失败
reg [15:0]  data_cnt;                       // 数据下发计数

// ====================== 5. DUT例化 ======================
OpuDataDistribute u_OpuDataDistribute(
    .iSysClk(iSysClk),
    .iRst_N(iRst_N),

    .iWgtConfigStart(iWgtConfigStart),
    .iInferStart(iInferStart),
    .iReadAddr(iReadAddr),
    .iLength_r(iLength_r),

    .oDp2OpuHS(oDp2OpuHS),
    .oWgtDataDistributeDone(oWgtDataDistributeDone),
    .oActDataDistributeDone(oActDataDistributeDone),

    .dp2opu_done(dp2opu_done),
    .dp2opu_ready(dp2opu_ready),
    .dp2opu_idle(dp2opu_idle),
    .dp2opu_start(dp2opu_start),
    .dp2opu_addr(dp2opu_addr),
    .length_r(length_r),

    .stream_out_TREADY(stream_out_TREADY),
    .stream_out_TVALID(stream_out_TVALID),
    .stream_out_TDATA(stream_out_TDATA),

    .iReady(iReady),
    .oDataValid(oDataValid),
    .oData(oData)
);

// ====================== 6. 测试用例执行 ======================
initial begin
    // 初始化所有输入信号
    iWgtConfigStart    = 1'b0;
    iInferStart        = 1'b0;
    iReadAddr          = 33'd0;
    iLength_r          = 16'd0;
    dp2opu_done        = 1'b0;
    dp2opu_ready       = 1'b0;
    dp2opu_idle        = 1'b1;
    stream_out_TVALID  = 1'b0;
    stream_out_TDATA   = 128'd0;
    iReady             = 9'b0;
    verify_flag        = 1'b1;
    data_cnt           = 16'd0;

    // 等待复位释放
    @(posedge iRst_N);

    #(CLK_PERIOD*2);
  
    // 2.1 配置输入信号，触发权重配置
    iWgtConfigStart <= 1'b1;
    iReadAddr       <= `WgtBaseAddr;
    iLength_r       <= `WgtDataLength;
    //iReady          <= 9'b111111111;  // 9路OPU全就绪
    dp2opu_ready    <= 1'b1;
    #CLK_PERIOD;
    iWgtConfigStart <= 1'b0;  // 1拍脉冲

    // 2.2 生成递增测试数据并下发DDR数据
    fork
        // 线程1：下发128bit递增数据
        begin
            stream_out_TVALID <= 1'b1;
            for(data_cnt=0; data_cnt<`WgtDataLength; data_cnt=data_cnt+1) begin
                stream_out_TDATA <= {128{1'b0}} | data_cnt;  // 递增数据
                // exp_data[data_cnt] = stream_out_TDATA;       // 缓存预期数据
                @(posedge iSysClk);
                while(!stream_out_TREADY) @(posedge iSysClk);  // 等待模块就绪
            end
            stream_out_TVALID <= 1'b0;
        end

        begin
            #CLK_PERIOD;
            iReady          <= 9'b111111111;  // 9路OPU全就绪
        end
    join

    // 2.3 验证Done信号和状态机跳转
    @(posedge oWgtDataDistributeDone);
    #CLK_PERIOD;


    // 复位模块状态
    iReadAddr   <= 33'd0;
    iLength_r   <= 16'd0;
    iReady      <= 9'b0;
    dp2opu_ready <= 1'b0;
    #(CLK_PERIOD*5);

    // ====================== 测试用例3：网络推理（NET_INFER）功能验证 ======================
    $display("[%0t] 执行测试用例3：网络推理功能验证", $time);
    // 3.1 配置输入信号，触发推理
    iInferStart  <= 1'b1;
    iReadAddr    <= `SampleActBaseAddr;
    iLength_r    <= `SampleDataLength;
    //iReady       <= 9'b111111111;  // 9路OPU全就绪
    dp2opu_ready <= 1'b1;
    #CLK_PERIOD;
    iInferStart  <= 1'b0;  // 1拍脉冲

    // 3.2 生成递增测试数据并下发DDR数据
    fork
        // 线程1：下发128bit递增数据
        begin
            stream_out_TVALID <= 1'b1;
            for(data_cnt=0; data_cnt<`SampleDataLength; data_cnt=data_cnt+1) begin
                stream_out_TDATA <= {128{1'b0}} | data_cnt;  // 递增数据
                // exp_data[data_cnt] = stream_out_TDATA;       // 缓存预期数据
                @(posedge iSysClk);
                while(!stream_out_TREADY) @(posedge iSysClk);  // 等待模块就绪
            end
            stream_out_TVALID <= 1'b0;
        end

        // 线程2：监测数据分路正确性
        begin
            #CLK_PERIOD;
            iReady       <= 9'b111111111;  // 9路OPU全就绪
        end
    join




    // 3.3 验证Done信号和状态机跳转
    @(posedge oActDataDistributeDone);
    #CLK_PERIOD;
    if(u_OpuDataDistribute.fsmCurState != 2'd0 || oActDataDistributeDone != 1'b1) begin
        $error("[%0t] 推理Done信号验证失败", $time);
        verify_flag = 1'b0;
    end else begin
        $display("[%0t] 测试用例3通过", $time);
    end

    // 复位模块状态
    iReadAddr   <= 33'd0;
    iLength_r   <= 16'd0;
    iReady      <= 9'b0;
    dp2opu_ready <= 1'b0;
    #(CLK_PERIOD*5);

    // ====================== 测试用例4：异常场景验证（OPU未就绪） ======================
    $display("[%0t] 执行测试用例4：OPU未就绪异常验证", $time);
    // 4.1 触发权重配置，模拟1路OPU未就绪
    iWgtConfigStart <= 1'b1;
    iReadAddr       <= `WgtBaseAddr;
    iLength_r       <= `WgtDataLength;
    iReady          <= 9'b111111110;  // 第0路OPU未就绪
    dp2opu_ready    <= 1'b1;
    #CLK_PERIOD;
    iWgtConfigStart <= 1'b0;

    // 4.2 下发数据，监测SingleSendCNT是否停止
    stream_out_TVALID <= 1'b1;
    @(posedge u_OpuDataDistribute.fsmCurState == 2'd1);
    #(CLK_PERIOD*10);
    if(u_OpuDataDistribute.SingleSendCNT != 4'd0) begin
        $error("[%0t] OPU未就绪时SingleSendCNT未停止", $time);
        verify_flag = 1'b0;
    end

    // 4.3 恢复OPU就绪，验证分发继续
    iReady <= 9'b111111111;
    #(CLK_PERIOD*`WgtDataLength*16);  // 等待数据分发完成
    @(posedge oWgtDataDistributeDone);
    if(u_OpuDataDistribute.fsmCurState != 2'd0) begin
        $error("[%0t] OPU恢复就绪后未正常完成分发", $time);
        verify_flag = 1'b0;
    end else begin
        $display("[%0t] 测试用例4通过", $time);
    end

    // ====================== 验证总结 ======================
    #(CLK_PERIOD*10);
    if(verify_flag) begin
        $display("[%0t] 所有测试用例通过！", $time);
    end else begin
        $error("[%0t] 部分测试用例失败，请检查波形和日志", $time);
    end

    $finish;
end

endmodule