# ============================================================
# DE2 (Cyclone II EP2C35F672C6) PIN ASSIGNMENTS
# Project: FPU Addition/Subtraction
# ============================================================

set_global_assignment -name FAMILY "Cyclone II"
set_global_assignment -name DEVICE EP2C35F672C6

# ============================================================
# CLOCK (50 MHz)s
# ============================================================
set_location_assignment PIN_N2 -to CLOCK_50

# ============================================================
# SWITCHES (SW[17:0])
# Mapping:
# SW[9]: Op, SW[8]: Sign A, SW[7:4]: Exp A, SW[3:0]: Mant A
# ============================================================
set_location_assignment PIN_N25 -to SW[0]
set_location_assignment PIN_N26 -to SW[1]
set_location_assignment PIN_P25 -to SW[2]
set_location_assignment PIN_AE14 -to SW[3]
set_location_assignment PIN_AF14 -to SW[4]
set_location_assignment PIN_AD13 -to SW[5]
set_location_assignment PIN_AC13 -to SW[6]
set_location_assignment PIN_C13 -to SW[7]
set_location_assignment PIN_B13 -to SW[8]
set_location_assignment PIN_A13 -to SW[9]
set_location_assignment PIN_N1 -to SW[10]
set_location_assignment PIN_P1 -to SW[11]
set_location_assignment PIN_P2 -to SW[12]
set_location_assignment PIN_T7 -to SW[13]
set_location_assignment PIN_U3 -to SW[14]
set_location_assignment PIN_U4 -to SW[15]
set_location_assignment PIN_V1 -to SW[16]
set_location_assignment PIN_V2 -to SW[17]

# ============================================================
# RED LEDS (LEDR[17:0])
# Mapping:
# LEDR[9]: Sign S, LEDR[8:5]: Exp S, LEDR[4:0]: Mant S
# ============================================================
set_location_assignment PIN_AE23 -to LEDR[0]
set_location_assignment PIN_AF23 -to LEDR[1]
set_location_assignment PIN_AB21 -to LEDR[2]
set_location_assignment PIN_AC22 -to LEDR[3]
set_location_assignment PIN_AD22 -to LEDR[4]
set_location_assignment PIN_AD23 -to LEDR[5]
set_location_assignment PIN_AD21 -to LEDR[6]
set_location_assignment PIN_AC21 -to LEDR[7]
set_location_assignment PIN_AA14 -to LEDR[8]
set_location_assignment PIN_Y13 -to LEDR[9]
set_location_assignment PIN_AA13 -to LEDR[10]
set_location_assignment PIN_AC14 -to LEDR[11]
set_location_assignment PIN_AD15 -to LEDR[12]
set_location_assignment PIN_AE15 -to LEDR[13]
set_location_assignment PIN_AF13 -to LEDR[14]
set_location_assignment PIN_AE13 -to LEDR[15]
set_location_assignment PIN_AE12 -to LEDR[16]
set_location_assignment PIN_AD12 -to LEDR[17]

# ============================================================
# GREEN LEDS (LEDG[8:0]) - HIỂN THỊ CỜ
# ============================================================
set_location_assignment PIN_AE22 -to LEDG[0]
set_location_assignment PIN_AF22 -to LEDG[1]
set_location_assignment PIN_W19  -to LEDG[2]
# Các chân còn lại (không dùng nhưng cứ khai báo cho đủ bộ)
set_location_assignment PIN_V18  -to LEDG[3]
set_location_assignment PIN_U18  -to LEDG[4]
set_location_assignment PIN_U17  -to LEDG[5]
set_location_assignment PIN_AA20 -to LEDG[6]
set_location_assignment PIN_Y18  -to LEDG[7]
set_location_assignment PIN_Y12  -to LEDG[8]

# ============================================================
# IO Standard Settings
# ============================================================
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to CLOCK_50
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[*]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDR[*]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDG[*]

# Commit assignments
export_assignments