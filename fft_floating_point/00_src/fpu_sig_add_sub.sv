`timescale 1ns/1ps

module fpu_sig_add_sub (
    input  logic [26:0] mant_big,
    input  logic [26:0] mant_small,
    input  logic        add_path,  
    output logic [26:0] mant_res,
    output logic        carry_out
);
    logic [26:0] sum_add, diff_sub;
    logic        cout_add, cout_sub;
    
    // --- Phép CỘNG ---
    // Gọi module cụ thể, KHÔNG dùng parameter
    ripple_adder_27bit u_add (
        .a   (mant_big),
        .b   (mant_small),
        .cin (1'b0),
        .s   (sum_add),
        .cout(cout_add)
    );

    // --- Phép TRỪ ---
    ripple_adder_27bit u_sub (
        .a   (mant_big),
        .b   (~mant_small), // Đảo bit tại chỗ
        .cin (1'b1),        // Cộng 1 (Bù 2)
        .s   (diff_sub),
        .cout(cout_sub) 
    );

    // --- MUX chọn kết quả ---
    mux2 #(.N(27)) u_mux_res (
        .d0 (diff_sub),
        .d1 (sum_add),
        .sel(add_path),
        .y  (mant_res)
    );

    mux2 #(.N(1)) u_mux_cout (
        .d0 (cout_sub),
        .d1 (cout_add),
        .sel(add_path),
        .y  (carry_out)
    );

endmodule