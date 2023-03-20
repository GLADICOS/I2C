
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
	    		input PCLK,
			input PRESETn,
			input PSELx,
			input PWRITE,
			input PENABLE,
			input [31:0] PADDR,
			input [31:0] PWDATA,

			//internal pin FIFO RX/TX
			input TX_EMPTY,
			input TX_FULL,
			input [15:0] READ_DATA_OUT_RX,
			input RX_EMPTY,
			input RX_FULL,						
	
			//CURRENT DATA FROM i2C

	                input [31:0] CURRENT_DATA_TX,
	                
	                	               
			//internal I2C error
			input ERROR,
	                input RESPONSE_ACK_NACK,

	                
			//internal pin FIFO RX/TX
	                //output  [31:0] READ_DATA_IN_TX, 
			output  RD_ENA_RX,		
			output  WR_ENA_TX,
			
			//external APB pin
			output [31:0] PRDATA,

			//internal pin 
			output reg [13:0] INTERNAL_I2C_REGISTER_CONFIG,
			output reg [13:0] INTERNAL_I2C_REGISTER_TIMEOUT,
			output [31:0] WRITE_DATA_ON_TX,		
			
			//external APB port 
			output PREADY,
			output PSLVERR,

			//external APB interruption
			output INT_RX,
			output INT_TX
	   

	  );

//ENABLE WRITE ON TX FIFO
assign WR_ENA_TX = (PWRITE == 1'b1 & PENABLE == 1'b1 & PADDR == 32'd0 & PSELx == 1'b1)?  1'b1:1'b0;

//ENABLE READ ON RX FIFO
assign RD_ENA_RX = (PWRITE == 1'b0 & PENABLE == 1'b1  & PADDR == 32'd4 & PSELx == 1'b1)?  1'b1:1'b0;

//WRITE ON I2C MODULE
assign PREADY = ((WR_ENA_TX == 1'b1 | RD_ENA_RX == 1'b1 | PADDR == 32'd8 | PADDR == 32'd12) &  (PENABLE == 1'b1 & PSELx == 1'b1))? 1'b1:1'b0;

//INPUT TO WRITE ON TX FIFO
assign WRITE_DATA_ON_TX = (PADDR == 32'd0)? PWDATA:PWDATA;

//OUTPUT DATA FROM RX TO PRDATA
assign PRDATA = (PADDR == 32'd4)? {16'd0,READ_DATA_OUT_RX}:(PADDR == 32'd16)?CURRENT_DATA_TX:CURRENT_DATA_TX;

//ERROR FROM I2C CORE
assign PSLVERR = (ERROR || RESPONSE_ACK_NACK)?1'b1:1'b0; 

//INTERRUPTION FROM I2C
assign INT_TX = (TX_EMPTY || TX_FULL)?1'b1:1'b0;

//INTERRUPTION FROM I2C
assign INT_RX = (RX_EMPTY || RX_FULL)?1'b1:1'b0;

//This is sequential logic used only to register configuration
always@(posedge PCLK)
begin

	if(!PRESETn)
	begin
		INTERNAL_I2C_REGISTER_CONFIG <= 14'd0;
		INTERNAL_I2C_REGISTER_TIMEOUT <= 14'd0;
	end
	else
	begin

		// Set configuration to i2c
		if(PADDR == 32'd8 && PSELx == 1'b1 && PWRITE == 1'b1 && PREADY == 1'b1)
		begin
			INTERNAL_I2C_REGISTER_CONFIG <= PWDATA[13:0];
		end
		else if(PADDR == 32'd12 && PSELx == 1'b1 && PWRITE == 1'b1 && PREADY == 1'b1)
		begin
			INTERNAL_I2C_REGISTER_TIMEOUT <= PWDATA[13:0];
		end
		else
		begin
			INTERNAL_I2C_REGISTER_CONFIG <= INTERNAL_I2C_REGISTER_CONFIG;
		end
		
	end

end 


endmodule
