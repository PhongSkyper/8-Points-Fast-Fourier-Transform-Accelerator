`timescale 1ns/1ps
//============================================================
// fpu_add_sub_top.sv
//  - Nối tất cả block FPU add/sub lại với nhau (combinational)
//  - 32-bit single precision, IEEE-754 (đơn giản hóa)
//============================================================

module fpu_add_sub_top (
    input  logic [31:0] i_a,
    input  logic [31:0] i_b,
    input  logic        i_add_sub,   // 0: A + B, 1: A - B
    output logic [31:0] o_z,
    output logic        o_overflow,
    output logic        o_underflow,
    output logic        o_zero
);

    //========================================================
    // 1. Unpack & Pretest
    //========================================================
    logic        sign_a, sign_b;
    logic [7:0]  exp_a_raw, exp_b_raw;
    logic [22:0] frac_a, frac_b;
    logic        is_zero_a, is_zero_b;
    logic        is_inf_a,  is_inf_b;
    logic        is_nan_a,  is_nan_b;
    logic        is_subn_a, is_subn_b;

    fpu_unpack_pretest u_unpack (
        .raw_a      (i_a),
        .raw_b      (i_b),
        .sign_a     (sign_a),
        .sign_b     (sign_b),
        .exp_a      (exp_a_raw),
        .exp_b      (exp_b_raw),
        .frac_a     (frac_a),
        .frac_b     (frac_b),
        .is_zero_a  (is_zero_a),
        .is_zero_b  (is_zero_b),
        .is_inf_a   (is_inf_a),
        .is_inf_b   (is_inf_b),
        .is_nan_a   (is_nan_a),
        .is_nan_b   (is_nan_b),
        .is_subn_a  (is_subn_a),
        .is_subn_b  (is_subn_b)
    );

    //========================================================
    // 2. Hiệu chỉnh dấu của B theo i_add_sub  (A ± B)
    //    sign_b_eff = sign_b XOR add_sub
    //========================================================
    logic sign_b_eff;

    xor_gate_2 u_xor_b (
        .a (sign_b),
        .b (i_add_sub),
        .y (sign_b_eff)
    );

    //========================================================
    // 3. Special cases: NaN, Inf, Zero...
    //========================================================
    logic        special_valid;
    logic [31:0] special_res;

    fpu_special_case u_special (
        .sign_a       (sign_a),
        .sign_b_eff   (sign_b_eff),
        .exp_a        (exp_a_raw),
        .exp_b        (exp_b_raw),
        .frac_a       (frac_a),
        .frac_b       (frac_b),
        .is_zero_a    (is_zero_a),
        .is_zero_b    (is_zero_b),
        .is_inf_a     (is_inf_a),
        .is_inf_b     (is_inf_b),
        .is_nan_a     (is_nan_a),
        .is_nan_b     (is_nan_b),
        .special_valid(special_valid),
        .special_res  (special_res)
    );

    //========================================================
    // 4. Chuẩn hóa đầu vào (bit ẩn + exponent subnormal)
    //    - Thêm bit ẩn (hidden bit) = 1 nếu normal, = 0 nếu subnormal
    //    - Exponent: nếu subnormal → e=1, ngược lại dùng e_raw
    //========================================================
    logic [7:0]  exp_a_eff, exp_b_eff;
    logic [23:0] sig_a,     sig_b;       // 1 bit ẩn + 23 frac

    // Thêm bit ẩn (hidden bit)
    assign sig_a = {(~is_subn_a), frac_a};
    assign sig_b = {(~is_subn_b), frac_b};

    // Exponent: nếu subnormal → e=1, ngược lại dùng e_raw
    assign exp_a_eff = is_subn_a ? 8'd1 : exp_a_raw;
    assign exp_b_eff = is_subn_b ? 8'd1 : exp_b_raw;

    //========================================================
    // 5. Exponent Subtractor  (|Ex-Ey|, max, ...)
    //========================================================
    logic [7:0] exp_max, exp_min;
    logic [4:0] exp_diff;
    logic       a_ge_b_exp;
    logic       ex_eq;

    // So sánh exponent
    fpu_exponent_subtractor u_exp_sub (
        .exp_a   (exp_a_eff),
        .exp_b   (exp_b_eff),
        .exp_max (exp_max),
        .exp_min (exp_min),
        .exp_diff(exp_diff),
        .a_ge_b  (a_ge_b_exp),
        .ex_eq   (ex_eq)
    );

    //========================================================
    // 6. Swap toán hạng theo độ lớn |A|, |B|
    //========================================================
    logic [7:0]  exp_big, exp_small;
    logic [23:0] sig_big, sig_small;
    logic        a_is_big_mag;

    fpu_swap_operands #(.SIG_W(24)) u_swap (
        .exp_a       (exp_a_eff),
        .exp_b       (exp_b_eff),
        .sig_a       (sig_a),
        .sig_b       (sig_b),
        .a_ge_b_exp  (a_ge_b_exp),
        .ex_eq       (ex_eq),
        .exp_big     (exp_big),
        .exp_small   (exp_small),
        .sig_big     (sig_big),
        .sig_small   (sig_small),
        .a_is_big_mag(a_is_big_mag)
    );

    //========================================================
    // 7. Tính dấu kết quả & chọn ADD / SUB trên mantissa
    //========================================================
    logic sign_big, sign_small;
    logic add_path;   // 1: cộng, 0: trừ (trên trị tuyệt đối)

    fpu_sign_computation u_sign_comp (
        .sign_a     (sign_a),
        .sign_b_eff (sign_b_eff),
        .a_is_big   (a_is_big_mag),
        .sign_big   (sign_big),
        .sign_small (sign_small),
        .add_path   (add_path)
    );

    //========================================================
    // 8. Align: dịch phải toán hạng nhỏ, tạo G/R/S
    //========================================================
    logic [26:0] sig_small_align;   // [26:3]=24bit, [2]=G,[1]=R,[0]=S
    logic        guard_bit, round_bit, sticky_bit;

    fpu_align_shift_right #(.SIG_W(24)) u_align (
        .sig_small_in (sig_small),
        .shift_amt    (exp_diff),
        .sig_small_out(sig_small_align),
        .guard        (guard_bit),
        .round        (round_bit),
        .sticky       (sticky_bit)
    );

    //========================================================
    // 9. Chuẩn bị mantissa cho bộ cộng/trừ 27 bit
    //========================================================
    logic [26:0] mant_big, mant_small;
    logic [26:0] mant_res;
    logic        carry_addsub;

    // mantissa của toán hạng lớn: GRS = 000
    assign mant_big   = {sig_big, 3'b000};
    // toán hạng nhỏ đã align + GRS
    assign mant_small = sig_small_align;

    fpu_sig_add_sub u_sig_addsub (
        .mant_big  (mant_big),
        .mant_small(mant_small),
        .add_path  (add_path),
        .mant_res  (mant_res),
        .carry_out (carry_addsub)
    );

    //========================================================
    // 10. Normalize + Rounding cuối cùng
    //========================================================
    logic [7:0]  exp_norm;
    logic [22:0] frac_norm;
    logic        ovf_norm, unf_norm;
    logic        is_zero_norm;

    fpu_normalization u_norm_final (
        .is_add_path (add_path),
        .carry_in    (carry_addsub),
        .mant_in     (mant_res),
        .exp_in      (exp_big),
        .exp_out     (exp_norm),
        .frac_out    (frac_norm),
        .overflow    (ovf_norm),
        .underflow   (unf_norm),
        .is_zero     (is_zero_norm)
    );

    //========================================================
    // 11. Gộp sign + exponent + fraction → normal_result
    //      - Nếu kết quả normal = 0 → ép về +0 (sign = 0)
    //========================================================
    logic sign_z_normal;
    logic [31:0] normal_res;

    mux2 #(.N(1)) u_mux_sign_zero (
        .d0 (sign_big),
        .d1 (1'b0),
        .sel(is_zero_norm),
        .y  (sign_z_normal)
    );

    assign normal_res = {sign_z_normal, exp_norm, frac_norm};

    //========================================================
    // 12. Chọn giữa normal path và special case
    //========================================================
    mux2 #(.N(32)) u_mux_result (
        .d0 (normal_res),
        .d1 (special_res),
        .sel(special_valid),
        .y  (o_z)
    );

    //========================================================
    // 13. Các cờ trạng thái: overflow, underflow, zero
    //========================================================
    // Overflow/Underflow chỉ tính cho normal path
    assign o_overflow  = (~special_valid) & ovf_norm;
    assign o_underflow = (~special_valid) & unf_norm;

    // Cờ zero: từ normal hoặc từ special_res
    logic zero_norm_total;
    logic zero_special_exp, zero_special_frac, zero_special;

    assign zero_norm_total = is_zero_norm;

    // special_res là 0 nếu exponent=0 và frac=0
    assign zero_special_exp  = ~(|special_res[30:23]);
    assign zero_special_frac = ~(|special_res[22:0]);
    assign zero_special      = zero_special_exp & zero_special_frac;

    mux2 #(.N(1)) u_mux_zero (
        .d0 (zero_norm_total),
        .d1 (zero_special),
        .sel(special_valid),
        .y  (o_zero)
    );

endmodule