module Chip8 (
output high,
output low,
input clock,
output[7:0] led,
input btn0,
output [3:0] keypad_out,
input [3:0] keypad_in,
output timing
);

assign timing = c0;
assign led[3:0] = key;
assign led[7:4] = keypad_in;
reg aclr_a, aclr_b, aclr;
wire clock_a, clock_b, clock_m;
wire[63:0] data_a, q_a, q_b;
reg[63:0] data_b;
reg wren_a, wren_b, wren;
reg[4:0] address_b;
wire[4:0] address_a;
reg[12:0] address;
wire [7:0] q;
reg[7:0] data;
VRAM vram(	
	aclr_a,
	aclr_b,
	address_a,
	address_b,
	clock_a,
	clock_b,
	data_a,
	data_b,
	wren_a,
	wren_b,
	q_a,
	q_b);
	
NTSC_out out(address_a, q_a, clock_a, clock, high, low);
Memory mem (
	aclr,
	address,
	clock_m,
	data,
	wren,
	q);

Keypad keypad(keypad_in, keypad_out, key, c1, isPressed);
assign clock_m = c1;	
assign clock_b = c1;

reg[3:0] state;
reg[15:0] PC = 16'd512, IR, I;
reg[7:0] V[16];
reg[7:0] SP;
reg[15:0] stack[16];
reg[7:0] sound_timer, delay_timer;

reg[8:0] acc;
reg[7:0] rnd = 8'd1;
reg[63:0] lineBuffer;
reg[63:0] sprLineBuffer;
reg[7:0] counter;
wire[3:0] key;
wire isPressed;

parameter START = 4'd0;
parameter FETCH_1 = 4'd1;
parameter FETCH_2 = 4'd2;
parameter FETCH_3 = 4'd3;
parameter DECODE = 4'd4;
parameter INCR = 4'd5;
parameter DISP_1 = 4'd6;
parameter DISP_2 = 4'd7;
parameter BCD_1 = 4'd8;
parameter DISP_3 = 4'd9;
parameter DISP_4 = 4'd10;
parameter RAMREAD_1 = 4'd11;
parameter RAMREAD_2 = 4'd12;

wire[11:0] nnn;
wire[3:0] n, x, y, op;
wire[7:0] kk;

assign nnn = IR[11:0];
assign n = IR[3:0];
assign x = IR[11:8];
assign y = IR[7:4];
assign kk = IR[7:0];
assign op = IR[15:12];

reg[3:0] freq;
reg nclk;

always @(posedge btn0) begin
	//enable = 1'd1;
end

