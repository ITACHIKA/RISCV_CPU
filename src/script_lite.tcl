# remove_wave /cpu_tb/*
remove_wave -of [get_wave_config] \
    [get_waves -of [get_wave_config] -regexp ".*"]
add_wave /cpu_tb/uut/clk
add_wave /cpu_tb/uut/reset_n
add_wave /cpu_tb/uut/soc/core/pipeline_regs/if_id_reg_q
add_wave /cpu_tb/uut/soc/core/pipeline_regs/id_ex_reg_q
add_wave /cpu_tb/uut/soc/core/pipeline_regs/ex_mem_reg_q
add_wave /cpu_tb/uut/soc/core/pipeline_regs/mem_wb_reg_q
add_wave /cpu_tb/uut/soc/core/decode_stage/registers/registers
add_wave /cpu_tb/uut/soc/dmem/data_ram
add_wave /cpu_tb/uut/soc/imem/instruction
restart
run 5us
