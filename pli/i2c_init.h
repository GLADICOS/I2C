static int init_calltf(char*user_data)
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
	vpiHandle i = vpi_handle_by_name("I2C_GLADIC_tb.i", NULL);


	if(RESET_GENERATED >= MAX_RESET_TIMES)
	{}
	else
	{

		/**/
		PACKETS_GENERATED = 0;
		reset_counter = 0;
		STATE_RESET = IDLE_RESET;	

		v_initial.format=vpiIntVal;

		v_initial.value.integer = 0;
		vpi_put_value(PENABLE, &v_initial, NULL, vpiNoDelay);	
		vpi_put_value(PSELx , &v_initial, NULL, vpiNoDelay);
		vpi_put_value(PADDR, &v_initial, NULL, vpiNoDelay);
		vpi_put_value(i, &v_initial, NULL, vpiNoDelay);
		vpi_put_value(PWRITE, &v_initial, NULL, vpiNoDelay);
		vpi_put_value(PWDATA, &v_initial, NULL, vpiNoDelay);
	}
	
	return 0;
}
