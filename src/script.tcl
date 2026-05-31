#remove_wave /cpu_tb/*
remove_wave -of [get_wave_config] \
    [get_waves -of [get_wave_config] -regexp ".*"]
add_wave -recursive /cpu_tb/uut/*
restart
run 1us