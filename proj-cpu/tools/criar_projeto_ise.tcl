# Cria proj-cpu/ise/cpu8.xise (projeto do ISE 14.7 para a Spartan-3E Starter Kit).
# Uso (dentro de proj-cpu/ise, com o ambiente do ISE carregado):
#   xtclsh ../tools/criar_projeto_ise.tcl
# Os caminhos sao relativos a proj-cpu/ise, entao a pasta proj-cpu pode ser movida.
project new cpu8
project set family "Spartan3E"
project set device "xc3s500e"
project set package "fg320"
project set speed "-4"
project set "Preferred Language" "VHDL"
project set "Evaluation Development Board" "Spartan-3E Starter Board"

foreach f {alu lcd_pkg lcd_texto lcd RAM_8x256 cpu main} {
    xfile add "../rtl/$f.vhd"
}
xfile add "../constraints/spartan3e.ucf"
foreach f {lcd_modelo tb_alu tb_ram tb_lcd_texto tb_lcd tb_cpu_programas tb_main} {
    xfile add "../tb/$f.vhd" -view "Simulation"
}
project set top "Behavioral" "main"
project set "Simulation Run Time" "all" -process "Simulate Behavioral Model"
project close
