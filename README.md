# 8-Point FFT with Floating-Point Arithmetic

An 8-point Fast Fourier Transform (FFT) implementation using custom floating-point arithmetic on FPGA.

## Project Description

This project implements an 8-point FFT algorithm using Radix-2 Decimation-In-Time (DIT) architecture with custom floating-point computation modules.

### Key Features:
- 8-point FFT with high precision
- Custom Floating-Point arithmetic units
- Pipelined architecture for improved performance
- Support for Cyclone V FPGA (DE10-Standard Board)

## Project Structure

```
├── docs/                           # Documentation and reports
│   ├── fft_guideline.pdf          # FFT implementation guide
│   └── L01_NHÓM 3_BTL2.pdf        # Project report
│
├── fft_floating_point/             # Main project directory
│   ├── 00_src/                     # SystemVerilog source files
│   │   ├── fft_8point_top.sv      # FFT top-level module
│   │   ├── fft_wrapper.sv          # FFT wrapper module
│   │   ├── fft_control.sv          # FFT control module
│   │   ├── butterfly_unit_pipe.sv  # Butterfly computation unit
│   │   ├── bf_compute.sv           # Butterfly compute logic
│   │   ├── complex_mult_pipe.sv    # Complex multiplication pipeline
│   │   ├── fpu_*.sv                # FPU (Floating-Point Unit) modules
│   │   ├── rom_twiddle.sv          # ROM for twiddle factors
│   │   └── de10.sdc                # Timing constraints file
│   │
│   ├── 04_tb/                      # Testbench and simulation
│   │   └── filelist.f             # File list for simulation
│   │
│   ├── 8_points_fft.qpf            # Quartus Prime Project File
│   └── 8_points_fft.qsf            # Quartus Settings File
│
└── .gitignore                      # Git ignore file
```

## Main Modules

### 1. FFT Top Module (`fft_8point_top.sv`)
The top-level module for 8-point FFT, integrating all butterfly stages.

#### I/O Interface

| Port Name | Direction | Width | Type | Description |
|-----------|-----------|-------|------|-------------|
| **Clock & Reset** | | | | |
| `i_clk` | Input | 1 | logic | System clock |
| `i_rst_n` | Input | 1 | logic | Asynchronous active-low reset |
| **Control Signals** | | | | |
| `i_start` | Input | 1 | logic | Start FFT computation |
| `i_valid` | Input | 1 | logic | Input data valid signal (8 cycles) |
| `o_valid` | Output | 1 | logic | Output data valid signal |
| `o_done` | Output | 1 | logic | FFT computation complete |
| **Input Data** | | | | |
| `i_re` | Input | 32 | logic | Input real part (IEEE 754 single-precision) |
| `i_im` | Input | 32 | logic | Input imaginary part (IEEE 754 single-precision) |
| **Output Data** | | | | |
| `o_re` | Output | 32 | logic | Output real part (IEEE 754 single-precision) |
| `o_im` | Output | 32 | logic | Output imaginary part (IEEE 754 single-precision) |

#### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `L_MUL` | 2 | Pipeline depth for floating-point multiplication |
| `L_ADD` | 2 | Pipeline depth for floating-point addition/subtraction |

#### Operation Sequence

1. **Reset**: Assert `i_rst_n = 0` to initialize
2. **Start**: Assert `i_start = 1` to begin FFT computation
3. **Input**: Provide 8 complex samples with `i_valid = 1` for 8 consecutive cycles
4. **Processing**: Internal pipeline processes data (latency = 1 + L_MUL + 2*L_ADD cycles)
5. **Output**: 8 complex frequency-domain samples appear with `o_valid = 1`
6. **Complete**: `o_done = 1` indicates FFT operation finished

### 2. Floating-Point Units
- `fpu_mult_pipe.sv` - FPU multiplication with pipeline
- `fpu_add_sub_pipe.sv` - FPU addition/subtraction with pipeline
- `complex_mult_pipe.sv` - Complex number multiplication

### 3. Butterfly Unit (`butterfly_unit_pipe.sv`)
Implements the basic FFT butterfly computation with pipeline optimization.

### 4. Control Logic (`fft_control.sv`)
Controls data flow and synchronizes FFT stages.

## Requirements

### Hardware:
- FPGA Cyclone V (DE10-Standard Board) or equivalent
- LEs: 50,000 logic elements
- Registers: 

### Software:
- Intel Quartus Prime (version 20.1)
- Cadence Xcelium (for simulation)
- Cadence Simvision (for waveform viewing)
- Python 3.x (for scripts and testbench generation)

## Getting Started

### 1. Clone repository

```bash
git clone https://github.com/PhongSkyper/8-Points-Fast-Fourier-Transform-Accelerator.git
cd 8-Points-Fast-Fourier-Transform-Accelerator
```

### 2. Open project in Quartus

```bash
cd fft_floating_point
# Open 8_points_fft.qpf in Quartus Prime
```

### 3. Compile project

1. In Quartus Prime, select **Processing → Start Compilation**
2. Or use command line:
   ```bash
   quartus_sh --flow compile 8_points_fft
   ```

### 4. Run Simulation

```bash
cd fft_floating_point/04_tb
# Run simulation with Xcelium
xrun -f filelist.f +access+r
# View waveforms with Simvision
simvision waves.shm
```

## Specifications

- **FFT Points**: 8
- **Data Format**: 32-bit Floating-Point (IEEE 754)
- **Architecture**: Radix-2 DIT with pipeline
- **Latency**: ~50 cycles
- **Operating Frequency**: Up to 100 MHz (on Cyclone V)

## Documentation

See more in the [docs/](docs/) directory:
- `fft_guideline.pdf` - Detailed FFT implementation guide
- `L01_NHÓM 3_BTL2.pdf` - Full project report

## Authors

**Group 3 - L01**

## License

This project is developed for educational and research purposes. See [LICENSE](LICENSE) for more details.

---

## TODO / Future Improvements

- [ ] Add automated testbenches
- [ ] Optimize timing for higher frequency operation
- [ ] Support flexible FFT sizes (16, 32, 64, ...)
- [ ] Integrate AXI interface
- [ ] Add detailed architecture documentation
