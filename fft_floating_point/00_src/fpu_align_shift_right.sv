`timescale 1ns/1ps

module fpu_align_shift_right #(
    parameter int SIG_W = 24
) (
    input  logic [SIG_W-1:0] sig_small_in,
    input  logic [4:0]       shift_amt,
    output logic [SIG_W+2:0] sig_small_out,
    output logic             guard,
    output logic             round,
    output logic             sticky
);
    logic [26:0] in_padded;
    logic [54:0] out_shifted_full;

    assign in_padded = {sig_small_in, 3'b000};

    barrel_shifter_right_27 u_shifter (
        .in_data   (in_padded),
        .shift_amt (shift_amt),
        .out_data  (out_shifted_full)
    );

    assign sig_small_out = out_shifted_full[54:28];
    assign guard = sig_small_out[2];
    assign round = sig_small_out[1];
    
    logic bits_shifted_out;
    or_reduction_23 u_or_sticky (.a(out_shifted_full[22:0]), .y(bits_shifted_out));
    // Note: Lấy 23 bit thấp đại diện (vì input pad 28 bit 0)
    // Chính xác là OR của 28 bit thấp: out_shifted_full[27:0]
    // Nhưng ta có thể dùng logic OR |out_shifted_full[27:0]
    assign sticky = sig_small_out[0] | (|out_shifted_full[27:0]);

endmodule