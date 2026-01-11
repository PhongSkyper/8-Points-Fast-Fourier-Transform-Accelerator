`timescale 1ns/1ps
module fpu_mult_pipe #(
    parameter int L_MUL = 3
)(
    input  logic        clk, rst_n,
    input  logic        valid_in,
    input  logic [31:0] i_op_a, i_op_b,
    output logic        valid_out,
    output logic [31:0] o_res,
    output logic        o_overflow, o_underflow, o_invalid
);
    // core combinational (FTZ) tái dùng
    logic [31:0] res_c; logic ovf_c, unf_c, inv_c;
    fpu_mult u_core(.i_op_a(i_op_a), .i_op_b(i_op_b),
                    .o_res(res_c), .o_overflow(ovf_c),
                    .o_underflow(unf_c), .o_invalid(inv_c));
    // pipeline shift
    logic [L_MUL-1:0] v; logic [L_MUL-1:0] ovf, unf, inv;
    logic [31:0] r [L_MUL-1:0];
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v <= '0; ovf <= '0; unf <= '0; inv <= '0;
            for (i=0;i<L_MUL;i++) r[i] <= 32'd0;
        end else begin
            v[0]   <= valid_in;
            ovf[0] <= ovf_c; unf[0] <= unf_c; inv[0] <= inv_c;
            r[0]   <= res_c;
            for (i=1;i<L_MUL;i++) begin
                v[i]   <= v[i-1];
                ovf[i] <= ovf[i-1];
                unf[i] <= unf[i-1];
                inv[i] <= inv[i-1];
                r[i]   <= r[i-1];
            end
        end
    end
    assign valid_out   = v[L_MUL-1];
    assign o_res       = r[L_MUL-1];
    assign o_overflow  = ovf[L_MUL-1];
    assign o_underflow = unf[L_MUL-1];
    assign o_invalid   = inv[L_MUL-1];
endmodule