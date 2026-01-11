`timescale 1ns/1ps

module fpu_normalization (
    input  logic        is_add_path,
    input  logic        carry_in,
    input  logic [26:0] mant_in,
    input  logic [7:0]  exp_in,
    output logic [7:0]  exp_out,
    output logic [22:0] frac_out,
    output logic        overflow,
    output logic        underflow,
    output logic        is_zero
);
    // Path A: Overflow
    logic is_overflow_add;
    assign is_overflow_add = is_add_path & carry_in;

    logic [22:0] mant_right_res;
    logic [7:0]  exp_right;
    logic        ovf_right;
    
    logic r_guard, r_round, r_sticky, r_lsb, need_round_right;
    assign r_guard = mant_in[3]; assign r_round = mant_in[2];
    assign r_sticky = mant_in[1] | mant_in[0]; assign r_lsb = mant_in[4]; 
    assign need_round_right = r_guard & (r_round | r_sticky | r_lsb);

    logic [22:0] mant_right_rounded;
    incrementer_23bit u_round_r (.A(mant_in[26:4]), .S(mant_right_rounded));

    logic [7:0] exp_inc; logic exp_inc_ovf;
    incrementer_8bit u_exp_inc (.A(exp_in), .S(exp_inc), .Cout(exp_inc_ovf));
    
    logic exp_is_254; assign exp_is_254 = (exp_in == 8'hFE);
    assign ovf_right = exp_inc_ovf | (exp_inc == 8'hFF) | exp_is_254;
    assign exp_right = ovf_right ? 8'hFF : exp_inc;
    
    logic [22:0] mant_right_temp;
    assign mant_right_temp = need_round_right ? mant_right_rounded : mant_in[26:4];
    assign mant_right_res = ovf_right ? 23'd0 : mant_right_temp;

    // Path B: Normalization
    logic [22:0] mant_left_res;
    logic [7:0]  exp_left;
    logic        unf_left;
    logic [23:0] mant_24_raw;
    assign mant_24_raw = mant_in[26:3];

    logic [4:0] shift_amt;
    // Gọi lzc_manual (bên trong là Tree)
    lzc_manual u_lzc (.in_data({mant_24_raw, 8'h00}), .count(shift_amt));

    logic [26:0] shift_out_full;
    barrel_shifter_left_manual u_shifter_l (.in_data(mant_in), .shift_amt(shift_amt), .out_data(shift_out_full));
    assign mant_left_res = shift_out_full[25:3];

    // Trừ Exponent (Dùng adder thủ công bù 2: A + ~B + 1)
    logic [7:0] exp_sub_res; logic exp_sub_cout; 
    adder_8bit_manual u_exp_sub (.a(exp_in), .b(~{3'b000, shift_amt}), .cin(1'b1), .sum(exp_sub_res), .cout(exp_sub_cout));

    logic mant_is_zero_raw;
    zero_detect #(.N(24)) u_zd (.a(mant_24_raw), .is_zero(mant_is_zero_raw));
    assign unf_left = (~exp_sub_cout) & (~mant_is_zero_raw);
    assign exp_left = (exp_sub_cout) ? exp_sub_res : 8'b00;

    // Final Muxing
    logic use_right_path; assign use_right_path = is_overflow_add;
    logic [7:0]  exp_pre_final; logic [22:0] frac_pre_final;
    logic        ovf_final, unf_final;

    assign exp_pre_final  = use_right_path ? exp_right : exp_left;
    assign frac_pre_final = use_right_path ? mant_right_res : mant_left_res;
    assign ovf_final      = use_right_path ? ovf_right : 1'b0;
    assign unf_final      = (!use_right_path) ? unf_left : 1'b0;

    logic frac_zero, exp_zero, result_cancellation;
    assign frac_zero = ~(|frac_pre_final);
    assign exp_zero  = ~(|exp_pre_final);
    assign result_cancellation = (!use_right_path) & mant_is_zero_raw;
    assign is_zero = (frac_zero & exp_zero) | result_cancellation;

    logic real_underflow;
    assign real_underflow = (unf_final | (exp_pre_final == 8'd0)) & (~is_zero);
    logic result_is_inf;
    assign result_is_inf = (exp_pre_final == 8'hFF);
    
    logic [22:0] frac_clean;
    assign frac_clean = result_is_inf ? 23'd0 : frac_pre_final;

    assign exp_out   = (is_zero | real_underflow) ? 8'b0 : exp_pre_final;
    assign frac_out  = (is_zero | real_underflow) ? 23'b0 : frac_clean;
    assign overflow  = (ovf_final | result_is_inf) & (~is_zero);
    assign underflow = real_underflow;

endmodule