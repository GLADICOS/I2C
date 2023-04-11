static int i2c_reset_calltf(char*user_data)
{

	vpiHandle PRESETn = vpi_handle_by_name("I2C_GLADIC_tb.PRESETn", NULL);

	std::mt19937 rd_counter{std::random_device{}()};
	std::uniform_int_distribution<int> counter(1,50);

 	std::mt19937 rd{std::random_device{}()};
        std::uniform_real_distribution<> time(0,50);

	
	v_reset.format=vpiIntVal;

	//printf("STATE_RESET : %i\n",STATE_RESET);
	//printf("MAX_RESET_TIMES : %i\n",MAX_RESET_TIMES);
	//printf("RESET_GENERATED : %i\n",RESET_GENERATED);
		
	switch(STATE_RESET)
	{

		case IDLE_RESET:

			if(RESET_GENERATED > MAX_RESET_TIMES)
			{
				STATE_RESET = IDLE_RESET;
			}else
			{

				STATE_RESET = ENTER_RESET;

				v_reset.value.integer = 0;
				t_reset.type = vpiScaledRealTime;
				t_reset.real = time(rd);
				v_wr.format=vpiIntVal;
				v_reset.value.integer = 0;
				vpi_put_value(PRESETn, &v_reset, &t_reset, vpiTransportDelay);
				counter_reset_wait = counter(rd_counter);

			}

			counter_reset_enter=0;
			counter_reset_wait=0;	


		break;

		case ENTER_RESET:

			if(counter_reset_enter >= counter_reset_wait)
			{
				v_reset.value.integer = 0;
				t_reset.type = vpiScaledRealTime;
				t_reset.real = time(rd);
				v_wr.format=vpiIntVal;
				v_reset.value.integer = 1;
				vpi_put_value(PRESETn,&v_reset, &t_reset, vpiTransportDelay);
				STATE_RESET = GET_OUT_RESET;					
			}

			counter_reset_enter++;
					
		break;

		case GET_OUT_RESET:

			counter_reset_wait=0;
			counter_reset_enter=0;

			STATE_RESET = WAIT_RESET;

			counter_reset_wait = counter(rd_counter);

		break;

		case WAIT_RESET:
			
			if(counter_reset_enter >= counter_reset_wait)
			{
				STATE_RESET = IDLE_RESET;
				counter_reset_wait=0;
				counter_reset_enter=0;
				RESET_GENERATED++;
			}
			counter_reset_enter++;

		break;

	}
	

	return 0;
}

