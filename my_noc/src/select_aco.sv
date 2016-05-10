`include "config.sv"

module select_aco#(
  parameter integer X_LOC, // Current location on the X axis
  parameter integer Y_LOC // Current location on the Y axis
)(
  input logic reset_n,
  
  input logic [0:`N-1] i_update,
  input logic [0:`N-1] i_select_neighbor,
  input logic [0:`N-1][0:`M-1][1:0] i_avail_directions,
  input logic [0:`N-1][$clog2(`X_NODES)-1:0] i_x_dest,
  input logic [0:`N-1][$clog2(`Y_NODES)-1:0] i_y_dest,
  output logic [0:`N-1][0:`M-1] o_output_req,
  
  output logic [0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] test_pheromones,
  output logic [`PH_TABLE_DEPTH-1:0] test_max_pheromone_value,
  output logic [`PH_TABLE_DEPTH-1:0] test_min_pheromone_value
);
   logic [0:`N-1][`M-1:0] rand_seed;
	logic [0:`N-1][1:0] rand_num;
	
   logic [0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] pheromones;
   logic [`PH_TABLE_DEPTH-1:0] max_pheromone_value;
   logic [`PH_TABLE_DEPTH-1:0] min_pheromone_value;
   logic [$clog2(`N)-1:0] max_pheromone_neighbor;
   logic [$clog2(`N)-1:0] min_pheromone_neighbor;
  
   logic [0:`N-1][$clog2(`NODES)-1:0] l_dest;
  
   assign test_pheromones = pheromones;
   assign test_max_pheromone_value = max_pheromone_value;
   assign test_min_pheromone_value = min_pheromone_value;

   always_comb begin
    
      if(~reset_n)begin
			rand_seed = '0;
			rand_num = '0;
		   pheromones = '0;
		   o_output_req = '0;
		   l_dest = '0;
         max_pheromone_value = '0;
         min_pheromone_value = '0;
         max_pheromone_neighbor = '0;
         min_pheromone_neighbor = '0;
      end else begin
         for(int i=0;i<`N;i++)begin
			   rand_seed[i] = rand_seed[i] == 11111 ? 0 : rand_seed[i] + 1;
				//rand_seed[i] = rand_seed[i] + 1;
				rand_num[i] = i_avail_directions[i][`M-1]==0 ? 3 : rand_seed % i_avail_directions[i][`M-1];
	         o_output_req[i] = '0;//o_output_req[i];
    	      l_dest[i] = i_y_dest[i] * `X_NODES + i_x_dest[i];
				
	         max_pheromone_value = `PH_MIN_VALUE;
	         min_pheromone_value = `PH_MAX_VALUE; 
	         max_pheromone_neighbor = '0;
	         min_pheromone_neighbor = '0;
        
	         if(i_select_neighbor[i]) begin
               for(int j = 0; j < i_avail_directions[i][`M-1]; j++) begin
                  if(i_avail_directions[i][j]+1 != i) begin
	    	            if(max_pheromone_value < pheromones[l_dest[i]][i_avail_directions[i][j]]) begin
                        max_pheromone_value = pheromones[l_dest[i]][i_avail_directions[i][j]];
                        max_pheromone_neighbor = i_avail_directions[i][j]+1;
		               end
		               if(min_pheromone_value > pheromones[l_dest[i]][i_avail_directions[i][j]]) begin
                        min_pheromone_value = pheromones[l_dest[i]][i_avail_directions[i][j]];
                        min_pheromone_neighbor = i_avail_directions[i][j]+1;
		               end
                  end
               end
//	            if((max_pheromone_value - min_pheromone_value) > 2) begin//:calculate by using table 
//	               //may make error choice(choose output with less pheromone)
//	 	            //prevent deadlock
//		            /*
//                     rule
//	 	            */
//	 	            for(int j = 0; j < `N; j++) begin
//                     o_output_req[i][j] = (j == max_pheromone_neighbor) ? 1 : 0;
//                end
//	 	         end else begin//(is not ant packet and table.d is not avail) begin:calculate by XY-random router
	 	            for(int j = 0; j < `N; j++) begin
                     //o_output_req[i][j] = (j == i_avail_directions[i][0]) ? 1 : 0;
                     o_output_req[i][j] = (j == (i_avail_directions[i][rand_num[i]] + 1) ) ? 1 : 0;
					   end
//	            end
            end else if(i_update[i]) begin
               for(int j = 0; j < `N-1; j++) begin
                  if(j+1 == i) begin
			 	         pheromones[l_dest[i]][j] = (pheromones[l_dest[i]][j] < `PH_MAX_VALUE) ? pheromones[l_dest[i]][j]+1:pheromones[l_dest[i]][j];
                  end else begin
				         pheromones[l_dest[i]][j] = (pheromones[l_dest[i]][j] > `PH_MIN_VALUE) ? pheromones[l_dest[i]][j]-1:pheromones[l_dest[i]][j];
                  end
               end
            end
	      end
	   end
   end
endmodule

					/*
	               //XY-YX routing
		            //temp = pheromones[l_dest[i]][0] + pheromones[l_dest[i]][1] + pheromones[l_dest[i]][2] + pheromones[l_dest[i]][3];
	 	            if(i_x_dest[i] > i_y_dest[i]) begin    //if(temp[0] == 0) begin //temp[7] == 0
		               if(i_x_dest[i] != X_LOC) 
                        o_output_req[i] = (i_x_dest[i] > X_LOC) ? 5'b00100 : 5'b00001;
                     else if (i_y_dest[i] != Y_LOC)
                        o_output_req[i] = (i_y_dest[i] > Y_LOC) ? 5'b01000 : 5'b00010;//1 : 3;
		            end else begin
		               if(i_y_dest[i] != Y_LOC)
                        o_output_req[i] = (i_y_dest[i] > Y_LOC) ? 5'b01000 : 5'b00010;//1 : 3;
                     else if (i_x_dest[i] != X_LOC) 
                        o_output_req[i] = (i_x_dest[i] > X_LOC) ? 5'b00100 : 5'b00001;
		            end
					*/