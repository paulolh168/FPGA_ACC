`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/24 02:35:30
// Design Name: 
// Module Name: BRAM2
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


// 출력용 FIFO 버퍼 모듈
module BRAM2 #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 11 // 2^11 = 2048칸 (768바이트를 담기에 충분함)
)(
    input  wire                  clk,
    
    // 쓰기 포트 (Model이 연산 직후 데이터를 집어넣음)
    input  wire                  we,
    input  wire [DATA_WIDTH-1:0] din,
    
    // 읽기 포트 (TX가 한가할 때 데이터를 빼감)
    input  wire                  re,
    output reg  [DATA_WIDTH-1:0] dout,
    
    // 상태 플래그
    output wire                  empty // 1이면 버퍼가 비어있다는 뜻
);

    (* ram_style = "block" *) 
    reg [DATA_WIDTH-1:0] ram [0:(1<<ADDR_WIDTH)-1];
    
    reg [ADDR_WIDTH-1:0] wr_ptr = 0; // 쓰는 위치
    reg [ADDR_WIDTH-1:0] rd_ptr = 0; // 읽는 위치

    // 두 포인터가 같은 위치를 가리키면 텅 빈 상태이다.
    assign empty = (wr_ptr == rd_ptr); 

    // 1. 쓰기 동작 (들어오는 즉시 저장)
    always @(posedge clk) begin
        if (we) begin
            ram[wr_ptr] <= din;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // 2. 읽기 동작 (빼갈 때만 주소 이동)
    always @(posedge clk) begin
        if (re && !empty) begin
            dout <= ram[rd_ptr];
            rd_ptr <= rd_ptr + 1;
        end
    end

endmodule