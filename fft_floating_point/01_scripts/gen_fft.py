import math
import random
import struct

# --- CẤU HÌNH ---
N_VEC = 50       # Số lượng vector test
VEC_LEN = 8      # FFT 8 điểm
FILENAME_IN = "fft_input.hex"
FILENAME_EXP = "fft_expected.hex"
PI = 3.141592653589793

def float_to_hex(f):
    """Chuyển số thực sang hex 32-bit IEEE-754 dùng thư viện chuẩn struct"""
    return struct.pack('>f', f).hex()

def manual_dft(in_re, in_im):
    """Tính DFT thủ công (O(N^2))"""
    out_re = [0.0] * VEC_LEN
    out_im = [0.0] * VEC_LEN
    
    for k in range(VEC_LEN):
        sum_re = 0.0
        sum_im = 0.0
        for n in range(VEC_LEN):
            # Góc theta = -2*pi*k*n / N
            angle = -2.0 * PI * k * n / VEC_LEN
            c = math.cos(angle)
            s = math.sin(angle)
            
            # Nhân số phức: (a + jb) * (c + js) 
            # Real = a*c - b*s
            # Imag = a*s + b*c
            re_part = in_re[n] * c - in_im[n] * s
            im_part = in_re[n] * s + in_im[n] * c
            
            sum_re += re_part
            sum_im += im_part
            
        out_re[k] = sum_re
        out_im[k] = sum_im
    return out_re, out_im

print("--- [PYTHON PURE] LOAD duoc python ---")
print(f"Generating {N_VEC} vectors for 8-point FFT...")

try:
    f_in = open(FILENAME_IN, "w")
    f_exp = open(FILENAME_EXP, "w")

    for v in range(N_VEC):
        # 1. Tạo input ngẫu nhiên (-5.0 đến 5.0)
        curr_in_re = []
        curr_in_im = []
        for i in range(VEC_LEN):
            val_re = random.uniform(-5.0, 5.0)
            val_im = random.uniform(-5.0, 5.0)
            curr_in_re.append(val_re)
            curr_in_im.append(val_im)
            
            # Ghi vào file Input (Hex)
            f_in.write(f"{float_to_hex(val_re)} {float_to_hex(val_im)}\n")

        # 2. Tính tay DFT 
        exp_re, exp_im = manual_dft(curr_in_re, curr_in_im)

        # 3. Ghi vào file Expected (Hex)
        for i in range(VEC_LEN):
            f_exp.write(f"{float_to_hex(exp_re[i])} {float_to_hex(exp_im[i])}\n")

    f_in.close()
    f_exp.close()
    print("SUCCESS: Files generated (fft_input.hex, fft_expected.hex)")

except Exception as e:
    print(f"ERROR: {e}")
