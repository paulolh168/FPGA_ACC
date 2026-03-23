`timescale 1ns / 1ps

module top(
    input wire CLK100MHZ,
    input wire UART_TXD_IN,    // ★ 수정: PC에서 보드로 "들어오는(IN)" 핀 (보드의 RX)
    output wire UART_RXD_OUT   // ★ 수정: 보드에서 PC로 "나가는(OUT)" 핀 (보드의 TX)
);
    wire [7:0] tx_data;
    wire tx_valid;
    
    wire [7:0] rx_data;
    wire rx_valid;
    wire rx_busy;
    
    
    // 1. 수신기 (PC -> 보드)
    UART_TX tx(
        .clk(CLK100MHZ),       
        .tx(UART_TXD_IN),     // PC가 쏘는 데이터가 들어오는 핀
        .tx_data(tx_data),
        .tx_valid(tx_valid)
    );

    // 2. 데이터 가공 모듈 (+1 연산)
    Model model(
        .clk(CLK100MHZ),
        
        // TX에서 들어오는 선을 받음
        .tx_data(tx_data),
        .tx_valid(tx_valid),
        
        // RX로 나가는 선을 제어함
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_busy(rx_busy)    // TX가 바쁜지 상태를 확인
    );
     
    // 3. 송신기 (보드 -> PC)
    UART_RX rx(
        .clk(CLK100MHZ),       
        .rx(UART_RXD_OUT),    // PC로 쏴줄 데이터가 나가는 핀
        .rx_data(rx_data),    // ★ Model에서 가공된(+1) 데이터 연결
        .rx_busy(rx_busy),
        .rx_valid(rx_valid)   // ★ Model이 연산 끝났다고 알려주는 신호 연결
    );    

endmodule