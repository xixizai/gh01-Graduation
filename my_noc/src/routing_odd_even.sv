`include "config.sv"
//d != LOC
module routing_odd_even#(
  parameter integer X_LOC, // Current location on the X axis
  parameter integer Y_LOC // Current location on the Y axis
)
(
  input logic [0:`N-1] i_routing_calculate,
  input logic [0:`N-1][$clog2(`X_NODES)-1:0] i_x_source,
  input logic [0:`N-1][$clog2(`X_NODES)-1:0] i_x_dest,
  input logic [0:`N-1][$clog2(`Y_NODES)-1:0] i_y_dest,
  
  output logic [0:`N-1] o_select_neighbor,
  output logic [0:`N-1][0:`M-1][1:0] o_avail_directions
  // One-hot request for the [local, north, east, south, west] output port
  //     1
  //   4 0 2
  //     3
);

	//logic [0:`N-1][$clog2(`X_NODES)-1:0] e0;
	//logic [0:`N-1][$clog2(`Y_NODES)-1:0] e1;
	
   always_comb begin
		   o_select_neighbor = '0;
		   o_avail_directions = '0;
      for(int i=0;i<`N;i++)begin
   	   //e0[i] = i_x_dest[i] - X_LOC;
	      //e1[i] - Y_LOC[i] = i_y_dest[i] - Y_LOC;
	      if(i_routing_calculate[i])begin
				if(i_x_dest[i] == X_LOC[i]) begin
					if(i_y_dest[i] > Y_LOC[i]) begin
						o_avail_directions[i][o_avail_directions[i][`M-1]] = 1-1;//directions.push_back(DIRECTION_NORTH);
						o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
					end else begin
						o_avail_directions[i][o_avail_directions[i][`M-1]] = 3-1;//directions.push_back(DIRECTION_SOUTH);
						o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
					end
				end else begin
					if(i_x_dest[i] > X_LOC[i]) begin
						if(i_y_dest[i] == Y_LOC) begin
							o_avail_directions[i][o_avail_directions[i][`M-1]] = 2-1;//directions.push_back(DIRECTION_EAST);
							o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
						end else begin
							if((X_LOC % 2 == 1) || (X_LOC == i_x_source[i])) begin
								if(i_y_dest[i] > Y_LOC[i]) begin
									o_avail_directions[i][o_avail_directions[i][`M-1]] = 1-1;//directions.push_back(DIRECTION_NORTH);
									o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
								end else begin
									o_avail_directions[i][o_avail_directions[i][`M-1]] = 3-1;//directions.push_back(DIRECTION_SOUTH);
									o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
								end
							end
							if((i_x_dest[i] % 2 == 1) || ((i_x_dest[i] - X_LOC != 1) && (X_LOC - i_x_dest[i] != 1))) begin
								o_avail_directions[i][o_avail_directions[i][`M-1]] = 2-1;//directions.push_back(DIRECTION_EAST);
								o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
							end
						end
					end else begin
						o_avail_directions[i][o_avail_directions[i][`M-1]] = 4-1;//directions.push_back(DIRECTION_WEST);
						o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
						if(X_LOC % 2 == 0) begin
							if(i_y_dest[i] > Y_LOC[i]) begin
								o_avail_directions[i][o_avail_directions[i][`M-1]] = 1-1;//directions.push_back(DIRECTION_NORTH);
								o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
							end
							if(i_y_dest[i] < Y_LOC[i]) begin
								o_avail_directions[i][o_avail_directions[i][`M-1]] = 3-1;//directions.push_back(DIRECTION_SOUTH);
								o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
							end
						end
					end
				end
				o_select_neighbor[i] = 1;
			end
		end
   end

endmodule
