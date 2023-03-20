module top_i2c_master(
	    		input PCLK,
			input PRESETn,
			input PSELx,
			input PWRITE,
			input PENABLE,
			input [31:0] PADDR,
			input [31:0] PWDATA,				
		
			//external APB pin
			output [31:0] PRDATA,
			
			//external APB port 
			output PREADY,
			output PSLVERR,

			//external APB interruption
			output INT_RX,
			output INT_TX,
			
			//I2C BI DIRETIONAL PORTS
			output PAD_EN_SDA,
			output PAD_EN_SCL,
			inout  SDA,
			output SCL			
			
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
    
	    		.PCLK(PCLK),
			.PRESETn(PRESETn),
			.PSELx(PSELx),
			.PWRITE(PWRITE),
			.PENABLE(PENABLE),
			.PADDR(PADDR),
			.PWDATA(PWDATA),

			//internal pin FIFO RX/TX
			.TX_EMPTY(w_fifo_tx_f_empty),
			.TX_FULL(w_fifo_tx_f_full),
			.READ_DATA_OUT_RX(w_data_out_rx),
			.RX_EMPTY(w_fifo_rx_f_empty),
			.RX_FULL(w_fifo_rx_f_full),						
	
			//CURRENT DATA FROM i2C

	                .CURRENT_DATA_TX(w_data_out_tx),
	                
	                	               
			//internal I2C error
			.ERROR(w_error),
	                .RESPONSE_ACK_NACK(w_response_ack_nack),

	                
			//internal pin FIFO RX/TX
	                //output  [31:0] READ_DATA_IN_TX, 
			.RD_ENA_RX(w_rd_en_rx),		
			.WR_ENA_TX(w_wr_en_tx),
			
			//external APB pin
			 .PRDATA(PRDATA),

			//internal pin 
			.INTERNAL_I2C_REGISTER_CONFIG(w_internal_i2c_register_config),
			.INTERNAL_I2C_REGISTER_TIMEOUT(w_timeout_tx),
			.WRITE_DATA_ON_TX(w_write_data_on_tx),		
			
			//external APB port 
			.PREADY(PREADY),
			.PSLVERR(PSLVERR),

			//external APB interruption
			.INT_RX(INT_RX),
			.INT_TX(INT_TX)   
    		   );
    		   
    		   
    fifo FIFO_TX(
	 	.clock(PCLK), 
	 	.reset(PRESETn), 
	 	.wr_en(w_wr_en_tx), 
	 	.rd_en(w_fifo_tx_rd_en),
		.data_in(w_write_data_on_tx),
		.f_full(w_fifo_tx_f_full), 
		.f_empty(w_fifo_tx_f_empty),
		.data_out(w_data_out_tx)   
    
                );
                
    fifo #(.DWIDTH(DWIDTH),.AWIDTH(AWIDTH))
    		 FIFO_RX (
	  	.clock(PCLK), 
	 	.reset(PRESETn), 
	 	.wr_en(w_fifo_rx_wr_en), 
	 	.rd_en(w_rd_en_rx),
		.data_in(w_data_in_rx),
		.f_full(w_fifo_rx_f_full), 
		.f_empty(w_fifo_rx_f_empty),
		.data_out(w_data_out_rx)   
                ); 
                
                
   module_i2c_master I2CMASTER(
				//I2C INTERFACE WITH ANOTHER BLOCKS
				 .PCLK(PCLK),
				 .PRESETn(PRESETn),


				//INTERFACE WITH FIFO RECEIVE DATA
				 .fifo_rx_f_full(w_fifo_rx_f_full),
				 .fifo_rx_f_empty(w_fifo_rx_f_empty),
				 
				 //
				 .fifo_tx_f_full(w_fifo_tx_f_full),
				 .fifo_tx_f_empty(w_fifo_tx_f_empty),
				 		 
				//INTERFACE WITH FIFO TRANSMISSION
				 .fifo_tx_data_out(w_data_out_tx),

				//INTERFACE WITH REGISTER CONFIGURATION
				 .DATA_CONFIG_REG(w_internal_i2c_register_config),
		 		 .TIMEOUT_TX(w_timeout_tx),
		 		 	
				//INTERFACE TO APB AND READ FOR FIFO   
				 .fifo_tx_rd_en(w_fifo_tx_rd_en),
				 .fifo_rx_wr_en(w_fifo_rx_wr_en),
				 
				 .fifo_rx_data_in(w_data_in_rx),

				 .ERROR(w_error),
				 .RESPONSE(w_response_ack_nack),

				//I2C BI DIRETIONAL PORTS
				 .PAD_EN_SDA(PAD_EN_SDA),
				 .PAD_EN_SCL(PAD_EN_SCL),
				 .SDA(SDA),
				 .SCL(SCL)	   
                              );              
                               

endmodule
