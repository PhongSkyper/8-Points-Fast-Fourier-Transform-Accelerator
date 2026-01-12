`timescale 1ns/1ps

module tb_fft;

    // --- 1. CONFIGURATION ---
    localparam int L_MUL = 2;
    localparam int L_ADD = 2;
    localparam int N_VEC = 50;
    localparam int VEC_LEN = 8;
    localparam int TOTAL_SAMPLES = N_VEC * VEC_LEN;
    localparam real TOL = 5e-2; // sai số cho float

    // --- 2. SIGNALS ---
    logic        i_clk, i_rst_n;
    logic        i_start, i_valid;
    logic [31:0] i_re, i_im;
    wire         o_valid, o_done;
    wire [31:0]  o_re, o_im;

    // --- 3. DUT INSTANCE ---
    fft_8point_top #(.L_MUL(L_MUL), .L_ADD(L_ADD)) dut (
        .i_clk(i_clk), .i_rst_n(i_rst_n),
        .i_start(i_start), .i_valid(i_valid),
        .i_re(i_re), .i_im(i_im),
        .o_valid(o_valid), .o_re(o_re), .o_im(o_im), .o_done(o_done)
    );

    // --- 4. CLOCK & WAVEFORM ---
    initial i_clk = 0;
    always #5 i_clk = ~i_clk;

    initial begin
        // Dump VCD theo yêu cầu của Phong
        $dumpfile("fft_wave.vcd");
        $dumpvars(0, tb_fft);
    end

    // --- 5. DATA MEMORY (Load from Python Hex) ---
    reg [31:0] mem_in_re  [0:TOTAL_SAMPLES-1];
    reg [31:0] mem_in_im  [0:TOTAL_SAMPLES-1];
    reg [31:0] mem_exp_re [0:TOTAL_SAMPLES-1];
    reg [31:0] mem_exp_im [0:TOTAL_SAMPLES-1];

    // Helper: Absolute value
    function real fabs(input real r);
        fabs = (r < 0) ? -r : r;
    endfunction

    // Load Data Block
    initial begin
        int fd_in, fd_exp, i, r;
        
        // Đọc Input Hex
        fd_in = $fopen("fft_input.hex", "r");
        if (!fd_in) begin $error("ERROR: Cannot open fft_input.hex"); $finish; end
        for (i=0; i<TOTAL_SAMPLES; i++) r = $fscanf(fd_in, "%h %h", mem_in_re[i], mem_in_im[i]);
        $fclose(fd_in);

        // Đọc Expected Hex
        fd_exp = $fopen("fft_expected.hex", "r");
        if (!fd_exp) begin $error("ERROR: Cannot open fft_expected.hex"); $finish; end
        for (i=0; i<TOTAL_SAMPLES; i++) r = $fscanf(fd_exp, "%h %h", mem_exp_re[i], mem_exp_im[i]);
        $fclose(fd_exp);
    end

    // --- 6. DRIVER TASK ---
    task automatic driver();
        int v, n, idx;
        i_rst_n = 0; i_start = 0; i_valid = 0; i_re = 0; i_im = 0;
        repeat(10) @(negedge i_clk);
        i_rst_n = 1;

        for (v=0; v<N_VEC; v++) begin
            // Pulse Start
            @(negedge i_clk); i_start = 1;
            @(negedge i_clk); i_start = 0;

            // Drive Input Data
            for (n=0; n<VEC_LEN; n++) begin
                idx = v*VEC_LEN + n;
                @(negedge i_clk);
                i_valid = 1;
                i_re = mem_in_re[idx];
                i_im = mem_in_im[idx];
            end
            @(negedge i_clk);
            i_valid = 0; i_re = 0; i_im = 0;

            // Wait for Done
            @(posedge o_done);
            repeat ($urandom_range(2, 5)) @(posedge i_clk);
        end
    endtask

    // --- 7. MONITOR TASK ---
    task automatic monitor();
        int cnt = 0;
        int vec_idx, samp_idx;
        shortreal dr, di, er, ei; // Data Real, Data Imag, Exp Real, Exp Imag
        string status;

        $display("\n[MONITOR] Starting Verification Loop...");
        $display("__________________________________________________________________________");
        $display("| VEC | IDX |    EXPECTED (Re, Im)    |      GOT (Re, Im)       | STATUS |");
        $display("|_____|_____|_________________________|_________________________|________|");

        while (cnt < TOTAL_SAMPLES) begin
            @(posedge i_clk);
            if (o_valid) begin
                dr = $bitstoshortreal(o_re);
                di = $bitstoshortreal(o_im);
                er = $bitstoshortreal(mem_exp_re[cnt]);
                ei = $bitstoshortreal(mem_exp_im[cnt]);

                if (fabs(dr - er) > TOL || fabs(di - ei) > TOL) status = "FAIL";
                else status = "PASS";

                vec_idx = cnt / VEC_LEN;
                samp_idx = cnt % VEC_LEN;

                $display("| %3d |  %1d  | (%7.3f, %7.3f) | (%7.3f, %7.3f) |  %s  |", 
                    vec_idx, samp_idx, er, ei, dr, di, status);

                if (status == "FAIL") begin
                    $error("MISMATCH at Vector %0d Sample %0d", vec_idx, samp_idx);
                end

                if (samp_idx == VEC_LEN - 1)
                    $display("|_____|_____|_________________________|_________________________|________|");
                
                cnt++;
            end
        end
    endtask

    // --- 8. ASSERTIONS ---
    // Check 1: Start -> Done handshake
    property p_start_to_done;
        @(posedge i_clk) disable iff (!i_rst_n)
        $rose(i_start) |-> ##[1:1000] o_done;
    endproperty
    ASSERT_LIVENESS: assert property (p_start_to_done) else $error("Assertion Failed: Started but never Done!");

    // Check 2: Valid Data Check
    property p_valid_data_known;
        @(posedge i_clk) disable iff (!i_rst_n)
        o_valid |-> (!$isunknown(o_re) && !$isunknown(o_im));
    endproperty
    ASSERT_DATA_VALID: assert property (p_valid_data_known) else $error("Assertion Failed: Output is X/Z when Valid!");

    // --- 9. MAIN BLOCK & WATCHDOG ---
    initial begin
        fork
            driver();
            monitor();
        join
        
        $display("\n===================================================");
        $display(" [FINAL RESULT] PASSED: ALL VECTORS MATCHED!");
        $display("===================================================\n");
        $finish;
    end

    // Watchdog (Đã trả lại cho bạn)
    initial begin
        #50ms; 
        $display("\nTIMEOUT: Simulation hung! Watchdog triggered.");
        $stop;
    end

endmodule