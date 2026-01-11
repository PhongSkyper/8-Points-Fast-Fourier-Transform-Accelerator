`timescale 1ns/1ps
(* keep_hierarchy = "yes" *)
module twiddle_pipe #(
    parameter int L_MUL = 3,
    parameter int L_ADD = 2
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid_in,
    input  logic [31:0] br, bi,
    input  logic [31:0] w_re, w_im,
    input  logic        is_mj,      // 1 nếu -j
    output logic        valid_out,
    output logic [31:0] bw_r,
    output logic [31:0] bw_i
);
    localparam int L_MW = L_MUL + L_ADD;

    // bypass -j pipeline
    logic [L_MW-1:0] bp_v;
    logic [31:0] bp_r[L_MW-1:0], bp_i[L_MW-1:0];
    genvar i;
    generate
        for (i=0; i<L_MW; i++) begin : G_BP
            if (i==0) begin
                dffr #(.W(1))  dv (.clk(clk), .rst_n(rst_n), .d(valid_in), .q(bp_v[i]));
                dffr #(.W(32)) dr (.clk(clk), .rst_n(rst_n), .d(bi),       .q(bp_r[i]));
                wire [31:0] neg_br = {~br[31], br[30:0]};
                dffr #(.W(32)) di (.clk(clk), .rst_n(rst_n), .d(neg_br),   .q(bp_i[i]));
            end else begin
                dffr #(.W(1))  dv (.clk(clk), .rst_n(rst_n), .d(bp_v[i-1]), .q(bp_v[i]));
                dffr #(.W(32)) dr (.clk(clk), .rst_n(rst_n), .d(bp_r[i-1]), .q(bp_r[i]));
                dffr #(.W(32)) di (.clk(clk), .rst_n(rst_n), .d(bp_i[i-1]), .q(bp_i[i]));
            end
        end
    endgenerate

    // generic twiddle
    logic vmw; logic [31:0] cmul_re, cmul_im;
    complex_mult_pipe #(.L_MUL(L_MUL), .L_ADD(L_ADD)) u_cmul (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .a_re(br), .a_im(bi), .b_re(w_re), .b_im(w_im),
        .valid_out(vmw), .p_re(cmul_re), .p_im(cmul_im),
        .o_overflow(), .o_underflow(), .o_invalid()
    );

    always_comb begin
        if (is_mj) begin
            valid_out = bp_v[L_MW-1];
            bw_r      = bp_r[L_MW-1];
            bw_i      = bp_i[L_MW-1];
        end else begin
            valid_out = vmw;
            bw_r      = cmul_re;
            bw_i      = cmul_im;
        end
    end
endmodule