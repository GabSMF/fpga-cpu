# Cria cpu8.xise (projeto do ISE 14.7 para a Spartan-3E Starter Kit), na pasta atual.
# Com o ambiente do ISE carregado:
#   cd proj-cpu/ise && xtclsh ../tools/criar_projeto_ise.tcl          (fontes em ../rtl, ../tb, ../constraints)
#   cd projeto_ise  && xtclsh criar_projeto_ise.tcl plano             (tudo na mesma pasta; ver exportar_ise.sh)
# Os caminhos ficam relativos, entao a pasta pode ser movida.
set plano [expr {[llength $argv] > 0 && [lindex $argv 0] eq "plano"}]
if {$plano} {
    set RTL ""; set TB ""; set UCF ""
} else {
    set RTL "../rtl/"; set TB "../tb/"; set UCF "../constraints/"
}

project new cpu8
project set family "Spartan3E"
project set device "xc3s500e"
project set package "fg320"
project set speed "-4"
project set "Preferred Language" "VHDL"
project set "Evaluation Development Board" "Spartan-3E Starter Board"

foreach f {alu lcd_pkg lcd_texto lcd RAM_8x256 cpu main} {
    xfile add "${RTL}$f.vhd"
}
xfile add "${UCF}spartan3e.ucf"
foreach f {lcd_modelo tb_alu tb_ram tb_lcd_texto tb_lcd tb_cpu_programas tb_main} {
    xfile add "${TB}$f.vhd" -view "Simulation"
}
project set top "Behavioral" "main"
project set "Simulation Run Time" "all" -process "Simulate Behavioral Model"
project close
