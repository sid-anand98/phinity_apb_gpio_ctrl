`timescale 1ns/1ps
module rc5_enc_16bit(input clock,
                     input reset,
					 input enc_start, 
					 input [15:0]p, 
					 output reg [15:0]c, 
					 output reg enc_done
					 );
	//enc_start - HIGH to start the encryption; p - 16-bit plaintext input ; 
	//c - 16-bit cipher text output ; enc_done - Encryption output availability indicator
	logic [7:0]s[0:5];
	reg [15:0] p_tmp;//Internal signal to handle encryption operation 
	reg [2:0] state;//State representation to manage operations of encryption algorithm FSM
    reg [7:0] CA_seed;
	reg [7:0] CA_out;
	int cnt_g = 0;
	
	CA_8bit dut (.clock(clock),
	             .reset(reset),
				 .CA_seed(CA_seed),
				 .CA_out(CA_out)
				 );
	always_ff @(posedge clock or negedge reset)//Encryption is carried out during positive clock edges of clock input
	begin
		if (!reset)//State will be at "000" during reset at LOW and p_tmp will carry the input plain text
		begin
			state <= 3'b000;
			p_tmp <= p;
			enc_done <= 1'b0;
			c <= 'd0;
			CA_seed <= 8'hFF;
			cnt_g <= 0;
		end
		else
		begin
			if (enc_start == 1'b1)//If enc_start is HIGH, the encryption process begins
			begin
				case (state)
				3'b000:	begin	//S-box key values generation state
						if (cnt_g <= 5)
						begin
							s[cnt_g] <= CA_out;
							cnt_g <= cnt_g + 1;
						end
						else
							state <= 3'b001;
						end
				3'b001:	begin //Initial addition stage
						p_tmp[15:8] <= (p_tmp[15:8] + s[0]) % 9'h100;
						p_tmp[7:0] <= (p_tmp[7:0] + s[1]) % 9'h100;
						state <= 3'b010;
						end
				3'b010:	begin // Computation of MSB 8-bits (Round 1)
						p_tmp[15:8] <= (rotate_left_8bit(p_tmp[15:8]^p_tmp[7:0],(p_tmp[7:0]%8)) + s[2]) % 9'h100;
						state <= 3'b011;
						end
				3'b011:	begin //Computation of LSB 8-bits (Round 1)
						p_tmp[7:0] <= (rotate_left_8bit(p_tmp[7:0]^p_tmp[15:8],(p_tmp[15:8]%8)) + s[3]) % 9'h100;
						state <= 3'b100;
						end
				3'b100:	begin // Computation of MSB 8-bits (Round 2)
						p_tmp[15:8] <= (rotate_left_8bit(p_tmp[15:8]^p_tmp[7:0],(p_tmp[7:0]%8)) + s[4]) % 9'h100;
						state <= 3'b101;
						end
				3'b101:	begin //Computation of LSB 8-bits (Round 2)
						p_tmp[7:0] <= (rotate_left_8bit(p_tmp[7:0]^p_tmp[15:8],(p_tmp[15:8]%8)) + s[5]) % 9'h100;
						state <= 3'b110;
						end
				3'b110:	begin //Final encrypted 16-bit value after two rounds
						c[15:0] <= p_tmp [15:0];
						enc_done <= 1'b1;
						end        
				default:c <= 16'd0;
				endcase
			end
		end
	end
	
	//Function for performing left rotation of 8-bit data
	function [7:0] rotate_left_8bit(
	    input [7:0] data,
		input [2:0] shift
		);
	    rotate_left_8bit =(data << shift) | (data >> (8-shift));
	endfunction
	
endmodule
 