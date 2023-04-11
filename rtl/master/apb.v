
/*

     Design name : Felipe Fernandes da Costa
     
     Description: 
     This is a APB interface used to configure IP modes , get or set data to be delivered to others compatible devices data transport.
     
     Brazil -- 04/03/2023 -- initial code apb i2c
     
         
     ADDRs meaning
     
     0  --> WRITE TX FIFO
     4  --> READ  RX FIFO
     8  --> WRITE CONFIG ON I2C
     12 --> WRITE COUNTER TIME ON I2C
     16 --> READ DATA BEGIN TRANSMMITED ON TX     
     
*/


`timescale 1ns/1ps //timescale 

module apb(
			//standard ARM
	    		input pclk,
			input presetn,
			input pselx,
			input pwrite,
			input penable,
			input [31:0] paddr,
			input [31:0] pwdata,

			//internal pin FIFO RX/TX
			input tx_empty,
			input tx_full,
			input [15:0] read_data_out_rx,
			input rx_empty,
			input rx_full,						
	
			//CURRENT DATA FROM i2C

	                input [31:0] current_data_tx,
	                
	                	               
			//internal I2C error
			input error,
	                input response_ack_nack,

	                
			//internal pin FIFO RX/TX
	                //output  [31:0] READ_DATA_IN_TX, 
			output  rd_ena_rx,		
			output  wr_ena_tx,
			
			//external APB pin
			output [31:0] prdata,

			//internal pin 
			output reg [13:0] internal_i2c_register_config,
			output reg [13:0] internal_i2c_register_timeout,
			output [31:0] write_data_on_tx,		
			
			//external APB port 
			output pready,
			output pslverr,

			//external APB interruption
			output int_rx,
			output int_tx
	   

	  );

//ENABLE WRITE ON TX FIFO
assign wr_ena_tx = (pwrite == 1'b1 & penable == 1'b1 & paddr == 32'd0 & pselx == 1'b1)?  1'b1:1'b0;

//ENABLE READ ON RX FIFO
assign rd_ena_rx = (pwrite == 1'b0 & penable == 1'b1  & paddr == 32'd4 & pselx == 1'b1)?  1'b1:1'b0;

//WRITE ON I2C MODULE
assign pready = ((wr_ena_tx == 1'b1 | rd_ena_rx == 1'b1 | paddr == 32'd8 | paddr == 32'd12) &  (penable == 1'b1 & pselx == 1'b1))? 1'b1:1'b0;

//INPUT TO WRITE ON TX FIFO
assign write_data_on_tx = (paddr == 32'd0)? pwdata:pwdata;

//OUTPUT DATA FROM RX TO prdata
assign prdata = (paddr == 32'd0)? 32'd0:(paddr == 32'd4)? {16'd0,read_data_out_rx}:(paddr == 32'd16)?current_data_tx:current_data_tx;

//error FROM I2C CORE
assign pslverr = (error || response_ack_nack)?1'b1:1'b0; 

//INTERRUPTION FROM I2C
assign int_tx = (!tx_empty & tx_full)?1'b1:1'b0;

//INTERRUPTION FROM I2C
assign int_rx = (!rx_empty & rx_full)?1'b1:1'b0;

//This is sequential logic used only to register configuration
always@(posedge pclk)
begin

	if(!presetn)
	begin
		internal_i2c_register_config <= 14'd0;
		internal_i2c_register_timeout <= 14'd0;
	end
	else
	begin

		// Set configuration to i2c
		if(paddr == 32'd8 && pselx == 1'b1 && pwrite == 1'b1 && pready == 1'b1)
		begin
			internal_i2c_register_config <= pwdata[13:0];
		end
		else if(paddr == 32'd12 && pselx == 1'b1 && pwrite == 1'b1 && pready == 1'b1)
		begin
			internal_i2c_register_timeout <= pwdata[13:0];
		end
		else
		begin
			internal_i2c_register_config <= internal_i2c_register_config;
		end
		
	end

end 


endmodule
