`timescale 1ps/1ps

`include "config.sv"

module tb_nw_packet_b
#(
   parameter CLK_PERIOD = 100ps,
   parameter integer PACKET_RATE = 1, // Offered traffic as percent of capacity
   
   parameter integer WARMUP_PACKETS = `warmup_packets_num, // Number of packets to warm-up the network
   parameter integer MEASURE_PACKETS = `warmup_packets_num*5, // Number of packets to be measured
   parameter integer DRAIN_PACKETS = `warmup_packets_num*3, // Number of packets to drain the network
  
   parameter integer NODE_QUEUE_DEPTH = `INPUT_QUEUE_DEPTH * 8,
   parameter integer RUNNING_TIME = 10000,
	parameter logic debug = 1
);

   // ================================================================================================================================
	
   logic    clk;
   logic    reset_n;
   longint  f_time;
   longint  f_time_begin;
   logic    [7:0] packet_id;
   // network port ------------------------------
   packet_t [0:`NODES-1] i_data; 
   logic    [0:`NODES-1] i_data_val; 
   logic    [0:`NODES-1] o_en; 
   
   packet_t [0:`NODES-1] o_data; 
   logic    [0:`NODES-1] o_data_val; 
   // random number -----------------------------
   int      rand_i;
   logic    [0:`NODES-1] rand_data_val;
   logic    [0:`NODES-1][$clog2(`X_NODES)-1:0] rand_x_dest;
   logic    [0:`NODES-1][$clog2(`Y_NODES)-1:0] rand_y_dest;
	
   // ================================================================================================================================
   // FLAGS:  Control --------------------------------------------------------------------------------------------------
   longint f_port_i_data_count_all [0:`NODES-1]; // Count number of packets that left the node, transmitted on each port
	longint f_port_i_data_count_normal [0:`NODES-1];
	longint f_port_i_data_count_ant [0:`NODES-1];
	longint f_port_i_data_count_forward [0:`NODES-1];
	longint f_port_i_data_count_backward [0:`NODES-1];
   longint f_port_o_data_count_all [0:`NODES-1]; // Count number of received packets on each port
	longint f_port_o_data_count_normal [0:`NODES-1];
	longint f_port_o_data_count_ant [0:`NODES-1];
	longint f_port_o_data_count_forward [0:`NODES-1];
	longint f_port_o_data_count_backward [0:`NODES-1];
   longint f_total_i_data_count_all;            // Count total number of transmitted packets
	longint f_total_i_data_count_normal;
	longint f_total_i_data_count_ant;
	longint f_total_i_data_count_forward;
	longint f_total_i_data_count_backward;
   longint f_total_o_data_count_all;            // Count total number of received packets
	longint f_total_o_data_count_normal;
	longint f_total_o_data_count_ant;
	longint f_total_o_data_count_forward;
	longint f_total_o_data_count_backward;
	
   longint f_throughput_port_i_packet_count_all [0:`NODES-1]; // Counts number of packets sent over a given number of cycles
   longint f_throughput_port_i_packet_count_normal [0:`NODES-1];
   longint f_throughput_port_i_packet_count_ant [0:`NODES-1];
   longint f_throughput_port_i_packet_count_forward [0:`NODES-1];
   longint f_throughput_port_i_packet_count_backward [0:`NODES-1];
	longint f_throughput_port_o_packet_count_all [0:`NODES-1]; // Counts number of packets received over a given number of cycles
	longint f_throughput_port_o_packet_count_normal [0:`NODES-1];
	longint f_throughput_port_o_packet_count_ant [0:`NODES-1];
	longint f_throughput_port_o_packet_count_forward [0:`NODES-1];
	longint f_throughput_port_o_packet_count_backward [0:`NODES-1];
   real    f_throughput_total_i_packet_count_all;            // Counts number of packets simulated over a given number of cycles
   real    f_throughput_total_i_packet_count_normal;
   real    f_throughput_total_i_packet_count_ant;
   real    f_throughput_total_i_packet_count_forward;
   real    f_throughput_total_i_packet_count_backward;
   real    f_throughput_total_o_packet_count_all;            // Counts number of packets received over a given number of cycles
   real    f_throughput_total_o_packet_count_normal;
   real    f_throughput_total_o_packet_count_ant;
   real    f_throughput_total_o_packet_count_forward;
   real    f_throughput_total_o_packet_count_backward;
   real    f_throughput_cycle_count;   // Counts the number of cycles f_throughput_packet_count has been counting
   //real    f_throughput_all;    // Calculates throughput during the measure period
	real    f_throughput_i_all;
	real    f_throughput_i_normal;
	real    f_throughput_i_ant;
	real    f_throughput_i_forward;
	real    f_throughput_i_backward;
	real    f_throughput_o_all;
	real    f_throughput_o_normal;
	real    f_throughput_o_ant;
	real    f_throughput_o_forward;
	real    f_throughput_o_backward;
	
   real    f_total_latency_all;       // Counts the total amount of time all measured packets have spent in the router
   real    f_total_latency_normal;
   real    f_total_latency_ant;
   real    f_total_latency_forward;
   real    f_total_latency_backward;
   real    f_average_latency_all;     // Calculates the average latency of measured packets
   real    f_average_latency_normal;
   real    f_average_latency_ant;
   real    f_average_latency_forward;
   real    f_average_latency_backward;
   real    f_latency_o_packet_count_all;  // Number of packets measured
   real    f_latency_o_packet_count_normal;
   real    f_latency_o_packet_count_ant;
   real    f_latency_o_packet_count_forward;
   real    f_latency_o_packet_count_backward;
   integer f_max_latency_all;         // The longest measured latency
	integer f_max_latency_normal;
	integer f_max_latency_ant;
	integer f_max_latency_forward;
	integer f_max_latency_backward;
	longint current_packet_latency;
   //integer f_latency_frequency [0:99]; // The amount of times a single latency occurs
	
	
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

   // ================================================ Data generation ==============================================================
   
   // intermediate variable generation(random)
   // ------------------------------------------------------------
	always_ff@(posedge clk) begin
      if(~reset_n) begin
         for(int i=0; i<`NODES; i++) begin
            rand_x_dest[i] <= 0;
            rand_y_dest[i] <= 0;
         end
      end else begin
         for(int i=0; i<`NODES; i++) begin
            rand_x_dest[i] <= $urandom_range(`X_NODES-1, 0);
            rand_y_dest[i] <= $urandom_range(`Y_NODES-1, 0);
         end
      end
   end
	// rand_data_val -------------------
   always_ff@(posedge clk) begin
      if(~reset_n) begin
		   /*
         for(int i=0; i<`NODES; i++) begin
            rand_data_val[i] <= 0;
         end
			*/
		   rand_i <= 0; //one cycle, one packet 1
      end else begin
		   /*
         for(int i=0; i<`NODES; i++) begin
            rand_data_val[i] <= ($urandom_range(100,1) <= PACKET_RATE && f_time < (RUNNING_TIME-100)) ? 1'b1 : 1'b0;
         end
			*/
		   rand_i <= $urandom_range(`NODES-1, 0); //one cycle, one packet 2
      end
   end
	
   // input data of network generation
   // -------------------------------------------------------------
   always_ff@(negedge clk) begin
	   if(~reset_n) begin
		   f_time_begin <= 0;
         packet_id <= 0;
         for(int y = 0; y < `Y_NODES; y++) begin
            for (int x = 0; x < `X_NODES; x++) begin
			      i_data_val[y*`X_NODES + x] <= 0;
			      
					i_data[y*`X_NODES + x].id <= 0;
					
               i_data[y*`X_NODES + x].x_source <= x; 
               i_data[y*`X_NODES + x].y_source <= y; 
               i_data[y*`X_NODES + x].x_dest <= 0; 
               i_data[y*`X_NODES + x].y_dest <= 0; 
				   
			      i_data[y*`X_NODES + x].ant <= 0;
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
		   /*
		   packet_id <= packet_id + 1;
		   for(int i=0; i<`NODES; i++) begin
			   i_data_val[i] <= rand_data_val[i] && o_en[i];
			   
			   i_data[i].id <= packet_id * `NODES + i;
            i_data[i].x_dest <= rand_x_dest[i];
            i_data[i].y_dest <= rand_y_dest[i];
			   i_data[i].timestamp <= f_time;
				
				if(f_time % 2 == 0)begin
				   i_data[i].ant <= 0;
				end else begin
				   i_data[i].ant <= 1;
				end
			end
			*/
			///*                                 //one cycle, one packet 3
         if (f_time % 10 == 0) begin
			//if (f_time == 10) begin
			      i_data_val[rand_i] <= 1;
			      
			      i_data[rand_i].id <= packet_id;
				   packet_id <= packet_id + 1;
					
					if(f_time % 20 == 0)begin
				      i_data[rand_i].ant <= 0;
				   end else begin
				      i_data[rand_i].ant <= 1;
				   end
               i_data[rand_i].x_dest <= rand_x_dest[rand_i]; 
               i_data[rand_i].y_dest <= rand_y_dest[rand_i]; 
					
         end else begin
			   for(int i=0; i<`NODES; i++) begin
               i_data_val[i] <= 0;
			      i_data[i].x_dest <= 0;
			      i_data[i].y_dest <= 0;
				end
			end
			//*/
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
	
   // ====================================================== Test function =========================================================
	
   // Test Function:  TX and RX packet counters --------------------------------------------
   always_ff@(negedge clk) begin
      if(~reset_n) begin
		   //f_test_complete <= 0;
         for(int i=0; i<`NODES; i++) begin
            f_port_i_data_count_all[i]      <= 0;
            f_port_i_data_count_normal[i]   <= 0;
            f_port_i_data_count_ant[i]      <= 0;
            f_port_i_data_count_forward[i]  <= 0;
            f_port_i_data_count_backward[i] <= 0;
				
            f_port_o_data_count_all[i]      <= 0;
            f_port_o_data_count_normal[i]   <= 0;
            f_port_o_data_count_ant[i]      <= 0;
            f_port_o_data_count_forward[i]  <= 0;
            f_port_o_data_count_backward[i] <= 0;
         end          
      end else begin
         for(int i=0; i<`NODES; i++) begin
			   if(i_data_val[i])begin
				//TX packet couters
               f_port_i_data_count_all[i] <= f_port_i_data_count_all[i] + 1;
					
					if(i_data[i].ant == 0) begin
					   f_port_i_data_count_normal[i] <= f_port_i_data_count_normal[i] + 1;
					end else begin
					   f_port_i_data_count_ant[i] <= f_port_i_data_count_ant[i] + 1;
						
					   if(i_data[i].backward == 0) begin
					      f_port_i_data_count_forward[i] <= f_port_i_data_count_forward[i] + 1;
					   //end else begin
						   f_port_i_data_count_backward[i] <= f_port_i_data_count_backward[i] + 1;
						end
					end
				end
				if(o_data_val[i])begin
				//RX packet couters
               f_port_o_data_count_all[i] <= f_port_o_data_count_all[i] + 1;
					
					if(o_data[i].ant == 0) begin
					   f_port_o_data_count_normal[i] <= f_port_o_data_count_normal[i] + 1;
					end else begin
					   f_port_o_data_count_ant[i] <= f_port_o_data_count_ant[i] + 1;
						
						if(o_data[i].b_num_memories == 0) begin
					      f_port_o_data_count_forward[i] <= f_port_o_data_count_forward[i] + 1;
						   f_port_o_data_count_backward[i] <= f_port_o_data_count_backward[i] + 1;
						end else begin
					      if(o_data[i].b_num_memories == 1) begin // (i_data[i].backward == 0)
					         f_port_o_data_count_forward[i] <= f_port_o_data_count_forward[i] + 1;
					      end else begin
						      f_port_o_data_count_backward[i] <= f_port_o_data_count_backward[i] + 1;
						   end
						end
					end
				end
         end
      end
   end

   always_comb begin
      f_total_i_data_count_all      = 0;
      f_total_i_data_count_normal   = 0;
      f_total_i_data_count_ant      = 0;
      f_total_i_data_count_forward  = 0;
      f_total_i_data_count_backward = 0;
		
      f_total_o_data_count_all      = 0;
      f_total_o_data_count_normal   = 0;
      f_total_o_data_count_ant      = 0;
      f_total_o_data_count_forward  = 0;
      f_total_o_data_count_backward = 0;
      for (int i=0; i<`NODES; i++) begin
         f_total_i_data_count_all = f_port_i_data_count_all[i] + f_total_i_data_count_all;
         f_total_i_data_count_normal = f_port_i_data_count_normal[i] + f_total_i_data_count_normal;
         f_total_i_data_count_ant = f_port_i_data_count_ant[i] + f_total_i_data_count_ant;
         f_total_i_data_count_forward = f_port_i_data_count_forward[i] + f_total_i_data_count_forward;
         f_total_i_data_count_backward = f_port_i_data_count_backward[i] + f_total_i_data_count_backward;
			
         f_total_o_data_count_all = f_port_o_data_count_all[i] + f_total_o_data_count_all;
         f_total_o_data_count_normal = f_port_o_data_count_normal[i] + f_total_o_data_count_normal;
         f_total_o_data_count_ant = f_port_o_data_count_ant[i] + f_total_o_data_count_ant;
         f_total_o_data_count_forward = f_port_o_data_count_forward[i] + f_total_o_data_count_forward;
         f_total_o_data_count_backward = f_port_o_data_count_backward[i] + f_total_o_data_count_backward;
      end
   end
	
	// Test Function:  Throughput measurement  --------------------------------------------
   always_ff@(negedge clk) begin
      if(~reset_n) begin
         for(int i=0; i<`NODES; i++) begin
            f_throughput_port_i_packet_count_all[i]      <= 0;
            f_throughput_port_i_packet_count_normal[i]   <= 0;
            f_throughput_port_i_packet_count_ant[i]      <= 0;
            f_throughput_port_i_packet_count_forward[i]  <= 0;
            f_throughput_port_i_packet_count_backward[i] <= 0;
				
            f_throughput_port_o_packet_count_all[i]      <= 0;
            f_throughput_port_o_packet_count_normal[i]   <= 0;
            f_throughput_port_o_packet_count_ant[i]      <= 0;
            f_throughput_port_o_packet_count_forward[i]  <= 0;
            f_throughput_port_o_packet_count_backward[i] <= 0;
         end
         f_throughput_cycle_count <= 0;
      end else begin
         for(int i=0; i<`NODES; i++) begin
			   if(i_data_val[i])begin
               f_throughput_port_i_packet_count_all[i] <= f_throughput_port_i_packet_count_all[i] + 1;
					
					if(i_data[i].ant == 0) begin
					   f_throughput_port_i_packet_count_normal[i] <= f_throughput_port_i_packet_count_normal[i] + 1;
					end else begin
                  f_throughput_port_i_packet_count_ant[i] <= f_throughput_port_i_packet_count_ant[i] + 1;
					   
					   if(i_data[i].backward == 0) begin
					      f_throughput_port_i_packet_count_forward[i] <= f_throughput_port_i_packet_count_forward[i] + 1;
					   //end else begin
						   f_throughput_port_i_packet_count_backward[i] <= f_throughput_port_i_packet_count_backward[i] + 1;
						end
					end
				end
				if(o_data_val[i])begin
               f_throughput_port_o_packet_count_all[i] <= f_throughput_port_o_packet_count_all[i] + 1;
					
					if(o_data[i].ant == 0) begin
					   f_throughput_port_o_packet_count_normal[i] <= f_throughput_port_o_packet_count_normal[i] + 1;
					end else begin
					   f_throughput_port_o_packet_count_ant[i] <= f_throughput_port_o_packet_count_ant[i] + 1;
					   
						if(o_data[i].b_num_memories == 0) begin
					      f_throughput_port_o_packet_count_forward[i] <= f_throughput_port_o_packet_count_forward[i] + 1;
						   f_throughput_port_o_packet_count_backward[i] <= f_throughput_port_o_packet_count_backward[i] + 1;
						end else begin
					      if(o_data[i].b_num_memories == 1) begin // (i_data[i].backward == 0)
					         f_throughput_port_o_packet_count_forward[i] <= f_throughput_port_o_packet_count_forward[i] + 1;
					      end else begin
						      f_throughput_port_o_packet_count_backward[i] <= f_throughput_port_o_packet_count_backward[i] + 1;
						   end
						end
					end
				end
         end
         f_throughput_cycle_count <= f_throughput_cycle_count + 1;
      end
   end
   
   always_comb begin
      f_throughput_total_i_packet_count_all      = 0;
      f_throughput_total_i_packet_count_normal   = 0;
      f_throughput_total_i_packet_count_ant      = 0;
      f_throughput_total_i_packet_count_forward  = 0;
      f_throughput_total_i_packet_count_backward = 0;
		
      f_throughput_total_o_packet_count_all      = 0;
      f_throughput_total_o_packet_count_normal   = 0;
      f_throughput_total_o_packet_count_ant      = 0;
      f_throughput_total_o_packet_count_forward  = 0;
      f_throughput_total_o_packet_count_backward = 0;
		
      f_throughput_i_all      = 0;
      f_throughput_i_normal   = 0;
      f_throughput_i_ant      = 0;
      f_throughput_i_forward  = 0;
      f_throughput_i_backward = 0;
		
	   f_throughput_o_all      = 0;
	   f_throughput_o_normal   = 0;
	   f_throughput_o_ant      = 0;
	   f_throughput_o_forward  = 0;
	   f_throughput_o_backward = 0;
      for (int i=0; i<`NODES; i++) begin
         f_throughput_total_i_packet_count_all = f_throughput_port_i_packet_count_all[i] + f_throughput_total_i_packet_count_all;
         f_throughput_total_i_packet_count_normal = f_throughput_port_i_packet_count_normal[i] + f_throughput_total_i_packet_count_normal;
         f_throughput_total_i_packet_count_ant = f_throughput_port_i_packet_count_ant[i] + f_throughput_total_i_packet_count_ant;
         f_throughput_total_i_packet_count_forward = f_throughput_port_i_packet_count_forward[i] + f_throughput_total_i_packet_count_forward;
         f_throughput_total_i_packet_count_backward = f_throughput_port_i_packet_count_backward[i] + f_throughput_total_i_packet_count_backward;
			
         f_throughput_total_o_packet_count_all = f_throughput_port_o_packet_count_all[i] + f_throughput_total_o_packet_count_all;
         f_throughput_total_o_packet_count_normal = f_throughput_port_o_packet_count_normal[i] + f_throughput_total_o_packet_count_normal;
         f_throughput_total_o_packet_count_ant = f_throughput_port_o_packet_count_ant[i] + f_throughput_total_o_packet_count_ant;
         f_throughput_total_o_packet_count_forward = f_throughput_port_o_packet_count_forward[i] + f_throughput_total_o_packet_count_forward;
         f_throughput_total_o_packet_count_backward = f_throughput_port_o_packet_count_backward[i] + f_throughput_total_o_packet_count_backward;
      end
      if (f_throughput_cycle_count != 0) begin
         f_throughput_i_all = (f_throughput_total_i_packet_count_all/f_throughput_cycle_count);
         f_throughput_i_normal = (f_throughput_total_i_packet_count_normal/f_throughput_cycle_count);
         f_throughput_i_ant = (f_throughput_total_i_packet_count_ant/f_throughput_cycle_count);
         f_throughput_i_forward = (f_throughput_total_i_packet_count_forward/f_throughput_cycle_count);
         f_throughput_i_backward = (f_throughput_total_i_packet_count_backward/f_throughput_cycle_count);
			
         f_throughput_o_all = (f_throughput_total_o_packet_count_all/f_throughput_cycle_count);
         f_throughput_o_normal = (f_throughput_total_o_packet_count_normal/f_throughput_cycle_count);
         f_throughput_o_ant = (f_throughput_total_o_packet_count_ant/f_throughput_cycle_count);
         f_throughput_o_forward = (f_throughput_total_o_packet_count_forward/f_throughput_cycle_count);
         f_throughput_o_backward = (f_throughput_total_o_packet_count_backward/f_throughput_cycle_count);
      end
   end
   
	// Test Function: Latency of measure packets
   // ------------------------------------------------------------------------------------------------------------------
   initial begin
      f_total_latency_all      = 0;
      f_total_latency_normal   = 0;
      f_total_latency_ant      = 0;
      f_total_latency_forward  = 0;
      f_total_latency_backward = 0;
      f_average_latency_all      = 0;
      f_average_latency_normal   = 0;
      f_average_latency_ant      = 0;
      f_average_latency_forward  = 0;
      f_average_latency_backward = 0;
      f_latency_o_packet_count_all      = 0;
      f_latency_o_packet_count_normal   = 0;
      f_latency_o_packet_count_ant      = 0;
      f_latency_o_packet_count_forward  = 0;
      f_latency_o_packet_count_backward = 0;
      forever @(negedge clk) begin
         for (int i=0; i<`NODES; i++) begin
            if (o_data_val[i] == 1) begin
               f_total_latency_all = f_total_latency_all + (f_time - o_data[i].timestamp);
               f_latency_o_packet_count_all = f_latency_o_packet_count_all + 1;
					
				   if(o_data[i].ant == 0) begin
                  f_total_latency_normal = f_total_latency_normal + (f_time - o_data[i].timestamp);
                  f_latency_o_packet_count_normal = f_latency_o_packet_count_normal + 1;
               end else begin
                  f_total_latency_ant = f_total_latency_ant + (f_time - o_data[i].timestamp);
                  f_latency_o_packet_count_ant = f_latency_o_packet_count_ant + 1;
					   
					   if(o_data[i].b_num_memories == 0) begin
                     f_total_latency_forward = f_total_latency_forward + (f_time - o_data[i].timestamp);
                     f_latency_o_packet_count_forward = f_latency_o_packet_count_forward + 1;
                     f_total_latency_backward = f_total_latency_backward + (f_time - o_data[i].timestamp);
                     f_latency_o_packet_count_backward = f_latency_o_packet_count_backward + 1;
						end else begin
					      if(o_data[i].b_num_memories == 1) begin // (o_data[i].backward == 0)
                     f_total_latency_forward = f_total_latency_forward + (f_time - o_data[i].timestamp);
                     f_latency_o_packet_count_forward = f_latency_o_packet_count_forward + 1;
					      end else begin
                     f_total_latency_backward = f_total_latency_backward + (f_time - o_data[i].timestamp);
                     f_latency_o_packet_count_backward = f_latency_o_packet_count_backward + 1;
						   end
						end
					end
            end
         end
         if(f_latency_o_packet_count_all != 0)begin //((f_total_latency_all != 0) /*&& (f_test_saturated != 1)*/)begin
            f_average_latency_all      = f_total_latency_all/f_latency_o_packet_count_all;
         end else begin
            f_average_latency_all      = 10000000;
         end
			if(f_latency_o_packet_count_normal != 0)begin
            f_average_latency_normal   = f_total_latency_normal/f_latency_o_packet_count_normal;
         end else begin
            f_average_latency_normal   = 10000000;
         end
         if(f_latency_o_packet_count_ant != 0)begin //((f_total_latency_all != 0) /*&& (f_test_saturated != 1)*/)begin
            f_average_latency_ant      = f_total_latency_ant/f_latency_o_packet_count_ant;
         end else begin
            f_average_latency_ant      = 10000000;
         end
			if(f_latency_o_packet_count_forward != 0)begin
            f_average_latency_forward  = f_total_latency_forward/f_latency_o_packet_count_forward;
         end else begin
            f_average_latency_forward  = 10000000;
         end
			if(f_latency_o_packet_count_backward != 0)begin
            f_average_latency_backward = f_total_latency_backward/f_latency_o_packet_count_backward;
         end else begin
            f_average_latency_backward = 10000000;
         end
      end
   end
   
   // Test Function: Max packet latency
   // ------------------------------------------------------------------------------------------------------------------
   always_ff@(negedge clk) begin
      if(~reset_n) begin
         f_max_latency_all      <= '0;
			f_max_latency_normal   <= '0;
         f_max_latency_ant      <= '0;
			f_max_latency_forward  <= '0;
			f_max_latency_backward <= '0;
      end else begin
         for(int i=0; i<`NODES; i++) begin
			   current_packet_latency <= f_time - o_data[i].timestamp;
            if(o_data_val[i] == 1) begin
				   if(current_packet_latency > f_max_latency_all)begin
                  f_max_latency_all <= current_packet_latency;
               end
					
				   if(o_data[i].ant == 0 && current_packet_latency > f_max_latency_normal)begin
                  f_max_latency_normal <= current_packet_latency;
               end else begin
					   if(current_packet_latency > f_max_latency_ant)begin
                     f_max_latency_ant <= current_packet_latency;
                  end
					   
						if(o_data[i].b_num_memories == 0) begin
				         if(current_packet_latency > f_max_latency_forward) begin // o_data[i].backward == 0
                        f_max_latency_forward <= f_time - o_data[i].timestamp;
                     end
						   if(current_packet_latency > f_max_latency_backward)begin
                        f_max_latency_backward <= current_packet_latency;
							end
						end else begin
				         if(o_data[i].b_num_memories == 1 && current_packet_latency > f_max_latency_forward) begin // o_data[i].backward == 0
                        f_max_latency_forward <= f_time - o_data[i].timestamp;
                     end else begin
						      if(current_packet_latency > f_max_latency_backward)begin
                           f_max_latency_backward <= current_packet_latency;
							   end
				         end
						end
				   end
				end
         end
      end
   end
  
   // ==================================================== Simulation =============================================================
    
	// Simulation:  System clock ----------------------------------
   initial begin
      clk = 1;
      forever #(CLK_PERIOD/2) clk = ~clk;
   end
	
   // Simulation:  System time -----------------------------------
   initial begin
      f_time = 0;
      forever #(CLK_PERIOD) f_time = f_time + 1;
   end
	
   // Simulation:  System reset -----------------------------------
   initial begin
      reset_n = 0;
      #(CLK_PERIOD + 3 * CLK_PERIOD / 4)
      reset_n = 1;
   end
	
   // Simulation:  Run period -------------------------------------
   initial begin
      #(CLK_PERIOD * RUNNING_TIME) $finish;
   end
	
   // Simulation:  Display -----------------------------------------------------
   initial begin
      $display(""); // $display，$write，$strobe，$monitot("",);
      forever@(posedge clk) begin
		   //show single packet message one by one
		   for(int i=0; i<`NODES; i++) begin
			  if(debug)begin
			   if(i_data_val[i]) begin
               $display("f_time: %g;  packet_id:%g;  type:%g;  input node: %g;", f_time, i_data[i].id, i_data[i].ant, i);
				   $display(" source: %d,%d ; destinaton: %d,%d ; ", i_data[i].x_source, i_data[i].y_source, i_data[i].x_dest, i_data[i].y_dest);
            end
            if(o_data_val[i]) begin
               $display("f_time: %g;  packet_id:%g;  type:%g;  output node: %g;", f_time, o_data[i].id, o_data[i].ant, i);
					$display(" source: %d,%d ; destinaton: %d,%d ; ", o_data[i].x_source, o_data[i].y_source, o_data[i].x_dest, o_data[i].y_dest);
				   //$display(" source: %d,%d ; destinaton: %d,%d ; ", o_data[i].x_dest, o_data[i].y_dest, o_data[i].x_source, o_data[i].y_source);
			      for(int m=0; m<o_data[i].num_memories; m++) begin
				      $display(" path: %d,%d ; ", o_data[i].x_memory[m], o_data[i].y_memory[m]);
				   end
				   //$display(" source: %d,%d ; destinaton: %d,%d ; ", o_data[i].x_source, o_data[i].y_source, o_data[i].x_dest, o_data[i].y_dest);
			      for(int m=0; m<o_data[i].b_num_memories; m++) begin
				      $display(" back path: %d,%d ; ", o_data[i].b_x_memory[m], o_data[i].b_y_memory[m]);
				   end
            end
			  end else begin
            if(o_data_val[i]) begin
				   if(o_data[i].ant==0) begin
					// Normal packet:
					   // 1.[ <cycle> ] Packet id: <> (packet type),
					   $write(" [ %g ] Packet id: %g (normal packet),  ", f_time, o_data[i].id);
						// 2.Memory: [,,,],
						$write(" Memory: [%g", o_data[i].y_memory[0] * `X_NODES + o_data[i].x_memory[0]);
						for(int m=1; m<o_data[i].num_memories; m++) begin
				         $write(",%g", o_data[i].y_memory[m] * `X_NODES + o_data[i].x_memory[m]);
				      end
						$write("],  ");
						// 3.Timestamp: <>,   Latency: <>
						$write(" Timestamp: %g,   Latency: %g  ", o_data[i].timestamp, f_time-o_data[i].timestamp);
						$display("");
					end else begin
					/*
					// Ant packets:
					   // 1.[ <cycle> ] Packet id: <> (packet type),
					   $write(" [ %g ] Packet id: %g (ant packet),  ", f_time, o_data[i].id);
						// 2.Memory: [,,,],
						$write(" Memory: [%g", o_data[i].y_memory[0] * `X_NODES + o_data[i].x_memory[0]);
						for(int m=1; m<o_data[i].num_memories; m++) begin
				         $write(",%g", o_data[i].y_memory[m] * `X_NODES + o_data[i].x_memory[m]);
				      end
						$write("],  ");
						// 3.Timestamp: <>,   Latency: <>
						$write(" Timestamp: %g,   Latency: %g  ", o_data[i].timestamp, f_time-o_data[i].timestamp);
					   $display("");
					*/
					   if(o_data[i].b_num_memories == 1) begin // (o_data[i].backward==0)
						//Ant.forward:
					      // 1.[ <cycle> ] Packet id: <> (packet type),
					      $write(" [ %g ] Packet id: %g (ant.forward),  ", f_time, o_data[i].id);
						   // 2.Memory: [,,,],
						   $write(" Memory: [%g", o_data[i].y_memory[0] * `X_NODES + o_data[i].x_memory[0]);
						   for(int m=1; m<o_data[i].num_memories; m++) begin
				            $write(",%g", o_data[i].y_memory[m] * `X_NODES + o_data[i].x_memory[m]);
				         end
						   $write("],  ");
						   // 3.Timestamp: <>,   Latency: <>
						   $write(" Timestamp: %g,   Latency: %g  ", o_data[i].timestamp, f_time-o_data[i].timestamp);
							$display("");
						end else begin
						//Ant.backward:
					      // 1.[ <cycle> ] Packet id: <> (packet type),
					      $write(" [ %g ] Packet id: %g (ant.backward),  ", f_time, o_data[i].id);
						   // 2.Memory: [,,,],
						   $write(" Memory: [%g", o_data[i].b_y_memory[0] * `X_NODES + o_data[i].b_x_memory[0]);
						   for(int m=1; m<o_data[i].b_num_memories; m++) begin
				            $write(",%g", o_data[i].b_y_memory[m] * `X_NODES + o_data[i].b_x_memory[m]);
				         end
						   $write("],  ");
						   // 3.Timestamp: <>,   Latency: <>
						   $write(" Timestamp: %g,   Latency: %g  ", o_data[i].timestamp, f_time-o_data[i].timestamp);
							$display("");
						end
						
				   end
            end
			  end
			end
		   //show total packets message in the end
			if (f_time == RUNNING_TIME-1) begin
			   $display("");
			   $display(" # Total cycles: %g",RUNNING_TIME-f_time_begin);
			   $display("");
				
			   $display(" -- All packets:");
			   $display("      # Packets transmitted: %g, # Packets received: %g", f_total_i_data_count_all, f_total_o_data_count_all);
            $display("      # Throughput: %g packets/cycle %g, %g", f_throughput_o_all
				                                                      , f_throughput_total_o_packet_count_all, f_throughput_cycle_count);
            $display("      # Average packet latency: %g cycles", f_average_latency_all);
            $display("      # Max packet latency: %g cycles", f_max_latency_all);
			   $display("");
			   $display(" -- Normal packet:");
			   $display("      # Packets transmitted: %g, # Packets received: %g", f_total_i_data_count_normal, f_total_o_data_count_normal);
            $display("      # Throughput: %g packets/cycle", f_throughput_o_normal);
            $display("      # Average packet latency: %g cycles", f_average_latency_normal);
            $display("      # Max packet latency: %g cycles", f_max_latency_normal);
			   $display("");
			   $display(" -- Ant packet:");
			   $display("      # Packets transmitted: %g, # Packets received: %g", f_total_i_data_count_ant, f_total_o_data_count_ant);
            $display("      # Throughput: %g packets/cycle %g, %g", f_throughput_o_ant
				                                                      , f_throughput_total_o_packet_count_ant, f_throughput_cycle_count);
            $display("      # Average packet latency: %g cycles", f_average_latency_ant);
            $display("      # Max packet latency: %g cycles", f_max_latency_ant);
			   $display("");
				
			   $display(" -- Ant.forward:");
			   $display("      # Packets transmitted: %g, # Packets received: %g", f_total_i_data_count_forward, f_total_o_data_count_forward);
            $display("      # Throughput: %g packets/cycle", f_throughput_o_forward);
            $display("      # Average packet latency: %g cycles", f_average_latency_forward);
            $display("      # Max packet latency: %g cycles", f_max_latency_forward);
			   $display("");
			   $display(" -- Ant.backward:");
			   $display("      # Packets transmitted: %g, # Packets received: %g", f_total_i_data_count_backward, f_total_o_data_count_backward);
            $display("      # Throughput: %g packets/cycle", f_throughput_o_backward);
            $display("      # Average packet latency: %g cycles", f_average_latency_backward);
            $display("      # Max packet latency: %g cycles", f_max_latency_backward);
			   $display("");
				
			end
      end
   end
	
