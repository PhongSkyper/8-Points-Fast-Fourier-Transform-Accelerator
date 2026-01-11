`timescale 1ns/1ps
module bf_input_latch (
    input  logic        clk, rst_n, issue,
    // Data Inputs
    input  logic [31:0] in_ar, in_ai, in_br, in_bi,
    // Twiddle Inputs (MỚI THÊM)
    input  logic [31:0] in_w_re, in_w_im,
    input  logic        in_is_mj,
    // Address Inputs (MỚI THÊM)
    input  logic [2:0]  in_a_now, in_b_now,

    // Outputs đã đồng bộ
    output logic [31:0] out_ar, out_ai, out_br, out_bi,
    output logic [31:0] out_w_re, out_w_im,
    output logic        out_is_mj,
    output logic [2:0]  out_a_now, out_b_now,
    output logic        out_valid
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_ar <= '0; out_ai <= '0; out_br <= '0; out_bi <= '0;
            out_w_re <= '0; out_w_im <= '0; out_is_mj <= '0;
            out_a_now <= '0; out_b_now <= '0;
        end else begin
            out_valid <= issue;
            if (issue) begin
                // Latch tất cả dữ liệu cùng lúc
                out_ar <= in_ar; out_ai <= in_ai; 
                out_br <= in_br; out_bi <= in_bi;
                out_w_re <= in_w_re; out_w_im <= in_w_im;
                out_is_mj <= in_is_mj;
                out_a_now <= in_a_now; out_b_now <= in_b_now;
            end
        end
    end
endmodule
