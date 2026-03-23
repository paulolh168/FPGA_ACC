`timescale 1ns / 1ps

module UART_TX (
    input  wire       clk,      // 100MHz 시스템 클럭
    input  wire       tx,       // PC에서 들어오는 1비트 직렬 데이터 선
    output reg  [7:0] tx_data,  // 조립 완료된 8비트 픽셀 데이터
    output reg        tx_valid  // "데이터 1바이트 다 조립했어!" 신호
);

    // ==========================================
    // 1. 상수 및 FSM 상태 정의
    // ==========================================
    // 100MHz / 115200bps = 약 868 클럭 (1비트 길이)
    localparam CLKS_PER_BIT = 108; 
    
    // FSM 상태 (State)
    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    // 내부 레지스터 선언
    reg [1:0] state = IDLE;
    reg [9:0] clk_count = 0;    // 868까지 세는 타이머
    reg [2:0] bit_index = 0;    // 8비트 중 몇 번째 비트인지 (0~7)
    reg [7:0] shift_reg = 0;    // 1비트씩 찰칵찰칵 조립할 임시 공간

    // ==========================================
    // 2. 메인 수신 로직 (FSM)
    // ==========================================
    always @(posedge clk) begin
        
        // 기본적으로 valid는 0 유지 (1클럭만 튕기기 위함)
        tx_valid <= 1'b0;

        case (state)
            // --------------------------------------
            // [상태 0] 대기: 선이 0(Start Bit)으로 떨어질 때까지 감시
            // --------------------------------------
            IDLE: begin
                clk_count <= 0;
                bit_index <= 0;
                if (tx == 1'b0) begin  // 선이 0으로 떨어지면 시작!
                    state <= START;
                end
            end
            
            // --------------------------------------
            // [상태 1] 시작 확인: 진짜 시작인지 노이즈인지 확인
            // --------------------------------------
            START: begin
                // 비트 길이의 딱 '절반(434)' 지점까지 기다림
                if (clk_count == (CLKS_PER_BIT / 2)) begin
                    if (tx == 1'b0) begin // 여전히 0이면 진짜 시작!
                        clk_count <= 0;
                        state     <= DATA;
                    end else begin        // 아니면 노이즈였으니 돌아감
                        state     <= IDLE;
                    end
                end else begin
                    clk_count <= clk_count + 1; // 절반 올 때까지 타이머 증가
                end
            end
            
            // --------------------------------------
            // [상태 2] 데이터 수신: 8비트를 1비트씩 조립
            // --------------------------------------
            DATA: begin
                // 1비트 길이(868)만큼 기다림 (이전 상태에서 절반부터 셌으므로, 비트의 정중앙에서 계속 읽게 됨)
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    clk_count <= 0;
                    
                    // 정중앙 타이밍에 rx 선의 값을 읽어서 shift_reg에 넣음 (LSB부터 채움)
                    shift_reg[bit_index] <= tx; 
                    
                    // 8비트 다 채웠는지 확인
                    if (bit_index < 7) begin
                        bit_index <= bit_index + 1; // 다음 비트로
                    end else begin
                        bit_index <= 0;
                        state     <= STOP;          // 8개 다 모았으면 종료 상태로
                    end
                end
            end
            
            // --------------------------------------
            // [상태 3] 종료 및 완료 신호 발생
            // --------------------------------------
            STOP: begin
                // 마지막 Stop Bit(1) 길이만큼 기다림
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    // 완료! 조립된 데이터를 출력 포트에 넘겨주고 valid를 튕김
                    tx_data  <= shift_reg;
                    tx_valid <= 1'b1;
                    state    <= IDLE; // 다음 픽셀 받으러 대기
                end
            end
            
            default: state <= IDLE;
        endcase
    end

endmodule