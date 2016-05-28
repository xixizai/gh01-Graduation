`timescale 1ps/1ps
`include "config.sv"
// 测试 整个网络（network）总的 Tx 和 Rx, 和在 MEASURE_PACKETS 阶段的 Tx 和 Rx, 吞吐率, 包时延。
// 在各个平均包注入率下测试
module tb_network
#(
   parameter CLK_PERIOD = 100ps, // 设置一个时钟周期为 100ps
   parameter integer WARMUP_PACKETS = `warmup_packets_num, // 使用WARMUP_PACKETS数量的包来 warm-up the network
   parameter integer MEASURE_PACKETS = `warmup_packets_num*10, // 用来测试的包的数量
   parameter integer DRAIN_PACKETS = `warmup_packets_num*3, // 使用DRAIN_PACKETS数量的包来 drain the network
	parameter longint FINISH_TIME = CLK_PERIOD * `warmup_packets_num*10,
   
   parameter integer PACKET_RATE = 20, // 平均包注入率 Offered traffic as percent of capacity
   parameter integer ANT_PACKET_RATE = PACKET_RATE, // 平均包注入率 Offered traffic as percent of capacity
   parameter integer HOTSPOT_PACKET_RATE = 50, // hotspot包注入率
   
   parameter integer NODE_QUEUE_DEPTH = `INPUT_QUEUE_DEPTH * 5, // 模拟PE结点中 fifo 的深度
	parameter integer traffic_type = 1, //0:nothing   1:uniform   2:transpose   3:hotspot
   parameter integer routing_type = 1, //0:nothing   1:xy   2:odd even
   parameter integer selection_type = 1 //0:选择第一个   1:random   2:obl   3:aco
);
 
   // =================================================== 变量 ==============================================================
	integer file_id;
  
   logic clk;
   logic reset_n;
   
   longint  f_time;   // 计算时钟周期数（时间）
   longint  f_time_begin;  // 记录开始时间（最初的复位时间）
   longint  f_time_finish;  // 记录开始时间（时间）
   logic    [7:0] packet_count;  // 对仿真生成的包进行计数，可用来标记每个包的id
	
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
   real f_throughput_cycle_count;        // 接收到的measure包的数量

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
   longint current_packet_latency; // 当前包时延
   //integer f_latency_frequency [0:99]; // The amount of times a single latency occurs
	
   // ================================================ 值为随机生成的变量 ==========================================================
	
   logic [0:`NODES-1] rand_data_val; // 根据包注入率随机生成0或1，如果等于1则赋予数据包有效
   logic [0:`NODES-1] rand_ant_data_val; // 根据包注入率随机生成0或1，如果等于1则赋予数据包有效
   logic [0:`NODES-1][$clog2(`X_NODES)-1:0] rand_x_dest; // 随机生成数据包的x坐标
   logic [0:`NODES-1][$clog2(`Y_NODES)-1:0] rand_y_dest; // 随机生成数据包的y坐标
   logic [$clog2(`NODES)-1:0] rand_hotspots_num;
	logic [0:`NODES-1][$clog2(`X_NODES)-1:0] rand_hotspots;
	
   // ================================================ 从子模块里引出的test变量 ===========================================================
	
   logic    [0:`NODES-1][0:`N-1] test_en_SCtoFF;
   // data_val -----------------------------------------------------------------------
   logic    [0:`NODES-1][0:`N-1] test_data_val_FFtoAA;
   // data ----------------------------------------------------------------------
   packet_t [0:`NODES-1][0:`N-1] test_data_FFtoAA;
   packet_t [0:`NODES-1][0:`N-1] test_data_AAtoSW;
   // routing_odd_even ----------------------------------------------------------
   logic    [0:`NODES-1][0:`N-1] test_routing_calculate;
   logic    [0:`NODES-1][0:`N-1][0:`M-1][1:0] test_avail_directions;
   // selection_aco -------------------------------------------------------------
   logic    [0:`NODES-1][0:`N-1] test_update;
   logic    [0:`NODES-1][0:`N-1] test_select_neighbor;
   logic    [0:`NODES-1][0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] test_pheromones;
   logic    [0:`NODES-1][0:`N-1][0:`PH_TABLE_DEPTH-1] test_max_pheromone_value;
   logic    [0:`NODES-1][0:`N-1][0:`PH_TABLE_DEPTH-1] test_min_pheromone_value;
   logic    [0:`NODES-1][0:`N-1][$clog2(`N)-1:0] test_max_pheromone_column;
   logic    [0:`NODES-1][0:`N-1][$clog2(`N)-1:0] test_min_pheromone_column;
   logic    [0:`NODES-1][0:`N-1][0:`M-1] test_tb_o_output_req;
   // AA.sv ----------------------------------------------------------------------
   logic    [0:`NODES-1][0:`N-1][0:`M-1] test_l_output_req;
   logic    [0:`NODES-1][0:`N-1][0:`M-1] test_output_req_AAtoSC;
   // SC.sv ----------------------------------------------------------------------
   logic    [0:`NODES-1][0:`N-1][0:`M-1] test_l_req_matrix_SC;
   	
	// ===============================================  链接network模块端口的变量定义  =========================================================
	
   // packet_t [0:`NODES-1] l_data_FFtoN;     // 输入，包，   fifo -> network 中的对应路由
   // logic    [0:`NODES-1] l_data_val_FFtoN; // 输入，包信号，fifo -> network 中的对应路由
   
   packet_t [0:`NODES-1] o_data_N;     // 输出，包，   network -> testbench 仿真PE结点
   logic    [0:`NODES-1] o_data_val_N; // 输出，包信号，network -> testbench 仿真PE结点
   logic    [0:`NODES-1][3:0] o_en_N;  // 输出，对应路由的使能信号，network -> fifo
   
   // ==========================================  链接fifo模块（属于仿真的PE结点）端口的变量定义  ===============================================
	
   packet_t [0:`NODES-1] i_data_FF;     // 输入，仿真包，   testbench 仿真PE结点-> fifo
   logic    [0:`NODES-1] i_data_val_FF; // 输入，仿真包信号，testbench 仿真PE结点-> fifo
   logic    [0:`NODES-1] i_en_FF;       // 输入，对应路由的使能信号，network -> fifo
   
   packet_t [0:`NODES-1] l_data_FFtoN;    // 输出，包，             fifo -> network 中的对应路由
   logic    [0:`NODES-1] l_data_val_FFtoN;// 输出，包信号，          fifo -> network 中的对应路由
   logic    [0:`NODES-1][3:0] o_en_FF;    // 输出，fifo模块的使能信号，fifo -> testbench 仿真PE结点
   
   // ====================================================  生成 network 模块  ============================================================
  
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
   
   // =============================================  生成 各PE结点的 FIFO 模块  ===========================================================
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


   // =============================================== uniform traffic 仿真数据生成 =========================================================
   
   // 中间变量的生成（随机地） ------------------------------------------------------
	
   // 随机目的地 ------------------
   always_ff@(posedge clk) begin
      if(~reset_n) begin
         for(int i=0; i<`NODES; i++) begin
            rand_x_dest[i] <= 0;
            rand_y_dest[i] <= 0;
         end
      end else begin
		   if(traffic_type==2)begin// transpose 还没改
				for (int y = 0; y < `Y_NODES; y++) begin
					for (int x = 0; x < `X_NODES; x++) begin
						rand_x_dest[y*`X_NODES+x] <= `X_NODES-1-x;
						rand_y_dest[y*`X_NODES+x] <= `Y_NODES-1-y;
					end
				end
			end else begin
				for(int i=0; i<`NODES; i++) begin
					rand_x_dest[i] <= $urandom_range(`X_NODES-1, 0);
					rand_y_dest[i] <= $urandom_range(`Y_NODES-1, 0);
				end
			end
      end
   end
   // 随机包有效 -------------------
   always_ff@(posedge clk) begin
      if(~reset_n) begin
         for(int i=0; i<`NODES; i++) begin
            rand_data_val[i] <= 0;
            rand_ant_data_val[i] <= 0;
         end
      end else begin
         if(traffic_type==1)begin // uniform
            for(int i=0; i<`NODES; i++) begin
               rand_data_val[i] <= ($urandom_range(100,1) <= PACKET_RATE) ? 1'b1 : 1'b0;
               rand_ant_data_val[i] <= ($urandom_range(100,1) <= ANT_PACKET_RATE) ? 1'b1 : 1'b0;
            end
		   end else if(traffic_type==2)begin// transpose 还没改
				for(int i=0; i<`NODES; i++) begin
					rand_data_val[i] <= ($urandom_range(100,1) <= PACKET_RATE) ? 1'b1 : 1'b0;
               rand_ant_data_val[i] <= ($urandom_range(100,1) <= ANT_PACKET_RATE) ? 1'b1 : 1'b0;
				end
			end else begin // hotspot
			// 随机hotspot生成 在下面initial部分
				for(int i=0; i<`NODES; i++) begin
               rand_ant_data_val[i] <= ($urandom_range(100,1) <= ANT_PACKET_RATE) ? 1'b1 : 1'b0;
					if(i==rand_hotspots[0] || i==rand_hotspots[1] || i==rand_hotspots[2] || i==rand_hotspots[3])begin
						// n个热点必须一一写出。。没想出其它办法。。
						rand_data_val[i] <= ($urandom_range(100,1) <= HOTSPOT_PACKET_RATE) ? 1'b1 : 1'b0;
					end else begin
						rand_data_val[i] <= ($urandom_range(100,1) <= PACKET_RATE) ? 1'b1 : 1'b0;
					end
				end
			end
		end
   end
  
   // input data of network generation -----------------------------------------------------------------
   // fifo输入端口 数据的生成 -----------------
   always_ff@(posedge clk) begin
      if(~reset_n) begin
		   f_time_begin <= f_time;
			f_time_finish <= 0;
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
					
					if(selection_type==3)begin
					   // normal+ant packet
						if(f_time % `CREATE_ANT_PERIOD == 0)begin
							i_data_val_FF[i] <= rand_ant_data_val[i] && ( |o_en_FF[i]);
							i_data_FF[i].ant <= 1;
						end else begin
							i_data_val_FF[i] <= rand_data_val[i] && ( |o_en_FF[i]);
							i_data_FF[i].ant <= 0;
						end
               end else begin
						// only normal packet
						i_data_val_FF[i] <= rand_data_val[i] && ( |o_en_FF[i]);
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
					f_time_finish <= (f_time_finish==0)? f_time : f_time_finish;
            end
         end
      end
   end

   // ======================================================  测试  ==============================================================
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
            if(l_data_val_FFtoN[i] && i_en_FF[i])begin
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

   // 测试: measure时期的 cycle 和 TX 和 RX  --------------------------------------------
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
		   f_throughput_cycle_count <= 0;
      end else begin
         if(   (f_total_o_data_count_all >= WARMUP_PACKETS) 
            && (f_total_o_data_count_all < (WARMUP_PACKETS + MEASURE_PACKETS)))begin
		      f_throughput_cycle_count <= f_throughput_cycle_count+1;
			end
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
         f_throughput_o_all      = (f_measure_total_o_packet_count_all     / (f_throughput_cycle_count * `NODES));
         f_throughput_o_normal   = (f_measure_total_o_packet_count_normal  / (f_throughput_cycle_count * `NODES));
         f_throughput_o_ant      = (f_measure_total_o_packet_count_ant     / (f_throughput_cycle_count * `NODES));
         f_throughput_o_forward  = (f_measure_total_o_packet_count_forward / (f_throughput_cycle_count * `NODES));
         f_throughput_o_backward = (f_measure_total_o_packet_count_backward/ (f_throughput_cycle_count * `NODES));
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
			
         if(f_total_latency_all == 0)begin
			   f_average_latency_all      = 0;
         end else (f_latency_o_packet_count_all == 0)begin
            f_average_latency_all      = 10000000;
         end else begin
            f_average_latency_all      = f_total_latency_all/f_latency_o_packet_count_all;
			end
			
         if(f_total_latency_normal == 0)begin
			   f_average_latency_normal   = 0;
         end else (f_latency_o_packet_count_normal == 0)begin
            f_average_latency_normal   = 10000000;
         end else begin
            f_average_latency_normal   = f_total_latency_normal/f_latency_o_packet_count_normal;
         end
			
         if(f_total_latency_ant == 0)begin
            f_average_latency_ant      = 0;
         end else (f_latency_o_packet_count_ant == 0)begin
            f_average_latency_ant      = 10000000;
         end else begin
            f_average_latency_ant      = f_total_latency_ant/f_latency_o_packet_count_ant;
         end
			
         if(f_total_latency_forward == 0)begin
			   f_average_latency_forward  = 0;
         end else (f_latency_o_packet_count_forward == 0)begin
            f_average_latency_forward  = 10000000;
         end else begin
            f_average_latency_forward  = f_total_latency_forward/f_latency_o_packet_count_forward;
         end
			
         if(f_total_latency_backward == 0)begin
			   f_average_latency_backward = 0;
         end else (f_latency_o_packet_count_backward == 0)begin
            f_average_latency_backward = 10000000;
         end else begin
            f_average_latency_backward = f_total_latency_backward/f_latency_o_packet_count_backward;
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
   
   // ====================================================== Simulation =========================================================
   // Simulation:  System Clock ----------------------------------
   initial begin
	   rand_hotspots_num = $urandom_range(`NODES-1, 4);
		//rand_hotspots[0] = 0;
		//rand_hotspots[rand_hotspots_num-1]=`NODES;
	   for (int i=0; i<rand_hotspots_num; i++)begin
	      rand_hotspots[i] = $urandom_range(`NODES-1, 0);
		   for(int j=0; j<i; j++)begin
			   if(rand_hotspots[j] == rand_hotspots[i])begin
   	         rand_hotspots[i] = $urandom_range(`NODES-1, 0);
				end
			end
	   end
	end
	
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
	   #(CLK_PERIOD * `warmup_packets_num*10) $finish;
   end
			
/************************************************************************************************************************************************

                                                   RESULTS CONTROL
	
************************************************************************************************************************************************/

   initial begin
      $display("");//$monitot("",);
      forever@(posedge clk) begin
		
   /*************************************************************************************************************************************

                                                       display
	
	*************************************************************************************************************************************/
	
         if(f_time % 100 == 0 
            && (f_total_i_data_count_all != f_total_o_data_count_all
                || f_total_i_data_count_all < (WARMUP_PACKETS+MEASURE_PACKETS+DRAIN_PACKETS))) begin
            $display("[ %g ]:  Transmitted %g packets,  Received %g packets   0:%g  1:%g  2:%g  3:%g  %g:%g",
                      f_time,  f_total_i_data_count_all,f_total_o_data_count_all,
				  f_port_o_data_count_all[0],f_port_o_data_count_all[1],f_port_o_data_count_all[2],f_port_o_data_count_all[3],`NODES,f_port_o_data_count_all[`NODES-1]);
         end
			
         //show total packets message in the end
         if (f_time == `warmup_packets_num*10-1) begin
            $display("");
            $display(" # Total cycles: %g",f_time_finish-f_time_begin);
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
				
         end
			
   /*************************************************************************************************************************************

                                                      写到 XY_routing/uniform/stats.json 文件
	
{ //config
    "aco_packet_injection_rate": 10,
    "enable_debugging": false,
    "link_delay": 1,
    "link_width": 4,
    "max_cycles": 1000,
    "max_injection_buffer_size": 32,
    "max_input_buffer_size": 20,
    "max_packets": -1,
    "no_drain": true,
    "num_nodes": 64,
    "num_virtual_channels": 4,
    "packet_injection_rate": 10,
    "packet_size": 16,
    "rand_seed": 13,
    "reinforcement_factor": 0.05,
    "result_dir": "results/j_10/t_hotspot/r_odd_even/s_aco/",
    "routing": "odd_even",
    "selection": "aco",
    "traffic": "hotspot"
}
{ //stats
    "acopacket.average_packet_delay": 221.22202359671076,
    "acopacket.max_packet_delay": 905,
    "acopacket.num_packets_received": 3920,
    "acopacket.num_packets_transmitted": 1567,
    "acopacket.throughput": 0.024484375,
    "average_packet_delay": 395.35395066142297,
    "max_packet_delay": 940,
    "num_packets_received": 6760,
    "num_packets_transmitted": 2797,
    "packet.average_packet_delay": 174.1319270647122,
    "packet.max_packet_delay": 940,
    "packet.num_packets_received": 2840,
    "packet.num_packets_transmitted": 1230,
    "packet.throughput": 0.01921875,
    "simulation_time": 73.83912818200042,
    "throughput": 0.043703125,
    "total_cycles": 1000
}
{ //config
    "num_nodes":`NODES,
    "packet_injection_rate":PACKET_RATE,
    "aco_packet_injection_rate":ANT_PACKET_RATE,
	 "warmup_packets":`WARMUP_PACKETS,
	 "measure_packets":MEASURE_PACKETS,
    "drain_packets":DRAIN_PACKETS,
    "router_input_queue_depth":`INPUT_QUEUE_DEPTH,
	 "PEnode_input_queue_depth":NODE_QUEUE_DEPTH,
    "create_ant_packet_period":`CREATE_ANT_PERIOD,
    "pheromone_table_value_width":`PH_TABLE_DEPTH,
    "result_dir":"results/j_10/t_hotspot/r_odd_even/s_aco/",
    "routing":"odd_even",
    "selection":"aco",
    "traffic":"hotspot",
	 "hotspot_packet_injection_rate":HOTSPOT_PACKET_RATE
}
{ //stats
    "max_cycles":`warmup_packets_num*10,
    "total_cycles":f_time_finish-f_time_begin,
    "measure_cycles":MEASURE_PACKETS,
    "throughput":f_throughput_o_all,
    "num_packets_transmitted":f_measure_total_i_packet_count_all,
    "num_packets_received":f_measure_total_o_packet_count_all,
    "average_packet_delay":f_average_latency_all,
    "max_packet_delay":f_max_latency_all,
    "packet.throughput":f_throughput_o_normal,
    "packet.num_packets_transmitted":f_measure_total_i_packet_count_normal,
    "packet.num_packets_received":f_measure_total_o_packet_count_normal,
    "packet.average_packet_delay":f_average_latency_normal,
    "packet.max_packet_delay":f_max_latency_normal,
    "acopacket.throughput":f_throughput_o_ant,
    "acopacket.num_packets_transmitted":f_measure_total_i_packet_count_ant,
    "acopacket.num_packets_received":f_measure_total_o_packet_count_ant,
    "acopacket.average_packet_delay":f_average_latency_ant,
    "acopacket.max_packet_delay":f_max_latency_ant
}				
	function void wr_file(file_id,f_time,f_time_begin,f_total_i_data_count_all,f_total_o_data_count_all,f_measure_total_i_packet_count_all,f_measure_total_o_packet_count_all,f_throughput_o_all,f_average_latency_all,f_max_latency_all,f_measure_total_i_packet_count_normal,f_measure_total_o_packet_count_normal,f_throughput_o_normal,f_average_latency_normal,f_max_latency_normal,f_measure_total_i_packet_count_ant,f_measure_total_o_packet_count_ant,f_throughput_o_ant,f_average_latency_ant,f_max_latency_ant);
		
			if (f_time == `warmup_packets_num*10-1) begin
	
				$fdisplay(file_id,"");
				$fdisplay(file_id,"Total cycles,%g,f_time_finish-f_time_begin);
				$fdisplay(file_id," # Total packets transmitted: %g, # Total packets received: %g",f_total_i_data_count_all, f_total_o_data_count_all);
				$fdisplay(file_id,"",);
				
				$fdisplay(file_id," -- All packets:");
				$fdisplay(file_id,"Packets transmitted: %g, # Packets received: %g",
														  f_measure_total_i_packet_count_all, f_measure_total_o_packet_count_all);
//				$fdisplay(file_id,"Throughput: %g packets/cycle/node", f_throughput_o_all);
				$fdisplay(file_id,"Average packet latency: %g cycles", f_average_latency_all);
				$fdisplay(file_id,"Max packet latency: %g cycles", f_max_latency_all);
				$fdisplay(file_id,"");
				$fdisplay(file_id," -- Normal packet:");
				$fdisplay(file_id,"Packets transmitted: %g, # Packets received: %g",
													  f_measure_total_i_packet_count_normal, f_measure_total_o_packet_count_normal);
				$fdisplay(file_id,"Throughput: %g packets/cycle/node", f_throughput_o_normal);
				$fdisplay(file_id,"Average packet latency: %g cycles", f_average_latency_normal);
				$fdisplay(file_id,"Max packet latency: %g cycles", f_max_latency_normal);
				$fdisplay(file_id,"");
				$fdisplay(file_id," -- Ant packet:");
				$fdisplay(file_id,"Packets transmitted: %g, # Packets received: %g",
														  f_measure_total_i_packet_count_ant, f_measure_total_o_packet_count_ant);
				$fdisplay(file_id,"Throughput: %g packets/cycle/node", f_throughput_o_ant);
				$fdisplay(file_id,"Average packet latency: %g cycles", f_average_latency_ant);
				$fdisplay(file_id,"Max packet latency: %g cycles", f_max_latency_ant);
				$fdisplay(file_id,"");
			
				$fclose(file_id);
			end
			wr_file = 1;
	endfunction:wr_file
	
	*************************************************************************************************************************************/
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/
			if(PACKET_RATE == 1 && traffic_type == 1 && routing_type == 1 && selection_type == 1)begin
				/*wr_file(file_id,f_time,f_time_begin,f_total_i_data_count_all,f_total_o_data_count_all,f_measure_total_i_packet_count_all,f_measure_total_o_packet_count_all,f_throughput_o_all,f_average_latency_all,f_max_latency_all,f_measure_total_i_packet_count_normal,f_measure_total_o_packet_count_normal,f_throughput_o_normal,f_average_latency_normal,f_max_latency_normal,f_measure_total_i_packet_count_ant,f_measure_total_o_packet_count_ant,f_throughput_o_ant,f_average_latency_ant,f_max_latency_ant);*/
				
			if (f_time == `warmup_packets_num*10-1) begin
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_uniform/r_xy/s_random/stats.json");
	         $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
				
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_uniform/r_xy/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 1 && traffic_type == 1 && routing_type == 2 && selection_type == 1)begin

			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_uniform/r_odd_even/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_uniform/r_odd_even/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 1 && traffic_type == 1 && routing_type == 2 && selection_type == 2)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_uniform/r_odd_even/s_buffer_level/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_uniform/r_odd_even/s_buffer_level/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 1 && traffic_type == 1 && routing_type == 2 && selection_type == 3)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_uniform/r_odd_even/s_aco/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_uniform/r_odd_even/s_aco/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end

   /*************************************************************************************************************************************

	*************************************************************************************************************************************/
			if(PACKET_RATE == 1 && traffic_type == 2 && routing_type == 1 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_transpose/r_xy/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_transpose/r_xy/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 1 && traffic_type == 2 && routing_type == 2 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_transpose/r_odd_even/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_transpose/r_odd_even/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 1 && traffic_type == 2 && routing_type == 2 && selection_type == 2)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_transpose/r_odd_even/s_buffer_level/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_transpose/r_odd_even/s_buffer_level/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 1 && traffic_type == 2 && routing_type == 2 && selection_type == 3)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_transpose/r_odd_even/s_aco/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_transpose/r_odd_even/s_aco/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/
			if(PACKET_RATE == 1 && traffic_type == 3 && routing_type == 1 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_hotspot/r_xy/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_hotspot/r_xy/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 1 && traffic_type == 3 && routing_type == 2 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_hotspot/r_odd_even/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_hotspot/r_odd_even/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 1 && traffic_type == 3 && routing_type == 2 && selection_type == 2)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_hotspot/r_odd_even/s_buffer_level/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_hotspot/r_odd_even/s_buffer_level/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 1 && traffic_type == 3 && routing_type == 2 && selection_type == 3)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_hotspot/r_odd_even/s_aco/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_1/t_hotspot/r_odd_even/s_aco/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
			
			
			
			
			
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/
			if(PACKET_RATE == 5 && traffic_type == 1 && routing_type == 1 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_uniform/r_xy/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_uniform/r_xy/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 5 && traffic_type == 1 && routing_type == 2 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_uniform/r_odd_even/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_uniform/r_odd_even/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 5 && traffic_type == 1 && routing_type == 2 && selection_type == 2)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_uniform/r_odd_even/s_buffer_level/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_uniform/r_odd_even/s_buffer_level/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 5 && traffic_type == 1 && routing_type == 2 && selection_type == 3)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_uniform/r_odd_even/s_aco/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_uniform/r_odd_even/s_aco/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end

   /*************************************************************************************************************************************

	*************************************************************************************************************************************/
			if(PACKET_RATE == 5 && traffic_type == 2 && routing_type == 1 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_transpose/r_xy/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_transpose/r_xy/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 5 && traffic_type == 2 && routing_type == 2 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_transpose/r_odd_even/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_transpose/r_odd_even/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 5 && traffic_type == 2 && routing_type == 2 && selection_type == 2)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_transpose/r_odd_even/s_buffer_level/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_transpose/r_odd_even/s_buffer_level/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 5 && traffic_type == 2 && routing_type == 2 && selection_type == 3)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_transpose/r_odd_even/s_aco/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_transpose/r_odd_even/s_aco/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/
			if(PACKET_RATE == 5 && traffic_type == 3 && routing_type == 1 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_hotspot/r_xy/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_hotspot/r_xy/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 5 && traffic_type == 3 && routing_type == 2 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_hotspot/r_odd_even/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_hotspot/r_odd_even/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 5 && traffic_type == 3 && routing_type == 2 && selection_type == 2)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_hotspot/r_odd_even/s_buffer_level/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_hotspot/r_odd_even/s_buffer_level/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 5 && traffic_type == 3 && routing_type == 2 && selection_type == 3)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_hotspot/r_odd_even/s_aco/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_5/t_hotspot/r_odd_even/s_aco/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
			
			
			
			
			
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/
			if(PACKET_RATE == 10 && traffic_type == 1 && routing_type == 1 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_uniform/r_xy/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_uniform/r_xy/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 10 && traffic_type == 1 && routing_type == 2 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_uniform/r_odd_even/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_uniform/r_odd_even/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 10 && traffic_type == 1 && routing_type == 2 && selection_type == 2)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_uniform/r_odd_even/s_buffer_level/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_uniform/r_odd_even/s_buffer_level/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 10 && traffic_type == 1 && routing_type == 2 && selection_type == 3)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_uniform/r_odd_even/s_aco/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_uniform/r_odd_even/s_aco/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end

   /*************************************************************************************************************************************

	*************************************************************************************************************************************/
			if(PACKET_RATE == 10 && traffic_type == 2 && routing_type == 1 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_transpose/r_xy/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_transpose/r_xy/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 10 && traffic_type == 2 && routing_type == 2 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_transpose/r_odd_even/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_transpose/r_odd_even/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 10 && traffic_type == 2 && routing_type == 2 && selection_type == 2)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_transpose/r_odd_even/s_buffer_level/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_transpose/r_odd_even/s_buffer_level/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 10 && traffic_type == 2 && routing_type == 2 && selection_type == 3)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_transpose/r_odd_even/s_aco/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_transpose/r_odd_even/s_aco/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/
			if(PACKET_RATE == 10 && traffic_type == 3 && routing_type == 1 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_hotspot/r_xy/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_hotspot/r_xy/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 10 && traffic_type == 3 && routing_type == 2 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_hotspot/r_odd_even/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_hotspot/r_odd_even/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 10 && traffic_type == 3 && routing_type == 2 && selection_type == 2)begin
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_hotspot/r_odd_even/s_buffer_level/stats.json");
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_hotspot/r_odd_even/s_buffer_level/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 10 && traffic_type == 3 && routing_type == 2 && selection_type == 3)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_hotspot/r_odd_even/s_aco/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_10/t_hotspot/r_odd_even/s_aco/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
			
			
			
			
			
			
			
			
			
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/
			if(PACKET_RATE == 20 && traffic_type == 1 && routing_type == 1 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_uniform/r_xy/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_uniform/r_xy/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 20 && traffic_type == 1 && routing_type == 2 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_uniform/r_odd_even/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_uniform/r_odd_even/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 20 && traffic_type == 1 && routing_type == 2 && selection_type == 2)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_uniform/r_odd_even/s_buffer_level/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_uniform/r_odd_even/s_buffer_level/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 20 && traffic_type == 1 && routing_type == 2 && selection_type == 3)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_uniform/r_odd_even/s_aco/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_uniform/r_odd_even/s_aco/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end

   /*************************************************************************************************************************************

	*************************************************************************************************************************************/
			if(PACKET_RATE == 20 && traffic_type == 2 && routing_type == 1 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_transpose/r_xy/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_transpose/r_xy/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 20 && traffic_type == 2 && routing_type == 2 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_transpose/r_odd_even/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_transpose/r_odd_even/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 20 && traffic_type == 2 && routing_type == 2 && selection_type == 2)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_transpose/r_odd_even/s_buffer_level/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_transpose/r_odd_even/s_buffer_level/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 20 && traffic_type == 2 && routing_type == 2 && selection_type == 3)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_transpose/r_odd_even/s_aco/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_transpose/r_odd_even/s_aco/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/
			if(PACKET_RATE == 20 && traffic_type == 3 && routing_type == 1 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_hotspot/r_xy/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_hotspot/r_xy/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 20 && traffic_type == 3 && routing_type == 2 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_hotspot/r_odd_even/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_hotspot/r_odd_even/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 20 && traffic_type == 3 && routing_type == 2 && selection_type == 2)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_hotspot/r_odd_even/s_buffer_level/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_hotspot/r_odd_even/s_buffer_level/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 20 && traffic_type == 3 && routing_type == 2 && selection_type == 3)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_hotspot/r_odd_even/s_aco/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_20/t_hotspot/r_odd_even/s_aco/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
			
			
			
			
			
			
			
			
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/
			if(PACKET_RATE == 50 && traffic_type == 1 && routing_type == 1 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_uniform/r_xy/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_uniform/r_xy/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 50 && traffic_type == 1 && routing_type == 2 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_uniform/r_odd_even/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_uniform/r_odd_even/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 50 && traffic_type == 1 && routing_type == 2 && selection_type == 2)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_uniform/r_odd_even/s_buffer_level/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_uniform/r_odd_even/s_buffer_level/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 50 && traffic_type == 1 && routing_type == 2 && selection_type == 3)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_uniform/r_odd_even/s_aco/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_uniform/r_odd_even/s_aco/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end

   /*************************************************************************************************************************************

	*************************************************************************************************************************************/
			if(PACKET_RATE == 50 && traffic_type == 2 && routing_type == 1 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_transpose/r_xy/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_transpose/r_xy/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 50 && traffic_type == 2 && routing_type == 2 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_transpose/r_odd_even/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_transpose/r_odd_even/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 50 && traffic_type == 2 && routing_type == 2 && selection_type == 2)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_transpose/r_odd_even/s_buffer_level/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_transpose/r_odd_even/s_buffer_level/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 50 && traffic_type == 2 && routing_type == 2 && selection_type == 3)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_transpose/r_odd_even/s_aco/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_transpose/r_odd_even/s_aco/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/
			if(PACKET_RATE == 50 && traffic_type == 3 && routing_type == 1 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_hotspot/r_xy/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_hotspot/r_xy/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 50 && traffic_type == 3 && routing_type == 2 && selection_type == 1)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_hotspot/r_odd_even/s_random/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_hotspot/r_odd_even/s_random/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 50 && traffic_type == 3 && routing_type == 2 && selection_type == 2)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_hotspot/r_odd_even/s_buffer_level/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_hotspot/r_odd_even/s_buffer_level/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
			
   /*************************************************************************************************************************************

	*************************************************************************************************************************************/

			if(PACKET_RATE == 50 && traffic_type == 3 && routing_type == 2 && selection_type == 3)begin
			   
			if (f_time == `warmup_packets_num*10-1) begin
	
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_hotspot/r_odd_even/s_aco/stats.json");
				$fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
	         $fdisplay(file_id,"   \"throughput\":%g,",f_throughput_o_all);
	         $fdisplay(file_id,"   \"num_packets_transmitted\":%g,",f_measure_total_i_packet_count_all);
	         $fdisplay(file_id,"   \"num_packets_received\":%g,",f_measure_total_o_packet_count_all);
	         $fdisplay(file_id,"   \"average_packet_delay\":%g,",f_average_latency_all);
	         $fdisplay(file_id,"   \"max_packet_delay\":%g,",f_max_latency_all);
	         $fdisplay(file_id,"   \"packet.throughput\":%g,",f_throughput_o_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.num_packets_received\":%g,",f_measure_total_o_packet_count_normal);
	         $fdisplay(file_id,"   \"packet.average_packet_delay\":%g,",f_average_latency_normal);
	         $fdisplay(file_id,"   \"packet.max_packet_delay\":%g,",f_max_latency_normal);
	         $fdisplay(file_id,"   \"acopacket.throughput\":%g,",f_throughput_o_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_transmitted\":%g,",f_measure_total_i_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.num_packets_received\":%g,",f_measure_total_o_packet_count_ant);
	         $fdisplay(file_id,"   \"acopacket.average_packet_delay\":%g,",f_average_latency_ant);
	         $fdisplay(file_id,"   \"acopacket.max_packet_delay\":%g",f_max_latency_ant);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
            file_id = $fopen(
"/media/jcq/e052d853-5bf0-41fb-9617-220923a0fe5f/Tools/FPGA/altera_lite/gh02-my_noc/my_noc/results/j_50/t_hotspot/r_odd_even/s_aco/config.json");
            $fdisplay(file_id,"{");
	         $fdisplay(file_id,"   \"num_nodes\":%g,",`NODES);
				$fdisplay(file_id,"   \"warmup_packets\":%g,",WARMUP_PACKETS);
				$fdisplay(file_id,"   \"measure_packets\":%g,",MEASURE_PACKETS);
				$fdisplay(file_id,"   \"drain_packets\":%g,",DRAIN_PACKETS);
	         $fdisplay(file_id,"   \"max_cycles\":%g,",`warmup_packets_num*10);
	         $fdisplay(file_id,"   \"total_cycles\":%g,",f_time_finish-f_time_begin);
	         $fdisplay(file_id,"   \"measure_cycles\":%g,",f_throughput_cycle_count);
				$fdisplay(file_id,"   \"router_input_queue_depth\":%g,",`INPUT_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"PEnode_input_queue_depth\":%g,",NODE_QUEUE_DEPTH);
				$fdisplay(file_id,"   \"create_ant_packet_period\":%g,",`CREATE_ANT_PERIOD);
				$fdisplay(file_id,"   \"pheromone_table_value_width\":%g,",`PH_TABLE_DEPTH);
				$fdisplay(file_id,"   \"result_dir\":\"results/j_10/t_hotspot/r_odd_even/s_aco/\",");
				$fdisplay(file_id,"   \"routing\":\"odd_even\",");
				$fdisplay(file_id,"   \"selection\":\"aco\",");
				$fdisplay(file_id,"   \"traffic\":\"hotspot\",");
				$fdisplay(file_id,"   \"packet_injection_rate\":%g,",PACKET_RATE);
				$fdisplay(file_id,"   \"aco_packet_injection_rate\":%g,",ANT_PACKET_RATE);
				$fdisplay(file_id,"   \"hotspot_packet_injection_rate\":%g",HOTSPOT_PACKET_RATE);
	         $fdisplay(file_id,"}");
				$fclose(file_id);
			end
			end
      end
   end
endmodule
/*
{ //config
    "aco_packet_injection_rate": 10,
    "enable_debugging": false,
    "link_delay": 1,
    "link_width": 4,
    "max_cycles": 1000,
    "max_injection_buffer_size": 32,
    "max_input_buffer_size": 20,
    "max_packets": -1,
    "no_drain": true,
    "num_nodes": 64,
    "num_virtual_channels": 4,
    "packet_injection_rate": 10,
    "packet_size": 16,
    "rand_seed": 13,
    "reinforcement_factor": 0.05,
    "result_dir": "results/j_10/t_hotspot/r_odd_even/s_aco/",
    "routing": "odd_even",
    "selection": "aco",
    "traffic": "hotspot"
}
{ //stats
    "acopacket.average_packet_delay": 221.22202359671076,
    "acopacket.max_packet_delay": 905,
    "acopacket.num_packets_received": 3920,
    "acopacket.num_packets_transmitted": 1567,
    "acopacket.throughput": 0.024484375,
    "average_packet_delay": 395.35395066142297,
    "max_packet_delay": 940,
    "num_packets_received": 6760,
    "num_packets_transmitted": 2797,
    "packet.average_packet_delay": 174.1319270647122,
    "packet.max_packet_delay": 940,
    "packet.num_packets_received": 2840,
    "packet.num_packets_transmitted": 1230,
    "packet.throughput": 0.01921875,
    "simulation_time": 73.83912818200042,
    "throughput": 0.043703125,
    "total_cycles": 1000
}
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
