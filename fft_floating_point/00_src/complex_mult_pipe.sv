`timescale 1ns/1ps

module complex_mult_pipe #(
    parameter int L_MUL = 2, // Lưu ý: Với fpu_mult mới, giá trị này thực tế là 2
    parameter int L_ADD = 2  // Độ trễ của bộ cộng
)(
    input  logic        clk, rst_n,
    input  logic        valid_in,
    input  logic [31:0] a_re, a_im,
    input  logic [31:0] b_re, b_im,
    output logic        valid_out,
    output logic [31:0] p_re, p_im,
    output logic        o_overflow, o_underflow, o_invalid
);

    // =========================================================================
    // 1. GIAI ĐOẠN NHÂN (4 Multipliers)
    // (a + ji) * (c + jd) = (ac - bd) + j(ad + bc)
    // =========================================================================
    logic vm1, vm2, vm3, vm4;
    logic [31:0] ac, bd, ad, bc;
    logic [3:0] ovf_m, unf_m, inv_m;

    // Instance 1: ac
    fpu_mult m1 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .i_op_a(a_re), .i_op_b(b_re),
        .valid_out(vm1), .o_res(ac),
        .o_overflow(ovf_m[0]), .o_underflow(unf_m[0]), .o_invalid(inv_m[0])
    );

    // Instance 2: bd
    fpu_mult m2 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .i_op_a(a_im), .i_op_b(b_im),
        .valid_out(vm2), .o_res(bd),
        .o_overflow(ovf_m[1]), .o_underflow(unf_m[1]), .o_invalid(inv_m[1])
    );

    // Instance 3: ad
    fpu_mult m3 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .i_op_a(a_re), .i_op_b(b_im),
        .valid_out(vm3), .o_res(ad),
        .o_overflow(ovf_m[2]), .o_underflow(unf_m[2]), .o_invalid(inv_m[2])
    );

    // Instance 4: bc
    fpu_mult m4 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .i_op_a(a_im), .i_op_b(b_re),
        .valid_out(vm4), .o_res(bc),
        .o_overflow(ovf_m[3]), .o_underflow(unf_m[3]), .o_invalid(inv_m[3])
    );

    logic vm_all; 
    assign vm_all = vm1 & vm2 & vm3 & vm4;

    // Tổng hợp cờ lỗi từ giai đoạn nhân (OR logic)
    logic mul_ovf_comb, mul_unf_comb, mul_inv_comb;
    assign mul_ovf_comb = |ovf_m;
    assign mul_unf_comb = |unf_m;
    assign mul_inv_comb = |inv_m;

    // =========================================================================
    // 2. GIAI ĐOẠN CỘNG/TRỪ (Add/Sub Pipeline)
    // Real = ac - bd
    // Imag = ad + bc
    // =========================================================================
    logic va1, va2;
    logic ovf_a1, unf_a1, inv_a1; // Cờ lỗi từ bộ cộng/trừ 1 (Real)
    logic ovf_a2, unf_a2, inv_a2; // Cờ lỗi từ bộ cộng/trừ 2 (Imag) -- (Add module chưa có output inv, tạm bỏ qua)

    // Tính phần thực: ac - bd
    fpu_add_sub_pipe #(.L_ADD(L_ADD)) sub_re (
        .clk(clk), .rst_n(rst_n), .valid_in(vm_all),
        .i_a(ac), .i_b(bd), .i_add_sub(1'b1), // 1: SUB
        .valid_out(va1), .o_z(p_re),
        .o_overflow(ovf_a1), .o_underflow(unf_a1), .o_zero()
    );

    // Tính phần ảo: ad + bc
    fpu_add_sub_pipe #(.L_ADD(L_ADD)) add_im (
        .clk(clk), .rst_n(rst_n), .valid_in(vm_all),
        .i_a(ad), .i_b(bc), .i_add_sub(1'b0), // 0: ADD
        .valid_out(va2), .o_z(p_im),
        .o_overflow(ovf_a2), .o_underflow(unf_a2), .o_zero()
    );

    // =========================================================================
    // 3. ĐỒNG BỘ CỜ LỖI (Flag Alignment)
    // Cần delay cờ lỗi của phép nhân (mul_*) thêm L_ADD chu kỳ để khớp với output
    // =========================================================================
    logic [L_ADD-1:0] dly_ovf, dly_unf, dly_inv;
    integer i;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dly_ovf <= '0;
            dly_unf <= '0;
            dly_inv <= '0;
        end else begin
            // Shift register cho cờ Overflow
            dly_ovf[0] <= mul_ovf_comb;
            for (i=1; i<L_ADD; i++) dly_ovf[i] <= dly_ovf[i-1];

            // Shift register cho cờ Underflow
            dly_unf[0] <= mul_unf_comb;
            for (i=1; i<L_ADD; i++) dly_unf[i] <= dly_unf[i-1];

            // Shift register cho cờ Invalid
            dly_inv[0] <= mul_inv_comb;
            for (i=1; i<L_ADD; i++) dly_inv[i] <= dly_inv[i-1];
        end
    end

    // =========================================================================
    // 4. OUTPUT FINALIZATION
    // Kết quả hợp lệ khi cả 2 nhánh cộng/trừ xong
    // Cờ lỗi = (Lỗi nhân đã delay) OR (Lỗi cộng mới sinh ra)
    // =========================================================================
    assign valid_out   = va1 & va2;
    
    // Cờ lỗi tổng hợp
    assign o_overflow  = dly_ovf[L_ADD-1] | ovf_a1 | ovf_a2;
    assign o_underflow = dly_unf[L_ADD-1] | unf_a1 | unf_a2;
    assign o_invalid   = dly_inv[L_ADD-1]; // Giả sử bộ cộng không sinh NaN (Invalid)

endmodule