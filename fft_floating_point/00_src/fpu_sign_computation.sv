`timescale 1ns/1ps

module fpu_sign_computation (
    input  logic sign_a,
    input  logic sign_b_eff, 
    input  logic a_is_big,   
    output logic sign_big,   
    output logic sign_small,   
    output logic add_path     
);
    
    mux2 #(.N(1)) u_mux_big (
        .d0 (sign_b_eff),
        .d1 (sign_a),
        .sel(a_is_big),
        .y  (sign_big)
    );

    mux2 #(.N(1)) u_mux_small (
        .d0 (sign_a),
        .d1 (sign_b_eff),
        .sel(a_is_big),
        .y  (sign_small)
    );

    logic xor_signs;
    xor_gate_2 u_xor (.a(sign_a), .b(sign_b_eff), .y(xor_signs));
    not_gate   u_not (.a(xor_signs), .y(add_path));

endmodule