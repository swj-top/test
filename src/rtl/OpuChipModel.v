`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/12/13 21:17:10
// Design Name: 
// Module Name: OpuChipModel
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


module OpuChipModel(

    input           iSysClk,
    input           iRst_N,
    input [7:0]     iData,
    input           iDataValid,
    output          oPkFail,
    output          oReady,
    output          oDataValid,
    output [7:0]    oData

    );

    localparam IDLE     = 2'b00 ;
    localparam GET      = 2'b01 ;
    localparam PROCESS  = 2'b10 ;
    localparam OUT      = 2'b11 ;

    reg [1:0] state ;
    reg [1:0] next_state ;

    reg [7:0]   IN_DATA [0:23] ;
    reg [7:0]   OUT_DATA [0:7] ;
    reg [4:0]   IN_counter ;
    reg [4:0]   OUT_counter ;
    reg [4:0]   process_counter ;


    assign oReady = (state == OUT) ? 1'b0 : 1'b1 ;
    assign oDataValid = (state == OUT) ? 1'b1 : 1'b0 ;
    assign oData = OUT_DATA[OUT_counter] ;

    assign  oPkFail = 1'b0 ;

    wire done_process = process_counter == 5'd7 ;

    always @(posedge iSysClk or negedge iRst_N) begin
        if(!iRst_N) begin
            IN_counter <= 5'd0 ;
            OUT_counter <= 5'd0 ;
        end
        else if((state == IDLE && iDataValid) || (state == GET && iDataValid)) begin
            IN_DATA[IN_counter] <= iData ;
            IN_counter <= IN_counter + 1'b1 ;

        end
        else if(state == OUT ) begin
            OUT_counter <= OUT_counter + 1'b1 ;
        end
        else begin
            IN_counter <= 0 ;
            OUT_counter <= 0 ;
        end
    end

    always @(posedge iSysClk or negedge iRst_N) begin
        if(!iRst_N) begin
            process_counter <= 0 ;
        end
        else if((state == PROCESS) || (state == GET && next_state == PROCESS)) begin
            OUT_DATA[process_counter] <= process_counter ;
            process_counter <= process_counter + 1'b1 ;
        end
        else begin
            process_counter <= 0 ;
        end
    end


    always @(posedge iSysClk or negedge iRst_N) begin
        if(!iRst_N) begin
            state <= IDLE ;
        end
        else begin
            state <= next_state ;
        end

    end

    always @(*) begin

        case(state)
            IDLE: begin
                if(iDataValid) begin
                    next_state = GET ;
                end
                else begin
                    next_state = IDLE ;
                end
            end

            GET: begin
                if(IN_counter == 5'd23) begin
                    next_state = PROCESS ;
                end
                else begin
                    next_state = GET ;
                end
            end

            PROCESS: begin
                if (done_process) begin
                     next_state = OUT ;
                    
                end
                else begin
                    next_state = PROCESS ;
                end
               
            end

            OUT: begin
                if(OUT_counter == 5'd7) begin
                    next_state = IDLE ;

                end
                else begin
                    next_state = OUT ;
                end
            end

            default: begin
                next_state = IDLE ;
            end

        endcase
        
    end












endmodule
