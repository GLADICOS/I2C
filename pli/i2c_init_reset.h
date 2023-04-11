static int init_reset_calltf(char*user_data)
{
	STATE_RESET = IDLE_RESET;
	RESET_GENERATED= 0;

	reset_counter = 0;
	counter_reset_enter = 0;
	counter_reset_wait = 0;

	return 0;
}
