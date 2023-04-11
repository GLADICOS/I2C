module I2C_GLADIC_tb;

	    reg PCLK;
	    wire PRESETn;
	    wire PSELx;
	    wire PWRITE;
	    wire PENABLE;
	    wire [31:0] PADDR;
	    wire [31:0] PWDATA;
	    				
	    //external APB pin
	    wire [31:0] PRDATA;
			
	    //external APB port 
	    wire PREADY;
	    wire PSLVERR;

	    //external APB interruption
	    wire INT_RX;
	    wire INT_TX;
			
	    //I2C BI DIRETIONAL PORTS
	    wire PAD_EN_SDA;
	    wire PAD_EN_SCL;
	    wire SDA;
	    wire SCL;
	    
	    integer i,a;  
	    
	    top_i2c_master DUT (
	    
				    .pclk(PCLK),
				    .presetn(PRESETn),
				    .pselx(PSELx),
				    .pwrite(PWRITE),
				    .penable(PENABLE),
				    .paddr(PADDR),
				    .pwdata(PWDATA),
				    				
				    //external APB pin
				    .prdata(PRDATA),
						
				    //external APB port 
				    .pready(PREADY),
				    .pslverr(PSLVERR),

				    //external APB interruption
				    .int_rx(INT_RX),
				    .int_tx(INT_TX),
						
				    //I2C BI DIRETIONAL PORTS
				    .pad_en_sda(PAD_EN_SDA),
				    .pad_en_scl(PAD_EN_SCL),
				    .sda(SDA),
				    .scl(SCL)	    
	    
	    		       );
	
	initial
	 begin
	    $dumpfile("I2C_GLADIC_tb.vcd");
	    $dumpvars(0,I2C_GLADIC_tb);
	    $init;
	    $init_reset;
	 end
	 
	initial PCLK = 1'b0;
	always #(20) PCLK = ~PCLK;	


	//BFM READ REGISTER ONLY
	always@(posedge PCLK)
	   	$i2c_test_read_registers;
	
	//CHOOSE WHAT BFM WILL BE ENABLED
	always@(posedge PCLK)
	   	$bfm_generate_type;	
	   	
	//RESET DUT A FEW TIMES TO GO TO RIGHT STATE
	always@(posedge PCLK)
		$reset_i2c_master;	   	
	
	//THIS MAKE REGISTER INITIAL ASSIGNMENT
	always@(negedge PRESETn)
		$init;
		
	//FLAG USED TO FINISH SIMULATION PROGRAM 
	always@(posedge PCLK)
	begin

		wait(i == 1)		
		$finish();
	end	 
	 	    		       

endmodule
