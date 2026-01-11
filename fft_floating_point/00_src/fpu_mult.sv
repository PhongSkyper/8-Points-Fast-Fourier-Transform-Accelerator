`timescale 1ns/1ps

module fpu_mult (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid_in,
    input  logic [31:0] i_op_a,
    input  logic [31:0] i_op_b,
    output logic        valid_out,
    output logic [31:0] o_res,
    output logic        o_overflow,
    output logic        o_underflow,
    output logic        o_invalid
);

    //=========================================================================
    // STAGE 1: UNPACK & EXECUTE (Giải mã & Nhân thô)
    //=========================================================================
    // Các thanh ghi Pipeline lưu kết quả từ Stage 1 sang Stage 2
    logic        s1_valid;
    logic        s1_sign_res;
    logic [9:0]  s1_exp_temp;
    logic [47:0] s1_prod_raw;
    logic        s1_is_special;
    logic [31:0] s1_res_special;

    // Biến tạm (Logic tổ hợp cục bộ của Stage 1)
    logic s_a, s_b;
    logic [7:0] e_a, e_b;
    logic [22:0] f_a, f_b;
    logic a_is_zero, b_is_zero, a_is_inf, b_is_inf, a_is_nan, b_is_nan;
    logic [23:0] m_a, m_b;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid       <= 1'b0;
            s1_sign_res    <= 1'b0;
            s1_exp_temp    <= 10'd0;
            s1_prod_raw    <= 48'd0;
            s1_is_special  <= 1'b0;
            s1_res_special <= 32'd0;
        end else begin
            // 1.1 Unpack ngay tại đầu vào
            s1_valid <= valid_in;
            
            // Tách các trường (Fields)
            s_a = i_op_a[31]; e_a = i_op_a[30:23]; f_a = i_op_a[22:0];
            s_b = i_op_b[31]; e_b = i_op_b[30:23]; f_b = i_op_b[22:0];
            
            // Detect Special Cases
            a_is_zero = (e_a == 8'd0); 
            b_is_zero = (e_b == 8'd0);
            a_is_inf  = (e_a == 8'hFF) && (f_a == 0); 
            b_is_inf  = (e_b == 8'hFF) && (f_b == 0);
            a_is_nan  = (e_a == 8'hFF) && (f_a != 0); 
            b_is_nan  = (e_b == 8'hFF) && (f_b != 0);

            // 1.2 Tính toán logic chính (Lưu vào Register)
            s1_sign_res <= s_a ^ s_b;
            
            // Tính Exponent: Ea + Eb - 127
            // Dùng 10 bit để tránh tràn số khi cộng
            s1_exp_temp <= {2'b0, e_a} + {2'b0, e_b} - 10'd127;
            
            // Nhân Mantissa 24x24 -> 48 bit
            // Flush-to-Zero: Nếu exp=0 (subnormal) coi như mantissa = 0 (bit ẩn = 0)
            m_a = {~a_is_zero, f_a}; 
            m_b = {~b_is_zero, f_b};
            s1_prod_raw <= m_a * m_b; // <--- ĐIỂM CẮT PIPELINE

            // 1.3 Xử lý trước các case đặc biệt (Priority Logic)
            // Logic này chạy song song với phép nhân
            s1_is_special <= 1'b0; 
            s1_res_special <= 32'd0;

            if (a_is_nan || b_is_nan) begin
                // NaN Inputs -> QNaN
                s1_is_special <= 1'b1; 
                s1_res_special <= {1'b0, 8'hFF, 1'b1, 22'd0}; 
            end else if ((a_is_inf && b_is_zero) || (a_is_zero && b_is_inf)) begin
                // Inf * Zero -> Invalid Operation (NaN)
                s1_is_special <= 1'b1; 
                s1_res_special <= {1'b1, 8'hFF, 1'b1, 22'd0}; 
            end else if (a_is_inf || b_is_inf) begin
                // Inf * Normal -> Inf
                s1_is_special <= 1'b1; 
                s1_res_special <= {(s_a ^ s_b), 8'hFF, 23'd0}; 
            end else if (a_is_zero || b_is_zero) begin
                // Zero * Normal -> Zero
                s1_is_special <= 1'b1; 
                s1_res_special <= {(s_a ^ s_b), 8'd0, 23'd0}; 
            end
        end
    end

    //=========================================================================
    // STAGE 2: NORMALIZE & ROUND (Chuẩn hóa & Làm tròn)
    //=========================================================================
    // Inputs lấy từ Registers của Stage 1
    
    // Biến tạm cho Stage 2
    logic        norm_shift;
    logic [22:0] mant_norm;
    logic        guard, round, sticky, round_up;
    logic [23:0] mant_rounded;
    logic [9:0]  exp_final;
    logic        is_overflow, is_underflow;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out   <= 1'b0;
            o_res       <= 32'd0;
            o_overflow  <= 1'b0;
            o_underflow <= 1'b0;
            o_invalid   <= 1'b0;
        end else begin
            valid_out <= s1_valid;

            if (s1_is_special) begin
                // Nếu Stage 1 báo là case đặc biệt, output luôn
                o_res       <= s1_res_special;
                // Check lại tính chất của kết quả đặc biệt để gán cờ
                // Overflow = Inf, Invalid = NaN
                o_overflow  <= (s1_res_special[30:23] == 8'hFF) && (s1_res_special[22:0] == 0); 
                o_underflow <= 1'b0; 
                o_invalid   <= (s1_res_special[30:23] == 8'hFF) && (s1_res_special[22:0] != 0); 
            end else begin
                // --- Normal Path (Logic chuẩn hóa) ---
                
                // 1. Normalize: Check bit 47
                // Kết quả nhân 1.x * 1.y sẽ nằm trong [1, 4)
                norm_shift = s1_prod_raw[47];
                
                if (norm_shift) begin
                    // Nếu >= 2.0 (bit 47=1), dịch phải 1 bit để về dạng 1.x
                    mant_norm = s1_prod_raw[46:24];
                    guard     = s1_prod_raw[23]; 
                    round     = s1_prod_raw[22]; 
                    sticky    = |s1_prod_raw[21:0];
                end else begin
                    // Nếu < 2.0 (bit 47=0), giữ nguyên
                    mant_norm = s1_prod_raw[45:23];
                    guard     = s1_prod_raw[22]; 
                    round     = s1_prod_raw[21]; 
                    sticky    = |s1_prod_raw[20:0];
                end

                // 2. Round to Nearest Even
                round_up = guard && (round || sticky || mant_norm[0]);
                
                // Cộng bit làm tròn vào mantissa
                mant_rounded = {1'b0, mant_norm} + {23'd0, round_up};

                // 3. Update Exponent
                exp_final = s1_exp_temp;
                if (norm_shift) exp_final = exp_final + 1;
                
                // Nếu làm tròn gây tràn (ví dụ 1.11...1 + 1 -> 10.00...0)
                if (mant_rounded[23]) exp_final = exp_final + 1;

                // 4. Exception Check (Overflow / Underflow)
                // exp_final là 10 bit (signed), check bit dấu [9]
                is_overflow  = (exp_final[9] == 0) && (exp_final >= 10'd255);
                is_underflow = (exp_final[9] == 1) || (exp_final == 0);

                // 5. Final Pack & Output
                if (is_overflow) begin
                    // Tràn -> Inf
                    o_res <= {s1_sign_res, 8'hFF, 23'd0};
                    o_overflow <= 1'b1; o_underflow <= 0;
                end else if (is_underflow) begin
                    // Dưới mức -> Flush to Zero
                    o_res <= {s1_sign_res, 8'd0, 23'd0};
                    o_overflow <= 0; o_underflow <= 1'b1;
                end else begin
                    // Kết quả bình thường
                    o_res <= {s1_sign_res, exp_final[7:0], mant_rounded[22:0]};
                    o_overflow <= 0; o_underflow <= 0;
                end
                o_invalid <= 0;
            end
        end
    end

endmodule