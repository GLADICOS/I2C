g++ -c  -fpic ../pli/i2c_env.c  -std=c++11 -Wwrite-strings -fpermissive
g++ -shared  -o i2c_env.vpi i2c_env.o -lvpi -std=c++11 -Wwrite-strings -fpermissive
iverilog -oenv_i2c.vvp  ../testbench/i2c_tb_vpi.v ../rtl/master/*.v 
vvp -M. -mi2c_env env_i2c.vvp 
