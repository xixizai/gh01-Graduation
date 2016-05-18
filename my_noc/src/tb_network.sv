`timescale 1ps/1ps
`include "config.sv"
// 最终测试模块。
// 测试 整个网络（network）总的 Tx 和 Rx, 和在 MEASURE_PACKETS 阶段的 Tx 和 Rx, 吞吐率, 包时延。
// 在各个平均包注入率下测试
module tb_network
#(
   parameter CLK_PERIOD = 100ps, // 设置一个时钟周期为 100ps
   parameter integer PACKET_RATE = 10, // 平均包注入率 Offered traffic as percent of capacity
   
   parameter integer WARMUP_PACKETS = `warmup_packets_num, // 使用WARMUP_PACKETS数量的包来 warm-up the network
   parameter integer MEASURE_PACKETS = `warmup_packets_num*5, // 用来测试的包的数量
   parameter integer DRAIN_PACKETS = `warmup_packets_num*3, // 使用DRAIN_PACKETS数量的包来 drain the network
   
   parameter integer NODE_QUEUE_DEPTH = `INPUT_QUEUE_DEPTH * 8 // 模拟PE结点中 fifo 的深度
);

   // ===================================================  ==============================================================
	
   logic clk;
   logic reset_n;
   
   longint  f_time;   // 计算时钟周期数（时间）
   longint  f_time_begin;  // 记录开始时间（最初的复位时间）
   logic    [7:0] packet_count;  // 对仿真生成的包进行计数，可用来标记每个包的id
	
   // 链接network模块端口的变量定义 -------------------------------------------------
   //packet_t [0:`NODES-1] l_data_FFtoN;     // 输入，包，fifo -> network 中的对应路由
   //logic    [0:`NODES-1] l_data_val_FFtoN; // 输入，包信号，fifo -> network 中的对应路由
   //logic    [0:`NODES-1] l_en_NtoFF;       // 输出，对应路由的使能信号，network -> fifo
   
   packet_t [0:`NODES-1] o_data_N;     // 输出，包，network -> testbench 仿真PE结点
   logic    [0:`NODES-1] o_data_val_N; // 输出，包信号，network -> testbench 仿真PE结点
   
   // 链接fifo模块（属于仿真的PE结点）端口的变量定义 ---------------------------------
   packet_t [0:`NODES-1] i_data_FF;     // 输入，仿真包，testbench 仿真PE结点-> fifo
   logic    [0:`NODES-1] i_data_val_FF; // 输入，仿真包信号，testbench 仿真PE结点-> fifo
   logic    [0:`NODES-1] l_en_NtoFF;    // 输入，对应路由的使能信号，network -> fifo
   
   packet_t [0:`NODES-1] l_data_FFtoN;    // 输出，包，fifo -> network 中的对应路由
   logic    [0:`NODES-1] l_data_val_FFtoN;// 输出，包信号，fifo -> network 中的对应路由
   logic    [0:`NODES-1] o_en_FF;         // 输出，fifo模块的使能信号，fifo->testbench 仿真PE结点
   
   // 值为随机生成的变量 --------------------------------------
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
   logic    [0:`NODES-1][0:`N-1]test_routing_calculate;
   logic    [0:`NODES-1][0:`N-1] test_update;
   logic    [0:`NODES-1][0:`N-1] test_select_neighbor;
   logic    [0:`NODES-1][0:`N-1][0:`M-1] test_tb_o_output_req;
   // ant_routing_table.sv --------------------------------------------------------
   logic    [0:`NODES-1][0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] test_pheromones;
   logic    [0:`NODES-1][0:`PH_TABLE_DEPTH-1] test_max_pheromone_value;
   logic    [0:`NODES-1][0:`PH_TABLE_DEPTH-1] test_min_pheromone_value;
   logic    [0:`NODES-1][0:`N-1][0:`M-1][1:0] test_avail_directions;
	
   // ================================================== 生成 network 模块 ===========================================================
  
   network network(
						.clk(clk), 
						.reset_n(reset_n), 

                                                // 带fifo模块
						.i_data(l_data_FFtoN), 
						.i_data_val(l_data_val_FFtoN),
						.o_en(l_en_NtoFF),
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
                             .i_en(l_en_NtoFF[i]),
                             .o_data(l_data_FFtoN[i]),         //l_data_FFtoN
                             .o_data_val(l_data_val_FFtoN[i]), //f_o_data_val
                             .o_en(o_en_FF[i])
									 );
      end
   endgenerate
  
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
         for(int i=0; i<`NODES; i++) begin
            rand_data_val[i] <= 0;
         end
      end else begin
         for(int i=0; i<`NODES; i++) begin
            rand_data_val[i] <= ($urandom_range(100,1) <= PACKET_RATE) ? 1'b1 : 1'b0;
         end
      end
   end
  
   // input data of network generation -----------------------------------------------------------------
   // fifo输入端口 数据的生成 -----------------
   always_ff@(posedge clk) begin
      if(~reset_n) begin
         packet_count <= 0;
         for (int y = 0; y < `Y_NODES; y++) begin
            for (int x = 0; x < `X_NODES; x++) begin
               i_data_val_FF[y*`X_NODES + x] <= 0;
               
               i_data_FF[y*`X_NODES + x].id  <= 0;
               
               i_data_FF[y*`X_NODES + x].x_source <= x;
               i_data_FF[y*`X_NODES + x].y_source <= y;
               i_data_FF[y*`X_NODES + x].x_dest   <= 0;
               i_data_FF[y*`X_NODES + x].y_dest   <= 0;
               
               i_data_FF[y*`X_NODES + x].ant      <= 0;
               i_data_FF[y*`X_NODES + x].backward <= 0;
               
               i_data_FF[y*`X_NODES + x].x_memory     <= 0;
               i_data_FF[y*`X_NODES + x].y_memory     <= 0;
               i_data_FF[y*`X_NODES + x].num_memories <= 0;
               
               i_data_FF[y*`X_NODES + x].b_x_memory     <= 0;
               i_data_FF[y*`X_NODES + x].b_y_memory     <= 0;
               i_data_FF[y*`X_NODES + x].b_num_memories <= 0;
               
               i_data_FF[y*`X_NODES + x].measure   <= 0;
               i_data_FF[y*`X_NODES + x].timestamp <= 0;
            end
         end
      end else begin
         packet_count <= packet_count + 1;

         for(int i=0; i<`NODES; i++) begin
            if(f_total_i_data_count_all < (WARMUP_PACKETS+MEASURE_PACKETS+DRAIN_PACKETS))begin
               i_data_FF[i].x_dest <= rand_x_dest[i];
               i_data_FF[i].y_dest <= rand_y_dest[i];
               
               i_data_FF[i].timestamp <= f_time;
               i_data_FF[i].id <= packet_count*`NODES+i;
					
               if(f_time % `CREATE_ANT_PERIOD == 0)begin
                  i_data_val_FF[i] <= o_en_FF[i];
                  i_data_FF[i].ant <= 1;
               end else begin
                  i_data_val_FF[i] <= rand_data_val[i] && o_en_FF[i];
                  i_data_FF[i].ant <= 0;
               end
               
               if(f_total_i_data_count_all >= WARMUP_PACKETS && f_total_i_data_count_all < (WARMUP_PACKETS+MEASURE_PACKETS)) begin
                  i_data_FF[i].measure <= 1;
               end else begin
                  i_data_FF[i].measure <= 0;
               end
               //end else begin
               //end
            end else begin
               i_data_val_FF[i] <= 0;
            end
         end
      end
   end
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
            if(l_data_val_FFtoN[i] && (f_total_i_data_count_all >= WARMUP_PACKETS) 
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
                     if(current_packet_latency > f_max_latency_forward) begin
                        f_max_latency_forward <= f_time - o_data_N[i].timestamp;
                     end
                     if(current_packet_latency > f_max_latency_backward)begin
                        f_max_latency_backward <= current_packet_latency;
                     end
                  end else begin
                     if(o_data_N[i].b_num_memories == 1 && current_packet_latency > f_max_latency_forward) begin
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
   
   // ====================================================== Simulation =========================================================
    
   // Simulation:  System Clock ----------------------------------
   initial begin
      clk = 1;
      forever #(CLK_PERIOD/2) clk = ~clk;
   end
	
   // Simulation:  System Time -----------------------------------
   initial begin
      f_time = 0;
      forever #(CLK_PERIOD) f_time = f_time + 1;
   end
	
   // Simulation:  System Reset -----------------------------------
   initial begin
      reset_n = 0;
      #(CLK_PERIOD + 3 * CLK_PERIOD / 4)
      reset_n = 1;
   end
	
   // Simulation:  Run Period -------------------------------------
   initial begin
      #(CLK_PERIOD * `warmup_packets_num*20) $finish;
   end
	
   // RESULTS CONTROL --------------------------------------------------------
   initial begin
      $display("");//$monitot("",);
      forever@(posedge clk) begin
         if(f_time % 100 == 0 
            && (f_total_i_data_count_all != f_total_o_data_count_all
                || f_total_i_data_count_all < (WARMUP_PACKETS+MEASURE_PACKETS+DRAIN_PACKETS))) begin
            $display("[ %g ]:  Transmitted %g packets,  Received %g packets   0:%g  1:%g  2:%g  3:%g  %g:%g",
                      f_time,  f_total_i_data_count_all,f_total_o_data_count_all,
				  f_port_o_data_count_all[0],f_port_o_data_count_all[1],f_port_o_data_count_all[2],f_port_o_data_count_all[3],`NODES,f_port_o_data_count_all[`NODES-1]);
         end
			
         //show total packets message in the end
         if (f_time == `warmup_packets_num*20-1) begin
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
   end
endmodule
