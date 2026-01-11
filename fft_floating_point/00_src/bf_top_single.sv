`timescale 1ns/1ps
(* keep_hierarchy = "yes" *)
module bf_top_single #(
    parameter int L_MUL = 3,
    parameter int L_ADD = 2
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        issue,
    input  logic [2:0]  a_now,
    input  logic [2:0]  b_now,
    input  logic [31:0] in_ar, in_ai, in_br, in_bi,
    input  logic [31:0] w_re, w_im,
    input  logic        is_mj,
    output logic        wb_valid,
    output logic [2:0]  wb_addr_a,
    output logic [2:0]  wb_addr_b,
    output logic [31:0] wb_re_a, wb_im_a,
    output logic [31:0] wb_re_b, wb_im_b
);
    // 1. INPUT LATCH: Đồng bộ HÓA TOÀN BỘ (Data + Twiddle + Address)
    // Latency = 1 cycle
    logic li_valid;
    logic [31:0] li_ar, li_ai, li_br, li_bi;
    logic [31:0] li_w_re, li_w_im;
    logic        li_is_mj;
    logic [2:0]  li_a_now, li_b_now;

    bf_input_latch u_il (
        .clk(clk), .rst_n(rst_n), .issue(issue),
        // Data
        .in_ar(in_ar), .in_ai(in_ai), .in_br(in_br), .in_bi(in_bi),
        .out_ar(li_ar), .out_ai(li_ai), .out_br(li_br), .out_bi(li_bi),
        // Twiddle (Đã thêm mới)
        .in_w_re(w_re), .in_w_im(w_im), .in_is_mj(is_mj),
        .out_w_re(li_w_re), .out_w_im(li_w_im), .out_is_mj(li_is_mj),
        // Address (Đã thêm mới)
        .in_a_now(a_now), .in_b_now(b_now),
        .out_a_now(li_a_now), .out_b_now(li_b_now),
        // Valid
        .out_valid(li_valid)
    );

    // 2. COMPUTE PIPELINE
    // Input lấy từ sau Latch (li_*)
    logic v_cmp; logic [31:0] xr, xi, yr, yi;
    
    bf_compute #(.L_MUL(L_MUL), .L_ADD(L_ADD)) u_cmp (
        .clk(clk), .rst_n(rst_n), .valid_in(li_valid),
        .ar(li_ar), .ai(li_ai), .br(li_br), .bi(li_bi),
        .w_re(li_w_re), .w_im(li_w_im), .is_mj(li_is_mj),
        .valid_out(v_cmp), .xr(xr), .xi(xi), .yr(yr), .yi(yi)
    );

    // 3. ADDRESS PIPELINE
    // Latency phải bằng đúng độ trễ tính toán (L_MUL + 2*L_ADD)
    // Input lấy từ sau Latch (li_*) để đồng bộ với Data
    localparam int PIPE_LAT = L_MUL + 2*L_ADD;
    
    logic v_addr; logic [2:0] a_wb, b_wb;
    
    addr_pipe #(.LAT(PIPE_LAT)) u_ap (
        .clk(clk), .rst_n(rst_n), 
        .v_in(li_valid), // Input valid đã được Latch
        .a_in(li_a_now), // Input addr đã được Latch
        .b_in(li_b_now),
        .v_out(v_addr), 
        .a_out(a_wb), 
        .b_out(b_wb)
    );

    // 4. FINAL OUTPUT
    assign wb_valid = v_cmp & v_addr;
    assign wb_addr_a = a_wb;
    assign wb_addr_b = b_wb;
    assign wb_re_a   = xr;
    assign wb_im_a   = xi;
    assign wb_re_b   = yr;
    assign wb_im_b   = yi;

endmodule
