`include "config.sv"
//自适应路由算法自适应路由算法自适应路由算法自适应路由算法自适应路由算法自适应路由算法自适应路由算法自适应路由算法自适应路由算法自适应路由算法
module ant_agent
#(
  parameter integer X_LOC, // Current location on the X axis
  parameter integer Y_LOC // Current location on the Y axis
)
(
  input logic reset_n,  
  input packet_t [0:`N-1] i_data, // Data in
  input logic [0:`N-1] i_data_val, // Data in valid
  
  output packet_t [0:`M-1] o_data, // Data out
  output logic [0:`N-1] o_data_val, // Data out valid
  output logic [0:`N-1][0:`M-1] o_output_req, //output request
  
  output logic [0:`N-1]test_routing_calculate,
  output logic [0:`N-1]test_update,
  output logic [0:`N-1]test_select_neighbor,
  output logic [0:`N-1][0:`M-1] test_tb_o_output_req,
  
  output logic [0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] test_pheromones,
  output logic [`PH_TABLE_DEPTH-1:0] test_max_pheromone_value,
  output logic [`PH_TABLE_DEPTH-1:0] test_min_pheromone_value,
  output logic [0:`N-1][0:`M-1][1:0] test_avail_directions
);

   logic [0:`N-1][0:`M-1][$clog2(`Y_NODES)-1:0] l_avail_directions;
	
   logic [0:`N-1]l_routing_calculate;
   logic [0:`N-1]l_update;
   logic [0:`N-1]l_select_neighbor;
   
   logic [0:`N-1][$clog2(`X_NODES)-1:0] l_x_source;
   logic [0:`N-1][$clog2(`X_NODES)-1:0] l_x_temp;
   logic [0:`N-1][$clog2(`Y_NODES)-1:0] l_y_temp;
   
   logic [0:`N-1][0:`M-1] l_output_req;
   logic [0:`N-1][0:`M-1] tb_o_output_req;
	
	assign test_routing_calculate = l_routing_calculate;
   assign test_update = l_update;
   assign test_select_neighbor = l_select_neighbor;
   assign test_tb_o_output_req = tb_o_output_req;
	assign test_avail_directions = l_avail_directions;
   
	routing_odd_even #(.X_LOC(X_LOC), .Y_LOC(Y_LOC))
	   routing_odd_even(
		                 .i_routing_calculate(l_routing_calculate), //whether select neighbor or not
		                 .i_x_source(l_x_source),
		                 .i_x_dest(l_x_temp),
		                 .i_y_dest(l_y_temp),
		                 .o_select_neighbor(l_select_neighbor), //whether select neighbor or not
							  .o_avail_directions(l_avail_directions)
		                );
   select_aco #(.X_LOC(X_LOC), .Y_LOC(Y_LOC))
      select_aco(
		              .reset_n(reset_n),
						  
		              .i_update(l_update),// whether update or not
		              .i_select_neighbor(l_select_neighbor), //whether select neighbor or not
						  .i_avail_directions(l_avail_directions),
		              
		              .i_x_dest(l_x_temp),
		              .i_y_dest(l_y_temp),
		              
		              .o_output_req(tb_o_output_req),
		              
		              .test_pheromones(test_pheromones),
		              .test_max_pheromone_value(test_max_pheromone_value),
		              .test_min_pheromone_value(test_min_pheromone_value)
		             );

   always_comb begin

      for(int i=0; i<`N; i++) begin
         o_data[i] = '0;
         o_data_val[i] = '0;

         l_update[i] = '0;
         l_routing_calculate[i] = '0;
	 
	      l_x_source[i] = '0;
         l_x_temp[i] = '0;
         l_y_temp[i] = '0;
	 
         l_output_req[i] = '0;
	 
         if(i_data_val[i]) begin
         // data valid
            o_data[i] = i_data[i];
		      
				l_x_source[i] = o_data[i].x_source;
            l_x_temp[i] = o_data[i].x_dest;
            l_y_temp[i] = o_data[i].y_dest;
		    
            if(~o_data[i].ant) begin
            // handle normal packet ==========================================================================================
               // memorize
	            o_data[i].x_memory[o_data[i].num_memories] = X_LOC;
               o_data[i].y_memory[o_data[i].num_memories] = Y_LOC;
               o_data[i].num_memories = o_data[i].num_memories + 1;
               
               if(X_LOC != o_data[i].x_dest || Y_LOC != o_data[i].y_dest) begin 
               // LOC != dest: send normal packet
					
                  // 1.select_neighbor
				      //l_is_ant[i] = 1'b0;
                  l_routing_calculate[i] = 1'b1;
				      // delay
                  // 2.o_output_req[i] = r_o_output_req
               end else begin
			      // LOC == dest
                  l_output_req[i] = 5'b10000;
               end
            end else begin
            // handle ant packet ============================================================================================
               if(~o_data[i].backward) begin
	            // handle forward ant packet ---------------------------------------------------------------------------------
                  // memorize
	               o_data[i].x_memory[o_data[i].num_memories] = X_LOC;
                  o_data[i].y_memory[o_data[i].num_memories] = Y_LOC;
                  o_data[i].num_memories = o_data[i].num_memories + 1;
                     
                  if(X_LOC != o_data[i].x_dest || Y_LOC != o_data[i].y_dest) begin
                  // LOC != dest: send forward
				         // 1.select_neighbor
                     l_routing_calculate[i] = 1'b1;
				         // delay
				         // 2.o_output_req[i] = r_o_output_req
                  end else begin
                  // LOC == dest: create and send backward ant packet
				         
                     // create backward ant packet
                     o_data[i].backward = 1'b1;
                     l_x_temp[i] = o_data[i].x_dest;
                     l_y_temp[i] = o_data[i].y_dest;
				       
                     o_data[i].x_dest = o_data[i].x_source;
                     o_data[i].y_dest = o_data[i].y_source;
				        
                     o_data[i].x_source = l_x_temp[i];
                     o_data[i].y_source = l_y_temp[i];
	                  
	                  // send backward
							if(o_data[i].x_dest != X_LOC || o_data[i].y_dest != Y_LOC) begin
                        // memorize---back path
	                     o_data[i].b_x_memory[o_data[i].b_num_memories] = X_LOC;
                        o_data[i].b_y_memory[o_data[i].b_num_memories] = Y_LOC;
                        o_data[i].b_num_memories = o_data[i].b_num_memories + 1;
							
                        if(o_data[i].x_memory[o_data[i].num_memories-2] != X_LOC)
                           l_output_req[i] = (o_data[i].x_memory[o_data[i].num_memories-2] > X_LOC) ? 5'b10100 : 5'b10001;//2 : 4;
                        else //if(o_data[i].y_memory[o_data[i].num_memories-2] != Y_LOC)
                           l_output_req[i] = (o_data[i].y_memory[o_data[i].num_memories-2] > Y_LOC) ? 5'b11000 : 5'b10010;//1 : 3;
							end else begin
                        l_output_req[i] = 5'b10000;
						   end
                  end
               end else begin
	            // handle backward ant packet	---------------------------------------------------------------------------------
                  // memorize backward path
	               o_data[i].b_x_memory[o_data[i].b_num_memories] = X_LOC;
                  o_data[i].b_y_memory[o_data[i].b_num_memories] = Y_LOC;
                  o_data[i].b_num_memories = o_data[i].b_num_memories + 1;
						
						if(o_data[i].x_source != X_LOC || o_data[i].y_source != Y_LOC) begin
                  // LOC != src: update pheromones
                     l_update[i] = 1'b1;
						end
                  if(o_data[i].x_dest != X_LOC || o_data[i].y_dest != Y_LOC) begin
                  // LOC != dest: send backward
                     for(int m = 1;m < o_data[i].num_memories; m++) begin
                        if(o_data[i].x_memory[m] == X_LOC && o_data[i].y_memory[m] == Y_LOC) begin
                           if(o_data[i].x_memory[m-1] != X_LOC) 
                              l_output_req[i] = (o_data[i].x_memory[m-1] > X_LOC) ? 5'b00100 : 5'b00001;//2 : 4;
                           else
                              l_output_req[i] = (o_data[i].y_memory[m-1] > Y_LOC) ? 5'b01000 : 5'b00010;//1 : 3;
                        end
                     end
                  end else begin
						// LOC == dest: 
                     l_output_req[i] = 5'b10000;
                  end
               end // if(~o_data[i].backward)
            end // if(~o_data[i].ant)
				
            o_data_val[i] = 1'b1;
         end // if(i_data_val[i])
      end // for()
   end // always_comb  
  
   always_comb begin
      for(int i=0;i<`N;i++)begin
	      o_output_req[i]= l_select_neighbor[i] ? tb_o_output_req[i] : l_output_req[i];
	   end
   end

endmodule
