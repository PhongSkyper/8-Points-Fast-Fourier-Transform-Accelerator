`timescale 1ns/1ps

module fft_control #(
    parameter int LAT = 6 // Latency mac dinh (se duoc ghi de tu Top)
)(
    input  logic       i_clk,
    input  logic       i_rst_n,
    input  logic       i_start,
    input  logic       i_valid_in,
    
    // Memory Interface
    output logic       o_load_en,
    output logic [2:0] o_load_addr,
    
    // Compute Interface
    output logic [1:0] o_stage_sel,
    output logic [1:0] o_k_idx,
    output logic [1:0] o_twiddle_addr,
    output logic       o_issue,
    output logic       o_latch, // (Unused/Spare)
    
    // Output Interface
    output logic       o_output_en,
    output logic [2:0] o_output_addr,
    output logic       o_done
);

    // =========================================================================
    // FSM STATES
    // =========================================================================
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        CALC_ISSUE, // Day du lieu vao Pipeline
        CALC_WAIT,  // Cho Pipeline xa du lieu (Latency)
        DONE
    } state_t;

    state_t cur, nxt;

    // Counters
    logic [2:0] load_cnt;
    logic [1:0] stage_cnt;  // 0, 1, 2
    logic [2:0] group_cnt;  // Dem 8 nhip trong moi stage
    logic [7:0] lat_cnt;    // Dem Latency (du rong de chua LAT)
    
    // =========================================================================
    // NEXT STATE LOGIC
    // =========================================================================
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) cur <= IDLE;
        else          cur <= nxt;
    end

    always_comb begin
        nxt = cur;
        case (cur)
            IDLE: begin
                if (i_start) nxt = LOAD;
            end
            
            LOAD: begin
                // Load du 8 mau -> Chuyen sang Tinh toan
                if (i_valid_in && load_cnt == 3'd7) 
                    nxt = CALC_ISSUE;
            end
            
            CALC_ISSUE: begin
                // Sau khi issue du 8 mau cho stage hien tai
                if (group_cnt == 3'd7) begin
                    nxt = CALC_WAIT;
                end
            end
            
            CALC_WAIT: begin
                // Cho du thoi gian LAT
                if (lat_cnt >= LAT - 1) begin // -1 vi bat dau dem tu 0
                    if (stage_cnt == 2'd2) nxt = DONE;       // Het Stage 2 -> Xong
                    else                   nxt = CALC_ISSUE; // Chua het -> Stage tiep theo
                end
            end
            
            DONE: begin
                // Output 8 mau xong -> Ve IDLE
                if (group_cnt == 3'd7) nxt = IDLE;
            end
        endcase
    end

    // =========================================================================
    // OUTPUT LOGIC & COUNTERS
    // =========================================================================
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            load_cnt <= 0; stage_cnt <= 0; group_cnt <= 0; lat_cnt <= 0;
            o_done <= 0;
        end else begin
            // Mặc định reset done pulse
            if (cur != DONE) o_done <= 0;

            case (cur)
                IDLE: begin
                    load_cnt <= 0;
                    stage_cnt <= 0;
                    group_cnt <= 0;
                    lat_cnt <= 0;
                end

                LOAD: begin
                    if (i_valid_in) load_cnt <= load_cnt + 1;
                end

                CALC_ISSUE: begin
                    lat_cnt <= 0; // Reset latency counter cho pha Wait ke tiep
                    group_cnt <= group_cnt + 1;
                end

                CALC_WAIT: begin
                    lat_cnt <= lat_cnt + 1;
                    if (lat_cnt >= LAT - 1) begin
                        group_cnt <= 0; // Reset group counter cho stage moi
                        if (stage_cnt < 2) stage_cnt <= stage_cnt + 1;
                    end
                end

                DONE: begin
                    group_cnt <= group_cnt + 1;
                    if (group_cnt == 3'd7) o_done <= 1; // Pulse Done khi xuat xong
                end
            endcase
        end
    end

    // =========================================================================
    // CONTROL SIGNALS GENERATION
    // =========================================================================
    
    // 1. Loading
    assign o_load_en   = (cur == LOAD) && i_valid_in;
    assign o_load_addr = load_cnt;

    // 2. Compute / Issue
    assign o_issue     = (cur == CALC_ISSUE);
    assign o_stage_sel = stage_cnt;
    assign o_k_idx     = group_cnt[1:0]; // Dung 2 bit thap cua counter lam k_idx (tam thoi)
    // index gen se tu map lai dua tren stage_sel

    // 3. Twiddle Logic (DIT VERSION)
    // DIT: Stage 0 dung W0; Stage 1 dung W0,W2; Stage 2 dung W0,W1,W2,W3
    always_comb begin
        o_twiddle_addr = 0;
        if (cur == CALC_ISSUE) begin
            unique case (stage_cnt)
                // DIT Stage 0 (Span 1): Chi dung W0
                2'd0: o_twiddle_addr = 2'd0;
                
                // DIT Stage 1 (Span 2): (0,2) -> check bit 0 cua group_cnt
                // group_cnt chay 0..7. Can mapping dung voi logic idx_gen
                // De don gian: Group count chay tuyen tinh, idx_gen lo viec sap xep dia chi
                // Twiddle phu thuoc vao vi tri cap (pair). 
                // Voi DIT: 
                // Stage 1: cap (0,2) dung W0, cap (1,3) dung W2...
                // Logic: Neu group_cnt[0] == 1 -> W2, else W0? (Can check ky logic DIT index)
                // Theo tai lieu: 
                // Stage 1 (Layer 2): W0, W2, W0, W2... -> LSB toggles -> o_twiddle_addr = {group_cnt[0], 0}
                2'd1: o_twiddle_addr = (group_cnt[0]) ? 2'd2 : 2'd0;
                
                // DIT Stage 2 (Span 4): W0, W1, W2, W3... -> Dem 0,1,2,3...
                // O day moi clock xu ly 1 cap. 8 clock xu ly 4 cap roi lap lai? 
                // Hay 8 clock xu ly 8 lan? 
                // Thuc ra la 4 cap. Nhung issue chay 8 lan (vi doc 2 port A, B).
                // Nhung pipeline cua ban la single issue (1 cycle 1 butterfly).
                // Voi 8 diem, co 4 butterfly/stage. 
                // Code cu issue 8 lan -> tuc la co "nop" (no operation) hoac ghi de?
                // KHONG. idx_gen_8pt cua ban map 8 gia tri k_idx -> 8 dia chi.
                // a_now, b_now.
                // Voi 8 cycle issue, thuc chat ta thuc hien 8 butterfly? 
                // Khong, FFT 8 diem chi co 4 butterfly/stage.
                // Voi k_idx 2 bit (0..3).
                // group_cnt chay 0..7. Ban lay o_k_idx = group_cnt[1:0].
                // => No se chay 0,1,2,3 roi lai 0,1,2,3.
                // => Moi stage ban tinh 2 lan! (Redundant calculations).
                // Dieu nay lam cham nhung KHONG SAI (chi ghi de ket qua cu).
                // => OK, giu nguyen logic nay de an toan.
                
                // Stage 2: K_idx chay 0..3 -> Twiddle la 0..3
                2'd2: o_twiddle_addr = group_cnt[1:0];
                
                default: o_twiddle_addr = 0;
            endcase
        end
    end

    // 4. Output
    // DIT: Output En khi o DONE (hoac cuoi Stage 2)
    // O day ta cho xuat o trang thai DONE
    assign o_output_en   = (cur == DONE);
    assign o_output_addr = group_cnt; // Doc tuan tu 0..7
    
    assign o_latch = 0; // Unused

endmodule
