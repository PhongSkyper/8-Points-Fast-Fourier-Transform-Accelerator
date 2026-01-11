+incdir+fft_floating_point/00_src

# FPU base (combinational)
fft_floating_point/00_src/fpu_basic_lib.sv
fft_floating_point/00_src/fpu_unpack_pretest.sv
fft_floating_point/00_src/fpu_exponent_subtractor.sv
fft_floating_point/00_src/fpu_swap_operands.sv
fft_floating_point/00_src/fpu_sign_computation.sv
fft_floating_point/00_src/fpu_align_shift_right.sv
fft_floating_point/00_src/fpu_sig_add_sub.sv
fft_floating_point/00_src/fpu_normalization.sv
fft_floating_point/00_src/fpu_special_case.sv
fft_floating_point/00_src/fpu_add_sub_top.sv
fft_floating_point/00_src/fpu_mult.sv

# FPU pipelined
fft_floating_point/00_src/fpu_add_sub_pipe.sv
fft_floating_point/00_src/fpu_mult_pipe.sv
fft_floating_point/00_src/complex_mult_pipe.sv

# FFT support blocks
fft_floating_point/00_src/rom_twiddle.sv
fft_floating_point/00_src/fft_control.sv
fft_floating_point/00_src/idx_gen_8pt.sv
fft_floating_point/00_src/buf_bank.sv
fft_floating_point/00_src/bf_input_latch.sv
fft_floating_point/00_src/twiddle_pipe.sv
fft_floating_point/00_src/bf_compute.sv
fft_floating_point/00_src/addr_pipe.sv
fft_floating_point/00_src/bf_top_single.sv
fft_floating_point/00_src/fft_8point_top.sv
fft_floating_point/00_src/butterfly_unit_pipe.sv

# fft_floating_point/00_src/fpu_wrapper.sv

fft_floating_point/04_tb/tb_fft_8point_top.sv