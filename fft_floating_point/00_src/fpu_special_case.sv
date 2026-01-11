`timescale 1ns/1ps
//============================================================
// fpu_special_case.sv
//  - Xử lý NaN, ±Inf, ±0, A=0, B=0
//  - Nếu trúng case đặc biệt → special_valid=1, special_res hợp lệ
//============================================================

module fpu_special_case (
    input  logic        sign_a,
    input  logic        sign_b_eff,
    input  logic [7:0]  exp_a, exp_b,
    input  logic [22:0] frac_a, frac_b,
    input  logic        is_zero_a, is_zero_b,
    input  logic        is_inf_a,  is_inf_b,
    input  logic        is_nan_a,  is_nan_b,
    output logic        special_valid,
    output logic [31:0] special_res
);
    // Flag cơ bản
    logic any_nan, inf_any, both_inf, xor_inf_sign, zero_zero;
    logic not_is_zero_a, not_is_zero_b;
    logic not_both_inf, not_xor_inf_sign, not_inf_any;
    logic a_zero_only_pre, b_zero_only_pre;

    or_gate_2  u_any_nan  (.a(is_nan_a), .b(is_nan_b), .y(any_nan));
    or_gate_2  u_inf_any  (.a(is_inf_a), .b(is_inf_b), .y(inf_any));
    and_gate_2 u_both_inf (.a(is_inf_a), .b(is_inf_b), .y(both_inf));
    xor_gate_2 u_xor_sign (.a(sign_a),   .b(sign_b_eff), .y(xor_inf_sign));
    and_gate_2 u_zero_zero(.a(is_zero_a), .b(is_zero_b),  .y(zero_zero));

    not_gate u_not_is_zero_a (.a(is_zero_a), .y(not_is_zero_a));
    not_gate u_not_is_zero_b (.a(is_zero_b), .y(not_is_zero_b));
    not_gate u_not_both_inf  (.a(both_inf),  .y(not_both_inf));
    not_gate u_not_xor_sign  (.a(xor_inf_sign), .y(not_xor_inf_sign));
    not_gate u_not_inf_any   (.a(inf_any),   .y(not_inf_any));

    and_gate_2 u_a_zero_only_pre (.a(is_zero_a),     .b(not_is_zero_b), .y(a_zero_only_pre));
    and_gate_2 u_b_zero_only_pre (.a(not_is_zero_a), .b(is_zero_b),     .y(b_zero_only_pre));

    // Các điều kiện special
    logic cond_nan;
    logic cond_inf_pair_conflict, cond_inf_pair_same;
    logic cond_inf_a_only, cond_inf_b_only;
    logic cond_zero_zero_final, cond_a_zero_only, cond_b_zero_only;
    logic not_cond_nan;

    assign cond_nan = any_nan;
    not_gate u_not_cond_nan (.a(cond_nan), .y(not_cond_nan));

    and_gate_3 u_cond_inf_pair_conflict (
        .a(not_cond_nan), .b(both_inf),     .c(xor_inf_sign),
        .y(cond_inf_pair_conflict)
    );
    and_gate_3 u_cond_inf_pair_same (
        .a(not_cond_nan), .b(both_inf),     .c(not_xor_inf_sign),
        .y(cond_inf_pair_same)
    );
    and_gate_3 u_cond_inf_a_only (
        .a(not_cond_nan), .b(not_both_inf), .c(is_inf_a),
        .y(cond_inf_a_only)
    );
    and_gate_3 u_cond_inf_b_only (
        .a(not_cond_nan), .b(not_both_inf), .c(is_inf_b),
        .y(cond_inf_b_only)
    );
    and_gate_3 u_cond_zero_zero_final (
        .a(not_cond_nan), .b(not_inf_any), .c(zero_zero),
        .y(cond_zero_zero_final)
    );
    and_gate_3 u_cond_a_zero_only (
        .a(not_cond_nan), .b(not_inf_any), .c(a_zero_only_pre),
        .y(cond_a_zero_only)
    );
    and_gate_3 u_cond_b_zero_only (
        .a(not_cond_nan), .b(not_inf_any), .c(b_zero_only_pre),
        .y(cond_b_zero_only)
    );

    // OR lại → special_valid
    logic or1, or2, or3, or4, or5, or6;

    or_gate_2 u_or1 (.a(cond_nan),              .b(cond_inf_pair_conflict), .y(or1));
    or_gate_2 u_or2 (.a(or1),                   .b(cond_inf_pair_same),     .y(or2));
    or_gate_2 u_or3 (.a(or2),                   .b(cond_inf_a_only),        .y(or3));
    or_gate_2 u_or4 (.a(or3),                   .b(cond_inf_b_only),        .y(or4));
    or_gate_2 u_or5 (.a(or4),                   .b(cond_zero_zero_final),   .y(or5));
    or_gate_2 u_or6 (.a(or5),                   .b(cond_a_zero_only),       .y(or6));
    or_gate_2 u_or7 (.a(or6),                   .b(cond_b_zero_only),       .y(special_valid));

    // Kết quả cho từng case
    logic [31:0] res_qnan, res_inf_a, res_inf_b_eff;
    logic [31:0] res_zero, res_from_b, res_from_a;

    assign res_qnan      = {1'b0, 8'hFF, 1'b1, 22'd0};   // quiet NaN
    assign res_inf_a     = {sign_a,     8'hFF, 23'd0};
    assign res_inf_b_eff = {sign_b_eff, 8'hFF, 23'd0};
    assign res_zero      = 32'd0;
    assign res_from_b    = {sign_b_eff, exp_b, frac_b};
    assign res_from_a    = {sign_a,     exp_a, frac_a};

    assign special_res =
          ({32{cond_nan | cond_inf_pair_conflict}}   & res_qnan)
        | ({32{cond_inf_pair_same | cond_inf_a_only}} & res_inf_a)
        | ({32{cond_inf_b_only}}                      & res_inf_b_eff)
        | ({32{cond_zero_zero_final}}                 & res_zero)
        | ({32{cond_a_zero_only}}                     & res_from_b)
        | ({32{cond_b_zero_only}}                     & res_from_a);
endmodule