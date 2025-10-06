create_clock -name sys_clk -period 10.000 [get_ports clk]
set_false_path -from [get_ports rst_n]
# Do not place any I/O on these package pins（Prohibit the sites） 
set_property PROHIBIT TRUE [get_sites {AD6 W9 G4}]
