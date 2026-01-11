`timescale 1ns/1ps

module bf_compute #(
    parameter int L_MUL = 2,
    parameter int L_ADD = 2
)(
    input  logic        clk, rst_n,
    input  logic        valid_in,
    input  logic [31:0] ar, ai, br, bi, // A và B
    input  logic [31:0] w_re, w_im,     // Twiddle Factor
    input  logic        is_mj,          // (Unused in pure multiplier)
    output logic        valid_out,
    output logic [31:0] xr, xi, yr, yi  // X=A', Y=B'
);
    // ========================================================================
    // BƯỚC 1: NHÂN TWIDDLE (B * W) - DÙNG TRỰC TIẾP COMPLEX MULTIPLIER
    // Loại bỏ twiddle_pipe để tránh lỗi Bypass W0
    // ========================================================================
    logic v1;
    logic [31:0] bw_r, bw_i; // Kết quả B * W

    // Gọi trực tiếp bộ nhân phức -> Luôn tốn (L_MUL + L_ADD) cycles
    complex_mult_pipe #(.L_MUL(L_MUL), .L_ADD(L_ADD)) u_cmul (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in),
        .a_re(br), .a_im(bi),     // Input là B
        .b_re(w_re), .b_im(w_im), // Nhân với W
        .valid_out(v1),
        .p_re(bw_r), .p_im(bw_i),
        .o_overflow(), .o_underflow(), .o_invalid()
    );

    // ========================================================================
    // DELAY INPUT A (Để đợi B nhân xong)
    // Delay = Latency của bộ nhân (L_MUL + L_ADD)
    // ========================================================================
    localparam int MUL_LAT = L_MUL + L_ADD;
    logic [31:0] dly_ar[MUL_LAT-1:0];
    logic [31:0] dly_ai[MUL_LAT-1:0];
    
    always_ff @(posedge clk) begin
        dly_ar[0] <= ar;
        dly_ai[0] <= ai;
        for (int k=1; k<MUL_LAT; k++) begin
            dly_ar[k] <= dly_ar[k-1];
            dly_ai[k] <= dly_ai[k-1];
        end
    end

    logic [31:0] ar_delayed, ai_delayed;
    assign ar_delayed = dly_ar[MUL_LAT-1];
    assign ai_delayed = dly_ai[MUL_LAT-1];

    // ========================================================================
    // BƯỚC 2: CỘNG / TRỪ (BUTTERFLY)
    // DIT: X = A + (B*W); Y = A - (B*W)
    // ========================================================================
    logic v2_x, v2_y;

    // --- Tính X = A + BW ---
    // Real X
    fpu_add_sub_pipe #(.L_ADD(L_ADD)) u_add_xr (
        .clk(clk), .rst_n(rst_n), .valid_in(v1),
        .i_a(ar_delayed), .i_b(bw_r), .i_add_sub(1'b0), // 0: ADD
        .valid_out(v2_x), .o_z(xr), 
        .o_overflow(), .o_underflow(), .o_zero()
    );
    // Imag X
    fpu_add_sub_pipe #(.L_ADD(L_ADD)) u_add_xi (
        .clk(clk), .rst_n(rst_n), .valid_in(v1),
        .i_a(ai_delayed), .i_b(bw_i), .i_add_sub(1'b0), // 0: ADD
        .valid_out(), .o_z(xi), 
        .o_overflow(), .o_underflow(), .o_zero()
    );

    // --- Tính Y = A - BW ---
    // Real Y
    fpu_add_sub_pipe #(.L_ADD(L_ADD)) u_sub_yr (
        .clk(clk), .rst_n(rst_n), .valid_in(v1),
        .i_a(ar_delayed), .i_b(bw_r), .i_add_sub(1'b1), // 1: SUB
        .valid_out(v2_y), .o_z(yr), 
        .o_overflow(), .o_underflow(), .o_zero()
    );
    // Imag Y
    fpu_add_sub_pipe #(.L_ADD(L_ADD)) u_sub_yi (
        .clk(clk), .rst_n(rst_n), .valid_in(v1),
        .i_a(ai_delayed), .i_b(bw_i), .i_add_sub(1'b1), // 1: SUB
        .valid_out(), .o_z(yi), 
        .o_overflow(), .o_underflow(), .o_zero()
    );

    assign valid_out = v2_x;

endmodule
