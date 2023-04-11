static int i2c_bfm_handler_type_test_calltf(char*user_data)
{
	
	vpiHandle PRESETn = vpi_handle_by_name("I2C_GLADIC_tb.PRESETn", NULL);
	vpiHandle i = vpi_handle_by_name("I2C_GLADIC_tb.i", NULL);

	v_generate.format=vpiIntVal;
	vpi_get_value(PRESETn, &v_generate);

	if(RESET_GENERATED >= MAX_RESET_TIMES)
	{
		        type_bfm = SIMPLE_READ_AFTER_RESET;

			if(PACKETS_GENERATED == MAX_ITERATIONS)
			{
				v_generate.value.integer = 1;
				vpi_put_value(i, &v_generate, NULL, vpiNoDelay);
			}		
	}
	else
	{
		type_bfm = -1;
	}
	
	return 0;
}
