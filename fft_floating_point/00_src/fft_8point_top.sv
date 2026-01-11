`timescale 1ns/1ps

// =========================================================================
// 1. MODULE DFFR (Flip-flop có Reset)
// =========================================================================
module dffr #(parameter W=1) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [W-1:0] d,
    output logic [W-1:0] q
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) q <= '0; else q <= d;
    end
endmodule

// =========================================================================
// 2. MODULE IDX_GEN (Sinh địa chỉ cho DIT)
// =========================================================================
// DIT: Đi từ Butterfly nhỏ (Span 1) đến lớn (Span 4)
(* keep_hierarchy = "yes" *)
module idx_gen_8pt (
    input  logic [1:0] stage_sel,
    input  logic [1:0] k_idx,
    output logic [2:0] a_now,
    output logic [2:0] b_now
);
    always_comb begin
        unique case (stage_sel)
            // DIT STAGE 0 (Span 1): (0,1), (2,3), (4,5), (6,7)
            // Logic: k_idx * 2
            2'd0: begin 
                a_now = {k_idx, 1'b0}; 
                b_now = {k_idx, 1'b0} + 3'd1; 
            end
            
            // DIT STAGE 1 (Span 2): (0,2), (1,3), (4,6), (5,7)
            // Logic: chèn bit 0 vào giữa
            2'd1: begin 
                a_now = {k_idx[1], 1'b0, k_idx[0]}; 
                b_now = {k_idx[1], 1'b0, k_idx[0]} + 3'd2; 
            end
            
            // DIT STAGE 2 (Span 4): (0,4), (1,5), (2,6), (3,7)
            // Logic: bit 0 ở đầu
            default: begin 
                a_now = {1'b0, k_idx}; 
                b_now = {1'b0, k_idx} + 3'd4; 
            end
        endcase
    end
endmodule

// =========================================================================
// 3. TOP MODULE
// =========================================================================
module fft_8point_top #(
    parameter int L_MUL = 2,
    parameter int L_ADD = 2
)(
    input  logic        i_clk,
    input  logic        i_rst_n,
    input  logic        i_start,
    input  logic        i_valid,
    input  logic [31:0] i_re,
    input  logic [31:0] i_im,
    output logic        o_valid,
    output logic [31:0] o_re,
    output logic [31:0] o_im,
    output logic        o_done
);
    // Tính toán độ trễ: Input Latch (1) + Compute Pipeline
    // Compute DIT: Twiddle (L_MUL + L_ADD) + Adder (L_ADD)
    // Tùy vào bf_compute của bạn, nhưng thường là L_MUL + 2*L_ADD
    // Cộng thêm 1 cho Input Latch
    localparam int LAT = 1 + L_MUL + 2*L_ADD;

    // Control Signals
    logic load_en, issue, latch_unused, output_en;
    logic [2:0] load_addr, output_addr;
    logic [1:0] stage_sel, k_idx, tw_addr;
    
    // Instantiate Control Unit
    fft_control #(.LAT(LAT)) u_ctrl (
        .i_clk(i_clk), .i_rst_n(i_rst_n), .i_start(i_start), .i_valid_in(i_valid),
        .o_load_en(load_en), .o_load_addr(load_addr),
        .o_stage_sel(stage_sel), .o_k_idx(k_idx), .o_twiddle_addr(tw_addr),
        .o_issue(issue), .o_latch(latch_unused),
        .o_output_en(output_en), .o_output_addr(output_addr),
        .o_done(o_done)
    );

    // Twiddle ROM
    logic [31:0] W_re, W_im; logic is_mj;
    rom_twiddle u_tw(.i_addr(tw_addr), .o_wr(W_re), .o_wi(W_im), .o_is_mj(is_mj));

    // Index Generator
    logic [2:0] a_now, b_now;
    idx_gen_8pt u_idx (.stage_sel(stage_sel), .k_idx(k_idx), .a_now(a_now), .b_now(b_now));

    // Internal Signals
    logic [31:0] rd_ar, rd_ai, rd_br, rd_bi;
    logic [31:0] rd_re_out, rd_im_out;
    logic        wb_valid;
    logic [2:0]  wb_addr_a, wb_addr_b;
    logic [31:0] wb_re_a, wb_im_a, wb_re_b, wb_im_b;

    // Hàm đảo bit (Dùng cho Input Loading của DIT)
    function automatic [2:0] bitrev3(input [2:0] x);
        bitrev3 = {x[0], x[1], x[2]};
    endfunction

    // Buffer Bank
    buf_bank u_bank (
        .clk(i_clk), .rst_n(i_rst_n),
        // DIT: Input cần đảo bit -> dùng bitrev3(load_addr)
        .load_en(load_en), .load_addr(bitrev3(load_addr)), 
        .load_re(i_re), .load_im(i_im),
        
        .wb_en_a(wb_valid), .wb_addr_a(wb_addr_a), .wb_re_a(wb_re_a), .wb_im_a(wb_im_a),
        .wb_en_b(wb_valid && (wb_addr_b != wb_addr_a)), 
        .wb_addr_b(wb_addr_b), .wb_re_b(wb_re_b), .wb_im_b(wb_im_b),
        
        .rd_addr_a(a_now), .rd_addr_b(b_now),
        // DIT: Output là tự nhiên -> dùng thẳng output_addr
        .rd_addr_out(output_addr),
        .rd_re_a(rd_ar), .rd_im_a(rd_ai),
        .rd_re_b(rd_br), .rd_im_b(rd_bi),
        .rd_re_out(rd_re_out), .rd_im_out(rd_im_out)
    );

    // Butterfly Processing Unit
    bf_top_single #(.L_MUL(L_MUL), .L_ADD(L_ADD)) u_bf (
        .clk(i_clk), .rst_n(i_rst_n), .issue(issue),
        .a_now(a_now), .b_now(b_now),
        .in_ar(rd_ar), .in_ai(rd_ai), .in_br(rd_br), .in_bi(rd_bi),
        .w_re(W_re), .w_im(W_im), .is_mj(is_mj),
        .wb_valid(wb_valid),
        .wb_addr_a(wb_addr_a), .wb_addr_b(wb_addr_b),
        .wb_re_a(wb_re_a), .wb_im_a(wb_im_a),
        .wb_re_b(wb_re_b), .wb_im_b(wb_im_b)
    );

    assign o_valid = output_en;
    assign o_re    = rd_re_out;
    assign o_im    = rd_im_out;

endmodule
