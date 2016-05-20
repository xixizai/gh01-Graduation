`timescale 1ps/1ps

`include "config.sv"

// 针对router模块的testbench, 只查看 RX、TX 是否正常
module tb_router_debug
#(
  parameter integer X = 2,
  parameter integer Y = 1,
  parameter CLK_PERIOD = 100ps,
  parameter integer PACKET_RATE = 1 // 平均包注入率
  
//  parameter integer WARMUP_PACKETS = 1000, // Number of packets to warm-up the network
//  parameter integer MEASURE_PACKETS = 5000, // Number of packets to be measured
//  parameter integer DRAIN_PACKETS = 3000, // Number of packets to drain the network
  
//  parameter integer DOWNSTREAM_EN_RATE = 100, // Percent of time simulated nodes able to receive data
//  parameter integer NODE_QUEUE_DEPTH = `INPUT_QUEUE_DEPTH * 8
);

   logic clk;
   logic reset_n;
   
   // FLAGS:  Random
   // ------------------------------------------------------------------------------------------------------------------   
   logic [0:`N-1] f_data_val;
   
   logic [0:`N-1][$clog2(`X_NODES+1)-1:0] f_x_src;
   logic [0:`N-1][$clog2(`Y_NODES+1)-1:0] f_y_src;
   
   logic [0:`N-1][$clog2(`X_NODES+1)-1:0] f_x_dest;
   logic [0:`N-1][$clog2(`Y_NODES+1)-1:0] f_y_dest;
   
   // FLAGS:  Control
   // ------------------------------------------------------------------------------------------------------------------
   // Pseudo time value/clock counter
   longint f_time;
   
   integer f_port_t_data_count [0:`N-1];   // Count number of packets simulated and added to the node queues
   integer f_port_i_data_count [0:`N-1];   // Count number of packets that left the node, transmitted on each port
   integer f_port_o_data_count [0:`M-1];   // Count number of received packets on each port
   
   integer f_total_t_data_count;            // Count total number of simulated packets
   integer f_total_i_data_count;              // Count total number of transmitted packets
   integer f_total_o_data_count;              // Count total number of received packets

   // ================================================ test port definition ===========================================================
	
   logic    [0:`N-1] test_en_SCtoFF;
   // FFtoAA ---------------------------------------------------------------------
   packet_t [0:`N-1] test_data_FFtoAA;
   logic    [0:`N-1] test_data_val_FFtoAA;
   // AAtoSW ---------------------------------------------------------------------
   packet_t [0:`N-1] test_data_AAtoSW;
   // AAtoSC ---------------------------------------------------------------------
   logic    [0:`N-1][0:`M-1] test_output_req_AAtoSC;
   // SC.sv ----------------------------------------------------------------------
   logic    [0:`N-1][0:`M-1] test_l_req_matrix_SC;
   // AA.sv ----------------------------------------------------------------------
   logic    [0:`N-1][0:`M-1] test_l_output_req;
   logic [0:`N-1]test_routing_calculate;
   logic    [0:`N-1] test_update;
   logic    [0:`N-1] test_select_neighbor;
   logic    [0:`N-1][0:`M-1] test_tb_o_output_req;
   // ant_routing_table.sv --------------------------------------------------------
   logic    [0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] test_pheromones;
   logic    [0:`PH_TABLE_DEPTH-1] test_max_pheromone_value;
   logic    [0:`PH_TABLE_DEPTH-1] test_min_pheromone_value;
   logic [0:`N-1][0:`M-1][1:0] test_avail_directions;
     
   // ------------------------------------------------------------------------------------------------------------------
   
   packet_t [0:`N-1] l_i_data;
   logic [0:`N-1] l_i_data_val;
   logic [0:`N-1] l_o_en;
   
   packet_t [0:`M-1] l_o_data;
   logic [0:`M-1] l_o_data_val;
   //logic [0:`M-1] l_i_en;
   // ------------------------------------------------------------------------------------------------------------------
   router #(.X_LOC(X), .Y_LOC(Y))
      gen_router (
                  .clk(clk),
                  .reset_n(reset_n),
                  .i_data(l_i_data),          // From the upstream routers and nodes
                  .i_data_val(l_i_data_val),  // From the upstream routers and nodes
                  .o_en(l_o_en),              // To the upstream routers
                  .o_data(l_o_data),         // To the downstream routers
                  .o_data_val(l_o_data_val), // To the downstream routers
                  .i_en(5'b11111),             // From the downstream routers
                  
                  .test_en_SCtoFF(test_en_SCtoFF),
                  
                  .test_data_FFtoAA(test_data_FFtoAA),
                  .test_data_val_FFtoAA(test_data_val_FFtoAA),
                  
                  .test_data_AAtoSW(test_data_AAtoSW),
                  
                  .test_output_req_AAtoSC(test_output_req_AAtoSC),
					 
                  .test_l_req_matrix_SC(test_l_req_matrix_SC),
                  
		            .test_l_output_req(test_l_output_req),
                  .test_routing_calculate(test_routing_calculate),
                  .test_update(test_update),
                  .test_select_neighbor(test_select_neighbor),
                  .test_tb_o_output_req(test_tb_o_output_req),
						
                  .test_pheromones(test_pheromones),
                  .test_max_pheromone_value(test_max_pheromone_value),
                  .test_min_pheromone_value(test_min_pheromone_value),
                  .test_avail_directions(test_avail_directions)
                 );
   // SIMULATION:  System Clock
   // ------------------------------------------------------------------------------------------------------------------
   initial begin
      clk = 1;
      forever #(CLK_PERIOD/2) clk = ~clk;
   end
   // SIMULATION:  System Time
   // ------------------------------------------------------------------------------------------------------------------  
   initial begin
      f_time = 0;
      forever #(CLK_PERIOD) f_time = f_time + 1;
   end  
   // SIMULATION:  System Reset
   // ------------------------------------------------------------------------------------------------------------------
   initial begin
      reset_n = 0;
      #(CLK_PERIOD + 3 * CLK_PERIOD / 4)
      reset_n = 1;
   end

   // RANDOM  Destination
   // ------------------------------------------------------------------------------------------------------------------
   always_ff@(posedge clk) begin
      if(~reset_n) begin
         for(int i=0; i<`N; i++) begin
            f_x_src[i] <= 0;
            f_y_src[i] <= 0;
            f_x_dest[i] <= 0;
            f_y_dest[i] <= 0;
         end
      end else begin // 5个端口分别创建仿真数据
         f_x_src[0] <= X;
         f_y_src[0] <= Y;
         f_x_dest[0] <= $urandom_range(`X_NODES-1, 0);
         f_y_dest[0] <= $urandom_range(`Y_NODES-1, 0);
         
         f_x_src[1] <= $urandom_range(`X_NODES-1, 0);
         f_y_src[1] <= $urandom_range(`Y_NODES-1, Y+1);
         f_x_dest[1] <= X;
         f_y_dest[1] <= $urandom_range(Y-1, 0);//(Y, 0)
         
         f_x_src[2] <= $urandom_range(`X_NODES-1, X+1);
         f_y_src[2] <= Y;
         f_x_dest[2] <= $urandom_range(X-1, 0);//(X, 0);
         f_y_dest[2] <= $urandom_range(`Y_NODES-1, 0);
         
         f_x_src[3] <= $urandom_range(`X_NODES-1, 0);
         f_y_src[3] <= $urandom_range(Y-1, 0);
         f_x_dest[3] <= X;
         f_y_dest[3] <= $urandom_range(`Y_NODES-1, Y+1);//(`Y_NODES-1, Y)
         
         f_x_src[4] <= $urandom_range(X-1, 0);
         f_y_src[4] <= Y;
         f_x_dest[4] <= $urandom_range(`X_NODES-1, X+1);//(`X_NODES-1, X)
         f_y_dest[4] <= $urandom_range(`Y_NODES-1, 0);
      end
   end
   
   // RANDOM Valid
   // ------------------------------------------------------------------------------------------------------------------ 
   always_ff@(posedge clk) begin
      if(~reset_n) begin
         for(int i=0; i<`N; i++) begin
            f_data_val[i] <= 0;
         end
      end else begin
         for(int i=0; i<`N; i++) begin
            f_data_val[i] <= ($urandom_range(100,1) <= PACKET_RATE) ? 1'b1 : 1'b0;
         end
      end
   end
  
   // input data
   // ------------------------------------------------------------------------------------------------------------------  
   always_ff@(posedge clk) begin
      if(~reset_n) begin
         for (int i = 0; i < `N; i++) begin
            l_i_data_val[i] <= 0;
            
            l_i_data[i].id <= 0;
            l_i_data[i].x_source <= '0; // Source field used to declare which input port packet was presented to
            l_i_data[i].y_source <= '0; // Source field used to declare which input port packet was presented to
            l_i_data[i].x_dest <= '0; // Destination field indicates where packet is to be routed to
            l_i_data[i].y_dest <= '0; // Destination field indicates where packet is to be routed to 
            
            l_i_data[i].ant <= 0;
            l_i_data[i].backward <= 0;
            
            l_i_data[i].x_memory <= '0;
            l_i_data[i].y_memory <= '0;
            l_i_data[i].num_memories <= '0;
            
            
            l_i_data[i].b_x_memory <= 0;
            l_i_data[i].b_y_memory <= 0;
            l_i_data[i].b_num_memories <= 0;
            
            l_i_data[i].measure <= 0;
            l_i_data[i].timestamp <= 0;
         end
      end else begin
         for(int i=0; i<`N; i++) begin
			   
            l_i_data[i].x_source <= f_x_src[i];
            l_i_data[i].y_source <= f_y_src[i];
            l_i_data[i].x_dest <= f_x_dest[i];
            l_i_data[i].y_dest <= f_y_dest[i];
            
            if (f_time % `CREATE_ANT_PERIOD == 0)begin //每隔CREATE_ANT_PERIOD周期发送一次ant包
               l_i_data[i].ant <= 1;
               l_i_data_val[i] <= 1;
            end else begin
               l_i_data[i].ant <= 0;
               l_i_data_val[i] <= f_data_val[i];
            end
         end
      end
   end
   
   // TEST FUNCTION:  TX and RX Packet Counters
   // ------------------------------------------------------------------------------------------------------------------ 
   always_ff@(negedge clk) begin
      if(~reset_n) begin
         for(int i=0; i<`N; i++) begin
            f_port_t_data_count[i] <= 0;
            f_port_i_data_count[i] <= 0;
            f_port_o_data_count[i] <= 0;
         end          
      end else begin
         for(int i=0; i<`N; i++) begin
            f_port_t_data_count[i] <= f_port_t_data_count[i] + 1 ; // 未被平均包注入率缩小数目时仿真产生的总数据包数目
            f_port_i_data_count[i] <= l_i_data_val[i] ? f_port_i_data_count[i] + 1 : f_port_i_data_count[i]; // 分别记录5个输入输出端口的Rx
            f_port_o_data_count[i] <= l_o_data_val[i] ? f_port_o_data_count[i] + 1 : f_port_o_data_count[i]; // 分别记录5个输入输出端口的Tx
         end
      end
   end
   
   always_comb begin
      f_total_t_data_count = 0;   
      f_total_i_data_count = 0;
      f_total_o_data_count = 0;
      
      for (int i=0; i<`N; i++) begin
         f_total_t_data_count = f_port_t_data_count[i] + f_total_t_data_count;
         f_total_i_data_count = f_port_i_data_count[i] + f_total_i_data_count;
         f_total_o_data_count = f_port_o_data_count[i] + f_total_o_data_count;    
      end
   end
   
   initial begin
      #(CLK_PERIOD * 100000) $finish;
   end
   
   initial begin
      $display("");
      
      forever@(posedge clk) begin
         if(f_time % 100 == 0) begin
            $display("f_time %g:  Transmitted %g packets, Received %g packets   0:%g  1:%g  2:%g  3:%g  4:%g",
				             f_time,    f_total_i_data_count, f_total_o_data_count,
				f_port_o_data_count[0],f_port_o_data_count[1],f_port_o_data_count[2],f_port_o_data_count[3],f_port_o_data_count[4]);
         end
      end
   end

endmodule

