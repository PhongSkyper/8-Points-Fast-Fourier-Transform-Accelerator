`timescale 1ns/1ps
module butterfly_unit_pipe #(
    parameter int L_MUL = 3,
    parameter int L_ADD = 2,
    parameter bit USE_TWIDDLE = 1,
    parameter bit TWID_IS_MJ  = 0, // -j bypass
    parameter [31:0] W_RE = 32'h3f800000,
    parameter [31:0] W_IM = 32'h00000000
)(
    input  logic        clk, rst_n,
    input  logic        valid_in,
    input  logic [31:0] i_ar, i_ai,
    input  logic [31:0] i_br, i_bi,
    output logic        valid_out,
    output logic [31:0] o_xr, o_xi,
    output logic [31:0] o_yr, o_yi,
    output logic        o_overflow, o_underflow, o_invalid
);
    logic v_mul; logic [31:0] bw_r, bw_i; logic ovf_mul, unf_mul, inv_mul;
    generate
        if (USE_TWIDDLE && !TWID_IS_MJ) begin
            complex_mult_pipe #(.L_MUL(L_MUL), .L_ADD(L_ADD)) u_mul (
                .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
                .a_re(i_br), .a_im(i_bi), .b_re(W_RE), .b_im(W_IM),
                .valid_out(v_mul), .p_re(bw_r), .p_im(bw_i),
                .o_overflow(ovf_mul), .o_underflow(unf_mul), .o_invalid(inv_mul)
            );
        end else if (USE_TWIDDLE && TWID_IS_MJ) begin
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    v_mul <= 1'b0; bw_r <= 32'd0; bw_i <= 32'd0;
                    ovf_mul<=1'b0; unf_mul<=1'b0; inv_mul<=1'b0;
                end else begin
                    v_mul <= valid_in;
                    bw_r <= i_bi;
                    bw_i <= {~i_br[31], i_br[30:0]}; // -br
                    ovf_mul<=1'b0; unf_mul<=1'b0; inv_mul<=1'b0;
                end
            end
        end else begin
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    v_mul <= 1'b0; bw_r <= 32'd0; bw_i <= 32'd0;
                    ovf_mul<=1'b0; unf_mul<=1'b0; inv_mul<=1'b0;
                end else begin
                    v_mul <= valid_in;
                    bw_r <= i_br; bw_i <= i_bi;
                    ovf_mul<=1'b0; unf_mul<=1'b0; inv_mul<=1'b0;
                end
            end
        end
    endgenerate

    logic v1, v2;
    fpu_add_sub_pipe #(.L_ADD(L_ADD)) add_xr(
        .clk(clk), .rst_n(rst_n), .valid_in(v_mul),
        .i_a(i_ar), .i_b(bw_r), .i_add_sub(1'b0),
        .valid_out(v1), .o_z(o_xr),
        .o_overflow(), .o_underflow(), .o_zero());
    fpu_add_sub_pipe #(.L_ADD(L_ADD)) add_xi(
        .clk(clk), .rst_n(rst_n), .valid_in(v_mul),
        .i_a(i_ai), .i_b(bw_i), .i_add_sub(1'b0),
        .valid_out(), .o_z(o_xi),
        .o_overflow(), .o_underflow(), .o_zero());
    fpu_add_sub_pipe #(.L_ADD(L_ADD)) sub_yr(
        .clk(clk), .rst_n(rst_n), .valid_in(v_mul),
        .i_a(i_ar), .i_b(bw_r), .i_add_sub(1'b1),
        .valid_out(v2), .o_z(o_yr),
        .o_overflow(), .o_underflow(), .o_zero());
    fpu_add_sub_pipe #(.L_ADD(L_ADD)) sub_yi(
        .clk(clk), .rst_n(rst_n), .valid_in(v_mul),
        .i_a(i_ai), .i_b(bw_i), .i_add_sub(1'b1),
        .valid_out(), .o_z(o_yi),
        .o_overflow(), .o_underflow(), .o_zero());

    logic [L_ADD-1:0] vflag;
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) vflag <= '0;
        else begin
            vflag[0] <= v_mul;
            for (i=1;i<L_ADD;i++) vflag[i] <= vflag[i-1];
        end
    end
    assign valid_out   = v1 & v2;
    assign o_overflow  = vflag[L_ADD-1] & ovf_mul;
    assign o_underflow = vflag[L_ADD-1] & unf_mul;
    assign o_invalid   = vflag[L_ADD-1] & inv_mul;
endmodule