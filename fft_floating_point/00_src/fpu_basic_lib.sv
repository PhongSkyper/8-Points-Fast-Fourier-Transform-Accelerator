`timescale 1ns/1ps

// =================================================================
// 1. CỔNG LOGIC CƠ BẢN
// =================================================================
module not_gate (input logic a, output logic y); assign y = ~a; endmodule
module and_gate_2 (input logic a,b, output logic y); assign y = a & b; endmodule
module or_gate_2 (input logic a,b, output logic y); assign y = a | b; endmodule
module xor_gate_2 (input logic a,b, output logic y); assign y = a ^ b; endmodule
module and_gate_3 (input logic a,b,c, output logic y); assign y = a & b & c; endmodule
module or_gate_3 (input logic a,b,c, output logic y); assign y = a | b | c; endmodule

module mux2 #(parameter int N = 1) (
    input  logic [N-1:0] d0, d1,
    input  logic         sel,
    output logic [N-1:0] y
);
    assign y = sel ? d1 : d0; 
endmodule

module zero_detect #(parameter int N = 8) (input logic [N-1:0] a, output logic is_zero);
    assign is_zero = ~(|a);
endmodule

module or_reduction_8  (input logic [7:0] a, output logic y); assign y = |a; endmodule
module or_reduction_23 (input logic [22:0] a, output logic y); assign y = |a; endmodule
module and_reduction_8 (input logic [7:0] a, output logic y); assign y = &a; endmodule

// =================================================================
// 2. CÁC MODULE LÕI (CLA & LCU)
// =================================================================

module cla_4bit_super (
    input  logic [3:0] a, b,
    input  logic       cin, // FIXED: cin is 1 bit
    output logic [3:0] sum,
    output logic       group_p, group_g
);
    logic [3:0] p, g, c;
    assign p = a ^ b; 
    assign g = a & b;
    assign c[0] = cin;
    assign c[1] = g[0] | (p[0] & c[0]);
    assign c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & c[0]);
    assign c[3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & c[0]);
    assign sum  = p ^ c;
    assign group_p = &p; 
    assign group_g = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]);
endmodule

module lcu_7group_adder (
    input  logic [6:0] P, G,
    input  logic       cin_global,
    output logic [6:0] C
);
    assign C[0] = cin_global;
    assign C[1] = G[0] | (P[0] & cin_global);
    assign C[2] = G[1] | (P[1] & G[0]) | (P[1] & P[0] & cin_global);
    assign C[3] = G[2] | (P[2] & G[1]) | (P[2] & P[1] & G[0]) | (P[2] & P[1] & P[0] & cin_global);
    assign C[4] = G[3] | (P[3] & C[3]); 
    assign C[5] = G[4] | (P[4] & G[3]) | (P[4] & P[3] & C[3]);
    assign C[6] = G[5] | (P[5] & C[5]);
endmodule

(* flatten *)
module cla_adder_28bit_core (
    input  logic [27:0] a, b,
    input  logic        cin, // FIXED: cin is 1 bit
    output logic [27:0] sum,
    output logic        cout
);
    logic [6:0] P_grp, G_grp, C_grp;
    lcu_7group_adder u_lcu (.P(P_grp), .G(G_grp), .cin_global(cin), .C(C_grp));
    
    cla_4bit_super u0 (a[3:0],   b[3:0],   C_grp[0], sum[3:0],   P_grp[0], G_grp[0]);
    cla_4bit_super u1 (a[7:4],   b[7:4],   C_grp[1], sum[7:4],   P_grp[1], G_grp[1]);
    cla_4bit_super u2 (a[11:8],  b[11:8],  C_grp[2], sum[11:8],  P_grp[2], G_grp[2]);
    cla_4bit_super u3 (a[15:12], b[15:12], C_grp[3], sum[15:12], P_grp[3], G_grp[3]);
    cla_4bit_super u4 (a[19:16], b[19:16], C_grp[4], sum[19:16], P_grp[4], G_grp[4]);
    cla_4bit_super u5 (a[23:20], b[23:20], C_grp[5], sum[23:20], P_grp[5], G_grp[5]);
    cla_4bit_super u6 (a[27:24], b[27:24], C_grp[6], sum[27:24], P_grp[6], G_grp[6]);

    assign cout = G_grp[6] | (P_grp[6] & C_grp[6]);
endmodule

// =================================================================
// 3. CÁC MODULE WRAPPER
// =================================================================

module cla_4bit_manual (
    input  logic [3:0] a, b,
    input  logic       cin, // FIXED
    output logic [3:0] sum,
    output logic       cout
);
    logic gp, gg;
    cla_4bit_super u_core (.a(a), .b(b), .cin(cin), .sum(sum), .group_p(gp), .group_g(gg));
    assign cout = gg | (gp & cin);
endmodule

module adder_8bit_manual (
    input  logic [7:0] a, b,
    input  logic       cin, // FIXED
    output logic [7:0] sum,
    output logic       cout
);
    logic c_mid;
    logic [3:0] g0, p0, g1, p1;
    assign p0 = a[3:0] ^ b[3:0]; assign g0 = a[3:0] & b[3:0];
    assign c_mid = g0[3] | (p0[3] & g0[2]) | (p0[3] & p0[2] & g0[1]) | 
                   (p0[3] & p0[2] & p0[1] & g0[0]) | (p0[3] & p0[2] & p0[1] & p0[0] & cin);
    
    cla_4bit_super u0 (.a(a[3:0]), .b(b[3:0]), .cin(cin),   .sum(sum[3:0]), .group_p(), .group_g());
    cla_4bit_super u1 (.a(a[7:4]), .b(b[7:4]), .cin(c_mid), .sum(sum[7:4]), .group_p(), .group_g());
    
    assign p1 = a[7:4] ^ b[7:4]; assign g1 = a[7:4] & b[7:4];
    assign cout = g1[3] | 
                  (p1[3] & g1[2]) | (p1[3] & p1[2] & g1[1]) | (p1[3] & p1[2] & p1[1] & g1[0]) | 
                  (p1[3] & p1[2] & p1[1] & p1[0] & c_mid);
endmodule

module cla_adder_28bit_manual (
    input  logic [27:0] a, b,
    input  logic        cin, // FIXED
    output logic [27:0] sum,
    output logic        cout
);
    cla_adder_28bit_core u_core (.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));
endmodule

module ripple_adder_27bit (
    input  logic [26:0] a, b,
    input  logic        cin,
    output logic [26:0] s,
    output logic        cout
);
    logic [27:0] s_full;
    logic        cout_unused;
    cla_adder_28bit_core u_core (
        .a({1'b0, a}), .b({1'b0, b}), .cin(cin), 
        .sum(s_full), .cout(cout_unused)
    );
    assign s = s_full[26:0];
    assign cout = s_full[27];
endmodule

module ripple_sub_8bit (
    input  logic [7:0] a, b,
    output logic [7:0] diff,
    output logic       cout
);
    adder_8bit_manual u_core (.a(a), .b(~b), .cin(1'b1), .sum(diff), .cout(cout));
endmodule

module cmp_ge_24bit (
    input  logic [23:0] a, b,
    output logic        ge
);
    logic [27:0] s_full;
    logic        cout_full;
    cla_adder_28bit_core u_cmp (
        .a({4'd0, a}), .b({4'd0, ~b}), .cin(1'b1),
        .sum(s_full), .cout(cout_full) 
    );
    assign ge = s_full[24]; 
endmodule

// =================================================================
// 4. SHIFTERS & LZC (Giữ nguyên phần này)
// =================================================================
(* flatten *)
module barrel_shifter_right_27 (
    input  logic [26:0] in_data,
    input  logic [4:0]  shift_amt,
    output logic [54:0] out_data
);
    logic [54:0] s0, s1, s2, s3, s4, pad_in;
    assign pad_in = {in_data, 28'd0}; 
    assign s0 = shift_amt[0] ? {1'b0, pad_in[54:1]} : pad_in;
    assign s1 = shift_amt[1] ? {2'b00, s0[54:2]}    : s0;
    assign s2 = shift_amt[2] ? {4'h0, s1[54:4]}     : s1;
    assign s3 = shift_amt[3] ? {8'h00, s2[54:8]}    : s2;
    assign s4 = shift_amt[4] ? {16'h0000, s3[54:16]}: s3;
    assign out_data = s4;
endmodule

(* flatten *)
module barrel_shifter_left_manual (
    input  logic [26:0] in_data,
    input  logic [4:0]  shift_amt,
    output logic [26:0] out_data
);
    logic [26:0] s0, s1, s2, s3, s4;
    assign s0 = shift_amt[0] ? {in_data[25:0], 1'b0} : in_data;
    assign s1 = shift_amt[1] ? {s0[24:0], 2'b00}     : s0;
    assign s2 = shift_amt[2] ? {s1[22:0], 4'h0}      : s1;
    assign s3 = shift_amt[3] ? {s2[18:0], 8'h00}     : s2;
    assign s4 = shift_amt[4] ? {s3[10:0], 16'h0000}  : s3;
    assign out_data = s4;
endmodule

// --- LZC TREE (Giữ nguyên) ---
module lzc_cell_2 (input logic [1:0] in, output logic v, p);
    assign v = in[1] | in[0]; assign p = in[1];
endmodule
module lzc_cell_4 (input logic [3:0] in, output logic v, output logic [1:0] p);
    logic v_hi, v_lo, p_hi, p_lo;
    lzc_cell_2 u_hi (.in(in[3:2]), .v(v_hi), .p(p_hi));
    lzc_cell_2 u_lo (.in(in[1:0]), .v(v_lo), .p(p_lo));
    assign v = v_hi | v_lo; assign p[1] = v_hi; assign p[0] = v_hi ? p_hi : p_lo; 
endmodule
module lzc_cell_8 (input logic [7:0] in, output logic v, output logic [2:0] p);
    logic v_hi, v_lo; logic [1:0] p_hi, p_lo;
    lzc_cell_4 u_hi (.in(in[7:4]), .v(v_hi), .p(p_hi));
    lzc_cell_4 u_lo (.in(in[3:0]), .v(v_lo), .p(p_lo));
    assign v = v_hi | v_lo; assign p[2] = v_hi; assign p[1:0] = v_hi ? p_hi : p_lo;
endmodule
module lzc_cell_16 (input logic [15:0] in, output logic v, output logic [3:0] p);
    logic v_hi, v_lo; logic [2:0] p_hi, p_lo;
    lzc_cell_8 u_hi (.in(in[15:8]), .v(v_hi), .p(p_hi));
    lzc_cell_8 u_lo (.in(in[7:0]),  .v(v_lo), .p(p_lo));
    assign v = v_hi | v_lo; assign p[3] = v_hi; assign p[2:0] = v_hi ? p_hi : p_lo;
endmodule

(* flatten *)
module lzc_32_tree (input logic [31:0] in, output logic [4:0] count);
    logic v_hi, v_lo, v_total; logic [3:0] p_hi, p_lo;
    logic [4:0] pos;
    lzc_cell_16 u_hi (.in(in[31:16]), .v(v_hi), .p(p_hi));
    lzc_cell_16 u_lo (.in(in[15:0]),  .v(v_lo), .p(p_lo));
    assign v_total = v_hi | v_lo;
    assign pos[4] = v_hi; assign pos[3:0] = v_hi ? p_hi : p_lo;
    assign count = v_total ? (~pos) : 5'b11000;
endmodule

(* flatten *)
module lzc_manual (
    input  logic [31:0] in_data,
    output logic [4:0]  count
);
    lzc_32_tree u_core (.in(in_data), .count(count));
endmodule

// --- INCREMENTERS (Giữ nguyên) ---
module incrementer_8bit (input [7:0] A, output [7:0] S, output Cout);
    assign S[0] = ~A[0];
    assign S[1] = A[1] ^ A[0];
    assign S[2] = A[2] ^ (A[1] & A[0]);
    assign S[3] = A[3] ^ (A[2] & A[1] & A[0]);
    assign S[4] = A[4] ^ (A[3] & A[2] & A[1] & A[0]);
    assign S[5] = A[5] ^ (A[4] & A[3] & A[2] & A[1] & A[0]);
    assign S[6] = A[6] ^ (A[5] & A[4] & A[3] & A[2] & A[1] & A[0]);
    assign S[7] = A[7] ^ (A[6] & A[5] & A[4] & A[3] & A[2] & A[1] & A[0]);
    assign Cout = &A;
endmodule

module incrementer_23bit (input [22:0] A, output [22:0] S);
    logic [23:0] c;
    assign c[0] = 1'b1;
    assign S[0] = A[0] ^ c[0];   assign c[1] = A[0] & c[0];
    assign S[1] = A[1] ^ c[1];   assign c[2] = A[1] & c[1];
    assign S[2] = A[2] ^ c[2];   assign c[3] = A[2] & c[2];
    assign S[3] = A[3] ^ c[3];   assign c[4] = A[3] & c[3];
    assign S[4] = A[4] ^ c[4];   assign c[5] = A[4] & c[4];
    assign S[5] = A[5] ^ c[5];   assign c[6] = A[5] & c[5];
    assign S[6] = A[6] ^ c[6];   assign c[7] = A[6] & c[6];
    assign S[7] = A[7] ^ c[7];   assign c[8] = A[7] & c[7];
    assign S[8] = A[8] ^ c[8];   assign c[9] = A[8] & c[8];
    assign S[9] = A[9] ^ c[9];   assign c[10] = A[9] & c[9];
    assign S[10] = A[10] ^ c[10]; assign c[11] = A[10] & c[10];
    assign S[11] = A[11] ^ c[11]; assign c[12] = A[11] & c[11];
    assign S[12] = A[12] ^ c[12]; assign c[13] = A[12] & c[12];
    assign S[13] = A[13] ^ c[13]; assign c[14] = A[13] & c[13];
    assign S[14] = A[14] ^ c[14]; assign c[15] = A[14] & c[14];
    assign S[15] = A[15] ^ c[15]; assign c[16] = A[15] & c[15];
    assign S[16] = A[16] ^ c[16]; assign c[17] = A[16] & c[16];
    assign S[17] = A[17] ^ c[17]; assign c[18] = A[17] & c[17];
    assign S[18] = A[18] ^ c[18]; assign c[19] = A[18] & c[18];
    assign S[19] = A[19] ^ c[19]; assign c[20] = A[19] & c[19];
    assign S[20] = A[20] ^ c[20]; assign c[21] = A[20] & c[20];
    assign S[21] = A[21] ^ c[21]; assign c[22] = A[21] & c[21];
    assign S[22] = A[22] ^ c[22]; 
endmodule
