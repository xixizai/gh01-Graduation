`timescale 1ps/1ps
`define warmup_packets_num 1000
`include "config.sv"

module tb_nw_end_a
#(
   parameter CLK_PERIOD = 100ps,
   parameter integer PACKET_RATE = 10, // Offered traffic as percent of capacity
  
   parameter integer WARMUP_PACKETS = `warmup_packets_num, // Number of packets to warm-up the network
   parameter integer MEASURE_PACKETS = `warmup_packets_num*5, // Number of packets to be measured
   parameter integer DRAIN_PACKETS = `warmup_packets_num*3, // Number of packets to drain the network
  
   //parameter integer DOWNSTREAM_EN_RATE = 100, // Percent of time simulated nodes able to receive data
   parameter integer NODE_QUEUE_DEPTH = `INPUT_QUEUE_DEPTH * 8
);

   // =================================================== port definition ==============================================================
	
   logic clk;
   logic reset_n;
   
   longint  f_time;   // Pseudo time value/clock counter
	//logic    f_test_complete;
   logic    [7:0] packet_ID;
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
	
   // ================================================================================================================================
	
	longint    f_throughput_port_o_packet_count [0:`NODES-1]; // counts number of packets received over a given number of cycles
   real    f_throughput_total_o_packet_count;            // counts number of packets received over a given number of cycles  
   longint    f_throughput_port_i_packet_count [0:`NODES-1]; // counts number of packets sent over a given number of cycles
   real    f_throughput_total_i_packet_count;            // counts number of packets simulated over a given number of cycles
   longint    f_throughput_port_s_packet_count [0:`NODES-1]; // counts number of packets simulated over a given number of cycles
   real    f_throughput_total_s_packet_count;            // counts number of packets sent over a given number of cycles
   real    f_throughput_cycle_count;                     // counts the number of cycles f_throughput_packet_count has been counting
   real    f_throughput;                                 // calculates throughput during the measure period
   real    f_throughput_offered;                         // Calculates the offered traffic during the measure period
   real    f_throughput_simulated;                       // Calculates the simulated traffic during the measure period
	
   real    f_total_latency;            // Counts the total amount of time all measured packets have spent in the router
   real    f_average_latency;          // Calculates the average latency of measured packets
   real    f_measured_packet_count;    // Number of packets measured
   integer f_max_latency;              // The longest measured frequency
	integer f_max_latency_normol;
	integer f_max_latency_forward;
	integer f_max_latency_backward;
   //integer f_latency_frequency [0:99]; // The amount of times a single latency occurs
  
  
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
         packet_ID <= 0;
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
			   if (f_total_i_data_count < (WARMUP_PACKETS+MEASURE_PACKETS+DRAIN_PACKETS))begin
               i_data[i].x_dest <= rand_x_dest[i];
               i_data[i].y_dest <= rand_y_dest[i];
	            
			      i_data[i].id <= packet_ID;
				   packet_ID <= packet_ID + 1;
					
               if (f_time % `CREATE_ANT_PERIOD == 0)begin
                  i_data_val[i] <= o_en[i];
				      i_data[i].ant <= 1;
               end else begin
			         i_data_val[i] <= rand_i_data_val[i] && o_en[i];
				      i_data[i].ant <= 0;
						i_data[i].timestamp <= f_time;
			      end
					
					if (f_total_i_data_count >= WARMUP_PACKETS && f_total_i_data_count < (WARMUP_PACKETS+MEASURE_PACKETS)) begin
					   i_data[i].measure <= 1;
				   end else begin
					   i_data[i].measure <= 0;
					end
            end else begin
			      i_data_val[i] <= 0;
				end
		   end
      end
   end
   // ====================================================== calculation =========================================================
   //parameter integer WARMUP_PACKETS = 1000, // Number of packets to warm-up the network
   //parameter integer MEASURE_PACKETS = 5000, // Number of packets to be measured
   //parameter integer DRAIN_PACKETS = 3000, // Number of packets to drain the network
   
	// TEST FUNCTION:  Throughput measurement.
   // ------------------------------------------------------------------------------------------------------------------ 
   // Uses the count of the simulated input data so that even if the network is saturated and packets are being dropped
   // throughput measurement will still take place使用模拟输入数据的计数，以便即使在网络饱和，数据包被丢弃可以通过测量将仍然发生
   // ------------------------------------------------------------------------------------------------------------------  
   always_ff@(negedge clk) begin
      if(~reset_n) begin
         for(int i=0; i<`NODES; i++) begin
            f_throughput_port_o_packet_count[i] <= 0;
            f_throughput_port_i_packet_count[i] <= 0;  
            f_throughput_port_s_packet_count[i] <= 0;           
         end     
         f_throughput_cycle_count  <= 0;      
      end else begin
         for(int i=0; i<`NODES; i++) begin
            f_throughput_port_o_packet_count[i] <= (   (o_data_val[i]) 
                                                    && (f_total_s_data_count > WARMUP_PACKETS) 
                                                    && (f_total_s_data_count < (WARMUP_PACKETS+MEASURE_PACKETS))) 
                                                    ? f_throughput_port_o_packet_count[i] + 1 
                                                    : f_throughput_port_o_packet_count[i];
            f_throughput_port_i_packet_count[i] <= (   (i_data_val[i]) 
                                                    && (f_total_s_data_count > WARMUP_PACKETS) 
                                                    && (f_total_s_data_count < (WARMUP_PACKETS+MEASURE_PACKETS))) 
                                                    ? f_throughput_port_i_packet_count[i] + 1 
                                                    : f_throughput_port_i_packet_count[i];                                               
            f_throughput_port_s_packet_count[i] <= (   (rand_i_data_val[i]) 
                                                    && (f_total_s_data_count > WARMUP_PACKETS) 
                                                    && (f_total_s_data_count < (WARMUP_PACKETS+MEASURE_PACKETS))) 
                                                    ? f_throughput_port_s_packet_count[i] + 1 
                                                    : f_throughput_port_s_packet_count[i]; 
            f_throughput_cycle_count            <= (   (f_total_s_data_count > WARMUP_PACKETS) 
                                                    && (f_total_s_data_count < (WARMUP_PACKETS+MEASURE_PACKETS))) 
                                                    ? f_throughput_cycle_count + 1 
                                                    : f_throughput_cycle_count;    
         end
      end
   end
   
   always_comb begin
      f_throughput_total_i_packet_count = 0;
      f_throughput_total_o_packet_count = 0;
      f_throughput_total_s_packet_count = 0;
      f_throughput = 0;
      f_throughput_offered = 0;
      f_throughput_simulated = 0;
      for (int i=0; i<`NODES; i++) begin
         f_throughput_total_o_packet_count = f_throughput_port_o_packet_count[i] + f_throughput_total_o_packet_count;
         f_throughput_total_i_packet_count = f_throughput_port_i_packet_count[i] + f_throughput_total_i_packet_count;            
         f_throughput_total_s_packet_count = f_throughput_port_s_packet_count[i] + f_throughput_total_s_packet_count;
      end
      if (f_throughput_total_o_packet_count != 0) begin
         f_throughput = (f_throughput_total_o_packet_count/f_throughput_cycle_count);
      end
      if (f_throughput_total_i_packet_count != 0) begin
         f_throughput_offered = (f_throughput_total_i_packet_count/f_throughput_cycle_count);
      end
      if (f_throughput_total_s_packet_count != 0) begin
         f_throughput_simulated = (f_throughput_total_s_packet_count/f_throughput_cycle_count);
      end
   end
  
   // TEST FUNCTION:  TX and RX Packet Counters --------------------------------------------
   always_ff@(negedge clk) begin
      if(~reset_n) begin
		   //f_test_complete <= 0;
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
		   //if (f_total_o_data_count >= (WARMUP_PACKETS+MEASURE_PACKETS/*+DRAIN_PACKETS*/) && f_total_o_data_count < (WARMUP_PACKETS+MEASURE_PACKETS/*+DRAIN_PACKETS*/+`NODES))   f_test_complete = 1;
			//else f_test_complete = 0;
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
	
	// TEST FUNCTION: Latency of Measure Packets
   // ------------------------------------------------------------------------------------------------------------------
   initial begin
      f_total_latency         = 0;
      f_average_latency       = 0;
      f_measured_packet_count = 0;
      forever @(negedge clk) begin
         for (int i=0; i<`NODES; i++) begin
            if ((o_data_val[i] == 1) && (o_data[i].measure == 1)) begin
               f_total_latency = f_total_latency + (f_time - o_data[i].timestamp);
               f_measured_packet_count = f_measured_packet_count + 1;
            end
         end
         if ((f_total_latency != 0) /*&& (f_test_saturated != 1)*/)begin
            f_average_latency = f_total_latency/f_measured_packet_count;
         end else begin
            f_average_latency = 10000000;
         end
      end
   end
  
   // TEST FUNCTION: Longest Packet Latency
   // ------------------------------------------------------------------------------------------------------------------
   always_ff@(negedge clk) begin
      if(~reset_n) begin
         f_max_latency <= '0;  
			f_max_latency_normol <= '0;
			f_max_latency_forward <= '0;
			f_max_latency_backward <= '0;
      end else begin
         for(int i=0; i<`NODES; i++) begin
            if(o_data_val[i] == 1) begin
				   if((f_time - o_data[i].timestamp) > f_max_latency)begin
                  f_max_latency <= (f_time - o_data[i].timestamp);
               end else begin
                  f_max_latency <= f_max_latency;
				   end
				   if(o_data[i].ant == 0 && (f_time - o_data[i].timestamp) > f_max_latency_normol)begin
                  f_max_latency_normol <= (f_time - o_data[i].timestamp);
               end else begin
                  f_max_latency_normol <= f_max_latency_normol;
				   end
				   if(o_data[i].backward == 0 && (f_time - o_data[i].timestamp) > f_max_latency_forward)begin
                  f_max_latency_forward <= (f_time - o_data[i].timestamp);
               end else begin
                  f_max_latency_forward <= f_max_latency_forward;
				   end
				   if(o_data[i].backward == 1 && (f_time - o_data[i].timestamp) > f_max_latency_backward)begin
                  f_max_latency_backward <= (f_time - o_data[i].timestamp);
               end else begin
                  f_max_latency_backward <= f_max_latency_backward;
				   end
				end
         end
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
      #(CLK_PERIOD * `warmup_packets_num*20) $finish;
   end
	
   // RESULTS CONTROL --------------------------------------------------------
   initial begin
      $display("");//$monitot("",);
      forever@(posedge clk) begin
         if(f_time % 100 == 0 
			   && (f_total_i_data_count != f_total_o_data_count 
				    || f_total_i_data_count < (WARMUP_PACKETS+MEASURE_PACKETS+DRAIN_PACKETS))) begin
            $display("[ %g ]:  Transmitted %g packets,  Received %g packets   0:%g  1:%g  2:%g  3:%g  %g:%g",
  				          f_time,     f_total_i_data_count,    f_total_o_data_count,
				  f_port_o_data_count[0],f_port_o_data_count[1],f_port_o_data_count[2],f_port_o_data_count[3],`NODES,f_port_o_data_count[`NODES-1]);
         end
			if (f_time == `warmup_packets_num*20-1) begin
			   $display("");
			   $display(" # Total cycles: ");
			   $display(" # packets transmitted: %g, Packets received: %g", f_total_i_data_count, f_total_o_data_count);
				/*$display("# Simulated traffic rate #: %g packets/cycle     (%d<cycle<%d && rand_i_data_val)", f_throughput_simulated, WARMUP_PACKETS, WARMUP_PACKETS+MEASURE_PACKETS);
            $display("# Actual traffic rate #: %g packets/cycle     (%d<cycle<%d && i_data_val)", f_throughput_offered, WARMUP_PACKETS, WARMUP_PACKETS+MEASURE_PACKETS);*/
            $display(" # Throughput: %g packets/cycle     (%g<=cycle<%g)", f_throughput, WARMUP_PACKETS, WARMUP_PACKETS+MEASURE_PACKETS);
            $display(" # Average packet latency: %g cycles     (o_data.measure=1)", f_average_latency);
            $display(" # Max packet latency: %g", f_max_latency);
			   $display("");
			end
      end
   end

endmodule
/*FYI.
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

1. add comments
2. the above statistics
3. record each packet (normal packet and ACO packet) 's memory and debug

forward packet 到了也得打出来以下信息：

[<current_cycle>] packet_id: <>, memory: [,,,], timestamp: <>, latency: <>*/

	/*
	
  // --------------------------------------------------------------------------------------------------------------------
  // TEST FUNCTIONS
  // --------------------------------------------------------------------------------------------------------------------
   
   // TEST FUNCTION:  Throughput measurement.
   
   // TEST FUNCTION:  TX and RX Packet Counters --------------------------------------------
   
   // TEST FUNCTION:  TX and RX Packet identification
   // ------------------------------------------------------------------------------------------------------------------
   
   always_ff@(negedge clk) begin
      if(~reset_n) begin
         for(int i=0; i<NODES; i++) begin
            f_tx_packet[i] <= '0;
            f_rx_packet[i] <= '0;
         end
      end else begin
         for(int i=0; i<NODES; i++) begin
            if(i_data_val[i] && o_en[i]) begin 
               `ifdef TORUS
                  f_tx_packet[i][i_data[i].data] <= 1; 
               `else
                  f_tx_packet[i][i_data[i].data] <= 1;  
               `endif          
            end
            if(o_data_val[i]) begin
               `ifdef TORUS
                  f_rx_packet[(o_data[i].z_source*X_NODES*Y_NODES)+(o_data[i].y_source*X_NODES)+o_data[i].x_source][o_data[i].data] <= 1;
               `else
                  f_rx_packet[o_data[i].source][o_data[i].data] <= 1;         
               `endif
            end
         end
      end
   end
   
   // TEST FUNCTION: Latency of Measure Packets
   
  // TEST FUNCTION: Batch(批量) Latency of all packets
  // ------------------------------------------------------------------------------------------------------------------
  initial begin
    for(int i=0; i<BATCH_NUMBER; i++) begin
      f_batch_total_latency[i]         = 0;
      f_batch_average_latency[i]       = 0;
      f_batch_measured_packet_count[i] = 0;
    end
    f_batch_number = 0;
    forever @(negedge clk) begin
      for (int i=0; i<NODES; i++) begin
        if ((o_data_val[i] == 1) && (f_batch_measured_packet_count[f_batch_number] < BATCH_SIZE)) begin
          f_batch_total_latency[f_batch_number] = f_batch_total_latency[f_batch_number] + (f_time - o_data[i].timestamp);
          f_batch_measured_packet_count[f_batch_number] = f_batch_measured_packet_count[f_batch_number] + 1;
        end else if ((o_data_val[i] == 1) && (f_batch_measured_packet_count[f_batch_number] == BATCH_SIZE)) begin
          f_batch_total_latency[f_batch_number+1] = f_batch_total_latency[f_batch_number+1] + (f_time - o_data[i].timestamp);
          f_batch_measured_packet_count[f_batch_number+1] = f_batch_measured_packet_count[f_batch_number+1] + 1;
          f_batch_number = f_batch_number + 1;
        end
      end
      for(int i=0; i<BATCH_NUMBER; i++) begin
        if ((f_batch_total_latency[i] != 0) && (f_test_saturated != 1)) begin
          f_batch_average_latency[i] = f_batch_total_latency[i]/f_batch_measured_packet_count[i];
        end else begin
          f_batch_average_latency[i] = 10000;          
        end
      end
    end
  end
  
  // TEST FUNCTION: Longest Packet Latency
  // ------------------------------------------------------------------------------------------------------------------
  always_ff@(negedge clk) begin
    if(~reset_n) begin
      f_max_latency <= '0;  
    end else begin
      for(int i=0; i<NODES; i++) begin
        if(((f_time - o_data[i].timestamp) > f_max_latency) && (o_data_val[i] == 1)) begin
          f_max_latency <= (f_time - o_data[i].timestamp);
        end else begin
          f_max_latency <= f_max_latency;
        end
      end
    end
  end
  
   // TEST FUNCTION: Latency Frequency
   // ------------------------------------------------------------------------------------------------------------------
   always_ff@(negedge clk) begin
      if(~reset_n) begin
         for(int i=0; i<100; i++) begin
            f_latency_frequency[i] <= 0; 
         end        
      end else begin
         for(int i=0; i<NODES; i++) begin
            if(o_data[i].valid == 1) begin
               f_latency_frequency[(f_time - o_data[i].timestamp)] <= f_latency_frequency[(f_time - o_data[i].timestamp)] + 1;
            end else begin
               f_latency_frequency[(f_time - o_data[i].timestamp)] <= f_latency_frequency[(f_time - o_data[i].timestamp)];
            end
         end
      end
   end
   
  // TEST FUNCTION: Saturation(饱和)
  // ------------------------------------------------------------------------------------------------------------------
  initial begin
    f_test_saturated = 0;
    forever @(negedge clk) begin
      `ifdef TORUS
        for (int z=0; z<Z_NODES; z++) begin
          for (int y=0; y<Y_NODES; y++) begin
            for (int x=0; x<X_NODES; x++) begin
              if ((f_full[(z*X_NODES*Y_NODES)+(y*X_NODES)+x] == 0) && (f_test_saturated !=1)) begin
                $display("WARNING:  Input port %g, (xyz)=(%g,%g,%g), saturated at f_time %g", (z*X_NODES*Y_NODES)+(y*X_NODES)+x, x, y, z, f_time);
                $display("");
                f_test_saturated = 1;
                f_test_fail = 1;
              end
            end
          end
        end
      `else
        for (int i=0; i<NODES; i++) begin
          if ((f_full[i] == 0) && (f_test_saturated !=1)) begin
            $display("WARNING:  Input port %g saturated at f_time %g", i, f_time);
            $display("");
            f_test_saturated = 1;
            f_test_fail = 1;
          end
        end      
      `endif
    end
  end
	
  // TEST FUNCTION: Routing
  // ------------------------------------------------------------------------------------------------------------------
  initial begin
    f_routing_fail_count = 0;
    forever @(negedge clk) begin    
      `ifdef TORUS
        for (int z=0; z<Z_NODES; z++) begin
          for (int y=0; y<Y_NODES; y++) begin
            for (int x=0; x<X_NODES; x++) begin
              if (o_data_val[(z*X_NODES*Y_NODES)+(y*X_NODES)+x] == 1) begin
                if ((o_data[(z*X_NODES*Y_NODES)+(y*X_NODES)+x].x_dest != x) || (o_data[(z*X_NODES*Y_NODES)+(y*X_NODES)+x].y_dest != y) || (o_data[(z*X_NODES*Y_NODES)+(y*X_NODES)+x].z_dest != z)) begin
                  $display ("Routing error number %g at time %g.  The packet output to node %g (x,y,z) = (%g,%g,%g) should have been sent to node (x,y,z) = (%g,%g,%g)", f_routing_fail_count + 1, f_time, (z*X_NODES*Y_NODES)+(y*X_NODES)+x, x, y, z, o_data[(z*X_NODES*Y_NODES)+(y*X_NODES)+x].x_dest, o_data[(z*X_NODES*Y_NODES)+(y*X_NODES)+x].y_dest, o_data[(z*X_NODES*Y_NODES)+(y*X_NODES)+x].z_dest);
                  $display("");
                  f_routing_fail_count = f_routing_fail_count + 1;
                  f_test_fail  = 1;
                end
              end
            end
          end
        end    
      `else
        for (int i=0; i<NODES; i++) begin
          if (o_data_val[i] == 1) begin
            if (o_data[i].dest != i) begin
              $display ("Routing error number %g at time %g.  The packet output to node %g should have been sent to node %g", f_routing_fail_count + 1, f_time, i, o_data[i].dest);
              $display("");
              f_routing_fail_count = f_routing_fail_count + 1;
              f_test_fail  = 1;              
            end            
          end          
        end        
      `endif
    end
  end
    
	*/
