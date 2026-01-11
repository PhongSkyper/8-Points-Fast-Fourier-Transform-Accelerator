`timescale 1ns/1ps

module fpu_swap_operands #(
    parameter int unsigned SIG_W = 24
) (
    input  logic [7:0]       exp_a, exp_b,
    input  logic [SIG_W-1:0] sig_a, sig_b,
    input  logic             a_ge_b_exp,
    input  logic             ex_eq,
    output logic [7:0]       exp_big, exp_small,
    output logic [SIG_W-1:0] sig_big, sig_small,
    output logic             a_is_big_mag
);

    logic sig_a_ge_b;
    // Gọi module so sánh 24 bit cụ thể
    cmp_ge_24bit u_cmp_sig (
        .a  (sig_a),
        .b  (sig_b),
        .ge (sig_a_ge_b)
    );

    logic a_big_final;
    mux2 #(.N(1)) u_mux_decision (
        .d0 (a_ge_b_exp),
        .d1 (sig_a_ge_b),
        .sel(ex_eq),
        .y  (a_big_final)
    );

    assign a_is_big_mag = a_big_final;

    mux2 #(.N(8))     u_mux_exp_big   (.d0(exp_b), .d1(exp_a), .sel(a_big_final), .y(exp_big));
    mux2 #(.N(8))     u_mux_exp_small (.d0(exp_a), .d1(exp_b), .sel(a_big_final), .y(exp_small));
    mux2 #(.N(SIG_W)) u_mux_sig_big   (.d0(sig_b), .d1(sig_a), .sel(a_big_final), .y(sig_big));
    mux2 #(.N(SIG_W)) u_mux_sig_small (.d0(sig_a), .d1(sig_b), .sel(a_big_final), .y(sig_small));
endmodule