/*
     Design name : Felipe Fernandes da Costa
     Description: 
     
     data_config_reg [0]    --> register to enable ip master mode 
     data_config_reg [1]    --> 0 to read and 1 to write 
      
     data_config_reg [13:2] -->  A parameter counter used to divide clock
     
     timeout_tx --> A Simple timeout should used  to see if count_timeout < timeout_tx
     
     HOW WORK THIS I2C
     
     start There is a pattern indicates a start of transmit data
     NACK  Something goes wrong
     ACK   data send is fine  
       
     CONTROLIN --> addressing controler 8 bit  addrerss and one bit aditional read write
     address STATES WHERE IN IP WILL STORE data 
     data0 and data1 STATES WORD 16it Little endian to be delivered
     
     
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
		 input pclk,
		 input presetn,


		//INTERFACE WITH FIFO RECEIVE data
		 input fifo_rx_f_full,
		 input fifo_rx_f_empty,
		 
		 //
		 input fifo_tx_f_full,
		 input fifo_tx_f_empty,
		 		 
		//INTERFACE WITH FIFO TRANSMISSION
		 input [DWIDTH-1:0] fifo_tx_data_out,

		//INTERFACE WITH REGISTER CONFIGURATION
		 input [AWIDTH-1:0] data_config_reg,
 		 input [AWIDTH-1:0] timeout_tx,
 		 	
		//INTERFACE TO APB AND READ FOR FIFO   
		 output reg fifo_tx_rd_en,
		 output reg fifo_rx_wr_en,
		 
		 output reg [DFWIDTH-1:0] fifo_rx_data_in,
		 output reg response,
		 
		 output error,

		//I2C BI DIRETIONAL PORTS
		 output pad_en_sda,
		 output pad_en_scl,
		 inout  sda,
		 output scl	 

		 );

	//THIS COUNT IS USED TO CONTROL data ACCROSS FSM	
	//reg [1:0] count_tx;
	//CONTROL CLOCK AND COUNTER
	reg [11:0] count_send_data;
	//reg [11:0] count_receive_data;
	reg [AWIDTH-1:0] count_timeout;
	reg br_clk_o;
	reg sda_out;

	//response USED TO HOLD SIGNAL TO ACK OR NACK
	reg [2:0] response_error;

//    PARAMETERS USED TO STATE MACHINE

localparam [5:0] idle = 6'd0, //idle

	   start = 6'd1,//start BIT
	   
	     controlin_1 = 6'd2, //start BYTE
	     controlin_2 = 6'd3,
	     controlin_3 = 6'd4,
             controlin_4 = 6'd5,
	     controlin_5 = 6'd6,
	     controlin_6 = 6'd7,
             controlin_7 = 6'd8,
             controlin_8 = 6'd9, //END FIRST BYTE
             
             read_write  = 6'd10, //READ WRITE
             
	     response_cin =6'd11, //response

	     address_1 = 6'd12,//start BYTE
	     address_2 = 6'd13,
	     address_3 = 6'd14,
             address_4 = 6'd15,
	     address_5 = 6'd16,
	     address_6 = 6'd17,
             address_7 = 6'd18,
             address_8 = 6'd19,//END FIRST BYTE

	     response_address =6'd20, //response

	     data0_1 = 6'd21,//start BYTE
	     data0_2 = 6'd22,
	     data0_3 = 6'd23,
             data0_4 = 6'd24,
	     data0_5 = 6'd25,
	     data0_6 = 6'd26,
             data0_7 = 6'd27,
             data0_8 = 6'd28,//END FIRST BYTE
	   
	     data1_1 = 6'd29,//start BYTE
	     data1_2 = 6'd30,
	     data1_3 = 6'd31,
             data1_4 = 6'd32,
	     data1_5 = 6'd33,
	     data1_6 = 6'd34,
             data1_7 = 6'd35,
             data1_8 = 6'd36,//END SECOND BYTE

	     response_data1_1 = 6'd37,//response

	     //DELAY_BYTES = 6'd38,//USED ONLY IN ACK TO DELAY BETWEEN
	     //NACK = 6'd39,//USED ONLY IN ACK TO DELAY BETWEEN BYTES
	     stop = 6'd38;//USED TO SEND stop BIT

	//STATE CONTROL 
	reg [5:0] state_tx;
	reg [5:0] next_state_tx;

//ASSIGN REGISTERS TO BIDIRETIONAL PORTS
assign sda =(data_config_reg[0] == 1'b1 & state_tx != response_cin & state_tx != response_address & state_tx != response_data1_1)?sda_out:1'bz;


assign scl = (data_config_reg[0] == 1'b1)?br_clk_o:1'bz;

//STANDARD error
assign error = (count_timeout > timeout_tx | response_error == 3'd7)?1'b1:1'b0;

assign pad_en_sda = (data_config_reg[0] == 1'b1 & state_tx != response_cin & state_tx != response_address & state_tx != response_data1_1)?1'b1:1'b0;
assign pad_en_scl = (data_config_reg[0] == 1'b1)?1'b1:1'b0;


//COMBINATIONAL BLOCK TO   
always@(*)
begin

	//THE FUN start HERE :-)
	//COMBINATIONAL UPDATE STATE BE CAREFUL WITH WHAT YOU MAKE HERE
	next_state_tx=state_tx;

	case(state_tx)//state_   IS MORE SECURE CHANGE ONLY IF YOU KNOW WHAT ARE YOU DOING 
	idle:
	begin
		//OBEYING SPEC
		if(data_config_reg[0] == 1'b0 && (fifo_tx_f_full == 1'b1 || fifo_tx_f_empty == 1'b0))
		begin
			next_state_tx   = idle;
		end
		else if(data_config_reg[0] == 1'b1 && (fifo_tx_f_full == 1'b1 || fifo_tx_f_empty == 1'b0))
		begin
			next_state_tx   = idle;
		end
		else if(data_config_reg[0] == 1'b1 && ((fifo_tx_f_full == 1'b0 && fifo_tx_f_empty == 1'b0) || fifo_tx_f_full == 1'b1) && data_config_reg[1] == 1'b0 && count_timeout < timeout_tx)
		begin
			next_state_tx   = start;
		end


	end
	start://THIS IS USED TOO ALL STATE MACHINES THE COUNTER_SEND_data
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx   = start;
		end
		else
		begin
			next_state_tx   = controlin_1;
		end
		
	end
	controlin_1:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx  = controlin_1;
		end
		else
		begin
			next_state_tx  =  controlin_2;
		end

	end
	controlin_2:
	begin

		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx   = controlin_2;
		end
		else
		begin
			next_state_tx   = controlin_3;
		end

	end
	controlin_3:
	begin

		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx  =  controlin_3;
		end
		else
		begin
			next_state_tx   = controlin_4;
		end		
	end
	controlin_4:
	begin

		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx   = controlin_4;
		end
		else
		begin
			next_state_tx   = controlin_5;
		end		
	end
	controlin_5:
	begin

		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = controlin_5;
		end
		else
		begin
			next_state_tx = controlin_6;
		end		
	end
	controlin_6:
	begin

		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = controlin_6;
		end
		else
		begin
			next_state_tx = controlin_7;
		end		
	end
	controlin_7:
	begin

		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = controlin_7;
		end
		else
		begin
			next_state_tx = controlin_8;
		end		
	end
	controlin_8:
	begin

		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx  = controlin_8;
		end
		else 
		begin
			next_state_tx  = read_write;
		end		
	end
	
	read_write:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx  = read_write;
		end
		else 
		begin
			next_state_tx  = response_cin;
		end	
	end
	
	response_cin:
	begin

		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = response_cin;
		end
		else if(response == 1'b0)//ACK
		begin 
			next_state_tx = controlin_1;
		end
		else if(response == 1'b1)//NACK
		begin
			next_state_tx = stop;
		end	
		
	end

	//NOW SENDING address
	address_1:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx  = address_1;
		end
		else
		begin
			next_state_tx  =  address_2;
		end	
	end
	address_2:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = address_2;
		end
		else
		begin
			next_state_tx = address_3;
		end	
	end
	address_3:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = address_3;
		end
		else
		begin
			next_state_tx = address_4;
		end	
	end
	address_4:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = address_4;
		end
		else
		begin
			next_state_tx = address_5;
		end	
	end
	address_5:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = address_5;
		end
		else
		begin
			next_state_tx = address_6;
		end	
	end
	address_6:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = address_6;
		end
		else
		begin
			next_state_tx = address_7;
		end	
	end
	address_7:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = address_7;
		end
		else
		begin
			next_state_tx = address_8;
		end	
	end
	address_8:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = address_8;
		end
		else
		begin
			next_state_tx = response_address;
		end	
	end
	
	response_address:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = response_address;
		end
		else if(response == 1'b0)//ACK
		begin 
			next_state_tx = data0_1;
		end
		else if(response == 1'b1)//NACK --> RESTART CONDITION AND BACK TO start BYTE AGAIN
		begin
			next_state_tx = stop;
		end	
	end
	
	//data in
	data0_1:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = data0_1;
		end
		else
		begin
			next_state_tx = data0_2;
		end
	end
	data0_2:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = data0_2;
		end
		else
		begin
			next_state_tx = data0_3;
		end
	end
	data0_3:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = data0_3;
		end
		else
		begin
			next_state_tx = data0_4;
		end
	end
	data0_4:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = data0_4;
		end
		else
		begin
			next_state_tx = data0_5;
		end
	end
	data0_5:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = data0_5;
		end
		else
		begin
			next_state_tx   = data0_6;
		end
	end
	data0_6:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx  = data0_6;
		end
		else
		begin
			next_state_tx  = data0_7;
		end
	end
	data0_7:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx  = data0_7;
		end
		else
		begin
			next_state_tx  = data0_8;
		end
	end
	data0_8:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx  = data0_8;
		end
		else
		begin
			next_state_tx  =  data1_1;
		end
	end
	data1_1:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx  = data1_1;
		end
		else
		begin
			next_state_tx  = data1_2;
		end
	end
	data1_2:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = data1_2;
		end
		else
		begin
			next_state_tx = data1_3;
		end
	end
	data1_3:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx  = data1_3;
		end
		else
		begin
			next_state_tx  =  data1_4;
		end
	end
	data1_4:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx  = data1_4;
		end
		else
		begin
			next_state_tx  = data1_5;
		end
	end
	data1_5:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = data1_5;
		end
		else
		begin
			next_state_tx = data1_6;
		end
	end
	data1_6:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx  =  data1_6;
		end
		else
		begin
			next_state_tx  =  data1_7;
		end
	end
	data1_7:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx =  data1_7;
		end
		else
		begin
			next_state_tx =  data1_8;
		end
	end
	data1_8:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = data1_8;
		end
		else
		begin
				
			if(data_config_reg[1])
			begin
			   next_state_tx = response_data1_1;
			end
			else
			begin
			   next_state_tx = stop;
			end
			
		end
	end
	response_data1_1:
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx   =  response_data1_1;
		end
		else
		begin
		
			if(response)
			begin
				next_state_tx   =  data0_1;
			end
			else
			begin			
				next_state_tx   =  stop;
			end
		end
			
	end
	stop://THIS WORK
	begin
		if(count_send_data != data_config_reg[13:2])
		begin
			next_state_tx = stop;
		end
		else
		begin
		
			if(fifo_tx_f_empty)
			begin
				next_state_tx = idle;
			end
			else if(fifo_tx_f_full)
			begin
				next_state_tx = start;
			end
			else
			begin
				next_state_tx = start;
			end		
		
			
		end
	end
	default:
	begin
		next_state_tx =  idle;
	end
	endcase


end



//SEQUENTIAL   
always@(posedge pclk)
begin

	//RESET SYNC
	if(!presetn)
	begin
		//SIGNALS MUST BE RESETED
		count_send_data <= 12'd0;
		state_tx   <= idle;	
		sda_out<= 1'b1;
		fifo_tx_rd_en <= 1'b0;
		//count_tx   <= 2'd0;
		response_error <= 3'd0;
		br_clk_o <= 1'b1;
		response<= 1'b0;	
	end
	else
	begin
		
		// SEQUENTIAL FUN start
		state_tx  <= next_state_tx;

		case(state_tx)
		idle:
		begin

			fifo_tx_rd_en <= 1'b0;
			response_error <= 3'd0;
 
			if(data_config_reg[0] == 1'b0 && (fifo_tx_f_full == 1'b1 ||fifo_tx_f_empty == 1'b0) && data_config_reg[1] == 1'b0)
			begin
				count_send_data <= 12'd0;
				sda_out<= 1'b1;
				br_clk_o <= 1'b1;
			end
			else if(data_config_reg[0] == 1'b1 && ((fifo_tx_f_empty == 1'b0 && fifo_tx_f_full == 1'b0 )|| fifo_tx_f_full == 1'b1 ) && data_config_reg[1] == 1'b0)
			begin
				count_send_data <= count_send_data + 12'd1;
				sda_out<=1'b0;			
			end
			else if(data_config_reg[0] == 1'b1 && (fifo_tx_f_full == 1'b1 ||fifo_tx_f_empty == 1'b0) && data_config_reg[1] == 1'b1)
			begin
				count_send_data <= 12'd0;
				sda_out<= 1'b1;
				br_clk_o <= 1'b1;
			end			

		end
		start:
		begin
			response_error <= 3'd0;
			
			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				br_clk_o <= 1'b0;
			end
			else
			begin
				count_send_data <= 12'd0;					
			end	

			if(count_send_data == data_config_reg[13:2]- 12'd1)
			begin
				sda_out<=fifo_tx_data_out[0:0];
				//count_tx   <= 2'd0;
			end

		end
		controlin_1:
		begin

			
			response_error <= 3'd0;
			
			if(count_send_data < data_config_reg[13:2])
			begin
				
				count_send_data <= count_send_data + 12'd1;
				sda_out<=fifo_tx_data_out[0:0];	

								
				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end			
			end
			else
			begin
				count_send_data <= 12'd0;
				sda_out<=fifo_tx_data_out[1:1];
			end

				
		end
		
		controlin_2:
		begin

			

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				sda_out<=fifo_tx_data_out[1:1];

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				sda_out<=fifo_tx_data_out[2:2];
			end
				
		end

		controlin_3:
		begin

			

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				sda_out<=fifo_tx_data_out[2:2];

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				sda_out<=fifo_tx_data_out[3:3];
			end	


				
		end
		controlin_4:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				sda_out<=fifo_tx_data_out[3:3];

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end				
			end
			else
			begin
				count_send_data <= 12'd0;
				sda_out<=fifo_tx_data_out[4:4];
			end
				
		end

		controlin_5:
		begin

			

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				sda_out<=fifo_tx_data_out[4:4];

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end			
			end
			else
			begin
				count_send_data <= 12'd0;
				sda_out<=fifo_tx_data_out[5:5];
			end	

		end
		controlin_6:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				sda_out<=fifo_tx_data_out[5:5];

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end	
			end
			else
			begin
				count_send_data <= 12'd0;
				sda_out<=fifo_tx_data_out[6:6];
			end	

				
		end

		controlin_7:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				sda_out<=fifo_tx_data_out[6:6];

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end	
			end
			else
			begin
				count_send_data <= 12'd0;
				sda_out<=fifo_tx_data_out[7:7];
			end	

				
		end
		controlin_8:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				sda_out<=fifo_tx_data_out[7:7];

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				sda_out<= 1'b0;
			end

				
		end
		
		read_write:
		begin
		
			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				sda_out<=data_config_reg[1];

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				sda_out<= 1'b0;
			end
		
		
		end
		
		response_cin:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;

				//LETS TRY USE THIS BUT I DONT THINK IF WORKS  
				response<= sda;

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
			end	


		end
		address_1:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				sda_out<=fifo_tx_data_out[8:8];
				
				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				sda_out<=fifo_tx_data_out[9:9];
			end	
				
		end		
		address_2:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				sda_out<=fifo_tx_data_out[9:9];

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				sda_out<=fifo_tx_data_out[10:10];
			end	

		end
		address_3:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				sda_out<=fifo_tx_data_out[10:10];

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end			
			end
			else
			begin
				count_send_data <= 12'd0;
				sda_out<=fifo_tx_data_out[11:11];
			end	

		end
		address_4:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				sda_out<=fifo_tx_data_out[11:11];

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end			
			end
			else
			begin
				count_send_data <= 12'd0;
				sda_out<=fifo_tx_data_out[12:12];
			end	
		end
		address_5:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				sda_out<=fifo_tx_data_out[12:12];

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end				
			end
			else
			begin
				count_send_data <= 12'd0;
				sda_out<=fifo_tx_data_out[13:13];
			end	

				
		end
		address_6:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				sda_out<=fifo_tx_data_out[13:13];

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;		
				sda_out<=fifo_tx_data_out[14:14];
			end	
				
		end
		address_7:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				sda_out<=fifo_tx_data_out[14:14];

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				sda_out<=fifo_tx_data_out[15:15];
			end	

				
		end
		address_8:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				sda_out<=fifo_tx_data_out[15:15];

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				sda_out<=1'b0;
			end	
				
		end
		response_address:
		begin
			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;

				//LETS TRY USE THIS BUT I DONT THINK IF WORKS  
				response<= sda;

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
			end

		end
		data0_1:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				
				if(data_config_reg[1])
				begin
				    sda_out<=fifo_tx_data_out[16:16];
				end
				else
				begin
				   fifo_rx_data_in[0:0] <= sda;
				end
				
				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;	
				
				if(data_config_reg[1])
				begin
				    sda_out<=fifo_tx_data_out[17:17];
				end
				else
				begin
				   fifo_rx_data_in[1:1] <= sda;
				end			
			end	

				
		end
		data0_2:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				
				
				if(data_config_reg[1])
				begin
				    sda_out<=fifo_tx_data_out[17:17];
				end
				else
				begin
				   fifo_rx_data_in[1:1] <= sda;
				end
				
				

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[18:18];
				end
				else
				begin
				   fifo_rx_data_in[2:2] <= sda;
				end
								
				
			end	

				
		end		
		data0_3:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[18:18];
				end
				else
				begin
				   fifo_rx_data_in[2:2] <= sda;
				end
				
				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[19:19];
				end
				else
				begin
				   fifo_rx_data_in[3:3] <= sda;
				end		
			end	
				
		end
		data0_4:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[19:19];
				end
				else
				begin
				   fifo_rx_data_in[3:3] <= sda;
				end

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[20:20];
				end
				else
				begin
				   fifo_rx_data_in[4:4] <= sda;
				end			
			end	
				
		end
		data0_5:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[20:20];
				end
				else
				begin
				   fifo_rx_data_in[4:4] <= sda;
				end	
								
				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end			
			end
			else
			begin
				count_send_data <= 12'd0;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[21:21];
				end
				else
				begin
				   fifo_rx_data_in[5:5] <= sda;
				end
			end

		end
		data0_6:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[21:21];
				end
				else
				begin
				   fifo_rx_data_in[5:5] <= sda;
				end
				
				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end			
			end
			else
			begin
				count_send_data <= 12'd0;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[22:22];
				end
				else
				begin
				   fifo_rx_data_in[6:6] <= sda;
				end
			end
				
		end
		data0_7:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[22:22];
				end
				else
				begin
				   fifo_rx_data_in[6:6] <= sda;
				end

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[23:23];
				end
				else
				begin
				   fifo_rx_data_in[7:7] <= sda;
				end
			end	
				
		end
		data0_8:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[23:23];
				end
				else
				begin
				   fifo_rx_data_in[7:7] <= sda;
				end

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		

			end
			else
			begin
				count_send_data <= 12'd0;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[24:24];
				end
				else
				begin
				   fifo_rx_data_in[8:8] <= sda;
				end
			end	
				
		end
		data1_1:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[24:24];
				end
				else
				begin
				   fifo_rx_data_in[8:8] <= sda;
				end

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end				
			end
			else
			begin
				count_send_data <= 12'd0;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[25:25];
				end
				else
				begin
				   fifo_rx_data_in[9:9] <= sda;
				end

			end

				
		end
		data1_2:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[25:25];
				end
				else
				begin
				   fifo_rx_data_in[9:9] <= sda;
				end

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end	
			end
			else
			begin
				count_send_data <= 12'd0;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[26:26];
				end
				else
				begin
				   fifo_rx_data_in[10:10] <= sda;
				end
			end	

		end
		data1_3:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[26:26];
				end
				else
				begin
				   fifo_rx_data_in[10:10] <= sda;
				end

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end			

			end
			else
			begin
				count_send_data <= 12'd0;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[27:27];
				end
				else
				begin
				   fifo_rx_data_in[11:11] <= sda;
				end
			end	
				
		end
		data1_4:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[27:27];
				end
				else
				begin
				   fifo_rx_data_in[11:11] <= sda;
				end

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end			

			end
			else
			begin
				count_send_data <= 12'd0;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[28:28];
				end
				else
				begin
				   fifo_rx_data_in[12:12] <= sda;
				end
			end	
				
		end
		data1_5:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[28:28];
				end
				else
				begin
				   fifo_rx_data_in[12:12] <= sda;
				end

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		

			end
			else
			begin
				count_send_data <= 12'd0;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[29:29];
				end
				else
				begin
				   fifo_rx_data_in[13:13] <= sda;
				end
			end	
				
		end
		data1_6:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[29:29];
				end
				else
				begin
				   fifo_rx_data_in[13:13] <= sda;
				end

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		

			end
			else
			begin
				count_send_data <= 12'd0;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[30:30];
				end
				else
				begin
				   fifo_rx_data_in[14:14] <= sda;
				end
			end	
				
		end
		data1_7:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[30:30];
				end
				else
				begin
				   fifo_rx_data_in[14:14] <= sda;
				end

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		

			end
			else
			begin
				count_send_data <= 12'd0;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[31:31];
				end
				else
				begin
				   fifo_rx_data_in[15:15] <= sda;
				end
			end	

				
		end
		data1_8:
		begin

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;
				if(data_config_reg[1])
				begin
				   sda_out<=fifo_tx_data_out[31:31];
				end
				else
				begin
				   fifo_rx_data_in[15:15] <= sda;
				end

				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		

			end
			else
			begin
				count_send_data <= 12'd0;
				
				if(data_config_reg[1])
				begin
				   sda_out<=1'b0;
				end
				else
				begin
				
				   if(fifo_rx_f_empty)
				   begin
				   	fifo_rx_wr_en <= 1'b1;
				   	response <= 1'b0;
				   end
				   else if(fifo_rx_f_full)
				   begin
				   	fifo_rx_wr_en <= 1'b0;
				   	
				   	if(response_error == 3'd7)
				   	begin
				   		response_error <= response_error;
				   	end
				   	else
				   	begin
				   		response_error <= response_error + 3'd1;
				   	end
				   	
				   	response <= 1'b1;
				   end
				   else
				   begin
				   	fifo_rx_wr_en <= 1'b1;
				   	response <= 1'b0;
				   end
				   
				end				
				
				
			end	
				
		end
		response_data1_1:
		begin
			fifo_rx_wr_en <= 1'b0;

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;

				if(data_config_reg[1])
				begin
					sda_out <= response;
				end
				else
				begin
					//LETS TRY USE THIS BUT I DONT THINK IF WORKS  
					response<= sda;										
				end
				
				if(count_send_data < data_config_reg[13:2]/12'd4)
				begin
					br_clk_o <= 1'b0;
				end
				else if(count_send_data >= data_config_reg[13:2]/12'd4 && count_send_data < (data_config_reg[13:2]-(data_config_reg[13:2]/12'd4))-12'd1)
				begin
					br_clk_o <= 1'b1;
				end
				else
				begin
					br_clk_o <= 1'b0;
				end		
			end
			else
			begin
				count_send_data <= 12'd0;
				
				if(response)
				begin
				   	if(response_error == 3'd7)
				   	begin
				   		response_error <= response_error;
				   		response <= response;
				   	end
				   	else
				   	begin
				   		response_error <= response_error + 3'd1;
				   		response<=1'b1;
				   	end					
				end
				else
				begin
					response_error <= response_error;
					response <= response;
				end			
				
				if(fifo_tx_f_empty)
				begin
					fifo_tx_rd_en <= 1'b0;
				end
				else if(fifo_tx_f_full)
				begin
					fifo_tx_rd_en <= 1'b1;
				end
				else
				begin
					fifo_tx_rd_en <= 1'b1;
				end
				
			end	

		end
		stop:
		begin

			br_clk_o <= 1'b1;

			if(count_send_data < data_config_reg[13:2])
			begin
				count_send_data <= count_send_data + 12'd1;

				if(count_send_data < data_config_reg[13:2]/12'd2-12'd2)
				begin
					sda_out<=1'b0;
				end
				else if(count_send_data > data_config_reg[13:2]/12'd2-12'd1 && count_send_data < data_config_reg[13:2])
				begin
					sda_out<=1'b1;
				end	
			end
			else
			begin
				response_error <= response_error;
				count_send_data <= 12'd0;
			end
		end
		default:
		begin
			fifo_tx_rd_en <= 1'b0;
			response_error <= 3'd0;
			count_send_data <= 12'd4095;
		end
		endcase
		
	end


end 

//USED ONLY TO COUNTER TIME
always@(posedge pclk)
begin

	//RESET SYNC
	if(!presetn)
	begin
		count_timeout <= 14'd0;
	end
	else
	begin
		if(count_timeout <= timeout_tx && state_tx == idle)
		begin
			if(sda == 1'b0 && scl == 1'b0)
			count_timeout <= count_timeout + 14'd1;
		end
		else
		begin
			count_timeout <= 14'd0;
		end

	end

end


endmodule

