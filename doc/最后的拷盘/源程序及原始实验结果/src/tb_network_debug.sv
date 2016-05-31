`timescale 1ps/1ps

`include "config.sv"
// debug测试模块，可打印包的路径。
// 也可测试 整个网络（network）总的 Tx 和 Rx, 和在 MEASURE_PACKETS 阶段的 Tx 和 Rx, 吞吐率, 包时延。

module tb_network_debug
#(
   parameter CLK_PERIOD = 100ps,
   parameter integer PACKET_RATE = 1, // Offered traffic as percent of capacity
   
   parameter integer WARMUP_PACKETS = `warmup_packets_num, // Number of packets to warm-up the network
   parameter integer MEASURE_PACKETS = `warmup_packets_num*5, // Number of packets to be measured
   parameter integer DRAIN_PACKETS = `warmup_packets_num*3, // Number of packets to drain the network
  
   parameter integer NODE_QUEUE_DEPTH = `INPUT_QUEUE_DEPTH * 8,
   parameter integer RUNNING_TIME = 10000,
	parameter logic debug = 1 //if(debug==1), 一个cycle只发送一个packet，以便观察
);

   // ================================================================================================================================
	
   logic clk;
   logic reset_n;
   
   longint  f_time;   // 计算时钟周期数（时间）
   longint  f_time_begin;  // 记录开始时间（最初的复位时间）
   logic    [7:0] packet_count;  // 对仿真生成的包进行计数，可用来标记每个包的id
	
   // 值为随机生成的变量 --------------------------------------
	int rand_i;
   logic [0:`NODES-1] rand_data_val; // 根据包注入率随机生成0或1，如果等于1则赋予数据包有效
   logic [0:`NODES-1][$clog2(`X_NODES)-1:0] rand_x_dest; // 随机生成数据包的x坐标
   logic [0:`NODES-1][$clog2(`Y_NODES)-1:0] rand_y_dest; // 随机生成数据包的y坐标

	
   // =================================================== 测试变量 ==============================================================

   //记录 总的 Tx 和 Rx --------------------------------------------------------------------------------------------------
   longint f_port_i_data_count_all [0:`NODES-1];        // 计数，各个PE结点发往network的 包的数量
      longint f_port_i_data_count_normal [0:`NODES-1];  // 计数，各个PE结点发往network的 普通包的数量
      longint f_port_i_data_count_ant [0:`NODES-1];     // 计数，各个PE结点发往network的 ant包的数量
      longint f_port_i_data_count_forward [0:`NODES-1]; // 计数，各个PE结点发往network的 forward ant包的数量
      longint f_port_i_data_count_backward [0:`NODES-1];// 计数，各个PE结点发往network的 backward ant包的数量
   longint f_port_o_data_count_all [0:`NODES-1];          // 计数，各个PE结点从network接收到的 包的数量
      longint f_port_o_data_count_normal [0:`NODES-1];    // 计数，各个PE结点从network接收到的 普通包的数量
      longint f_port_o_data_count_ant [0:`NODES-1];       // 计数，各个PE结点从network接收到的 ant包的数量
      longint f_port_o_data_count_forward [0:`NODES-1];   // 计数，各个PE结点从network接收到的 forward ant包的数量
      longint f_port_o_data_count_backward [0:`NODES-1];  // 计数，各个PE结点从network接收到的 backward ant包的数量
   longint f_total_i_data_count_all;        // 总计数，所有PE结点发往network的 包的总数量
      longint f_total_i_data_count_normal;  // 总计数，所有PE结点发往network的 普通包的总数量
      longint f_total_i_data_count_ant;     // 总计数，所有PE结点发往network的 ant包的总数量
      longint f_total_i_data_count_forward; // 总计数，所有PE结点发往network的 forward ant包的总数量
      longint f_total_i_data_count_backward;// 总计数，所有PE结点发往network的 backward ant包的总数量
   longint f_total_o_data_count_all;          // 总计数，所有PE结点从network接收到的 包的总数量
      longint f_total_o_data_count_normal;    // 总计数，所有PE结点从network接收到的 普通包的总数量
      longint f_total_o_data_count_ant;       // 总计数，所有PE结点从network接收到的 ant包的总数量
      longint f_total_o_data_count_forward;   // 总计数，所有PE结点从network接收到的 forward ant包的总数量
      longint f_total_o_data_count_backward;  // 总计数，所有PE结点从network接收到的 backward ant包的总数量

   // 记录 measure阶段的 Tx 和 Rx --------------------------------------------------------------------------------------------------
   longint f_measure_port_i_packet_count_all [0:`NODES-1];        // measure阶段，各个PE结点发往network的 包的数量
      longint f_measure_port_i_packet_count_normal [0:`NODES-1];  // measure阶段，各个PE结点发往network的 普通包的数量
      longint f_measure_port_i_packet_count_ant [0:`NODES-1];     // measure阶段，各个PE结点发往network的 ant包的数量
      longint f_measure_port_i_packet_count_forward [0:`NODES-1]; // measure阶段，各个PE结点发往network的 forward ant包的数量
      longint f_measure_port_i_packet_count_backward [0:`NODES-1];// measure阶段，各个PE结点发往network的 backward ant包的数量
   longint f_measure_port_o_packet_count_all [0:`NODES-1];          // measure阶段，各个PE结点从network接收到的 包的数量
      longint f_measure_port_o_packet_count_normal [0:`NODES-1];    // measure阶段，各个PE结点从network接收到的 普通包的数量
      longint f_measure_port_o_packet_count_ant [0:`NODES-1];       // measure阶段，各个PE结点从network接收到的 ant包的数量
      longint f_measure_port_o_packet_count_forward [0:`NODES-1];   // measure阶段，各个PE结点从network接收到的 forward ant包的数量
      longint f_measure_port_o_packet_count_backward [0:`NODES-1];  // measure阶段，各个PE结点从network接收到的 backward ant包的数量
   real f_measure_total_i_packet_count_all;        // measure阶段，所有PE结点发往network的 包的总数量
      real f_measure_total_i_packet_count_normal;  // measure阶段，所有PE结点发往network的 普通包的总数量
      real f_measure_total_i_packet_count_ant;     // measure阶段，所有PE结点发往network的 ant包的总数量
      real f_measure_total_i_packet_count_forward; // measure阶段，所有PE结点发往network的 forward ant包的总数量
      real f_measure_total_i_packet_count_backward;// measure阶段，所有PE结点发往network的 backward ant包的总数量
   real f_measure_total_o_packet_count_all;          // measure阶段，所有PE结点从network接收到的 包的总数量
      real f_measure_total_o_packet_count_normal;    // measure阶段，所有PE结点从network接收到的 普通包的总数量
      real f_measure_total_o_packet_count_ant;       // measure阶段，所有PE结点从network接收到的 ant包的总数量
      real f_measure_total_o_packet_count_forward;   // measure阶段，所有PE结点从network接收到的 forward ant包的总数量
      real f_measure_total_o_packet_count_backward;  // measure阶段，所有PE结点从network接收到的 backward ant包的总数量

   // 记录 measure阶段的 吞吐率 --------------------------------------------------------------------------------------------------
   real f_throughput_o_all;          // 吞吐率
      real f_throughput_o_normal;    // 吞吐率，普通包
      real f_throughput_o_ant;       // 吞吐率，ant包
      real f_throughput_o_forward;   // 吞吐率，forward ant包
      real f_throughput_o_backward;  // 吞吐率，backward ant包

   // 只记录measure包的时延 --------------------------------------------------------------------------------------------------
   real f_latency_o_packet_count_all;        // 接收到的measure包的数量
      real f_latency_o_packet_count_normal;  // 接收到的measure包的数量，普通包
      real f_latency_o_packet_count_ant;     // 接收到的measure包的数量，ant包
      real f_latency_o_packet_count_forward; // 接收到的measure包的数量，forward ant包
      real f_latency_o_packet_count_backward;// 接收到的measure包的数量，backward ant包
   real f_total_latency_all;        // 总时延
      real f_total_latency_normal;  // 总时延，普通包
      real f_total_latency_ant;     // 总时延，ant包
      real f_total_latency_forward; // 总时延，forward ant包
      real f_total_latency_backward;// 总时延，backward ant包
   real f_average_latency_all;        // 平均包时延
      real f_average_latency_normal;  // 平均包时延，普通包
      real f_average_latency_ant;     // 平均包时延，ant包
      real f_average_latency_forward; // 平均包时延，forward ant包
      real f_average_latency_backward;// 平均包时延，backward ant包
   integer f_max_latency_all;        // 最长时延
      integer f_max_latency_normal;  // 最长时延，普通包
      integer f_max_latency_ant;     // 最长时延，ant包
      integer f_max_latency_forward; // 最长时延，forward ant包
      integer f_max_latency_backward;// 最长时延，backward ant包
   longint current_packet_latency;// 当前包时延
   //integer f_latency_frequency [0:99]; // The amount of times a single latency occurs
	
	
   // ================================================ 从子模块里引出的变量 ===========================================================
	
   logic    [0:`NODES-1][0:`N-1][3:0] test_en_SCtoFF;
   // FFtoAA ---------------------------------------------------------------------
   packet_t [0:`NODES-1][0:`N-1] test_data_FFtoAA;
   logic    [0:`NODES-1][0:`N-1] test_data_val_FFtoAA;
   // AAtoSW ---------------------------------------------------------------------
   packet_t [0:`NODES-1][0:`N-1] test_data_AAtoSW;
   // AAtoSC ---------------------------------------------------------------------
   logic    [0:`NODES-1][0:`N-1][0:`M-1] test_output_req_AAtoSC;
   // SC.sv ----------------------------------------------------------------------
   logic    [0:`NODES-1][0:`N-1][0:`M-1] test_l_req_matrix_SC;
   // AA.sv ----------------------------------------------------------------------
   logic    [0:`NODES-1][0:`N-1][0:`M-1] test_l_output_req;
   logic [0:`NODES-1][0:`N-1]test_routing_calculate;
   logic    [0:`NODES-1][0:`N-1] test_update;
   logic    [0:`NODES-1][0:`N-1] test_select_neighbor;
   logic    [0:`NODES-1][0:`N-1][0:`M-1] test_tb_o_output_req;
   // ant_routing_table.sv --------------------------------------------------------
   logic    [0:`NODES-1][0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] test_pheromones;
   logic    [0:`NODES-1][0:`N-1][0:`PH_TABLE_DEPTH-1] test_max_pheromone_value;
   logic    [0:`NODES-1][0:`N-1][0:`PH_TABLE_DEPTH-1] test_min_pheromone_value;
   logic [0:`NODES-1][0:`N-1][$clog2(`N)-1:0] test_max_pheromone_column;
   logic [0:`NODES-1][0:`N-1][$clog2(`N)-1:0] test_min_pheromone_column;
   logic [0:`NODES-1][0:`N-1][0:`M-1][1:0] test_avail_directions;
	
   // 链接network模块端口的变量定义 -------------------------------------------------
   //packet_t [0:`NODES-1] l_data_FFtoN;     // 输入，包，fifo -> network 中的对应路由
   //logic    [0:`NODES-1] l_data_val_FFtoN; // 输入，包信号，fifo -> network 中的对应路由
   
   packet_t [0:`NODES-1] o_data_N;     // 输出，包，network -> testbench 仿真PE结点
   logic    [0:`NODES-1] o_data_val_N; // 输出，包信号，network -> testbench 仿真PE结点
   logic    [0:`NODES-1][3:0] o_en_N;       // 输出，对应路由的使能信号，network -> fifo
   
   // 链接fifo模块（属于仿真的PE结点）端口的变量定义 ---------------------------------
   packet_t [0:`NODES-1] i_data_FF;     // 输入，仿真包，testbench 仿真PE结点-> fifo
   logic    [0:`NODES-1] i_data_val_FF; // 输入，仿真包信号，testbench 仿真PE结点-> fifo
   logic    [0:`NODES-1] i_en_FF;    // 输入，对应路由的使能信号，network -> fifo
   
   packet_t [0:`NODES-1] l_data_FFtoN;    // 输出，包，fifo -> network 中的对应路由
   logic    [0:`NODES-1] l_data_val_FFtoN;// 输出，包信号，fifo -> network 中的对应路由
   logic    [0:`NODES-1][3:0] o_en_FF;         // 输出，fifo模块的使能信号，fifo->testbench 仿真PE结点
   
   // ================================================== 生成 network 模块 ===========================================================
  
   network network(
						.clk(clk), 
						.reset_n(reset_n), 

                                                // 带fifo模块
						.i_data(l_data_FFtoN), 
						.i_data_val(l_data_val_FFtoN),
						.o_en(o_en_N),
						.o_data(o_data_N),
						.o_data_val(o_data_val_N),

						// 不带fifo模块
//						.i_data(i_data_FF), 
//						.i_data_val(i_data_val_FF),
//						.o_en(o_en_FF),
//						.o_data(o_data_N),
//						.o_data_val(o_data_val_N),

						// ---------------------------------------------
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
  .test_max_pheromone_column(test_max_pheromone_column),
  .test_min_pheromone_column(test_min_pheromone_column),
                  .test_avail_directions(test_avail_directions)
   );
   
   // ============================================= 生成 各PE结点的 FIFO 模块 ===========================================================
   genvar i;
   generate
      for (i=0; i<`NODES; i++) begin : GENERATE_INPUT_QUEUES
         fifo_packet #(.DEPTH(NODE_QUEUE_DEPTH))
            gen_fifo_packet (
                             .clk(clk),
                             .ce(1'b1),
                             .reset_n(reset_n),
                             .i_data(i_data_FF[i]),      
                             .i_data_val(i_data_val_FF[i]),    //f_data_val[i]
                             .i_en(i_en_FF[i]),
                             .o_data(l_data_FFtoN[i]),         //l_data_FFtoN
                             .o_data_val(l_data_val_FFtoN[i]), //f_o_data_val
                             .o_en(o_en_FF[i])
									 );
      end
   endgenerate
  
	always_comb begin
	   for(int i=0; i<`NODES; i++)begin
		   i_en_FF[i] = ( |o_en_N[i]);
		end
	end
   // =================================================== 仿真数据生成 ==============================================================
   
   // 中间变量的生成（随机地） ------------------------------------------------------
	
   // 随机目的地 ------------------
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
   // 随机包有效 -------------------
   always_ff@(posedge clk) begin
      if(~reset_n) begin
         if(debug)begin //one cycle, one packet
            rand_i <= 0;
         end else begin
            for(int i=0; i<`NODES; i++) begin
               rand_data_val[i] <= 0;
            end
         end

      end else begin
	 if(debug)begin //one cycle, one packet
            rand_i <= $urandom_range(`NODES-1, 0);
         end else begin
            for(int i=0; i<`NODES; i++) begin
               rand_data_val[i] <= ($urandom_range(100,1) <= PACKET_RATE && f_time < (RUNNING_TIME-100)) ? 1'b1 : 1'b0;
            end
         end
      end
   end
	
   // input data of network generation
   // -------------------------------------------------------------
   always_ff@(negedge clk) begin
      if(~reset_n) begin
         f_time_begin <= 0;
         packet_count <= 0;
         for(int y = 0; y < `Y_NODES; y++) begin
            for(int x = 0; x < `X_NODES; x++) begin
               i_data_val_FF[y*`X_NODES + x] <= 0;
 
               i_data_FF[y*`X_NODES + x].id <= 0;
    
               i_data_FF[y*`X_NODES + x].x_source <= x; 
               i_data_FF[y*`X_NODES + x].y_source <= y; 
               i_data_FF[y*`X_NODES + x].x_dest <= 0; 
               i_data_FF[y*`X_NODES + x].y_dest <= 0; 
 
               i_data_FF[y*`X_NODES + x].ant <= 0;
               i_data_FF[y*`X_NODES + x].backward <= 0;
 
               i_data_FF[y*`X_NODES + x].x_memory <= 0;
               i_data_FF[y*`X_NODES + x].y_memory <= 0;
               i_data_FF[y*`X_NODES + x].num_memories <= 0;
 
               i_data_FF[y*`X_NODES + x].b_x_memory <= 0;
               i_data_FF[y*`X_NODES + x].b_y_memory <= 0;
               i_data_FF[y*`X_NODES + x].b_num_memories <= 0;
            
               i_data_FF[y*`X_NODES + x].measure <= 0;
               i_data_FF[y*`X_NODES + x].timestamp <= 0;
            end
         end
      end else begin
         if(debug)begin // one cycle, one packet
            if (f_time % 10 == 0) begin
            //if (f_time == 10) begin
               i_data_val_FF[rand_i] <= 1;
			      
               i_data_FF[rand_i].id <= packet_count;
               packet_count <= packet_count + 1;
					
               if(f_time % 20 == 0)begin
                  i_data_FF[rand_i].ant <= 1;
               end else begin
                  i_data_FF[rand_i].ant <= 1;
               end
               i_data_FF[rand_i].x_dest <= rand_x_dest[rand_i]; 
               i_data_FF[rand_i].y_dest <= rand_y_dest[rand_i]; 
					
            end else begin
               for(int i=0; i<`NODES; i++) begin
                  i_data_val_FF[i] <= 0;
                  i_data_FF[i].x_dest <= 0;
                  i_data_FF[i].y_dest <= 0;
               end
            end
         end else begin
            packet_count <= packet_count + 1;

            for(int i=0; i<`NODES; i++) begin
               i_data_val_FF[i] <= rand_data_val[i] && o_en_FF[i];
   
               i_data_FF[i].id <= packet_count * `NODES + i;
               i_data_FF[i].x_dest <= rand_x_dest[i];
               i_data_FF[i].y_dest <= rand_y_dest[i];
               i_data_FF[i].timestamp <= f_time;
				
               if(f_time % 2 == 0)begin
                  i_data_FF[i].ant <= 0;
               end else begin
                  i_data_FF[i].ant <= 1;
               end
            end
         end // else

      end // else
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
   end // always_ff
	
   // ====================================================== Calculation =========================================================
   //parameter integer WARMUP_PACKETS = 1000, // Number of packets to warm-up the network
   //parameter integer MEASURE_PACKETS = 5000, // Number of packets to be measured
   //parameter integer DRAIN_PACKETS = 3000, // Number of packets to drain the network

   // ======================================================  测试  ==============================================================

   // 测试: 总的TX and RX --------------------------------------------
   always_ff@(negedge clk) begin
      if(~reset_n) begin
         for(int i=0; i<`NODES; i++) begin
            f_port_i_data_count_all[i]      <= 0;// 各个PE结点发往network的 包的数量
            f_port_i_data_count_normal[i]   <= 0;// 各个PE结点发往network的 普通包的数量
            f_port_i_data_count_ant[i]      <= 0;// 各个PE结点发往network的 ant包的数量
            f_port_i_data_count_forward[i]  <= 0;// 各个PE结点发往network的 forward ant包的数量
            f_port_i_data_count_backward[i] <= 0;// 各个PE结点发往network的 backward ant包的数量
				
            f_port_o_data_count_all[i]      <= 0;// 各个PE结点从network接收到的 包的数量
            f_port_o_data_count_normal[i]   <= 0;// 各个PE结点从network接收到的 普通包的数量
            f_port_o_data_count_ant[i]      <= 0;// 各个PE结点从network接收到的 ant包的数量
            f_port_o_data_count_forward[i]  <= 0;// 各个PE结点从network接收到的 forward ant包的数量
            f_port_o_data_count_backward[i] <= 0;// 各个PE结点从network接收到的 backward ant包的数量
         end          
      end else begin
         for(int i=0; i<`NODES; i++) begin
            if(l_data_val_FFtoN[i])begin
            //TX
               f_port_i_data_count_all[i] <= f_port_i_data_count_all[i] + 1; //所有包
               
               if(l_data_FFtoN[i].ant == 0) begin
                  f_port_i_data_count_normal[i] <= f_port_i_data_count_normal[i] + 1; //普通包
               end else begin//（生成一个ant包时，不仅ant包+1，forward ant包、backward ant包也各+1）
                  f_port_i_data_count_ant[i] <= f_port_i_data_count_ant[i] + 1; //ant包
                  f_port_i_data_count_forward[i] <= f_port_i_data_count_forward[i] + 1; //forward ant包
                  f_port_i_data_count_backward[i] <= f_port_i_data_count_backward[i] + 1; //backward ant包
               end
            end
            if(o_data_val_N[i])begin
            //RX（接收到的forward ant包的数量不计入 所有包 和 ant包）
               if(o_data_N[i].ant == 0) begin
                  f_port_o_data_count_all[i] <= f_port_o_data_count_all[i] + 1;//所有包
                  f_port_o_data_count_normal[i] <= f_port_o_data_count_normal[i] + 1;//普通包
               end else begin
                  if(o_data_N[i].b_num_memories == 0) begin//（源地址==目的地地址的包，forward和backward两种类型的ant包都在第一结点到达目的地）
                     f_port_o_data_count_all[i] <= f_port_o_data_count_all[i] + 1;//所有包
                     f_port_o_data_count_ant[i] <= f_port_o_data_count_ant[i] + 1;//ant包
                     
                     f_port_o_data_count_forward[i] <= f_port_o_data_count_forward[i] + 1;//forward ant包
                     f_port_o_data_count_backward[i] <= f_port_o_data_count_backward[i] + 1;//backward ant包
                  end else begin
                     if(o_data_N[i].b_num_memories == 1) begin // （forward类型的ant包到达目的地，backward类型继续前进，其实有问题）
                        f_port_o_data_count_forward[i] <= f_port_o_data_count_forward[i] + 1;//forward ant包
                     end else begin // （backward类型的ant包到达目的地）
                        f_port_o_data_count_all[i] <= f_port_o_data_count_all[i] + 1;//所有包
                        f_port_o_data_count_ant[i] <= f_port_o_data_count_ant[i] + 1;//ant包
                        
                        f_port_o_data_count_backward[i] <= f_port_o_data_count_backward[i] + 1;//backward ant包
                     end
                  end
               end
            end
         end
      end
   end

   always_comb begin
      f_total_i_data_count_all      = 0; // 所有PE结点发往network的 包的总数量
      f_total_i_data_count_normal   = 0; // 所有PE结点发往network的 普通包的总数量
      f_total_i_data_count_ant      = 0; // 所有PE结点发往network的 ant包的总数量
      f_total_i_data_count_forward  = 0; // 所有PE结点发往network的 forward ant包的总数量
      f_total_i_data_count_backward = 0; // 所有PE结点发往network的 backward ant包的总数量
		
      f_total_o_data_count_all      = 0; // 所有PE结点从network接收到的 包的总数量
      f_total_o_data_count_normal   = 0; // 所有PE结点从network接收到的 普通包的总数量
      f_total_o_data_count_ant      = 0; // 所有PE结点从network接收到的 ant包的总数量
      f_total_o_data_count_forward  = 0; // 所有PE结点从network接收到的 forward ant包的总数量
      f_total_o_data_count_backward = 0; // 所有PE结点从network接收到的 backward ant包的总数量
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

   // 测试: measure时期的 TX 和 RX  --------------------------------------------
   always_ff@(negedge clk) begin
      if(~reset_n) begin
         for(int i=0; i<`NODES; i++) begin
            f_measure_port_i_packet_count_all[i]      <= 0;
            f_measure_port_i_packet_count_normal[i]   <= 0;
            f_measure_port_i_packet_count_ant[i]      <= 0;
            f_measure_port_i_packet_count_forward[i]  <= 0;
            f_measure_port_i_packet_count_backward[i] <= 0;
				
            f_measure_port_o_packet_count_all[i]      <= 0;
            f_measure_port_o_packet_count_normal[i]   <= 0;
            f_measure_port_o_packet_count_ant[i]      <= 0;
            f_measure_port_o_packet_count_forward[i]  <= 0;
            f_measure_port_o_packet_count_backward[i] <= 0;
         end
      end else begin
         for(int i=0; i<`NODES; i++) begin
            if(l_data_val_FFtoN[i] && i_en_FF[i]
				                       && (f_total_i_data_count_all >= WARMUP_PACKETS) 
                                   && (f_total_i_data_count_all < (WARMUP_PACKETS + MEASURE_PACKETS)))begin
               f_measure_port_i_packet_count_all[i] <= f_measure_port_i_packet_count_all[i] + 1;
                  
               if(l_data_FFtoN[i].ant == 0) begin
                  f_measure_port_i_packet_count_normal[i] <= f_measure_port_i_packet_count_normal[i] + 1;
               end else begin
                  f_measure_port_i_packet_count_ant[i] <= f_measure_port_i_packet_count_ant[i] + 1;
            
                  f_measure_port_i_packet_count_forward[i] <= f_measure_port_i_packet_count_forward[i] + 1;
                  f_measure_port_i_packet_count_backward[i] <= f_measure_port_i_packet_count_backward[i] + 1;
               end
            end
            if(o_data_val_N[i] && (f_total_o_data_count_all >= WARMUP_PACKETS) 
                               && (f_total_o_data_count_all < (WARMUP_PACKETS + MEASURE_PACKETS)))begin
               if(o_data_N[i].ant == 0) begin
                  f_measure_port_o_packet_count_all[i] <= f_measure_port_o_packet_count_all[i] + 1;
                  f_measure_port_o_packet_count_normal[i] <= f_measure_port_o_packet_count_normal[i] + 1;
               end else begin
            
                  if(o_data_N[i].b_num_memories == 0) begin
                     f_measure_port_o_packet_count_all[i] <= f_measure_port_o_packet_count_all[i] + 1;
                     f_measure_port_o_packet_count_ant[i] <= f_measure_port_o_packet_count_ant[i] + 1;

                     f_measure_port_o_packet_count_forward[i] <= f_measure_port_o_packet_count_forward[i] + 1;
                     f_measure_port_o_packet_count_backward[i] <= f_measure_port_o_packet_count_backward[i] + 1;
                  end else begin
                     if(o_data_N[i].b_num_memories == 1) begin
                        f_measure_port_o_packet_count_forward[i] <= f_measure_port_o_packet_count_forward[i] + 1;
                     end else begin
                        f_measure_port_o_packet_count_all[i] <= f_measure_port_o_packet_count_all[i] + 1;
                        f_measure_port_o_packet_count_ant[i] <= f_measure_port_o_packet_count_ant[i] + 1;

                        f_measure_port_o_packet_count_backward[i] <= f_measure_port_o_packet_count_backward[i] + 1;
                     end
                  end
               end
            end
         end
      end
   end
   
   always_comb begin
      f_measure_total_i_packet_count_all      = 0;
      f_measure_total_i_packet_count_normal   = 0;
      f_measure_total_i_packet_count_ant      = 0;
      f_measure_total_i_packet_count_forward  = 0;
      f_measure_total_i_packet_count_backward = 0;
		
      f_measure_total_o_packet_count_all      = 0;
      f_measure_total_o_packet_count_normal   = 0;
      f_measure_total_o_packet_count_ant      = 0;
      f_measure_total_o_packet_count_forward  = 0;
      f_measure_total_o_packet_count_backward = 0;
      

      for (int i=0; i<`NODES; i++) begin
         f_measure_total_i_packet_count_all = f_measure_port_i_packet_count_all[i] + f_measure_total_i_packet_count_all;
         f_measure_total_i_packet_count_normal = f_measure_port_i_packet_count_normal[i] + f_measure_total_i_packet_count_normal;
         f_measure_total_i_packet_count_ant = f_measure_port_i_packet_count_ant[i] + f_measure_total_i_packet_count_ant;
         f_measure_total_i_packet_count_forward = f_measure_port_i_packet_count_forward[i] + f_measure_total_i_packet_count_forward;
         f_measure_total_i_packet_count_backward = f_measure_port_i_packet_count_backward[i] + f_measure_total_i_packet_count_backward;
			
         f_measure_total_o_packet_count_all = f_measure_port_o_packet_count_all[i] + f_measure_total_o_packet_count_all;
         f_measure_total_o_packet_count_normal = f_measure_port_o_packet_count_normal[i] + f_measure_total_o_packet_count_normal;
         f_measure_total_o_packet_count_ant = f_measure_port_o_packet_count_ant[i] + f_measure_total_o_packet_count_ant;
         f_measure_total_o_packet_count_forward = f_measure_port_o_packet_count_forward[i] + f_measure_total_o_packet_count_forward;
         f_measure_total_o_packet_count_backward = f_measure_port_o_packet_count_backward[i] + f_measure_total_o_packet_count_backward;
      end
   end
   
   // 测试: measure时期的 吞吐率  --------------------------------------------
   always_comb begin
      f_throughput_o_all      = 0;
      f_throughput_o_normal   = 0;
      f_throughput_o_ant      = 0;
      f_throughput_o_forward  = 0;
      f_throughput_o_backward = 0;

      if(`warmup_packets_num != 0) begin
         f_throughput_o_all      = (f_measure_total_o_packet_count_all     / (`warmup_packets_num * `NODES));
         f_throughput_o_normal   = (f_measure_total_o_packet_count_normal  / (`warmup_packets_num * `NODES));
         f_throughput_o_ant      = (f_measure_total_o_packet_count_ant     / (`warmup_packets_num * `NODES));
         f_throughput_o_forward  = (f_measure_total_o_packet_count_forward / (`warmup_packets_num * `NODES));
         f_throughput_o_backward = (f_measure_total_o_packet_count_backward/ (`warmup_packets_num * `NODES));
      end
   end

   // 测试: measure包的 时延  --------------------------------------------
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
            if (o_data_val_N[i] && o_data_N[i].measure) begin
               if(o_data_N[i].ant == 0) begin
                  f_total_latency_all = f_total_latency_all + (f_time - o_data_N[i].timestamp);
                  f_latency_o_packet_count_all = f_latency_o_packet_count_all + 1;
					
                  f_total_latency_normal = f_total_latency_normal + (f_time - o_data_N[i].timestamp);
                  f_latency_o_packet_count_normal = f_latency_o_packet_count_normal + 1;
               end else begin
                  if(o_data_N[i].b_num_memories == 0) begin
                     f_total_latency_all = f_total_latency_all + (f_time - o_data_N[i].timestamp);
                     f_latency_o_packet_count_all = f_latency_o_packet_count_all + 1;
					
                     f_total_latency_ant = f_total_latency_ant + (f_time - o_data_N[i].timestamp);
                     f_latency_o_packet_count_ant = f_latency_o_packet_count_ant + 1;
					   
                     f_total_latency_forward = f_total_latency_forward + (f_time - o_data_N[i].timestamp);
                     f_latency_o_packet_count_forward = f_latency_o_packet_count_forward + 1;

                     f_total_latency_backward = f_total_latency_backward + (f_time - o_data_N[i].timestamp);
                     f_latency_o_packet_count_backward = f_latency_o_packet_count_backward + 1;
                  end else begin
                     if(o_data_N[i].b_num_memories == 1) begin
                        f_total_latency_forward = f_total_latency_forward + (f_time - o_data_N[i].timestamp);
                        f_latency_o_packet_count_forward = f_latency_o_packet_count_forward + 1;
                     end else begin
                        f_total_latency_all = f_total_latency_all + (f_time - o_data_N[i].timestamp);
                        f_latency_o_packet_count_all = f_latency_o_packet_count_all + 1;
					
                        f_total_latency_ant = f_total_latency_ant + (f_time - o_data_N[i].timestamp);
                        f_latency_o_packet_count_ant = f_latency_o_packet_count_ant + 1;
					   
                        f_total_latency_backward = f_total_latency_backward + (f_time - o_data_N[i].timestamp);
                        f_latency_o_packet_count_backward = f_latency_o_packet_count_backward + 1;
                     end
                  end
               end
            end
         end
         if(f_latency_o_packet_count_all != 0)begin
            f_average_latency_all      = f_total_latency_all/f_latency_o_packet_count_all;
         end else begin
            f_average_latency_all      = 10000000;
         end
         if(f_latency_o_packet_count_normal != 0)begin
            f_average_latency_normal   = f_total_latency_normal/f_latency_o_packet_count_normal;
         end else begin
            f_average_latency_normal   = 10000000;
         end
         if(f_latency_o_packet_count_ant != 0)begin
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
   
   // 测试: 单包最长时延
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
            current_packet_latency <= f_time - o_data_N[i].timestamp;
            if(o_data_val_N[i] && o_data_N[i].measure) begin
               if(current_packet_latency > f_max_latency_all)begin
                  f_max_latency_all <= current_packet_latency;
               end
					
               if(o_data_N[i].ant == 0 && current_packet_latency > f_max_latency_normal)begin
                  f_max_latency_normal <= current_packet_latency;
               end else begin
                  if(current_packet_latency > f_max_latency_ant)begin
                     f_max_latency_ant <= current_packet_latency;
                  end
					   
                  if(o_data_N[i].b_num_memories == 0) begin
                     if(current_packet_latency > f_max_latency_forward) begin // o_data_N[i].backward == 0
                        f_max_latency_forward <= f_time - o_data_N[i].timestamp;
                     end
                     if(current_packet_latency > f_max_latency_backward)begin
                        f_max_latency_backward <= current_packet_latency;
                     end
                  end else begin
                     if(o_data_N[i].b_num_memories == 1 && current_packet_latency > f_max_latency_forward) begin // o_data_N[i].backward == 0
                        f_max_latency_forward <= f_time - o_data_N[i].timestamp;
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
         //显示每一个包的信息，包括路径
         for(int i=0; i<`NODES; i++) begin
            if(debug)begin
               if(l_data_val_FFtoN[i] && i_en_FF[i]) begin // 注入网络时包的信息
                  $display("f_time: %g;  packet_id:%g;  type:%g;  input node: %g;", f_time, l_data_FFtoN[i].id, l_data_FFtoN[i].ant, i);
                  $display(" source: %d,%d ; destinaton: %d,%d ; ", l_data_FFtoN[i].x_source, l_data_FFtoN[i].y_source, l_data_FFtoN[i].x_dest, l_data_FFtoN[i].y_dest);
               end
               if(o_data_val_N[i]) begin // 从网络收回时包的信息
                  $display("f_time: %g;  packet_id:%g;  type:%g;  output node: %g;", f_time, o_data_N[i].id, o_data_N[i].ant, i);
                  $display(" source: %d,%d ; destinaton: %d,%d ; ", o_data_N[i].x_source, o_data_N[i].y_source, o_data_N[i].x_dest, o_data_N[i].y_dest);
                  //$display(" source: %d,%d ; destinaton: %d,%d ; ", o_data_N[i].x_dest, o_data_N[i].y_dest, o_data_N[i].x_source, o_data_N[i].y_source);
                  for(int m=0; m<o_data_N[i].num_memories; m++) begin
                     $display(" path: %d,%d ; ", o_data_N[i].x_memory[m], o_data_N[i].y_memory[m]);
                  end
                  //$display(" source: %d,%d ; destinaton: %d,%d ; ", o_data_N[i].x_source, o_data_N[i].y_source, o_data_N[i].x_dest, o_data_N[i].y_dest);
                  for(int m=0; m<o_data_N[i].b_num_memories; m++) begin
                     $display(" back path: %d,%d ; ", o_data_N[i].b_x_memory[m], o_data_N[i].b_y_memory[m]);
                  end
               end
            end else begin
               if(o_data_val_N[i]) begin
                  if(o_data_N[i].ant==0) begin
                  // Normal packet 信息:
                     // 1.[ <cycle> ] Packet id: <> (packet type),
                     $write(" [ %g ] Packet id: %g (normal packet),  ", f_time, o_data_N[i].id);
                     // 2.Memory: [,,,],
                     $write(" Memory: [%g", o_data_N[i].y_memory[0] * `X_NODES + o_data_N[i].x_memory[0]);
                     for(int m=1; m<o_data_N[i].num_memories; m++) begin
                        $write(",%g", o_data_N[i].y_memory[m] * `X_NODES + o_data_N[i].x_memory[m]);
                     end
                     $write("],  ");
                     // 3.Timestamp: <>,   Latency: <>
                     $write(" Timestamp: %g,   Latency: %g  ", o_data_N[i].timestamp, f_time-o_data_N[i].timestamp);
                     $display("");
                  end else begin
                     if(o_data_N[i].b_num_memories == 1) begin // (o_data_N[i].backward==0)
                     // Ant.forward 信息:
                        // 1.[ <cycle> ] Packet id: <> (packet type),
                        $write(" [ %g ] Packet id: %g (ant.forward),  ", f_time, o_data_N[i].id);
                        // 2.Memory: [,,,],
                        $write(" Memory: [%g", o_data_N[i].y_memory[0] * `X_NODES + o_data_N[i].x_memory[0]);
                        for(int m=1; m<o_data_N[i].num_memories; m++) begin
                           $write(",%g", o_data_N[i].y_memory[m] * `X_NODES + o_data_N[i].x_memory[m]);
                        end
                        $write("],  ");
                        // 3.Timestamp: <>,   Latency: <>
                        $write(" Timestamp: %g,   Latency: %g  ", o_data_N[i].timestamp, f_time-o_data_N[i].timestamp);
                        $display("");
                     end else begin
                     // Ant.backward 信息:
                        // 1.[ <cycle> ] Packet id: <> (packet type),
                        $write(" [ %g ] Packet id: %g (ant.backward),  ", f_time, o_data_N[i].id);
                        // 2.Memory: [,,,],
                        $write(" Memory: [%g", o_data_N[i].b_y_memory[0] * `X_NODES + o_data_N[i].b_x_memory[0]);
                        for(int m=1; m<o_data_N[i].b_num_memories; m++) begin
                           $write(",%g", o_data_N[i].b_y_memory[m] * `X_NODES + o_data_N[i].b_x_memory[m]);   
                        end
                        $write("],  ");
                        // 3.Timestamp: <>,   Latency: <>
                        $write(" Timestamp: %g,   Latency: %g  ", o_data_N[i].timestamp, f_time-o_data_N[i].timestamp);
                        $display("");
                     end
                  end
               end
            end
         end
         // 在最后显示总的RX、TX，throughput，latency信息
         if (f_time == RUNNING_TIME-1) begin
            $display("");
            $display(" # Total cycles: %g",`warmup_packets_num*20-f_time_begin);
            $display(" # Total packets transmitted: %g, # Total packets received: %g",f_total_i_data_count_all, f_total_o_data_count_all);
            $display("");

            $display(" -- All packets:");
            $display("      # Packets transmitted: %g, # Packets received: %g",
                                            f_measure_total_i_packet_count_all, f_measure_total_o_packet_count_all);
            $display("      # Throughput: %g packets/cycle/node", f_throughput_o_all);
            $display("      # Average packet latency: %g cycles", f_average_latency_all);
            $display("      # Max packet latency: %g cycles", f_max_latency_all);
            $display("");
            $display(" -- Normal packet:");
            $display("      # Packets transmitted: %g, # Packets received: %g",
                                         f_measure_total_i_packet_count_normal, f_measure_total_o_packet_count_normal);
            $display("      # Throughput: %g packets/cycle/node", f_throughput_o_normal);
            $display("      # Average packet latency: %g cycles", f_average_latency_normal);
            $display("      # Max packet latency: %g cycles", f_max_latency_normal);
            $display("");
            $display(" -- Ant packet:");
            $display("      # Packets transmitted: %g, # Packets received: %g",
                                            f_measure_total_i_packet_count_ant, f_measure_total_o_packet_count_ant);
            $display("      # Throughput: %g packets/cycle/node", f_throughput_o_ant);
            $display("      # Average packet latency: %g cycles", f_average_latency_ant);
            $display("      # Max packet latency: %g cycles", f_max_latency_ant);
            $display("");
				
            $display(" -- Ant.forward:");
            $display("      # Packets transmitted: %g, # Packets received: %g",
                                        f_measure_total_i_packet_count_forward,  f_measure_total_o_packet_count_forward);
            $display("      # Throughput: %g packets/cycle/node", f_throughput_o_forward);
            $display("      # Average packet latency: %g cycles", f_average_latency_forward);
            $display("      # Max packet latency: %g cycles", f_max_latency_forward);
            $display("");
            $display(" -- Ant.backward:");
            $display("      # Packets transmitted: %g, # Packets received: %g",
                                       f_measure_total_i_packet_count_backward,  f_measure_total_o_packet_count_backward);
            $display("      # Throughput: %g packets/cycle/node", f_throughput_o_backward);
            $display("      # Average packet latency: %g cycles", f_average_latency_backward);
            $display("      # Max packet latency: %g cycles", f_max_latency_backward);
            $display("");
         end
      end
   end//initial
	
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
