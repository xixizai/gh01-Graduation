`timescale 1ps/1ps

`include "config.sv"

module tb_nw
#(
   parameter CLK_PERIOD = 100ps,
   parameter integer PACKET_RATE = 100, // Offered traffic as percent of capacity
  
   //parameter integer WARMUP_PACKETS = 1000, // Number of packets to warm-up the network
   //parameter integer MEASURE_PACKETS = 5000, // Number of packets to be measured
   //parameter integer DRAIN_PACKETS = 3000, // Number of packets to drain the network
  
   //parameter integer DOWNSTREAM_EN_RATE = 100, // Percent of time simulated nodes able to receive data
   parameter integer NODE_QUEUE_DEPTH = `INPUT_QUEUE_DEPTH * 8
);

   // ======================================================= definition ==============================================================
	
   logic clk;
   logic reset_n;
   
   longint  f_time;   // Pseudo time value/clock counter
   logic    [7:0] packet_count;
   // network port ---------------------------------------
   packet_t [0:`NODES-1] i_data; 
   logic    [0:`NODES-1] i_data_val; 
   logic    [0:`NODES-1] o_en; 
   
   packet_t [0:`NODES-1] o_data; 
   logic    [0:`NODES-1] o_data_val; 
   // random number --------------------------------------
   logic [0:`NODES-1] rand_i_data_val;
   logic [0:`NODES-1][$clog2(`X_NODES)-1:0] rand_x_dest;
   logic [0:`NODES-1][$clog2(`Y_NODES)-1:0] rand_y_dest;
   // FLAGS:  Control --------------------------------------------------------------------------------------------------
   longint f_port_s_data_count [0:`NODES-1]; // Count number of packets simulated and added to the node queues
   longint f_port_i_data_count [0:`NODES-1];   // Count number of packets that left the node, transmitted on each port
   longint f_port_o_data_count [0:`NODES-1];   // Count number of received packets on each port
   longint f_total_s_data_count;            // Count total number of simulated packets
   longint f_total_i_data_count;              // Count total number of transmitted packets
   longint f_total_o_data_count;              // Count total number of received packets

   // ================================================ test port definition ===========================================================
	
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
	
   // ============================================= network module generation ===========================================================
  
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

   //================================================ data generation ==============================================================
   
   // intermediate variable generation(random) ------------------------------------------------------
   // destination ------------------
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
   // i_data_val -------------------
   always_ff@(posedge clk) begin
      if(~reset_n) begin
         for(int i=0; i<`NODES; i++) begin
            rand_i_data_val[i] <= 0;
         end
      end else begin
         for(int i=0; i<`NODES; i++) begin
            rand_i_data_val[i] <= ($urandom_range(100,1) <= PACKET_RATE) ? 1'b1 : 1'b0;
         end
      end
   end
  
   // input data of network generation -----------------------------------------------------------------
   // input data -----------------
   always_ff@(posedge clk) begin
      if(~reset_n) begin
         packet_count <= 0;
         for (int y = 0; y < `Y_NODES; y++) begin
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
         for(int i=0; i<`NODES; i++) begin
               i_data[i].x_dest <= rand_x_dest[i];
               i_data[i].y_dest <= rand_y_dest[i];
	            
			      i_data[i].id <= packet_count;
				   packet_count <= packet_count + 1;
					
               if (f_time % `CREATE_ANT_PERIOD == 0)begin
                  i_data_val[i] <= o_en[i];
				      i_data[i].ant <= 1;
               end else begin
			         i_data_val[i] <= rand_i_data_val[i] && o_en[i];
				      i_data[i].ant <= 0;
			      end
		   end
      end
   end
   // ====================================================== calculation =========================================================

   // TEST FUNCTION:  TX and RX Packet Counters --------------------------------------------
   always_ff@(negedge clk) begin
      if(~reset_n) begin
         for(int i=0; i<`NODES; i++) begin
            f_port_s_data_count[i] <= 0;
            f_port_i_data_count[i] <= 0;
            f_port_o_data_count[i] <= 0;
         end          
      end else begin
         for(int i=0; i<`NODES; i++) begin
            f_port_s_data_count[i] <= f_port_s_data_count[i] + 1 ;
            f_port_i_data_count[i] <= i_data_val[i] /*&& n_o_en[i]*/ ? f_port_i_data_count[i] + 1 : f_port_i_data_count[i];
            f_port_o_data_count[i] <= o_data_val[i] ? f_port_o_data_count[i] + 1 : f_port_o_data_count[i];
         end
      end
   end

   always_comb begin
      f_total_s_data_count = 0;   
      f_total_i_data_count = 0;
      f_total_o_data_count = 0;
      for (int i=0; i<`NODES; i++) begin
         f_total_s_data_count = f_port_s_data_count[i] + f_total_s_data_count;
         f_total_i_data_count = f_port_i_data_count[i] + f_total_i_data_count;
         f_total_o_data_count = f_port_o_data_count[i] + f_total_o_data_count;  
      end
   end

   // ====================================================== SIMULATION =========================================================
    
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
      #(CLK_PERIOD * 100000) $finish;
   end
	
   // RESULTS CONTROL --------------------------------------------------------
   initial begin
      $display("");//$monitot("",);
      forever@(posedge clk) begin
         if(f_time % 100 == 0) begin
            $display("f_time %g:  Transmitted %g packets,  Received %g packets   0:%g  1:%g  2:%g  3:%g  %g:%g",
  				          f_time,     f_total_i_data_count,    f_total_o_data_count,
				  f_port_o_data_count[0],f_port_o_data_count[1],f_port_o_data_count[2],f_port_o_data_count[3],`NODES,f_port_o_data_count[`NODES-1]);
         end
      end
   end

endmodule