endmodule
/*FYI.
1. add comments
2. the above statistics
3. record each packet (normal packet and ACO packet) 's memory and debug

forward packet 到了也得打出来以下信息：
[<current_cycle>] packet_id: <>, memory: [,,,], timestamp: <>, latency: <>

[2016-04-26 10:45:11] INFO - Overall:
[2016-04-26 10:45:11] INFO -     # Total cycles: 435
[2016-04-26 10:45:11] INFO -
[2016-04-26 10:45:11] INFO -     # Packets received: 145, # packets transmitted: 145
[2016-04-26 10:45:11] INFO -     Throughput: 0.333333 packets/cycle
[2016-04-26 10:45:11] INFO -     Average packet latency: 118.937931 cycles/packet
[2016-04-26 10:45:11] INFO -     Max packet latency: 314.000000 cycles/packet
[2016-04-26 10:45:11] INFO -
[2016-04-26 10:45:11] INFO - ACOPacket:
[2016-04-26 10:45:11] INFO -     # Packets received: 96, # packets transmitted: 96
[2016-04-26 10:45:11] INFO -     Throughput: 0.220690 packets/cycle
[2016-04-26 10:45:11] INFO -     Average packet latency: 76.517241 cycles/packet
[2016-04-26 10:45:11] INFO -     Max packet latency: 314.000000 cycles/packet
[2016-04-26 10:45:11] INFO -
[2016-04-26 10:45:11] INFO - Packet:
[2016-04-26 10:45:11] INFO -     # Packets received: 49, # packets transmitted: 49
[2016-04-26 10:45:11] INFO -     Throughput: 0.112644 packets/cycle
[2016-04-26 10:45:11] INFO -     Average packet latency: 42.420690 cycles/packet
[2016-04-26 10:45:11] INFO -     Max packet latency: 298.000000 cycles/packet
*/