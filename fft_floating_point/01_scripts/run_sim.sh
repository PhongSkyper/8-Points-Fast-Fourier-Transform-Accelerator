#!/bin/bash

# Dọn dẹp file rác tại chỗ
rm -rf xcelium.d waves.shm *.log *.history *.hex

echo "--- STARTING SIMULATION FROM 01_SCRIPTS ---"

# 1. Chạy Python 
if command -v python3 &> /dev/null; then
    python3 gen_fft.py 
else
    python gen_fft.py
fi

# 2. Kiểm tra file hex
if [ ! -f fft_input.hex ]; then
    echo "ERROR: Hex files not generated!"
    exit 1
fi

# 3. Chạy Xcelium
# trỏ đến filelist nằm ở thư mục 04_tb
xrun -64bit -sv -access +rwc \
    -f ../04_tb/filelist.f \
    -l sim.log

echo "--- DONE ---"