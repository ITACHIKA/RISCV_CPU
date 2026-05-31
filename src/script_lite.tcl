# remove_wave /cpu_tb/*
remove_wave -of [get_wave_config] \
    [get_waves -of [get_wave_config] -regexp ".*"]
add_wave /cpu_tb/uut/clk
add_wave /cpu_tb/uut/reset_n
add_wave /cpu_tb/uut/cycle_counter
add_wave /cpu_tb/uut/registers/registers
add_wave /cpu_tb/uut/dmem/data_ram
add_wave /cpu_tb/uut/imem/instruction
restart
run 1us