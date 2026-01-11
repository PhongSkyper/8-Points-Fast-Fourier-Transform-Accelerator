`timescale 1ns/1ps
//============================================================
// fpu_unpack_pretest.sv
//  - Tách sign/exp/frac
//  - Phân loại: zero, subnormal, inf, NaN
//============================================================

module fpu_unpack_pretest (
    input  logic [31:0] raw_a, raw_b,
    output logic        sign_a, sign_b,
    output logic [7:0]  exp_a,  exp_b,
    output logic [22:0] frac_a, frac_b,
    output logic        is_zero_a, is_zero_b,
    output logic        is_inf_a,  is_inf_b,
    output logic        is_nan_a,  is_nan_b,
    output logic        is_subn_a, is_subn_b
);
    // Tách field
    assign sign_a = raw_a[31];
    assign sign_b = raw_b[31];
    assign exp_a  = raw_a[30:23];
    assign exp_b  = raw_b[30:23];
    assign frac_a = raw_a[22:0];
    assign frac_b = raw_b[22:0];

    // OR/AND reduction
    logic or_E_a, or_E_b;
    logic or_M_a, or_M_b;
    logic and_E_a, and_E_b;
    logic not_or_E_a, not_or_E_b;
    logic not_or_M_a, not_or_M_b;

    or_reduction_8  u_or_E_a (.a(exp_a),  .y(or_E_a));
    or_reduction_8  u_or_E_b (.a(exp_b),  .y(or_E_b));
    or_reduction_23 u_or_M_a (.a(frac_a), .y(or_M_a));
    or_reduction_23 u_or_M_b (.a(frac_b), .y(or_M_b));

    and_reduction_8 u_and_E_a (.a(exp_a), .y(and_E_a));
    and_reduction_8 u_and_E_b (.a(exp_b), .y(and_E_b));

    not_gate u_not_or_E_a (.a(or_E_a), .y(not_or_E_a));
    not_gate u_not_or_E_b (.a(or_E_b), .y(not_or_E_b));
    not_gate u_not_or_M_a (.a(or_M_a), .y(not_or_M_a));
    not_gate u_not_or_M_b (.a(or_M_b), .y(not_or_M_b));

    // zero:  E = 0, M = 0
    and_gate_2 u_is_zero_a (.a(not_or_E_a), .b(not_or_M_a), .y(is_zero_a));
    and_gate_2 u_is_zero_b (.a(not_or_E_b), .b(not_or_M_b), .y(is_zero_b));

    // subnormal: E = 0, M != 0
    and_gate_2 u_is_subn_a (.a(not_or_E_a), .b(or_M_a), .y(is_subn_a));
    and_gate_2 u_is_subn_b (.a(not_or_E_b), .b(or_M_b), .y(is_subn_b));

    // inf: E = 0xFF, M = 0
    and_gate_2 u_is_inf_a (.a(and_E_a), .b(not_or_M_a), .y(is_inf_a));
    and_gate_2 u_is_inf_b (.a(and_E_b), .b(not_or_M_b), .y(is_inf_b));

    // NaN: E = 0xFF, M != 0
    and_gate_2 u_is_nan_a (.a(and_E_a), .b(or_M_a), .y(is_nan_a));
    and_gate_2 u_is_nan_b (.a(and_E_b), .b(or_M_b), .y(is_nan_b));
endmodule