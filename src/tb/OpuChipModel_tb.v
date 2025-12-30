`timescale 1ns / 1ps

module tb_OpuChipModel;

    // =========================================================================
    // 1. 信号定义 & 参数设置
    // =========================================================================
    reg          sys_clk;
    reg          rst_n;
    reg  [7:0]   i_data;
    reg          i_data_valid;

    wire         o_pk_fail;
    wire         o_ready;
    wire         o_data_valid;
    wire [7:0]   o_data;

    // 参数定义
    parameter CLK_PERIOD = 10;      // 100MHz 时钟
    parameter DATA_LEN   = 24;      // 输入数据长度 
    parameter OUT_LEN    = 8;       // 输出数据周期 [cite: 5]

    // 用于存储测试向量的数组
    reg [7:0] send_data_mem [0:DATA_LEN-1];
    reg [7:0] recv_data_mem [0:OUT_LEN-1];
    
    integer i;

    // =========================================================================
    // 2. 模块例化 (DUT) [cite: 3]
    // =========================================================================
    OpuChipModel u_dut (
        .iSysClk    (sys_clk),
        .iRst_N     (rst_n),
        .iData      (i_data),
        .iDataValid (i_data_valid),
        .oPkFail    (o_pk_fail),
        .oReady     (o_ready),
        .oDataValid (o_data_valid),
        .oData      (o_data)
    );

    // =========================================================================
    // 3. 时钟与复位生成
    // =========================================================================
    initial begin
        sys_clk = 0;
        forever #(CLK_PERIOD/2) sys_clk = ~sys_clk;
    end

    initial begin
        rst_n = 1;
        #20;
        rst_n = 0;
        i_data = 0;
        i_data_valid = 0;
        #80;
        rst_n = 1; // 释放复位
        #50;
    end

    // =========================================================================
    // 4. 主测试流程
    // =========================================================================
    initial begin
        // 等待复位完成
        @(posedge rst_n);
        #100;

        $display("========================================");
        $display("Starting OpuChipModel Verification");
        $display("========================================");

        // --- Test Case 1: 发送标准数据包 ---
        
        // 4.1 准备随机数据 
        for(i = 0; i < DATA_LEN; i = i + 1) begin
            send_data_mem[i] = $random % 256;
        end

        // 4.2 等待芯片就绪 (IDLE state) [cite: 7]
        wait(o_ready == 1);
        $display("[%t] Module Ready. Starting Transaction...", $time);

        // 4.3 发送数据 (GET state) [cite: 11]
        @(posedge sys_clk);
        i_data_valid = 1;
        
        for(i = 0; i < DATA_LEN; i = i + 1) begin
            i_data = send_data_mem[i];
            // 打印部分发送数据
            if (i < 4) $display("[%t] Sending Byte %0d: %h", $time, i, i_data);
            @(posedge sys_clk);
        end

        // 4.4 结束发送，进入处理阶段 (PROCESS state) 
        i_data_valid = 0;
        i_data = 8'h00;
        
        // 检查 oReady 是否拉低 (表示进入非空闲状态) 
        #1; 
        if(o_ready == 0) 
            $display("[%t] Check OK: oReady went LOW (Processing Started).", $time);
        else 
            $display("[%t] Error: oReady should be LOW during processing!", $time);

        // 4.5 等待输出有效 (OUT state) 
        $display("[%t] Waiting for Output...", $time);
        wait(o_data_valid == 1);
        $display("[%t] Data Output Valid Detected.", $time);

        // 4.6 接收输出数据
        // 监测 oDataValid 保持高电平期间的数据
        i = 0;
        while(o_data_valid && i < OUT_LEN) begin
            // 在时钟上升沿采样
            // 注意：因为Testbench时钟和DUT同步，建议延时采样或非阻塞赋值观察
            recv_data_mem[i] = o_data; 
            $display("[%t] Received Output [%0d]: %h", $time, i, o_data);
            i = i + 1;
            @(posedge sys_clk);
            #1; // 微小延时以获取更新后的 oDataValid
        end

        // 4.7 检查回到 IDLE 状态 [cite: 22]
        #50;
        if(o_ready == 1 && o_data_valid == 0)
            $display("[%t] Transaction Complete. Module returned to IDLE.", $time);
        else
            $display("[%t] Error: Module did not return to IDLE correctly.", $time);

        $display("========================================");
        $display("Test Finished");
        $stop;
    end

    // =========================================================================
    // 5. 超时保护 (防止状态机死锁)
    // =========================================================================
    initial begin
        #10000;
        $display("[%t] Testbench Timeout! Simulation force stopped.", $time);
        $finish;
    end

endmodule