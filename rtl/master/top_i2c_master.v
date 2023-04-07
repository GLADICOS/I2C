module top_i2c_master(
	    		input pclk,
			input presetn,
			input pselx,
			input pwrite,
			input penable,
			input [31:0] paddr,
			input [31:0] pwdata,				
		
			//external APB pin
			output [31:0] prdata,
			
			//external APB port 
			output pready,
			output pslverr,

			//external APB interruption
			output int_rx,
			output int_tx,
			
			//I2C BI DIRETIONAL PORTS
			output pad_en_sda,
			output pad_en_scl,
			inout  sda,
			output scl			
			
		     );

   parameter integer DWIDTH = 16;
   parameter integer AWIDTH = 4; 

    wire [13:0] w_internal_i2c_register_config;
    wire [13:0] w_timeout_tx;
    
    wire w_response_ack_nack;
    wire w_error;

    wire w_fifo_rx_f_full;
    wire w_fifo_rx_f_empty;
	
			
    wire w_fifo_tx_f_full;
    wire w_fifo_tx_f_empty;
    
    wire [31:0] w_data_out_tx;
    wire [31:0] w_write_data_on_tx;
    
    wire [15:0] w_data_in_rx;
    wire [15:0] w_data_out_rx;
    
    wire w_wr_en_tx;
    wire w_rd_en_rx;
    
    wire w_fifo_tx_rd_en;
    wire w_fifo_rx_wr_en;
    
        

    apb APB_MASTER (
    
	    		.pclk(pclk),
			.presetn(presetn),
			.pselx(pselx),
			.pwrite(pwrite),
			.penable(penable),
			.paddr(paddr),
			.pwdata(pwdata),

			//internal pin FIFO RX/TX
			.tx_empty(w_fifo_tx_f_empty),
			.tx_full(w_fifo_tx_f_full),
			.read_data_out_rx(w_data_out_rx),
			.rx_empty(w_fifo_rx_f_empty),
			.rx_full(w_fifo_rx_f_full),						
	
			//CURRENT DATA FROM i2C

	                .current_data_tx(w_data_out_tx),
	                
	                	               
			//internal I2C error
			.error(w_error),
	                .response_ack_nack(w_response_ack_nack),

	                
			//internal pin FIFO RX/TX
	                //output  [31:0] READ_DATA_IN_TX, 
			.rd_ena_rx(w_rd_en_rx),		
			.wr_ena_tx(w_wr_en_tx),
			
			//external APB pin
			 .prdata(prdata),

			//internal pin 
			.internal_i2c_register_config(w_internal_i2c_register_config),
			.internal_i2c_register_timeout(w_timeout_tx),
			.write_data_on_tx(w_write_data_on_tx),		
			
			//external APB port 
			.pready(pready),
			.pslverr(pslverr),

			//external APB interruption
			.int_rx(int_rx),
			.int_tx(int_tx)   
    		   );
    		   
    		   
    fifo FIFO_TX(
	 	.clock(pclk), 
	 	.reset(presetn), 
	 	.wr_en(w_wr_en_tx), 
	 	.rd_en(w_fifo_tx_rd_en),
		.data_in(w_write_data_on_tx),
		.f_full(w_fifo_tx_f_full), 
		.f_empty(w_fifo_tx_f_empty),
		.data_out(w_data_out_tx)   
    
                );
                
    fifo #(.DWIDTH(DWIDTH),.AWIDTH(AWIDTH))
    		 FIFO_RX (
	  	.clock(pclk), 
	 	.reset(presetn), 
	 	.wr_en(w_fifo_rx_wr_en), 
	 	.rd_en(w_rd_en_rx),
		.data_in(w_data_in_rx),
		.f_full(w_fifo_rx_f_full), 
		.f_empty(w_fifo_rx_f_empty),
		.data_out(w_data_out_rx)   
                ); 
                
                
   module_i2c_master I2CMASTER(
				//I2C INTERFACE WITH ANOTHER BLOCKS
				 .pclk(pclk),
				 .presetn(presetn),


				//INTERFACE WITH FIFO RECEIVE DATA
				 .fifo_rx_f_full(w_fifo_rx_f_full),
				 .fifo_rx_f_empty(w_fifo_rx_f_empty),
				 
				 //
				 .fifo_tx_f_full(w_fifo_tx_f_full),
				 .fifo_tx_f_empty(w_fifo_tx_f_empty),
				 		 
				//INTERFACE WITH FIFO TRANSMISSION
				 .fifo_tx_data_out(w_data_out_tx),

				//INTERFACE WITH REGISTER CONFIGURATION
				 .data_config_reg(w_internal_i2c_register_config),
		 		 .timeout_tx(w_timeout_tx),
		 		 	
				//INTERFACE TO APB AND READ FOR FIFO   
				 .fifo_tx_rd_en(w_fifo_tx_rd_en),
				 .fifo_rx_wr_en(w_fifo_rx_wr_en),
				 
				 .fifo_rx_data_in(w_data_in_rx),

				 .error(w_error),
				 .response(w_response_ack_nack),

				//I2C BI DIRETIONAL PORTS
				 .pad_en_sda(pad_en_sda),
				 .pad_en_scl(pad_en_scl),
				 .sda(sda),
				 .scl(scl)	   
                              );              
                               

endmodule
