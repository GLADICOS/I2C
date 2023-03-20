/*
     Design name : Felipe Fernandes da Costa
     Description: 
     
     DATA_CONFIG_REG [0]    --> register to enable ip master mode 
     DATA_CONFIG_REG [1]    --> 0 to read and 1 to write 
      
     DATA_CONFIG_REG [13:2] -->  A parameter counter used to divide clock
     
     TIMEOUT_TX --> A Simple timeout should used  to see if count_timeout < TIMEOUT_TX
     
     HOW WORK THIS I2C
     
     START There is a pattern indicates a start of transmit data
     NACK  Something goes wrong
     ACK   Data send is fine  
       
     CONTROLIN --> Addressing controler 8 bit  addrerss and one bit aditional read write
     ADDRESS STATES WHERE IN IP WILL STORE DATA 
     DATA0 and DATA1 STATES WORD 16it Little endian to be delivered
     
     
     Brazil -- 04/03/2023 -- initial tx i2c
*/

`timescale 1ns/1ps //timescale 

module module_i2c_master#(
			//THIS IS USED ONLY LIKE PARAMETER TO BEM CONFIGURABLE
			parameter integer DWIDTH = 32,
			parameter integer DFWIDTH = 16,
			parameter integer AWIDTH = 14
		)
		(
		//I2C INTERFACE WITH ANOTHER BLOCKS
		 input PCLK,
		 input PRESETn,


		//INTERFACE WITH FIFO RECEIVE DATA
		 input fifo_rx_f_full,
		 input fifo_rx_f_empty,
		 
		 //
		 input fifo_tx_f_full,
		 input fifo_tx_f_empty,
		 		 
		//INTERFACE WITH FIFO TRANSMISSION
		 input [DWIDTH-1:0] fifo_tx_data_out,

		//INTERFACE WITH REGISTER CONFIGURATION
		 input [AWIDTH-1:0] DATA_CONFIG_REG,
 		 input [AWIDTH-1:0] TIMEOUT_TX,
 		 	
		//INTERFACE TO APB AND READ FOR FIFO   
		 output reg fifo_tx_rd_en,
		 output reg fifo_rx_wr_en,
		 
		 output reg [DFWIDTH-1:0] fifo_rx_data_in,
		 output reg RESPONSE,
		 
		 output ERROR,

		//I2C BI DIRETIONAL PORTS
		 output PAD_EN_SDA,
		 output PAD_EN_SCL,
		 inout  SDA,
		 output SCL	 

		 );

	//THIS COUNT IS USED TO CONTROL DATA ACCROSS FSM	
	//reg [1:0] count_tx;
	//CONTROL CLOCK AND COUNTER
	reg [11:0] count_send_data;
	//reg [11:0] count_receive_data;
	reg [AWIDTH-1:0] count_timeout;
	reg BR_CLK_O;
	reg SDA_OUT;

	//RESPONSE USED TO HOLD SIGNAL TO ACK OR NACK
	//reg RESPONSE;

//    PARAMETERS USED TO STATE MACHINE

localparam [5:0] IDLE = 6'd0, //IDLE

	   START = 6'd1,//START BIT
	   
	     CONTROLIN_1 = 6'd2, //START BYTE
	     CONTROLIN_2 = 6'd3,
	     CONTROLIN_3 = 6'd4,
             CONTROLIN_4 = 6'd5,
	     CONTROLIN_5 = 6'd6,
	     CONTROLIN_6 = 6'd7,
             CONTROLIN_7 = 6'd8,
             CONTROLIN_8 = 6'd9, //END FIRST BYTE
             
             READ_WRITE  = 6'd10, //READ WRITE
             
	     RESPONSE_CIN =6'd11, //RESPONSE

	     ADDRESS_1 = 6'd12,//START BYTE
	     ADDRESS_2 = 6'd13,
	     ADDRESS_3 = 6'd14,
             ADDRESS_4 = 6'd15,
	     ADDRESS_5 = 6'd16,
	     ADDRESS_6 = 6'd17,
             ADDRESS_7 = 6'd18,
             ADDRESS_8 = 6'd19,//END FIRST BYTE

	     RESPONSE_ADDRESS =6'd20, //RESPONSE

	     DATA0_1 = 6'd21,//START BYTE
	     DATA0_2 = 6'd22,
	     DATA0_3 = 6'd23,
             DATA0_4 = 6'd24,
	     DATA0_5 = 6'd25,
	     DATA0_6 = 6'd26,
             DATA0_7 = 6'd27,
             DATA0_8 = 6'd28,//END FIRST BYTE
	   
	     DATA1_1 = 6'd29,//START BYTE
	     DATA1_2 = 6'd30,
	     DATA1_3 = 6'd31,
             DATA1_4 = 6'd32,
	     DATA1_5 = 6'd33,
	     DATA1_6 = 6'd34,
             DATA1_7 = 6'd35,
             DATA1_8 = 6'd36,//END SECOND BYTE

	     RESPONSE_DATA1_1 = 6'd37,//RESPONSE

	     //DELAY_BYTES = 6'd38,//USED ONLY IN ACK TO DELAY BETWEEN
	     //NACK = 6'd39,//USED ONLY IN ACK TO DELAY BETWEEN BYTES
	     STOP = 6'd38;//USED TO SEND STOP BIT

	//STATE CONTROL 
	reg [5:0] state_tx;
	reg [5:0] next_state_tx;

//ASSIGN REGISTERS TO BIDIRETIONAL PORTS
assign SDA =(DATA_CONFIG_REG[0] == 1'b1 & state_tx != RESPONSE_CIN & state_tx != RESPONSE_ADDRESS & state_tx != RESPONSE_DATA1_1)?SDA_OUT:1'bz;


assign SCL = (DATA_CONFIG_REG[0] == 1'b1)?BR_CLK_O:1'bz;

//STANDARD ERROR
assign ERROR = (count_timeout > TIMEOUT_TX)?1'b1:1'b0;

assign PAD_EN_SDA = (DATA_CONFIG_REG[0] == 1'b1 & state_tx != RESPONSE_CIN & state_tx != RESPONSE_ADDRESS & state_tx != RESPONSE_DATA1_1)?1'b1:1'b0;
assign PAD_EN_SCL = (DATA_CONFIG_REG[0] == 1'b1)?1'b1:1'b0;


//COMBINATIONAL BLOCK TO   
always@(*)
begin

	//THE FUN START HERE :-)
	//COMBINATIONAL UPDATE STATE BE CAREFUL WITH WHAT YOU MAKE HERE
	next_state_tx=state_tx;

	case(state_tx)//state_   IS MORE SECURE CHANGE ONLY IF YOU KNOW WHAT ARE YOU DOING 
	IDLE:
	begin
		//OBEYING SPEC
		if(DATA_CONFIG_REG[0] == 1'b0 && (fifo_tx_f_full == 1'b1 || fifo_tx_f_empty == 1'b0))
		begin
			next_state_tx   = IDLE;
		end
		else if(DATA_CONFIG_REG[0] == 1'b1 && (fifo_tx_f_full == 1'b1 || fifo_tx_f_empty == 1'b0))
		begin
			next_state_tx   = IDLE;
		end
		else if(DATA_CONFIG_REG[0] == 1'b1 && ((fifo_tx_f_full == 1'b0 && fifo_tx_f_empty == 1'b0) || fifo_tx_f_full == 1'b1) && DATA_CONFIG_REG[1] == 1'b0 && count_timeout < TIMEOUT_TX)
		begin
			next_state_tx   = START;
		end


	end
	START://THIS IS USED TOO ALL STATE MACHINES THE COUNTER_SEND_DATA
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx   = START;
		end
		else
		begin
			next_state_tx   = CONTROLIN_1;
		end
		
	end
	CONTROLIN_1:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx  = CONTROLIN_1;
		end
		else
		begin
			next_state_tx  =  CONTROLIN_2;
		end

	end
	CONTROLIN_2:
	begin

		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx   = CONTROLIN_2;
		end
		else
		begin
			next_state_tx   = CONTROLIN_3;
		end

	end
	CONTROLIN_3:
	begin

		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx  =  CONTROLIN_3;
		end
		else
		begin
			next_state_tx   = CONTROLIN_4;
		end		
	end
	CONTROLIN_4:
	begin

		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx   = CONTROLIN_4;
		end
		else
		begin
			next_state_tx   = CONTROLIN_5;
		end		
	end
	CONTROLIN_5:
	begin

		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = CONTROLIN_5;
		end
		else
		begin
			next_state_tx = CONTROLIN_6;
		end		
	end
	CONTROLIN_6:
	begin

		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = CONTROLIN_6;
		end
		else
		begin
			next_state_tx = CONTROLIN_7;
		end		
	end
	CONTROLIN_7:
	begin

		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = CONTROLIN_7;
		end
		else
		begin
			next_state_tx = CONTROLIN_8;
		end		
	end
	CONTROLIN_8:
	begin

		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx  = CONTROLIN_8;
		end
		else 
		begin
			next_state_tx  = READ_WRITE;
		end		
	end
	
	READ_WRITE:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx  = READ_WRITE;
		end
		else 
		begin
			next_state_tx  = RESPONSE_CIN;
		end	
	end
	
	RESPONSE_CIN:
	begin

		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = RESPONSE_CIN;
		end
		else if(RESPONSE == 1'b0)//ACK
		begin 
			next_state_tx = CONTROLIN_1;
		end
		else if(RESPONSE == 1'b1)//NACK
		begin
			next_state_tx = STOP;
		end	
		
	end

	//NOW SENDING ADDRESS
	ADDRESS_1:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx  = ADDRESS_1;
		end
		else
		begin
			next_state_tx  =  ADDRESS_2;
		end	
	end
	ADDRESS_2:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = ADDRESS_2;
		end
		else
		begin
			next_state_tx = ADDRESS_3;
		end	
	end
	ADDRESS_3:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = ADDRESS_3;
		end
		else
		begin
			next_state_tx = ADDRESS_4;
		end	
	end
	ADDRESS_4:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = ADDRESS_4;
		end
		else
		begin
			next_state_tx = ADDRESS_5;
		end	
	end
	ADDRESS_5:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = ADDRESS_5;
		end
		else
		begin
			next_state_tx = ADDRESS_6;
		end	
	end
	ADDRESS_6:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = ADDRESS_6;
		end
		else
		begin
			next_state_tx = ADDRESS_7;
		end	
	end
	ADDRESS_7:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = ADDRESS_7;
		end
		else
		begin
			next_state_tx = ADDRESS_8;
		end	
	end
	ADDRESS_8:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = ADDRESS_8;
		end
		else
		begin
			next_state_tx = RESPONSE_ADDRESS;
		end	
	end
	
	RESPONSE_ADDRESS:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = RESPONSE_ADDRESS;
		end
		else if(RESPONSE == 1'b0)//ACK
		begin 
			next_state_tx = DATA0_1;
		end
		else if(RESPONSE == 1'b1)//NACK --> RESTART CONDITION AND BACK TO START BYTE AGAIN
		begin
			next_state_tx = STOP;
		end	
	end
	
	//data in
	DATA0_1:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = DATA0_1;
		end
		else
		begin
			next_state_tx = DATA0_2;
		end
	end
	DATA0_2:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = DATA0_2;
		end
		else
		begin
			next_state_tx = DATA0_3;
		end
	end
	DATA0_3:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = DATA0_3;
		end
		else
		begin
			next_state_tx = DATA0_4;
		end
	end
	DATA0_4:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = DATA0_4;
		end
		else
		begin
			next_state_tx = DATA0_5;
		end
	end
	DATA0_5:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = DATA0_5;
		end
		else
		begin
			next_state_tx   = DATA0_6;
		end
	end
	DATA0_6:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx  = DATA0_6;
		end
		else
		begin
			next_state_tx  = DATA0_7;
		end
	end
	DATA0_7:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx  = DATA0_7;
		end
		else
		begin
			next_state_tx  = DATA0_8;
		end
	end
	DATA0_8:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx  = DATA0_8;
		end
		else
		begin
			next_state_tx  =  DATA1_1;
		end
	end
	DATA1_1:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx  = DATA1_1;
		end
		else
		begin
			next_state_tx  = DATA1_2;
		end
	end
	DATA1_2:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = DATA1_2;
		end
		else
		begin
			next_state_tx = DATA1_3;
		end
	end
	DATA1_3:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx  = DATA1_3;
		end
		else
		begin
			next_state_tx  =  DATA1_4;
		end
	end
	DATA1_4:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx  = DATA1_4;
		end
		else
		begin
			next_state_tx  = DATA1_5;
		end
	end
	DATA1_5:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = DATA1_5;
		end
		else
		begin
			next_state_tx = DATA1_6;
		end
	end
	DATA1_6:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx  =  DATA1_6;
		end
		else
		begin
			next_state_tx  =  DATA1_7;
		end
	end
	DATA1_7:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx =  DATA1_7;
		end
		else
		begin
			next_state_tx =  DATA1_8;
		end
	end
	DATA1_8:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = DATA1_8;
		end
		else
		begin
				
			if(DATA_CONFIG_REG[1])
			begin
			   next_state_tx = RESPONSE_DATA1_1;
			end
			else
			begin
			   next_state_tx = STOP;
			end
			
		end
	end
	RESPONSE_DATA1_1:
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx   =  RESPONSE_DATA1_1;
		end
		else
		begin
			if(DATA_CONFIG_REG[1])
			begin
			   next_state_tx = RESPONSE_DATA1_1;
			end
			else
			begin
				if(RESPONSE == 1'b0)//ACK
				begin 
					next_state_tx   =  STOP;
				end
				else if(RESPONSE == 1'b1)//NACK
				begin
					next_state_tx   =  DATA0_1;
				end
			end
		
		end
			
	end
	STOP://THIS WORK
	begin
		if(count_send_data != DATA_CONFIG_REG[13:2])
		begin
			next_state_tx = STOP;
		end
		else
		begin
			next_state_tx = IDLE;
		end
	end
	default:
	begin
		next_state_tx =  IDLE;
	end
	endcase


end



//SEQUENTIAL   
always@(posedge PCLK)
begin

	//RESET SYNC
	if(!PRESETn)
	begin
		//SIGNALS MUST BE RESETED
		count_send_data <= 12'd0;
		state_tx   <= IDLE;	
		SDA_OUT<= 1'b1;
		fifo_tx_rd_en <= 1'b0;
		//count_tx   <= 2'd0;
		BR_CLK_O <= 1'b1;
		RESPONSE<= 1'b0;	
	end
	else
	begin
		
		// SEQUENTIAL FUN START
		state_tx  <= next_state_tx;

		case(state_tx)
		IDLE:
		begin

			fifo_tx_rd_en <= 1'b0;
			
 
			if(DATA_CONFIG_REG[0] == 1'b0 && (fifo_tx_f_full == 1'b1 ||fifo_tx_f_empty == 1'b0) && DATA_CONFIG_REG[1] == 1'b0)
			begin
				count_send_data <= 12'd0;
				SDA_OUT<= 1'b1;
				BR_CLK_O <= 1'b1;
			end
			else if(DATA_CONFIG_REG[0] == 1'b1 && ((fifo_tx_f_empty == 1'b0 && fifo_tx_f_full == 1'b0 )|| fifo_tx_f_full == 1'b1 ) && DATA_CONFIG_REG[1] == 1'b0)
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=1'b0;			
			end
			else if(DATA_CONFIG_REG[0] == 1'b1 && (fifo_tx_f_full == 1'b1 ||fifo_tx_f_empty == 1'b0) && DATA_CONFIG_REG[1] == 1'b1)
			begin
				count_send_data <= 12'd0;
				SDA_OUT<= 1'b1;
				BR_CLK_O <= 1'b1;
			end			

		end
		START:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				BR_CLK_O <= 1'b0;
			end
			else
			begin
				count_send_data <= 12'd0;					
			end	

			if(count_send_data == DATA_CONFIG_REG[13:2]- 12'd1)
			begin
				SDA_OUT<=fifo_tx_data_out[0:0];
				//count_tx   <= 2'd0;
			end

		end
		CONTROLIN_1:
		begin

			

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[0:0];	

								
				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end			
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[1:1];
			end

				
		end
		
		CONTROLIN_2:
		begin

			

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[1:1];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[2:2];
			end
				
		end

		CONTROLIN_3:
		begin

			

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[2:2];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[3:3];
			end	


				
		end
		CONTROLIN_4:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[3:3];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end				
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[4:4];
			end
				
		end

		CONTROLIN_5:
		begin

			

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[4:4];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end			
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[5:5];
			end	

		end
		CONTROLIN_6:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[5:5];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end	
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[6:6];
			end	

				
		end

		CONTROLIN_7:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[6:6];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end	
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[7:7];
			end	

				
		end
		CONTROLIN_8:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[7:7];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<= 1'b0;
			end

				
		end
		
		READ_WRITE:
		begin
		
			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=DATA_CONFIG_REG[1];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<= 1'b0;
			end
		
		
		end
		
		RESPONSE_CIN:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;

				//LETS TRY USE THIS BUT I DONT THINK IF WORKS  
				RESPONSE<= SDA;

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
			end	


		end
		ADDRESS_1:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[8:8];
				
				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[9:9];
			end	
				
		end		
		ADDRESS_2:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[9:9];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[10:10];
			end	

		end
		ADDRESS_3:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[10:10];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end			
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[11:11];
			end	

		end
		ADDRESS_4:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[11:11];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end			
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[12:12];
			end	
		end
		ADDRESS_5:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[12:12];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end				
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[13:13];
			end	

				
		end
		ADDRESS_6:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[13:13];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;		
				SDA_OUT<=fifo_tx_data_out[14:14];
			end	
				
		end
		ADDRESS_7:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[14:14];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=fifo_tx_data_out[15:15];
			end	

				
		end
		ADDRESS_8:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				SDA_OUT<=fifo_tx_data_out[15:15];

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				SDA_OUT<=1'b0;
			end	
				
		end
		RESPONSE_ADDRESS:
		begin
			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;

				//LETS TRY USE THIS BUT I DONT THINK IF WORKS  
				RESPONSE<= SDA;

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
			end

		end
		DATA0_1:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				
				if(DATA_CONFIG_REG[1])
				begin
				    SDA_OUT<=fifo_tx_data_out[16:16];
				end
				else
				begin
				   fifo_rx_data_in[0:0] <= SDA;
				end
				
				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;	
				
				if(DATA_CONFIG_REG[1])
				begin
				    SDA_OUT<=fifo_tx_data_out[17:17];
				end
				else
				begin
				   fifo_rx_data_in[1:1] <= SDA;
				end			
			end	

				
		end
		DATA0_2:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				
				
				if(DATA_CONFIG_REG[1])
				begin
				    SDA_OUT<=fifo_tx_data_out[17:17];
				end
				else
				begin
				   fifo_rx_data_in[1:1] <= SDA;
				end
				
				

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[18:18];
				end
				else
				begin
				   fifo_rx_data_in[2:2] <= SDA;
				end
								
				
			end	

				
		end		
		DATA0_3:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[18:18];
				end
				else
				begin
				   fifo_rx_data_in[2:2] <= SDA;
				end
				
				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[19:19];
				end
				else
				begin
				   fifo_rx_data_in[3:3] <= SDA;
				end		
			end	
				
		end
		DATA0_4:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[19:19];
				end
				else
				begin
				   fifo_rx_data_in[3:3] <= SDA;
				end

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[20:20];
				end
				else
				begin
				   fifo_rx_data_in[4:4] <= SDA;
				end			
			end	
				
		end
		DATA0_5:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[20:20];
				end
				else
				begin
				   fifo_rx_data_in[4:4] <= SDA;
				end	
								
				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end			
			end
			else
			begin
				count_send_data <= 12'd0;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[21:21];
				end
				else
				begin
				   fifo_rx_data_in[5:5] <= SDA;
				end
			end

		end
		DATA0_6:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[21:21];
				end
				else
				begin
				   fifo_rx_data_in[5:5] <= SDA;
				end
				
				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end			
			end
			else
			begin
				count_send_data <= 12'd0;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[22:22];
				end
				else
				begin
				   fifo_rx_data_in[6:6] <= SDA;
				end
			end
				
		end
		DATA0_7:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[22:22];
				end
				else
				begin
				   fifo_rx_data_in[6:6] <= SDA;
				end

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[23:23];
				end
				else
				begin
				   fifo_rx_data_in[7:7] <= SDA;
				end
			end	
				
		end
		DATA0_8:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[23:23];
				end
				else
				begin
				   fifo_rx_data_in[7:7] <= SDA;
				end

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		

			end
			else
			begin
				count_send_data <= 12'd0;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[24:24];
				end
				else
				begin
				   fifo_rx_data_in[8:8] <= SDA;
				end
			end	
				
		end
		DATA1_1:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[24:24];
				end
				else
				begin
				   fifo_rx_data_in[8:8] <= SDA;
				end

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end				
			end
			else
			begin
				count_send_data <= 12'd0;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[25:25];
				end
				else
				begin
				   fifo_rx_data_in[9:9] <= SDA;
				end

			end

				
		end
		DATA1_2:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[25:25];
				end
				else
				begin
				   fifo_rx_data_in[9:9] <= SDA;
				end

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end	
			end
			else
			begin
				count_send_data <= 12'd0;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[26:26];
				end
				else
				begin
				   fifo_rx_data_in[10:10] <= SDA;
				end
			end	

		end
		DATA1_3:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[26:26];
				end
				else
				begin
				   fifo_rx_data_in[10:10] <= SDA;
				end

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end			

			end
			else
			begin
				count_send_data <= 12'd0;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[27:27];
				end
				else
				begin
				   fifo_rx_data_in[11:11] <= SDA;
				end
			end	
				
		end
		DATA1_4:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[27:27];
				end
				else
				begin
				   fifo_rx_data_in[11:11] <= SDA;
				end

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end			

			end
			else
			begin
				count_send_data <= 12'd0;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[28:28];
				end
				else
				begin
				   fifo_rx_data_in[12:12] <= SDA;
				end
			end	
				
		end
		DATA1_5:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[28:28];
				end
				else
				begin
				   fifo_rx_data_in[12:12] <= SDA;
				end

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		

			end
			else
			begin
				count_send_data <= 12'd0;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[29:29];
				end
				else
				begin
				   fifo_rx_data_in[13:13] <= SDA;
				end
			end	
				
		end
		DATA1_6:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[29:29];
				end
				else
				begin
				   fifo_rx_data_in[13:13] <= SDA;
				end

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		

			end
			else
			begin
				count_send_data <= 12'd0;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[30:30];
				end
				else
				begin
				   fifo_rx_data_in[14:14] <= SDA;
				end
			end	
				
		end
		DATA1_7:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[30:30];
				end
				else
				begin
				   fifo_rx_data_in[14:14] <= SDA;
				end

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		

			end
			else
			begin
				count_send_data <= 12'd0;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[31:31];
				end
				else
				begin
				   fifo_rx_data_in[15:15] <= SDA;
				end
			end	

				
		end
		DATA1_8:
		begin

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=fifo_tx_data_out[31:31];
				end
				else
				begin
				   fifo_rx_data_in[15:15] <= SDA;
				end

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		

			end
			else
			begin
				count_send_data <= 12'd0;
				
				if(DATA_CONFIG_REG[1])
				begin
				   SDA_OUT<=1'b0;
				end
				else
				begin
				   fifo_rx_wr_en <= 1'b1;
				end				
				
				
			end	
				
		end
		RESPONSE_DATA1_1:
		begin
			//fifo_  _rd_en <= 1'b1;

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;

				//LETS TRY USE THIS BUT I DONT THINK IF WORKS  
				RESPONSE<= SDA;

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd4)
				begin
					BR_CLK_O <= 1'b0;
				end
				else if(count_send_data >= DATA_CONFIG_REG[13:2]/12'd4 && count_send_data < (DATA_CONFIG_REG[13:2]-(DATA_CONFIG_REG[13:2]/12'd4))-12'd1)
				begin
					BR_CLK_O <= 1'b1;
				end
				else
				begin
					BR_CLK_O <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				fifo_tx_rd_en <= 1'b1;
			end	

		end
		STOP:
		begin

			BR_CLK_O <= 1'b1;

			if(count_send_data < DATA_CONFIG_REG[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;

				if(count_send_data < DATA_CONFIG_REG[13:2]/12'd2-12'd2)
				begin
					SDA_OUT<=1'b0;
				end
				else if(count_send_data > DATA_CONFIG_REG[13:2]/12'd2-12'd1 && count_send_data < DATA_CONFIG_REG[13:2])
				begin
					SDA_OUT<=1'b1;
				end	
			end
			else
			begin
				count_send_data <= 12'd0;
			end
		end
		default:
		begin
			fifo_tx_rd_en <= 1'b0;
			count_send_data <= 12'd4095;
		end
		endcase
		
	end


end 

//USED ONLY TO COUNTER TIME
always@(posedge PCLK)
begin

	//RESET SYNC
	if(!PRESETn)
	begin
		count_timeout <= 14'd0;
	end
	else
	begin
		if(count_timeout <= TIMEOUT_TX && state_tx == IDLE)
		begin
			if(SDA == 1'b0 && SCL == 1'b0)
			count_timeout <= count_timeout + 14'd1;
		end
		else
		begin
			count_timeout <= 14'd0;
		end

	end

end


endmodule

