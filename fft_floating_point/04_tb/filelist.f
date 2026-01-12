+incdir+../00_src

// 2. FPU base (combinational)
../00_src/fpu_basic_lib.sv
../00_src/fpu_unpack_pretest.sv
../00_src/fpu_exponent_subtractor.sv
../00_src/fpu_swap_operands.sv
../00_src/fpu_sign_computation.sv
../00_src/fpu_align_shift_right.sv
../00_src/fpu_sig_add_sub.sv
../00_src/fpu_normalization.sv
../00_src/fpu_special_case.sv
../00_src/fpu_add_sub_top.sv
../00_src/fpu_mult.sv

// 3. FPU pipelined
../00_src/fpu_add_sub_pipe.sv
../00_src/fpu_mult_pipe.sv
../00_src/complex_mult_pipe.sv

// 4. FFT support blocks
../00_src/rom_twiddle.sv
../00_src/fft_control.sv
../00_src/idx_gen_8pt.sv
../00_src/buf_bank.sv
../00_src/bf_input_latch.sv
../00_src/twiddle_pipe.sv
../00_src/bf_compute.sv
../00_src/addr_pipe.sv
../00_src/bf_top_single.sv
../00_src/fft_8point_top.sv
../00_src/butterfly_unit_pipe.sv

// 5. Testbench
../04_tb/tb_fft.sv