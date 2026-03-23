`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/18 14:17:52
// Design Name: 
// Module Name: BRAM
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

// Simple Dual-Port BRAM 모듈 (포트 A는 쓰기 전용, 포트 B는 읽기 전용)
module BRAM #(
    parameter DATA_WIDTH = 8,      // 1픽셀 = 8비트(1바이트)
    parameter ADDR_WIDTH = 11      // 2^11 = 2048 (가로 768픽셀 2줄을 담기에 충분한 크기!)
)(
    input  wire                  clk,
    
    // 포트 A : 쓰기 전용 (UART_RX에서 들어오는 픽셀을 저장)
    input  wire                  we_a,   // 쓰기 허용 신호 (Write Enable)
    input  wire [ADDR_WIDTH-1:0] addr_a, // 쓸 주소
    input  wire [DATA_WIDTH-1:0] din_a,  // 쓸 데이터 (입력 픽셀)
    
    // 포트 B : 읽기 전용 (Model에서 윗줄 픽셀을 꺼내볼 때 사용)
    input  wire [ADDR_WIDTH-1:0] addr_b, // 읽을 주소
    output reg  [DATA_WIDTH-1:0] dout_b  // 읽은 데이터 (출력 픽셀)
);

    // BRAM 메모리 배열 선언 (2048칸짜리 8비트 배열)
    (* ram_style = "block" *) // Vivado에게 "이건 진짜 BRAM으로 만들어!"라고 강제 명령
    reg [DATA_WIDTH-1:0] ram [0:(1<<ADDR_WIDTH)-1];

    // 포트 A: 쓰기 동작
    always @(posedge clk) begin
        if (we_a) begin
            ram[addr_a] <= din_a;
        end
    end

    // 포트 B: 읽기 동작
    always @(posedge clk) begin
        dout_b <= ram[addr_b]; // 주소에 있는 값을 꺼내서 출력
    end

endmodule