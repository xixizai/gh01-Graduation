`timescale 1ps/1ps

`include "config.sv"

module tb_nw_packet
#(
  parameter CLK_PERIOD = 100ps,
  parameter integer PACKET_RATE = 2, // Offered traffic as percent of capacity
  parameter integer NODE_QUEUE_DEPTH = `INPUT_QUEUE_DEPTH * 8
);

   // ==========================================================================================================================
	
   logic    clk;
   logic    reset_n;
   longint  f_time;
   logic    [7:0] packet_count;
   // network port ------------------------------
   packet_t [0:`NODES-1] i_data; 
   logic    [0:`NODES-1] i_data_val; 
   logic    [0:`NODES-1] o_en; 
   
   packet_t [0:`NODES-1] o_data; 
   logic    [0:`NODES-1] o_data_val; 
   // random number -----------------------------
   int      rand_i;
   logic    [$clog2(`X_NODES)-1:0] rand_x_dest;
   logic    [$clog2(`Y_NODES)-1:0] rand_y_dest;
	
   // test port ================================================================================================================
	
   logic    [0:`NODES-1][0:`N-1] test_en_SCtoFF;
   // FFtoAA ---------------------------------------------------------------------
   packet_t [0:`NODES-1][0:`N-1] test_data_FFtoAA;
   logic    [0:`NODES-1][0:`N-1] test_data_val_FFtoAA;
   // AAtoSW ---------------------------------------------------------------------
   packet_t [0:`NODES-1][0:`N-1] test_data_AAtoSW;
   // AAtoRC ---------------------------------------------------------------------
   logic    [0:`NODES-1][0:`N-1] test_data_val_AAtoRC;
   logic    [0:`NODES-1][0:`N-1][0:`M-1] test_output_req_AAtoRC;
   // RCtoSC ---------------------------------------------------------------------
   logic    [0:`NODES-1][0:`N-1][0:`M-1] test_output_req_RCtoSC;
   // SC.sv ----------------------------------------------------------------------
   logic    [0:`NODES-1][0:`N-1][0:`M-1] test_l_req_matrix_SC;
   // AA.sv ----------------------------------------------------------------------
   logic [0:`NODES-1][0:`N-1]test_routing_calculate;
   logic    [0:`NODES-1][0:`N-1] test_update;
   logic    [0:`NODES-1][0:`N-1] test_select_neighbor;
   logic    [0:`NODES-1][0:`N-1][0:`M-1] test_tb_o_output_req;
   // ant_routing_table.sv --------------------------------------------------------
   logic    [0:`NODES-1][0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] test_pheromones;
   logic    [0:`NODES-1][0:`PH_TABLE_DEPTH-1] test_max_pheromone_value;
   logic    [0:`NODES-1][0:`PH_TABLE_DEPTH-1] test_min_pheromone_value;
   logic [0:`NODES-1][0:`N-1][0:`M-1][1:0] test_avail_directions;
	
   // ============================================================================================================================
   
   network network(
						.clk(clk), 
						.reset_n(reset_n), 
						.i_data(i_data), 
						.i_data_val(i_data_val),
						.o_en(o_en),
						.o_data(o_data),
						.o_data_val(o_data_val),
						// ---------------------------------------------
						.test_en_SCtoFF(test_en_SCtoFF),
						
						.test_data_FFtoAA(test_data_FFtoAA),
						.test_data_val_FFtoAA(test_data_val_FFtoAA), 
						
						.test_data_AAtoSW(test_data_AAtoSW),
						
						.test_data_val_AAtoRC(test_data_val_AAtoRC),
						.test_output_req_AAtoRC(test_output_req_AAtoRC),
						
						.test_output_req_RCtoSC(test_output_req_RCtoSC),
						
						.test_l_req_matrix_SC(test_l_req_matrix_SC),
						
						
                  .test_routing_calculate(test_routing_calculate),
						.test_update(test_update),
						.test_select_neighbor(test_select_neighbor),
						.test_tb_o_output_req(test_tb_o_output_req),
						
						.test_pheromones(test_pheromones),
						.test_max_pheromone_value(test_max_pheromone_value),
						.test_min_pheromone_value(test_min_pheromone_value),
					   .test_avail_directions(test_avail_directions)
   );

   // ===========================================================================================================================
   
   // intermediate variable generation(random)
   // ------------------------------------------------------------
   always_ff@(posedge clk) begin
      if(~reset_n) begin
	      rand_i <= 0;
		   rand_x_dest <= 0;
			rand_y_dest <= 0;
      end else begin
	      rand_i <= $urandom_range(`NODES-1, 0);
		   rand_x_dest <= $urandom_range(`X_NODES-1, 0);
			rand_y_dest <= $urandom_range(`Y_NODES-1, 0);
      end
   end

   // input data of network generation
   // -------------------------------------------------------------
   always_ff@(negedge clk) begin
	   if(~reset_n) begin
         packet_count <= 0;
         for(int y = 0; y < `Y_NODES; y++) begin
            for (int x = 0; x < `X_NODES; x++) begin
			      i_data_val[y*`X_NODES + x] <= 0;
			      
					i_data[y*`X_NODES + x].id <= 0;
					
               i_data[y*`X_NODES + x].x_source <= x; 
               i_data[y*`X_NODES + x].y_source <= y; 
               i_data[y*`X_NODES + x].x_dest <= 0; 
               i_data[y*`X_NODES + x].y_dest <= 0; 
				   
			      i_data[y*`X_NODES + x].ant <= 1;
				   i_data[y*`X_NODES + x].backward <= 0;
				   
               i_data[y*`X_NODES + x].x_memory <= 0;
               i_data[y*`X_NODES + x].y_memory <= 0;
               i_data[y*`X_NODES + x].num_memories <= 0;
					
               i_data[y*`X_NODES + x].b_x_memory <= 0;
               i_data[y*`X_NODES + x].b_y_memory <= 0;
               i_data[y*`X_NODES + x].b_num_memories <= 0;
					
					i_data[y*`X_NODES + x].measure <= 0;
					i_data[y*`X_NODES + x].timestamp <= 0;
            end
         end
      end else begin
         if (f_time % 10 == 0) begin
			//if (f_time == 10) begin
			      i_data_val[rand_i] <= 1;
			      
               i_data[rand_i].x_dest <= rand_x_dest; 
               i_data[rand_i].y_dest <= rand_y_dest; 
					
			      i_data[rand_i].id <= packet_count;
				   packet_count <= packet_count + 1;
         end else begin
			   for(int i=0; i<`NODES; i++) begin
               i_data_val[i] <= 0;
			      i_data[i].x_dest <= 0;
			      i_data[i].y_dest <= 0;
				end
			end
      end
	  /*
		seed = 2;
		$display(" seed is set %d",seed);
		void'($urandom(seed));
		for(i = 0;i < 10; i=i+1) begin
		   num = $urandom() % 10;
		   $write("| num=%2d |",num);
		end
		$display(" ");
	  */
   end
	
   // ===========================================================================================================================
    
	// SIMULATION:  System Clock ----------------------------------
   initial begin
      clk = 1;
      forever #(CLK_PERIOD/2) clk = ~clk;
   end
	
   // SIMULATION:  System Time -----------------------------------
   initial begin
      f_time = 0;
      forever #(CLK_PERIOD) f_time = f_time + 1;
   end
	
   // SIMULATION:  System Reset -----------------------------------
   initial begin
      reset_n = 0;
      #(CLK_PERIOD + 3 * CLK_PERIOD / 4)
      reset_n = 1;
   end
	
   // SIMULATION:  Run Period -------------------------------------
   initial begin
      #(CLK_PERIOD * 1000) $finish;
   end
	
   // SIMULATION:  display -----------------------------------------------------
   initial begin
      $display("");//$monitot("",);
      forever@(posedge clk) begin
		   for(int i=0; i<`NODES; i++) begin
			   if(i_data_val[i]) begin
               $display("f_time: %g;  packet_count:%g;  input node: %g;", f_time, i_data[i].id, i);
				   $display(" source: %d,%d ; destinaton: %d,%d ; ", i_data[i].x_source, i_data[i].y_source, i_data[i].x_dest, i_data[i].y_dest);
            end
            if(o_data_val[i]) begin
               $display("f_time: %g;  packet_count:%g;  output node: %g;", f_time, o_data[i].id, i);
				   $display(" source: %d,%d ; destinaton: %d,%d ; ", o_data[i].x_dest, o_data[i].y_dest, o_data[i].x_source, o_data[i].y_source);
			      for(int m=0; m<o_data[i].num_memories; m++) begin
				      $display(" path: %d,%d ; ", o_data[i].x_memory[m], o_data[i].y_memory[m]);
				   end
				   $display(" source: %d,%d ; destinaton: %d,%d ; ", o_data[i].x_source, o_data[i].y_source, o_data[i].x_dest, o_data[i].y_dest);
			      for(int m=0; m<o_data[i].b_num_memories; m++) begin
				      $display(" path: %d,%d ; ", o_data[i].b_x_memory[m], o_data[i].b_y_memory[m]);
				   end
            end
			end
      end
   end
	
endmodule
