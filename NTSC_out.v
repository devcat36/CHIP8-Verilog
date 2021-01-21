module NTSC_out (
output[4:0] addrA,
input[63:0] VramOut,
output ramClk,
input clk,
output out_high, out_low
);

wire base_clk;
reg high=0, low=0;

ntsc_pll ntsc(,clk,base_clk,);

reg[31:0] counter = 0;
reg[7:0] counter1 = 0;
reg[3:0] counter2 = 0;
reg[15:0] vertCount = 16'd1;
reg[7:0] pix_x = 0;
reg[7:0] pix_y = 0;
reg visible = 0;
reg invert = 0;
reg[63:0] lineBuffer;
reg readClk=0;

always @(posedge base_clk) begin
	counter <= counter + 'd1;
	
	case (counter)
	
		'd0:	begin
			high <= 1'b0;
			low <= 1'b0;
			if(vertCount > 16'd40) begin
				counter2 <= counter2 + 1;
			end
		end
		
		'd47:	begin
			high <= 1'b0; 
			low <= 1'b1;
			pix_x <= 5'b0;
			readClk = 1;
		end
		
		'd108:	begin
			high <= 1'b1; 
			low <= 1'b1;
		end
		
		'd131:	begin
			visible <= 1'b1;
		end
		
		
		'd623:	begin	
			high <= 1'b0; 
			low <= 1'b1;
			visible <= 0;
			readClk = 0;
			if(counter2 >= 4'd5) begin
				counter2 <= 0;
				if(pix_y < 33) begin
					pix_y <= pix_y + 1;
					if(pix_y!=0)lineBuffer <= VramOut;
					else lineBuffer <= 0;
				end
				else lineBuffer <= 0;
			end
		end
		
		'd635:	begin	
			high = 1'b0; 
			low = 1'b0; 
			if(vertCount != 262) begin
				vertCount <= vertCount + 1;
				if(vertCount == 243) invert <= 1'b1;
			end
			else begin
				invert <= 0;
				vertCount <= 0;
				pix_y <= 0;
				counter2 <= 0;
			end
			counter <= 0;
		end
		
		
	endcase
	
	
	
	if((visible == 1'b1) & (counter1 < 6)) counter1 <= counter1 + 1;

	if(counter1 == 6) begin
		if(pix_x < 8'd63) begin
			pix_x <= pix_x + 1;
		
		end
		else visible <= 0;
		counter1 <= 0;
	end
	


	
end


assign addrA = pix_y;
assign out_high = high & lineBuffer[8'd63 - pix_x] & (~invert) & visible;
assign out_low = low ^ invert;
assign ramClk = readClk;

endmodule
