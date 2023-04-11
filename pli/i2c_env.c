/*
     Design name : Felipe Fernandes da Costa
     Description: 
     
     A verification environment used to be a basic one.
          
     Brazil -- 21/03/2023 -- 
*/

#include "/usr/local/include/iverilog/vpi_user.h"
//#include <vpi_user.h>
#include <iostream>
#include <random>
#include<string.h>

s_vpi_value v_generate;

s_vpi_value v_initial;
s_vpi_time  t_initial;

s_vpi_value v_reset;
s_vpi_time  t_reset;

s_vpi_value v_wr;
s_vpi_time  t_wr;

/*GENERAL USE */

int STATE_PENABLE;
int READ_REGISTER;

/*THIS SPECIFY the BFMS we need to make sure we choose right tests*/
int type_bfm;

// GLOBAL PACKETS
int PACKETS_GENERATED;

//This is to be used on BFM
int STATE;

// RESET BFM ONLY
int reset_counter;
int counter_reset_enter;
int counter_reset_wait;

int STATE_RESET;
int RESET_GENERATED;


#define ADDR_I2C_WRITE_TX_FIFO 	   0
#define ADDR_I2C_READ_RX_FIFO  	   4

#define ADDR_I2C_CONFIG  	   8
#define ADDR_I2C_TIMEOUT 	  12
#define ADDR_I2C_READ_ACTUAL_DATA 16 


/*DEFINE A BFM RESET PROPER DEFINE*/
#define IDLE_RESET     0
#define ENTER_RESET    1
#define WAIT_RESET     2
#define GET_OUT_RESET  3


#define IDLE         0
#define WRITE        1
#define READ         2
#define WAIT         3
#define READ_RESULTS 4

/*BFM ACT TO PERFORM SIMPLE TASKS*/
#define SIMPLE_READ_AFTER_RESET       0
#define SIMPLE_WRITE_AFTER_RESET      1
#define SIMPLE_WRITE_READ_AFTER_RESET 2

/*MAX RESET GENERATION */
#define MAX_RESET_TIMES 4

/*MAX PACKETS GENERATION*/
#define MAX_ITERATIONS 8

//INITIAL ENV CONFIGURE
#include "i2c_init.h"
#include "i2c_bfm_handler_type_test.h"
#include "i2c_bfm_reset.h"
#include "i2c_init_reset.h"


#include "read/i2c_test_read_registers_bfm_r.h"

	
void I2C_GLADIC_register()
{
      s_vpi_systf_data tf_data;

      //i2c_test_read_registers_bfm_r
      tf_data.type      = vpiSysTask;
      tf_data.sysfunctype = 0;
      tf_data.tfname    = "$i2c_test_read_registers";
      tf_data.calltf    = i2c_test_read_registers_bfm_r_calltf;
      tf_data.compiletf = 0;
      tf_data.sizetf    = 0;
      tf_data.user_data = 0;
      vpi_register_systf(&tf_data);

      //MAIN DEFINE BFM TYPE
      tf_data.type      = vpiSysTask;
      tf_data.sysfunctype = 0;
      tf_data.tfname    = "$bfm_generate_type";
      tf_data.calltf    = i2c_bfm_handler_type_test_calltf;
      tf_data.compiletf = 0;
      tf_data.sizetf    = 0;
      tf_data.user_data = 0;
      vpi_register_systf(&tf_data);
      
      // RESET BFM
      tf_data.type      = vpiSysTask;
      tf_data.sysfunctype = 0;
      tf_data.tfname    = "$reset_i2c_master";
      tf_data.calltf    = i2c_reset_calltf;
      tf_data.compiletf = 0;
      tf_data.sizetf    = 0;
      tf_data.user_data = 0;
      vpi_register_systf(&tf_data);      

	
      //ENV CONFIGURATION
      tf_data.type      = vpiSysTask;
      tf_data.sysfunctype = 0;
      tf_data.tfname    = "$init";
      tf_data.calltf    = init_calltf;
      tf_data.compiletf = 0;
      tf_data.sizetf    = 0;
      tf_data.user_data = 0;
      vpi_register_systf(&tf_data);

      tf_data.type      = vpiSysTask;
      tf_data.sysfunctype = 0;
      tf_data.tfname    = "$init_reset";
      tf_data.calltf    = init_reset_calltf;
      tf_data.compiletf = 0;
      tf_data.sizetf    = 0;
      tf_data.user_data = 0;
      vpi_register_systf(&tf_data);

}


void (*vlog_startup_routines[])() = {
    I2C_GLADIC_register,
    0
};
