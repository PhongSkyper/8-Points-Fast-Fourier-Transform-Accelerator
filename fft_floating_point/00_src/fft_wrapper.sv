// Top-level Wrapper cho Kit DE2 (Đã sửa giao tiếp)
module fft_wrapper (
    input  logic        CLOCK_50,    // 50 MHz Clock
    input  logic [3:0]  KEY,         // Push buttons (Active Low)
    input  logic [17:0] SW,          // Toggle Switches
    output logic [17:0] LEDR,        // Red LEDs
    output logic [8:0]  LEDG,        // Green LEDs
    output logic [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7 // 7-Segment
);

    // --- 1. Tín hiệu nội bộ & Xử lý nút nhấn ---
    logic i_clk;
    assign i_clk = CLOCK_50;

    logic i_rst_n;
    assign i_rst_n = KEY[0]; // Active low

    logic i_start;
    assign i_start = ~KEY[1]; // Nhấn KEY1 -> Start = 1

    // --- 2. Khai báo tín hiệu kết nối FFT Core ---
    logic [31:0] load_re, load_im; // Dữ liệu nạp vào
    logic        load_en;          // Lệnh nạp
    logic        o_done;           // FFT báo xong
    
    // Tín hiệu đầu ra từ FFT
    logic        fft_out_valid;    // Tương đương o_valid từ core
    logic [31:0] fft_out_re, fft_out_im; 

    // Tín hiệu phụ trợ cho Wrapper
    logic [2:0]  cur_idx;       // Index đang nạp (hiển thị LED)
    logic [2:0]  out_wr_addr;   // Địa chỉ tự sinh để lưu kết quả ra
    
    // --- 3. Instantiate FFT Core (ĐÃ SỬA MAPPING) ---
    fft_8point_top #(
        .L_MUL(2), 
        .L_ADD(2)
    ) u_fft (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_start(i_start),
        
        // Input Interface
        .i_valid(load_en),    // Wrapper: load_en -> Core: i_valid
        .i_re(load_re),       // Wrapper: load_re -> Core: i_re
        .i_im(load_im),       // Wrapper: load_im -> Core: i_im
        
        // Output Interface
        .o_valid(fft_out_valid), // Core: o_valid -> Wrapper nhận
        .o_re(fft_out_re),       // Core: o_re    -> Wrapper nhận
        .o_im(fft_out_im),       // Core: o_im    -> Wrapper nhận
        .o_done(o_done)
    );

    // --- 4. Logic Nạp dữ liệu cứng (FSM) ---
    typedef enum logic [1:0] {IDLE, LOADING, DONE_LOAD} state_t;
    state_t state, next_state;
    logic [3:0] load_cnt; // Đếm số mẫu đã nạp (0..7)

    // Cập nhật trạng thái
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state <= IDLE;
            load_cnt <= 0;
        end else begin
            state <= next_state;
            if (state == IDLE)
                load_cnt <= 0;
            else if (state == LOADING) 
                load_cnt <= load_cnt + 1;
        end
    end

    // Logic chuyển trạng thái
    always_comb begin
        next_state = state;
        load_en = 1'b0;
        
        case (state)
            IDLE: begin
                if (i_start) next_state = LOADING;
            end
            LOADING: begin
                load_en = 1'b1;
                // Nạp đủ 8 mẫu (0-7), khi counter lên 7 là mẫu cuối cùng
                if (load_cnt == 4'd7) next_state = DONE_LOAD; 
            end
            DONE_LOAD: begin
                load_en = 1'b0;
                if (!i_start) next_state = IDLE;
            end
        endcase
    end

    // LUT dữ liệu đầu vào
    always_comb begin
        load_re = '0;
        load_im = '0;
        if (load_en) begin
            case (load_cnt[2:0])
                3'd0: begin load_re = 32'h4036A800; load_im = 32'hC01E1800; end
                3'd1: begin load_re = 32'h3F544000; load_im = 32'h40DEFC00; end
                3'd2: begin load_re = 32'h40C3A400; load_im = 32'h4124CA00; end
                3'd3: begin load_re = 32'h40991000; load_im = 32'h40526800; end
                3'd4: begin load_re = 32'hC06BB800; load_im = 32'h41170400; end
                3'd5: begin load_re = 32'h41162C00; load_im = 32'h40941400; end
                3'd6: begin load_re = 32'h400ED000; load_im = 32'h40D58000; end
                3'd7: begin load_re = 32'hBF118000; load_im = 32'h3F93C000; end
                default: begin load_re = '0; load_im = '0; end
            endcase
        end
    end

    // --- 5. Bộ đệm kết quả (Result Buffer) ---
    // Do Core không xuất địa chỉ, ta tự tạo bộ đếm địa chỉ ghi (out_wr_addr)
    // Core DIT của bạn xuất tuần tự (Natural Order), nên chỉ cần đếm 0->7 khi có valid.
    
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            out_wr_addr <= 0;
        end else begin
            if (i_start) begin
                out_wr_addr <= 0; // Reset khi bắt đầu tính mới
            end else if (fft_out_valid) begin
                out_wr_addr <= out_wr_addr + 1;
            end
        end
    end

    logic [31:0] res_re_mem [7:0];
    logic [31:0] res_im_mem [7:0];

    always_ff @(posedge i_clk) begin
        if (fft_out_valid) begin
            res_re_mem[out_wr_addr] <= fft_out_re;
            res_im_mem[out_wr_addr] <= fft_out_im;
        end
    end

    // --- 6. Hiển thị ra LED & HEX ---
    assign LEDG[0] = o_done;      
    assign LEDG[1] = load_en;     
    
    // Wrapper tự quản lý cur_idx dựa trên load_cnt
    assign cur_idx = load_cnt[2:0]; 
    assign LEDR[2:0] = cur_idx;   

    // MUX chọn dữ liệu hiển thị (SW[2:0] chọn index, SW[17] chọn Real/Imag)
    logic [31:0] data_to_show;
    logic [2:0]  sel_idx;
    logic        sel_type; 

    assign sel_idx  = SW[2:0];  
    assign sel_type = SW[17];   

    assign data_to_show = (sel_type) ? res_im_mem[sel_idx] : res_re_mem[sel_idx];

    // Module giải mã hiển thị HEX
    function logic [6:0] get_hex(input logic [3:0] val);
        case (val)
            4'h0: return 7'b1000000; 4'h1: return 7'b1111001; 4'h2: return 7'b0100100; 4'h3: return 7'b0110000;
            4'h4: return 7'b0011001; 4'h5: return 7'b0010010; 4'h6: return 7'b0000010; 4'h7: return 7'b1111000;
            4'h8: return 7'b0000000; 4'h9: return 7'b0010000; 4'hA: return 7'b0001000; 4'hB: return 7'b0000011;
            4'hC: return 7'b1000110; 4'hD: return 7'b0100001; 4'hE: return 7'b0000110; 4'hF: return 7'b0001110;
            default: return 7'b1111111;
        endcase
    endfunction

    assign HEX7 = get_hex(data_to_show[31:28]);
    assign HEX6 = get_hex(data_to_show[27:24]);
    assign HEX5 = get_hex(data_to_show[23:20]);
    assign HEX4 = get_hex(data_to_show[19:16]);
    assign HEX3 = get_hex(data_to_show[15:12]);
    assign HEX2 = get_hex(data_to_show[11:8]);
    assign HEX1 = get_hex(data_to_show[7:4]);
    assign HEX0 = get_hex(data_to_show[3:0]);

endmodule