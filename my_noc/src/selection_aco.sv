`include "config.sv"

//通过选择策略，在可选择的输出端口队列中选择一最终（最优）输出端口。
module selection_aco#(
  parameter integer X_LOC, // 当前结点的X坐标
  parameter integer Y_LOC, // 当前结点的Y坐标
  
  parameter integer selection_type = 3 //0:选择第一个   1:random   2:obl   3:aco
)(
  input logic reset_n,
  input logic [0:`M-1][3:0] i_en,
  
  input logic [0:`N-1] i_update,                       // 输入，信息素表 更新功能 的使能信号
  input logic [0:`N-1] i_select_neighbor,              // 输入，进行输出端口 选择 的使能信号
  input logic [0:`N-1][0:`M-1][1:0] i_avail_directions,// 输入，可选择的输出端口队列
  input logic [0:`N-1][$clog2(`X_NODES)-1:0] i_x_dest, // 输入，数据包的目的地信息（x坐标）
  input logic [0:`N-1][$clog2(`Y_NODES)-1:0] i_y_dest, // 输入，数据包的目的地信息（y坐标）

  output logic [0:`N-1][0:`M-1] o_output_req, // 输出，通过选择策略 得到的对应N个输入数据请求的输出端口
  
  output logic [0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] test_pheromones,
  output logic [0:`N-1][`PH_TABLE_DEPTH-1:0] test_max_pheromone_value,
  output logic [0:`N-1][`PH_TABLE_DEPTH-1:0] test_min_pheromone_value,
  output logic [0:`N-1][$clog2(`N)-1:0] test_max_pheromone_column,
  output logic [0:`N-1][$clog2(`N)-1:0] test_min_pheromone_column
);

   // ==================================================== Local Signals ========================================================
   // 对可选队列 使用随机选择时 相关的变量
   logic [0:`N-1][`M-1:0] rand_seed; // 用来生成随机数的随机种子
   logic [0:`N-1][1:0] rand_num; // 保存随机数
   
   // 对可选队列 使用路由选择时 相关的变量
   logic [0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] pheromones; // 信息素表,pheromones[路由结点号][对应输出端口号-1][值]
   logic [0:`N-1][`PH_TABLE_DEPTH-1:0] max_pheromone_value; // 保存信息素表当前行的最大值
   logic [0:`N-1][`PH_TABLE_DEPTH-1:0] min_pheromone_value; // 保存信息素表当前行的最小值
   logic [0:`N-1][$clog2(`N)-1:0] max_pheromone_column; // 保存信息素表当前行的最大值的列号（对应输出端口）[2?1?:0]
   logic [0:`N-1][$clog2(`N)-1:0] min_pheromone_column; // 保存信息素表当前行的最小值的列号（对应输出端口）[2?1?:0]
   
   assign test_pheromones = pheromones;
   assign test_max_pheromone_value = max_pheromone_value;
   assign test_min_pheromone_value = min_pheromone_value;
   assign test_max_pheromone_column = max_pheromone_column;
   assign test_min_pheromone_column = min_pheromone_column;
	
   logic [0:`N-1][3:0] max_en_value;
   logic [0:`N-1][3:0] min_en_value;
   logic [0:`N-1][$clog2(`N)-1:0] max_en_column;
   logic [0:`N-1][$clog2(`N)-1:0] min_en_column;

   // 其它变量
   logic [0:`N-1][$clog2(`NODES)-1:0] l_dest;
   // ===========================================================================================================================
   
   always_comb begin
      //if(~reset_n)begin // 复位
         rand_seed = '0;
         rand_num = '0;

         pheromones = '0;
         max_pheromone_value = '0;
         min_pheromone_value = '0;
         max_pheromone_column = '0;
         min_pheromone_column = '0;
         max_en_value = '0;
         min_en_value = '0;
         max_en_column = '0;
         min_en_column = '0;

         l_dest = '0;

         o_output_req = '0;
      //end else begin // reset_n
				   
         for(int i=0;i<`N;i++)begin
            o_output_req[i] = '0;
            
            if(i_select_neighbor[i]) begin
				
					rand_seed[i] = (rand_seed[i] == 5'b11111) ? 0 : rand_seed[i] + 1; // 0到11111循换
					rand_num[i] = (i_avail_directions[i][`M-1] == 0) ? 3 : rand_seed % i_avail_directions[i][`M-1]; // 生成随机数
					
					if(selection_type == 0)begin // XY_routing
					   // 选择第一个
						for(int j = 0; j < `N; j++) begin
							o_output_req[i][j] = (j == i_avail_directions[i][0] + 1) ? 1 : 0; // 选择第一个
						end
					end else if(selection_type == 1)begin // OddEven_Random
					   // 随机选择
						for(int j = 0; j < `N; j++) begin
							o_output_req[i][j] = (j == (i_avail_directions[i][rand_num[i]] + 1) ) ? 1 : 0; // 随机选择
						end
				   end else if(selection_type == 2)begin // OddEven_OBL
					   // OBL选择
						max_en_value[i] = '0;
						min_en_value[i] = 4'b1111;
						max_en_column[i] = i_avail_directions[i][0];
						min_en_column[i] = i_avail_directions[i][0];
						
						for(int j = 0; j < i_avail_directions[i][`M-1]; j++) begin
							if(i_avail_directions[i][j]+1 != i) begin
								if(max_en_value[i] < i_en[i_avail_directions[i][j]+1]) begin
									max_en_value[i] = i_en[i_avail_directions[i][j]+1];
									max_en_column[i] = i_avail_directions[i][j];
								end
								if(min_en_value[i] > i_en[i_avail_directions[i][j]+1]) begin
									min_en_value[i] = i_en[i_avail_directions[i][j]+1];
									min_en_column[i] = i_avail_directions[i][j];
								end
							end
						end
						
						for(int j = 0; j < `N; j++) begin
							o_output_req[i][j] = (j == max_en_column[i] + 1) ? 1 : 0; // OBL选择
						end
					end else begin // OddEven_ACO
						// ACO选择
						max_pheromone_value[i] = `PH_MIN_VALUE;
						min_pheromone_value[i] = `PH_MAX_VALUE;
						max_pheromone_column[i] = i_avail_directions[i][0];
						min_pheromone_column[i] = i_avail_directions[i][0];
						
						l_dest[i] = i_y_dest[i] * `X_NODES + i_x_dest[i]; // 计算数据的目的地地址
						
						// 计算信息素表 l_dest[i]行中 和i_avail_directions队列中的端口 对应的几个信息素值中的最大/最小值，以及其端口
						for(int j = 0; j < i_avail_directions[i][`M-1]; j++) begin
							if(i_avail_directions[i][j]+1 != i) begin
								if(max_pheromone_value[i] <= pheromones[l_dest[i]][i_avail_directions[i][j]]) begin
									max_pheromone_value[i] = pheromones[l_dest[i]][i_avail_directions[i][j]];
									max_pheromone_column[i] = i_avail_directions[i][j];
								end
								if(min_pheromone_value[i] >= pheromones[l_dest[i]][i_avail_directions[i][j]]) begin
									min_pheromone_value[i] = pheromones[l_dest[i]][i_avail_directions[i][j]];
									min_pheromone_column[i] = i_avail_directions[i][j];
								end
							end
						end
						for(int j = 0; j < `N; j++) begin
							o_output_req[i][j] = (j == max_pheromone_column[i] + 1) ? 1 : 0; // ACO选择
						end
						//max_pheromone_column = 0;
//						if((max_pheromone_value - min_pheromone_value) > 10) begin 
//							// ACO选择
//							// may make error choice(choose output with less pheromone)
//							// prevent deadlock
//							/* rule */
//							for(int j = 0; j < `N; j++) begin
//								o_output_req[i][j] = (j == (max_pheromone_column + 1)) ? 1 : 0; // ACO选择
//							end
//						end else begin //(is not ant packet and table.d is not avail) begin:calculate by random route
//							// 随机选择
//							for(int j = 0; j < `N; j++) begin
//								o_output_req[i][j] = (j == (i_avail_directions[i][rand_num[i]] + 1) ) ? 1 : 0; // 随机选择
//							end
//						end			
					end

            end else if(i_update[i]) begin
               for(int j = 0; j < `N-1; j++) begin
                  if(j + 1 == i) begin // parent结点i 对应的信息素表的位置 + 1
                    pheromones[l_dest[i]][j] = (pheromones[l_dest[i]][j] < `PH_MAX_VALUE) ? pheromones[l_dest[i]][j]+1:pheromones[l_dest[i]][j];
                  end else begin // parent结点i 对应的信息素表的位置 - 1
                    pheromones[l_dest[i]][j] = (pheromones[l_dest[i]][j] > `PH_MIN_VALUE) ? pheromones[l_dest[i]][j]-1:pheromones[l_dest[i]][j];
                  end
               end
            end
         end // for
      //end // reset_n
   end
endmodule
