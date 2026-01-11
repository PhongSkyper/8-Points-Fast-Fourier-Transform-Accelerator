`timescale 1ns/1ps
module fpu_add_sub_pipe #(
    parameter int L_ADD = 2
)(
    input  logic        clk, rst_n,
    input  logic        valid_in,
    input  logic [31:0] i_a, i_b,
    input  logic        i_add_sub, // 0 add, 1 sub
    output logic        valid_out,
    output logic [31:0] o_z,
    output logic        o_overflow, o_underflow, o_zero
);
    logic [31:0] z_c; logic ovf_c, unf_c, zero_c;
    fpu_add_sub_top u_core(.i_a(i_a), .i_b(i_b), .i_add_sub(i_add_sub),
                           .o_z(z_c), .o_overflow(ovf_c),
                           .o_underflow(unf_c), .o_zero(zero_c));
    logic [L_ADD-1:0] v, ovf, unf, zf;
    logic [31:0] zr [L_ADD-1:0];
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v <= '0; ovf <= '0; unf <= '0; zf <= '0;
            for (i=0;i<L_ADD;i++) zr[i] <= 32'd0;
        end else begin
            v[0]   <= valid_in;
            ovf[0] <= ovf_c; unf[0] <= unf_c; zf[0] <= zero_c; zr[0] <= z_c;
            for (i=1;i<L_ADD;i++) begin
                v[i]   <= v[i-1];
                ovf[i] <= ovf[i-1];
                unf[i] <= unf[i-1];
                zf[i]  <= zf[i-1];
                zr[i]  <= zr[i-1];
            end
        end
    end
    assign valid_out   = v[L_ADD-1];
    assign o_z         = zr[L_ADD-1];
    assign o_overflow  = ovf[L_ADD-1];
    assign o_underflow = unf[L_ADD-1];
    assign o_zero      = zf[L_ADD-1];
endmodule