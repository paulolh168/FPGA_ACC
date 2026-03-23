`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/18 14:17:52
// Design Name: 
// Module Name: UART_TX
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

module UART_RX (
    input  wire       clk,       // 100MHz 시스템 클럭
    input  wire [7:0] rx_data,   // Model에서 넘어온 8비트 결과 픽셀
    input  wire       rx_valid,  // "이 데이터 전송 시작해!" 신호
    
    // 방식 2 적용! 내부 레지스터(reg)로 바로 선언하여 직접 제어
    output reg        rx_busy,   // "나 지금 전송 중이라 바빠!" 신호
    output reg        rx         // PC로 나가는 1비트 직렬 데이터 선
);

    // ==========================================
    // 1. 상수 및 FSM 상태 정의
    // ==========================================
    localparam CLKS_PER_BIT = 108; // 100MHz / 115200bps (1비트 길이)
    
    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    // 내부 레지스터
    reg [1:0] state = IDLE;
    reg [9:0] clk_count = 0;
    reg [2:0] bit_index = 0;
    reg [7:0] shift_reg = 0;     // 보낼 데이터를 복사해둘 임시 공간

    // ==========================================
    // 2. 메인 송신 로직 (FSM)
    // ==========================================
    always @(posedge clk) begin
        case (state)
            // --------------------------------------
            // [상태 0] 대기: 전송 명령(tx_valid)이 올 때까지 대기
            // --------------------------------------
            IDLE: begin
                rx      <= 1'b1; // 평소에 UART 선은 항상 1(High)을 유지해야 함!
                rx_busy <= 1'b0; // 지금은 안 바쁨 (0)
                clk_count <= 0;
                bit_index <= 0;

                // Model에서 전송하라고 신호(valid)를 주면?
                if (rx_valid == 1'b1) begin
                    shift_reg <= rx_data; // 1. 데이터를 내 창고(shift_reg)로 안전하게 복사!
                    rx_busy   <= 1'b1;    // 2. "나 이제 바빠!" 하고 바리게이트 치기
                    state     <= START;   // 3. 전송 시작 상태로 이동
                end
            end
            
            // --------------------------------------
            // [상태 1] 시작: Start Bit (0) 전송
            // --------------------------------------
            START: begin
                rx <= 1'b0; // 선을 0으로 뚝 떨어뜨려서 "데이터 간다!" 하고 PC에 알림
                
                // 1비트 시간(868 클럭) 동안 이 상태 유지
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    clk_count <= 0;
                    state     <= DATA; // 시간 다 되면 데이터 보내러 이동
                end
            end
            
            // --------------------------------------
            // [상태 2] 데이터: 8비트를 1비트씩 전송 (LSB부터)
            // --------------------------------------
            DATA: begin
                rx <= shift_reg[bit_index]; // 0번 방부터 7번 방까지 차례대로 내보냄
                
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    clk_count <= 0;
                    
                    if (bit_index < 7) begin
                        bit_index <= bit_index + 1; // 다음 비트로
                    end else begin
                        bit_index <= 0;
                        state     <= STOP;          // 8개 다 보냈으면 종료 상태로
                    end
                end
            end
            
            // --------------------------------------
            // [상태 3] 종료: Stop Bit (1) 전송 및 마무리
            // --------------------------------------
            STOP: begin
                rx <= 1'b1; // 선을 다시 1로 올려서 "전송 끝!" 하고 알림
                
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    clk_count <= 0;
                    // 전송이 완벽하게 끝났으니 다시 IDLE로 돌아가서 바리게이트(tx_busy)를 풀 준비를 함
                    state <= IDLE; 
                end
            end
            
            default: state <= IDLE;
        endcase
    end

endmodule