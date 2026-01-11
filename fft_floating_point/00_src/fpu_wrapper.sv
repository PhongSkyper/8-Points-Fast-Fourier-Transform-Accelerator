`timescale 1ns/1ps

// ============================================================================
// MODULE: FPU DE2 WRAPPER (EXPLICIT VERSION)
// Mục tiêu: Kết nối Switch/LED của Kit DE2 vào bộ FPU Core
// ============================================================================

module fpu_wrapper (
    input  logic [17:0] SW,   // 18 Switch đầu vào
    output logic [17:0] LEDR, // 18 Đèn LED Đỏ (Hiển thị kết quả)
    output logic [8:0]  LEDG  // 9 Đèn LED Xanh (Hiển thị Cờ)
);

    // ========================================================================
    // 1. ĐỊNH NGHĨA TÍN HIỆU NỘI BỘ (INTERNAL SIGNALS)
    // ========================================================================
    
    // Tín hiệu giao tiếp với FPU
    logic [31:0] i_a;           // Toán hạng A (Từ Switch)
    logic [31:0] i_b;           // Toán hạng B (Hằng số)
    logic        i_add_sub;     // Lệnh điều khiển
    logic [31:0] o_z;           // Kết quả đầu ra
    logic        ov_flag;       // Cờ tràn
    logic        un_flag;       // Cờ dưới mức
    logic        zero_flag;     // Cờ không

    // Các thành phần cấu tạo nên số A (Để code tường minh hơn)
    logic        sign_a;        // Dấu của A
    logic [7:0]  exp_a;         // Số mũ của A
    logic [22:0] mant_a;        // Phần thập phân của A

    // Hằng số B = 20.25 (IEEE-754 Hex representation)
    localparam [31:0] CONST_B = 32'h41A20000;   // 32'h41A00000; 

    // ========================================================================
    // 2. XỬ LÝ ĐẦU VÀO (INPUT MAPPING)
    // ========================================================================

    // --- 2.1. Toán hạng B (Cố định) ---
    assign i_b = CONST_B;

    // --- 2.2. Điều khiển Phép toán ---
    assign i_add_sub = SW[9]; // 0: Cộng, 1: Trừ

    // --- 2.3. Xây dựng Toán hạng A từ Switch ---
    // SW[8]: Bit Dấu
    assign sign_a = SW[8];

    // Exponent (8 bit):
    // - 4 bit cao: FIX CỨNG là '1000' (Số 8) để A cùng bậc độ lớn với B.
    // - 4 bit thấp: Lấy từ SW[7:4].
    assign exp_a = {4'b1000, SW[7:4]};

    // Mantissa (23 bit):
    // - 4 bit cao: Lấy từ SW[3:0].
    // - 19 bit thấp: Padding số 0.
    assign mant_a = {SW[3:0], 1'b0, 1'b1, 17'd0};

    // Gộp lại thành số thực 32-bit hoàn chỉnh
    assign i_a = {sign_a, exp_a, mant_a};


    // ========================================================================
    // 3. KHỞI TẠO FPU CORE (INSTANTIATION)
    // ========================================================================
    fpu_add_sub_top u_core (
        .i_a         (i_a),
        .i_b         (i_b),
        .i_add_sub   (i_add_sub),
        .o_z         (o_z),
        .o_overflow  (ov_flag),
        .o_underflow (un_flag),
        .o_zero      (zero_flag)
    );


    // ========================================================================
    // 4. XỬ LÝ ĐẦU RA (OUTPUT MAPPING)
    // ========================================================================

    // --- 4.1. LED Đỏ (Hiển thị các bit quan trọng của kết quả) ---
    
    // LEDR[9]: Bit Dấu (Bit 31)
    assign LEDR[9] = o_z[31];

    // LEDR[8:5]: 4 bit giữa của Exponent (Bit 27 đến 24)
    assign LEDR[8:5] = o_z[27:24];

    // LEDR[4:0]: Hiển thị hỗn hợp (Bit 23 đến 20)
    // Cụ thể: Bit 23 (Exp LSB) và Bit 22-20 (Mantissa High)
    // Lưu ý: LEDR[4] được gán 0 để tránh warning lệch size (5 bit vs 4 bit)
    assign LEDR[4]   = 1'b0;       // Padding tắt đèn số 4
    assign LEDR[3:0] = o_z[23:20]; // 4 bit dữ liệu thực tế

    // Các LEDR còn lại không dùng -> Tắt hết
    assign LEDR[17:10] = 8'd0;


    // --- 4.2. LED Xanh (Hiển thị Cờ trạng thái) ---
    
    assign LEDG[2] = ov_flag;   // Tràn số (Overflow)
    assign LEDG[1] = un_flag;   // Dưới mức (Underflow)
    assign LEDG[0] = zero_flag; // Kết quả bằng 0 (Zero)

    // Các LEDG còn lại tắt
    assign LEDG[8:3] = 6'd0;

endmodule