always @(negedge c0) begin
	freq = freq + 4'd1;
	if(freq == 4'd5) begin
		nclk = ~nclk;
		freq = 4'd0;
	end
end
wire nnclk;
reg enable = 1'd1;
assign nnclk = nclk & enable;
always @(negedge c0) begin
	case(state) 
		START : begin
			counter = 8'd0;
			acc = 9'd0;
			wren = 1'd0;
			wren_b = 1'd0;
			state = FETCH_1;
		end
		FETCH_1 : begin
			address = PC;
			state = FETCH_2;
		end
		FETCH_2 :  begin
			IR[15:8] = q;
			address = PC + 16'd1;
			state = FETCH_3;
		end
		FETCH_3 : begin
			IR[7:0] = q;
			state = DECODE;
		end
		DECODE : begin
			state = INCR;
			case (op)
				4'h0 : begin
					case (n)
						4'h0 : begin
						address_b = counter;
							if(counter != 8'd32) begin
								wren_b = 1'd1;
								data_b = 64'd0;
								
								state = DECODE;
							end
							else if(q_b == 64'd0) state = INCR;
							else begin
								counter = 8'd0;
								state = DECODE;
							end
							counter = counter + 8'd1;
						end
						4'hE : begin
							SP = SP - 8'd1;
							PC = stack[SP];
						end
					endcase
				end
				4'h1 : begin
					PC = nnn;
					state = START;
				end
				4'h2 : begin
					stack[SP] = PC;
					SP = SP + 8'd1;
					PC = nnn;
					state = START;
				end
				4'h3 : if(V[x] == kk) PC = PC + 16'd2;
				4'h4 : if(V[x] != kk) PC = PC + 16'd2;
				4'h5 : if(V[x] == V[y]) PC = PC + 16'd2;
				4'h6 : V[x] = kk;
				4'h7 : V[x] = V[x] + kk;
				4'h8 : begin
					case(n)
						4'h0 : V[x] = V[y];
						4'h1 : V[x] = V[x] | V[y];
						4'h2 : V[x] = V[x] & V[y];
						4'h3 : V[x] = V[x] ^ V[y];
						4'h4 : begin 
							acc = 9'd0 + V[x] + V[y];
							V[15][0] = acc[8];
							V[15][7:1] = 7'd0;
							V[x] = acc[7:0];
						end
						4'h5 : begin 
							acc = 9'd0 + V[x] - V[y];
							V[15][0] = ~acc[8];
							V[15][7:1] = 7'd0;
							V[x] = acc[7:0];
						end
						4'h6 : begin
							V[15][0] = V[x][0];
							V[15][7:1] = 7'd0;
							V[x] = V[x] >> 8'd1;
						end
						4'h7 : begin 
							acc = 9'd0 + V[y] - V[x];
							V[15][0] = ~acc[8];
							V[15][7:1] = 7'd0;
							V[x] = acc[7:0];
						end
						4'hE : begin
							V[15][0] = V[x][7];
							V[15][7:1] = 7'd0;
							V[x] = V[x] << 1;
						end
					endcase
				end
				4'h9 : if(V[x] != V[y]) PC = PC + 16'd2;
				4'hA : I = nnn;
				4'hB : begin
					PC = nnn + V[0];
					state = START;
					end
				4'hC : V[x] = rnd & kk;
				4'hD : begin // Draw
					wren_b = 1'd0;
					address_b = V[y] + counter + 13'd1;
					address = I + counter;
					sprLineBuffer = 63'd0;
					lineBuffer = 63'd0;				
					if(counter == n) state = DISP_4;
					else state = DISP_1;
				end
				4'hE : begin
					case(n)
						4'hE : begin
							if(V[x] == key && isPressed == 1'd1) PC = PC + 13'd2;
						end
						4'h1 : begin
							if(V[x] != key || isPressed != 1'd1) PC = PC + 13'd2;
						end
					endcase
				end
				4'hF : begin
					case (kk)
						8'h07 : V[x] = delay_timer;
						8'h0A : begin
							if(isPressed == 1'd1) V[x] = key;
							else state = DECODE;
						end
						8'h15 : delay_timer = V[x];
						8'h18 : sound_timer = V[x];
						8'h1E : I = I + V[x];
						8'h29 : I = V[x] * 8'd5;
						8'h33 : begin // Binary to BCD
							case (counter)
								8'd0 : data = hundreds;
								8'd1 : data = tens;
								8'd2 : data = ones;
							endcase							
							if(counter == 8'd3) state = INCR;
							else begin
								state = BCD_1;
								wren = 1'd1;
								address = I + counter;
							end
						end
						8'h55: begin
							if(counter > x) state = INCR;
							else begin
								state = BCD_1;
								address = I + counter;
								wren = 1'd1;
								data = V[counter];
							end
						end
						8'h65: begin
							address = I + counter;
							if(counter > x) state = INCR;
							else state = RAMREAD_1;							
						end
					endcase
				end
			endcase
		end
		
		INCR : begin
			PC = PC + 16'd2;
			state = START;
		end
		
		
		DISP_1 : begin
			sprLineBuffer[63:56] = q;
			lineBuffer = q_b;
			state = DISP_2;
		end
		
		DISP_2 : begin
			counter = counter + 8'd1;
			state = DISP_3;
			sprLineBuffer = sprLineBuffer >> V[x];
		end
		
		DISP_3 : begin
			wren_b = 1'd1;
			data_b = lineBuffer ^ sprLineBuffer;
			acc[0] = acc[0] | (|(lineBuffer & sprLineBuffer));
			V[4'hF] = acc[7:0];
			state = DECODE;
		end
		
		DISP_4 : begin
			V[4'hF] = acc[7:0];
			state = INCR;
		end
		
		BCD_1 : begin
			wren = 1'd0;
			counter = counter + 8'd1;
			state = DECODE;
		end
		
		RAMREAD_1 : begin
			V[counter] = q;
			state = RAMREAD_2;
		end
		RAMREAD_2 : begin
			counter = counter + 8'd1;
			state = DECODE;
		end
		
	endcase
	
	timerCount = timerCount + 16'd1;
	if(timerCount == 16'd167) begin
		timerCount = 16'd0;
		if(delay_timer != 0) delay_timer = delay_timer - 8'd1;
		if(sound_timer != 0) sound_timer = sound_timer - 8'd1;
		ledUpdate = ledUpdate + 16'd1;		
	end
	
end

always @(negedge clock) begin
	rnd <= {rnd[6:0], rnd[7] ^ rnd[5] ^ rnd[4] ^ rnd[3]}; // polynomial for maximal LFSR
end

wire [7:0] ones, tens, hundreds;
binary_to_BCD bcd (V[x], ones, tens, hundreds);

wire c0, c1;
Timer timer(clock, c0, c1);

reg[15:0] timerCount = 0, ledUpdate = 0;



endmodule




module Keypad (
input[3:0] in,
output reg[3:0] out = 4'b0001,
output reg[3:0] key,
input clock,
output reg isPressed
);

reg btnPress;
always @(posedge clock) begin

if(out != 4'b1000) out <= (out << 1'b1);
else out <= 4'b0001;

if(out == 4'd0) out <= 4'b0001;
end

always @(negedge clock) begin

case (out)
	4'b0001 : begin
		if(in != 4'd0) begin 
			key = in[0] * 4'd0 + in[1] * 4'd1 + in[2] * 4'd2 + in[3] * 4'd3;
			btnPress = 1'd1;
		end
		else btnPress = 1'd0;
	end
	4'b0010 : begin
		if(in != 4'd0) begin 
			key = in[0] * 4'd4 + in[1] * 4'd5 + in[2] * 4'd6 + in[3] * 4'd7;
			btnPress = 1'd1;
		end
	end
	4'b0100 : begin
		if(in != 4'd0) begin 
			key = in[0] * 4'd8 + in[1] * 4'd9 + in[2] * 4'd10 + in[3] * 4'd11;
			btnPress = 1'd1;
		end
	end
	4'b1000 : begin
		if(in != 4'd0) begin 
			key = in[0] * 4'd12 + in[1] * 4'd13 + in[2] * 4'd14 + in[3] * 4'd15;
			isPressed = 1'd1;
		end
		else isPressed = btnPress;
	end
endcase

end

endmodule

module add3(in,out);
input [3:0] in;
output [3:0] out;
reg [3:0] out;
always @ (in)
	case (in)
		4'b0000: out <= 4'b0000;
		4'b0001: out <= 4'b0001;
		4'b0010: out <= 4'b0010;
		4'b0011: out <= 4'b0011;
		4'b0100: out <= 4'b0100;
		4'b0101: out <= 4'b1000;
		4'b0110: out <= 4'b1001;
		4'b0111: out <= 4'b1010;
		4'b1000: out <= 4'b1011;
		4'b1001: out <= 4'b1100;
		default: out <= 4'b0000;
	endcase
endmodule

module binary_to_BCD(A,ONES,TENS,HUNDREDS);
input [7:0] A;
output [3:0] ONES, TENS;
output [1:0] HUNDREDS;
wire [3:0] c1,c2,c3,c4,c5,c6,c7;
wire [3:0] d1,d2,d3,d4,d5,d6,d7;
assign d1 = {1'b0,A[7:5]};
assign d2 = {c1[2:0],A[4]};
assign d3 = {c2[2:0],A[3]};
assign d4 = {c3[2:0],A[2]};
assign d5 = {c4[2:0],A[1]};
assign d6 = {1'b0,c1[3],c2[3],c3[3]};
assign d7 = {c6[2:0],c4[3]};
add3 m1(d1,c1);
add3 m2(d2,c2);
add3 m3(d3,c3);
add3 m4(d4,c4);
add3 m5(d5,c5);
add3 m6(d6,c6);
add3 m7(d7,c7);
assign ONES = {c5[2:0],A[0]};
assign TENS = {c7[2:0],c5[3]};
assign HUNDREDS = {c6[3],c7[3]};
endmodule
