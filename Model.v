`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/18 14:17:52
// Design Name: 
// Module Name: Model
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

/*
module Model(
    input  wire       clk,
    
    // TX 모듈(수신기)에서 '들어오는' 선 (PC -> FPGA)
    input  wire [7:0] tx_data,
    input  wire       tx_valid,
    
    // RX 모듈(송신기)로 '나가는' 선 (FPGA -> PC)
    output reg  [7:0] rx_data,
    output reg        rx_valid,
    input  wire       rx_busy
);

    // ==========================================
    // 1. BRAM2 (FIFO 버퍼) 연결용 선언
    // ==========================================
    wire       fifo_empty;
    wire [7:0] fifo_dout;
    reg        fifo_re = 0;

    // BRAM2 인스턴스화 (방금 만든 BRAM2.v를 여기서 불러옴)
    BRAM2 #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(11) // 2048칸 (가로 768픽셀을 담고도 텅텅 남음!)
    ) output_buffer (
        .clk(clk),
        .we(tx_valid),           // PC에서 데이터가 들어오면 무조건! 즉시! 쓴다
        .din(tx_data + 8'd1),    // 여기서 픽셀에 +1 연산을 해서 버퍼에 집어넣음
        .re(fifo_re),            // 읽기 명령 (꺼내갈 때 1로 켬)
        .dout(fifo_dout),        // BRAM2에서 튀어나오는 데이터
        .empty(fifo_empty)       // 버퍼가 텅 비었는지 확인하는 신호
    );

    // ==========================================
    // 2. 안전하게 버퍼에서 꺼내서 PC로 송신하는 로직 (FSM)
    // ==========================================
    localparam IDLE      = 2'd0;
    localparam WAIT_BRAM = 2'd1;
    localparam SEND      = 2'd2;
    localparam WAIT_TX   = 2'd3;

    reg [1:0] state = IDLE;

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                rx_valid <= 1'b0;
                // 버퍼에 물(데이터)이 있고, 송신기(UART)가 안 바쁘면?
                if (!fifo_empty && !rx_busy) begin
                    fifo_re <= 1'b1;       // "BRAM2야, 데이터 하나 내놔!"
                    state   <= WAIT_BRAM;
                end else begin
                    fifo_re <= 1'b0;
                end
            end

            WAIT_BRAM: begin
                // BRAM은 읽기 명령(re)을 주면 다음 클럭에 데이터를 뱉음
                fifo_re <= 1'b0;
                state   <= SEND;
            end

            SEND: begin
                // BRAM이 뱉어낸 데이터를 송신 모듈로 넘김
                rx_data  <= fifo_dout;
                rx_valid <= 1'b1; // "PC로 쏴라!" 신호 켬
                state    <= WAIT_TX;
            end

            WAIT_TX: begin
                rx_valid <= 1'b0; // valid 신호는 딱 1클럭만 주고 끔
                // 거북이(송신 모듈)가 86마이크로초 동안 전송을 다 끝낼 때까지 대기
                if (!rx_busy) begin
                    state <= IDLE; // 다 끝났으면 다시 물탱크(BRAM2) 확인하러 감
                end
            end
        endcase
    end

endmodule
*/


module Model #(
    parameter IMG_WIDTH = 384
)(
    input  wire       clk,
    
    // TX 모듈(수신기)에서 '들어오는' 선 (PC -> FPGA)
    input  wire [7:0] tx_data,
    input  wire       tx_valid,
    
    // RX 모듈(송신기)로 '나가는' 선 (FPGA -> PC)
    output reg  [7:0] rx_data,
    output reg        rx_valid,
    input  wire       rx_busy     // 송신기가 바쁜지 확인
);

    // ==========================================
    // 1. 라인 버퍼 (이미지 윗줄 기억용)
    // ==========================================
    reg [10:0] col_cnt = 0;       
    reg [7:0]  left_pixel = 0;    
    reg [7:0]  current_pixel = 0; 
    reg [7:0]  top_pixel = 0;     
    reg        calc_en = 0;  

    wire [10:0] bram1_addr = col_cnt; 
    wire [7:0]  bram1_dout;           

    BRAM #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(11) 
    ) line_buffer (
        .clk(clk),
        .we_a(tx_valid),      
        .addr_a(bram1_addr),   
        .din_a(tx_data),      
        .addr_b(bram1_addr),   
        .dout_b(bram1_dout)    
    );

    // 픽셀 샘플링 로직
    always @(posedge clk) begin
        if (tx_valid) begin
            current_pixel <= tx_data;
            top_pixel     <= bram1_dout; 
            left_pixel    <= tx_data;

            if (col_cnt == IMG_WIDTH - 1) begin
                col_cnt <= 0;
                left_pixel <= 0; 
            end else begin
                col_cnt <= col_cnt + 1;
            end
            calc_en <= 1'b1; 
        end else begin
            calc_en <= 1'b0;
        end
    end

    // ==========================================
    // 2. 윤곽선(Edge) 계산 로직
    // ==========================================
    wire [8:0] diff_x = (current_pixel > left_pixel) ? (current_pixel - left_pixel) : (left_pixel - current_pixel);
    wire [8:0] diff_y = (current_pixel > top_pixel)  ? (current_pixel - top_pixel)  : (top_pixel - current_pixel);
    wire [9:0] edge_sum = diff_x + diff_y;
    wire [7:0] final_pixel = (edge_sum > 255) ? 255 : edge_sum[7:0];

    // ==========================================
    // 3. 출력용 BRAM2 (FIFO 버퍼) 연결
    // ==========================================
    wire       fifo_empty;
    wire [7:0] fifo_dout;
    reg        fifo_re = 0;

    BRAM2 #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(11) 
    ) output_fifo (
        .clk(clk),
        .we(calc_en),        // 윤곽선 계산이 완료된 순간 FIFO에 저장!
        .din(final_pixel),   // 계산된 윤곽선 픽셀값
        .re(fifo_re),
        .dout(fifo_dout),
        .empty(fifo_empty)
    );

    // ==========================================
    // 4. FIFO에서 꺼내어 송신 모듈로 전달 (FSM)
    // ==========================================
    localparam IDLE      = 2'd0;
    localparam WAIT_BRAM = 2'd1;
    localparam SEND      = 2'd2;
    localparam WAIT_TX   = 2'd3;

    reg [1:0] state = IDLE;

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                rx_valid <= 1'b0;
                // 버퍼에 데이터가 있고, 송신기가 안 바쁘면 꺼내기 시작
                if (!fifo_empty && !rx_busy) begin
                    fifo_re <= 1'b1;
                    state   <= WAIT_BRAM;
                end else begin
                    fifo_re <= 1'b0;
                end
            end

            WAIT_BRAM: begin
                fifo_re <= 1'b0;
                state   <= SEND; // BRAM2 데이터가 나오길 1클럭 대기
            end

            SEND: begin
                rx_data  <= fifo_dout;
                rx_valid <= 1'b1;  // 송신기에 데이터 전달
                state    <= WAIT_TX;
            end

            WAIT_TX: begin
                rx_valid <= 1'b0;
                // 송신기가 전송을 완료(busy 해제)하면 다음으로
                if (!rx_busy) begin
                    state <= IDLE;
                end
            end
        endcase
    end

endmodule