static int i2c_test_read_registers_bfm_r_calltf(char*user_data)
{

	vpiHandle PRESETn = vpi_handle_by_name("I2C_GLADIC_tb.PRESETn", NULL);
	vpiHandle PWDATA = vpi_handle_by_name("I2C_GLADIC_tb.PWDATA", NULL);
	vpiHandle PENABLE = vpi_handle_by_name("I2C_GLADIC_tb.PENABLE", NULL);
	vpiHandle PSELx = vpi_handle_by_name("I2C_GLADIC_tb.PSELx", NULL);
	vpiHandle PWRITE = vpi_handle_by_name("I2C_GLADIC_tb.PWRITE", NULL);
	vpiHandle PADDR = vpi_handle_by_name("I2C_GLADIC_tb.PADDR", NULL);
	vpiHandle PRDATA = vpi_handle_by_name("I2C_GLADIC_tb.PRDATA", NULL);
	vpiHandle PREADY = vpi_handle_by_name("I2C_GLADIC_tb.PREADY", NULL);
	vpiHandle PSLVERR = vpi_handle_by_name("I2C_GLADIC_tb.PSLVERR", NULL);


	v_wr.format=vpiIntVal;
	vpi_get_value(PRESETn, &v_wr);


	if(type_bfm == SIMPLE_READ_AFTER_RESET)
	{
		
		switch(STATE)
		{

			case IDLE:


				if(PACKETS_GENERATED >= MAX_ITERATIONS)
				{
					STATE = IDLE;
					type_bfm = -1;	

				}else
				{
					STATE = READ_RESULTS; 	

					v_wr.value.integer = 0;
					vpi_put_value(PWRITE, &v_wr, NULL, vpiNoDelay);	

					v_wr.value.integer = 1;
					vpi_put_value(PSELx, &v_wr, NULL, vpiNoDelay);
					
					v_wr.value.integer = 0;
					vpi_put_value(PENABLE, &v_wr, NULL, vpiNoDelay);
										
					READ_REGISTER = ADDR_I2C_WRITE_TX_FIFO;
					STATE_PENABLE = 1;
				}


	
			break;
			case READ_RESULTS:

			    switch(STATE_PENABLE)
			    {
			    	case 0:
			    		v_wr.value.integer = 1;
					vpi_put_value(PENABLE, &v_wr, NULL, vpiNoDelay);
					STATE_PENABLE = 1;
			    	break;
			    	case 1:
			  		v_wr.value.integer = 0;
					vpi_put_value(PENABLE, &v_wr, NULL, vpiNoDelay);
					STATE_PENABLE = 0;
					
					
					switch(READ_REGISTER)
					{
					  case ADDR_I2C_WRITE_TX_FIFO:					
					  	v_wr.value.integer = ADDR_I2C_WRITE_TX_FIFO;
						vpi_put_value(PADDR, &v_wr, NULL, vpiNoDelay);
						READ_REGISTER = ADDR_I2C_READ_RX_FIFO;
					  break;
					  case ADDR_I2C_READ_RX_FIFO:
					  	v_wr.value.integer = ADDR_I2C_READ_RX_FIFO;
						vpi_put_value(PADDR, &v_wr, NULL, vpiNoDelay);	
						READ_REGISTER = ADDR_I2C_CONFIG;				  
					  break;
					  case ADDR_I2C_CONFIG:
					  	v_wr.value.integer = ADDR_I2C_CONFIG;
						vpi_put_value(PADDR, &v_wr, NULL, vpiNoDelay);
						READ_REGISTER = ADDR_I2C_TIMEOUT;						  
					  break;
					  case ADDR_I2C_TIMEOUT:
					  	v_wr.value.integer = ADDR_I2C_TIMEOUT;
						vpi_put_value(PADDR, &v_wr, NULL, vpiNoDelay);	
						READ_REGISTER = ADDR_I2C_READ_ACTUAL_DATA;					  
					  break;
					  case ADDR_I2C_READ_ACTUAL_DATA:
					  	v_wr.value.integer = ADDR_I2C_TIMEOUT;
						vpi_put_value(PADDR, &v_wr, NULL, vpiNoDelay);	
					
						PACKETS_GENERATED = PACKETS_GENERATED + 1;
						STATE = IDLE;
					  break;
					}

			    	break;
			    }

			break;
		}


		
	}


	return 0;
}
