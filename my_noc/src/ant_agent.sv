`include "config.sv"
// ant agent will output 5 packed words, each word corresponds to an input, each bit corresponds to the output requested.
// 对需要输出的数据进行处理和路由计算，并将处理后的数据发送给交换开关（switch one hot）模块，将路由计算后得到的输出请求发送给交换控制（switch control）模块
module ant_agent
#(
  parameter integer X_LOC, // 当前结点的X坐标
  parameter integer Y_LOC // 当前结点的Y坐标
)
(
   input logic reset_n,
   input logic [0:`M-1][3:0] i_en,
   input packet_t [0:`N-1] i_data, // 数据输入端口
   input logic [0:`N-1] i_data_val, // 指出是否有数据输入
   
   output packet_t [0:`M-1] o_data, // 数据输出端口，输出给switch one hot
   output logic [0:`N-1] o_data_val, // 指出是否有数据输出，输出给none
   output logic [0:`N-1][0:`M-1] o_output_req, // N个输入端口的对输出端口的请求情况，输出给switch control
	
   output logic [0:`N-1][0:`M-1] test_l_output_req,
   output logic [0:`N-1]test_routing_calculate,
   output logic [0:`N-1]test_select_neighbor,
   output logic [0:`N-1]test_update,
   output logic [0:`N-1][0:`M-1] test_tb_o_output_req,
   
   output logic [0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] test_pheromones,
   output logic [0:`N-1][`PH_TABLE_DEPTH-1:0] test_max_pheromone_value,
   output logic [0:`N-1][`PH_TABLE_DEPTH-1:0] test_min_pheromone_value,
  output logic [0:`N-1][$clog2(`N)-1:0] test_max_pheromone_column,
  output logic [0:`N-1][$clog2(`N)-1:0] test_min_pheromone_column,
   output logic [0:`N-1][0:`M-1][1:0] test_avail_directions
);

   // ==================================================== Local Signals ========================================================
   
   // routing 模块 输入 -------------------------------------------------------
   logic [0:`N-1][$clog2(`X_NODES)-1:0] l_x_source; // local -> selection
   logic [0:`N-1][$clog2(`X_NODES)-1:0] l_x_temp;   // local -> selection
   logic [0:`N-1][$clog2(`Y_NODES)-1:0] l_y_temp;   // local -> selection
   logic [0:`N-1]l_routing_calculate; // selection -> routing

   assign test_routing_calculate = l_routing_calculate;

   // selection 模块 输入 -----------------------------------------------------
   logic [0:`N-1]l_update;          // local -> selection
   logic [0:`N-1]l_select_neighbor; // local -> selection
   logic [0:`N-1][0:`M-1][$clog2(`Y_NODES)-1:0] l_avail_directions; // routing -> selection

   assign test_select_neighbor = l_select_neighbor;
   assign test_update = l_update;
   assign test_avail_directions = l_avail_directions;

   // 综合考虑两种req，选其一赋给o_output_req -----------------------------------
   logic [0:`N-1][0:`M-1] l_output_req;
   logic [0:`N-1][0:`M-1] select_o_output_req;
	
   assign test_l_output_req = l_output_req;
   assign test_tb_o_output_req = select_o_output_req;
   
   // ====================================================  routing_odd_even  =======================================================
   routing_odd_even #(.X_LOC(X_LOC), .Y_LOC(Y_LOC))
      routing_odd_even(
                       .i_x_source(l_x_source),
                       .i_x_dest(l_x_temp),
                       .i_y_dest(l_y_temp),

                       .i_routing_calculate(l_routing_calculate), //whether select neighbor or not
                       .o_select_neighbor(l_select_neighbor), //whether select neighbor or not
                       .o_avail_directions(l_avail_directions)
                      );
   // =====================================================  selection_aco  ========================================================
   selection_aco #(.X_LOC(X_LOC), .Y_LOC(Y_LOC))
      selection_aco(
                    .reset_n(reset_n),
                    .i_en(i_en),
                    
                    .i_x_dest(l_x_temp),
                    .i_y_dest(l_y_temp),
                    
                    .i_update(l_update),// whether update or not
                    .i_select_neighbor(l_select_neighbor), //whether select neighbor or not
                    .i_avail_directions(l_avail_directions),
                    
                    .o_output_req(select_o_output_req),
                    
                    .test_pheromones(test_pheromones),
                    .test_max_pheromone_value(test_max_pheromone_value),
                    .test_min_pheromone_value(test_min_pheromone_value),
  .test_max_pheromone_column(test_max_pheromone_column),
  .test_min_pheromone_column(test_min_pheromone_column)
                   );
   // ============================================================================================================================
   always_comb begin

      for(int i=0; i<`N; i++) begin
         l_x_source[i] = '0;
         l_x_temp[i] = '0;
         l_y_temp[i] = '0;

         l_routing_calculate[i] = '0;
	 
         l_update[i] = '0;
	 
         l_output_req[i] = '0;
	 
         o_data[i] = '0;
         o_data_val[i] = '0;
         
         if(i_data_val[i]) begin
         // 有数据输入
            o_data[i] = i_data[i];
            
            l_x_source[i] = o_data[i].x_source;
            l_x_temp[i] = o_data[i].x_dest;
            l_y_temp[i] = o_data[i].y_dest;
		    
            if(~o_data[i].ant) begin
            // 是 normal packet =================================================================================================
               // 记录本地结点
               o_data[i].x_memory[o_data[i].num_memories] = X_LOC;
               o_data[i].y_memory[o_data[i].num_memories] = Y_LOC;
               o_data[i].num_memories = o_data[i].num_memories + 1;
               
               if(X_LOC != o_data[i].x_dest || Y_LOC != o_data[i].y_dest) begin 
               // 未到目的地: 发送 normal packet 给周围路由
                  // 给routing模块发送routing_calculate信号
                  l_routing_calculate[i] = 1'b1;

               end else begin
               // 到达目的地: 发送 normal packet 给PE结点
                  // 直接输出req = 10000
                  l_output_req[i] = 5'b10000;
               end
            end else begin
            // 是 ant packet ====================================================================================================
               if(~o_data[i].backward) begin
	          // 是 forward ant packet ---------------------------------------------------------------------------------
                  // 记录本地结点
                  o_data[i].x_memory[o_data[i].num_memories] = X_LOC;
                  o_data[i].y_memory[o_data[i].num_memories] = Y_LOC;
                  o_data[i].num_memories = o_data[i].num_memories + 1;
                     
                  if(X_LOC != o_data[i].x_dest || Y_LOC != o_data[i].y_dest) begin
               // 未到目的地: 发送 normal packet 给周围路由
                  // 给routing模块发送routing_calculate信号
                     l_routing_calculate[i] = 1'b1;
                  end else begin
                  // 到达目的地: 将 forward 转为 backward ant packet，并 发送
				         
                     // 将 ant packet 从 forward 转为 backward 
                     o_data[i].backward = 1'b1;
                     l_x_temp[i] = o_data[i].x_dest;
                     l_y_temp[i] = o_data[i].y_dest;
				         
                     o_data[i].x_dest = o_data[i].x_source;
                     o_data[i].y_dest = o_data[i].y_source;
				         
                     o_data[i].x_source = l_x_temp[i];
                     o_data[i].y_source = l_y_temp[i];
	                  
                     // 发送 backward
                     if(o_data[i].x_dest != X_LOC || o_data[i].y_dest != Y_LOC) begin
                        // 记录本地结点（返回路径）
                        o_data[i].b_x_memory[o_data[i].b_num_memories] = X_LOC;
                        o_data[i].b_y_memory[o_data[i].b_num_memories] = Y_LOC;
                        o_data[i].b_num_memories = o_data[i].b_num_memories + 1;
							
                        if(o_data[i].x_memory[o_data[i].num_memories-2] != X_LOC)begin
                           l_output_req[i] = (o_data[i].x_memory[o_data[i].num_memories-2] > X_LOC) ? 5'b00100 : 5'b00001;//2 : 4;
                        end else begin//(o_data[i].y_memory[o_data[i].num_memories-2] != Y_LOC)
                           l_output_req[i] = (o_data[i].y_memory[o_data[i].num_memories-2] > Y_LOC) ? 5'b01000 : 5'b00010;//1 : 3;
								end
                     end else begin
                        l_output_req[i] = 5'b10000;
                     end
                  end
               end else begin
                  // 是 backward ant packet	---------------------------------------------------------------------------------
                  // 记录本地结点（返回路径）（debug）
                  o_data[i].b_x_memory[o_data[i].b_num_memories] = X_LOC;
                  o_data[i].b_y_memory[o_data[i].b_num_memories] = Y_LOC;
                  o_data[i].b_num_memories = o_data[i].b_num_memories + 1;
                  
                  if(o_data[i].x_source != X_LOC || o_data[i].y_source != Y_LOC) begin
                  // 更新 信息素表
                     l_update[i] = 1'b1;
                  end
                  if(o_data[i].x_dest != X_LOC || o_data[i].y_dest != Y_LOC) begin
                  // 未到目的地（返回源点）: 发送 backward
                     for(int m = 1;m < o_data[i].num_memories; m++) begin
                        if(o_data[i].x_memory[m] == X_LOC && o_data[i].y_memory[m] == Y_LOC) begin
                           if(o_data[i].x_memory[m-1] != X_LOC) begin
                              l_output_req[i] = (o_data[i].x_memory[m-1] > X_LOC) ? 5'b00100 : 5'b00001;//2 : 4;
                           end else begin
                              l_output_req[i] = (o_data[i].y_memory[m-1] > Y_LOC) ? 5'b01000 : 5'b00010;//1 : 3;
									end
                        end
                     end
                  end else begin
                  // 到达目的地（返回源点）: 
                     // 直接输出req = 10000
                     l_output_req[i] = 5'b10000;
                  end
               end // if(~o_data[i].backward)
            end // if(~o_data[i].ant)
				
            o_data_val[i] = 1'b1; // 有数据输入，就有数据要输出
         end // if(i_data_val[i])
      end // for()
   end // always_comb  
   
   always_comb begin
      for(int i=0;i<`N;i++)begin
         o_output_req[i]= (l_select_neighbor[i]==1) ? select_o_output_req[i] : l_output_req[i];
      end
   end

endmodule
