`include "config.sv"
//d != LOC时执行
// 通过路由算法，计算出可选择的输出端口队列。路由算法可包括X-Y路由、奇偶转弯模型路由（odd even turn model routing）等，根据具体的路由算法进行路由计算时需要的具体信息条件可再创建更多的输入端口以输入需要的信息。
module routing_odd_even#(
  parameter integer X_LOC, // 当前结点的X坐标
  parameter integer Y_LOC, // 当前结点的Y坐标
  
  parameter integer routing_type = 2 //0:nothing   1:xy   2:odd even
)(
  input logic [0:`N-1] i_routing_calculate,             // 输入，路由计算使能信号
  input logic [0:`N-1][$clog2(`X_NODES)-1:0] i_x_source,// 输入，数据包源的信息（x坐标）
  input logic [0:`N-1][$clog2(`X_NODES)-1:0] i_x_dest,  // 输入，数据包的目的地信息（x坐标）
  input logic [0:`N-1][$clog2(`Y_NODES)-1:0] i_y_dest,  // 输入，数据包的目的地信息（y坐标）
  
  output logic [0:`N-1] o_select_neighbor,              // 输出，选择功能使能信号，-> selection 模块
  output logic [0:`N-1][0:`M-1][1:0] o_avail_directions // 输出，可选择的输出端口队列，-> selection 模块
                                                        // o_avail_directions[]队列 最后一个数，存放当前队列中的可选个数
  // One-hot request for the [local, north, east, south, west] output port
  //     1
  //   4 0 2
  //     3
);

   //logic [0:`N-1][$clog2(`X_NODES)-1:0] e0;
   //logic [0:`N-1][$clog2(`Y_NODES)-1:0] e1;

   always_comb begin
      o_select_neighbor = 5'b0;
      o_avail_directions = '0;
	   if(routing_type == 1)begin
			// XY路由
			for(int i=0;i<`N;i++)begin
				if(i_routing_calculate[i]) begin
					if(i_x_dest[i] != X_LOC) begin
						o_avail_directions[i][o_avail_directions[i][`M-1]] = (i_x_dest[i] > X_LOC) ? 2-1 : 4-1;//directions.push_back(DIRECTION_NORTH);
						o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
					end else if (i_y_dest[i] != Y_LOC)begin
						o_avail_directions[i][o_avail_directions[i][`M-1]] = (i_y_dest[i] > Y_LOC) ? 1-1 : 3-1;//directions.push_back(DIRECTION_NORTH);
						o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
					end //else o_output_req = 5'b10000;
					o_select_neighbor[i] = 1;
				end // if(i_routing_calculate[i])
			end // for
		end else begin
			// odd even路由
			for(int i=0;i<`N;i++)begin
				//e0[i] = i_x_dest[i] - X_LOC;
				//e1[i] = i_y_dest[i] - Y_LOC;
				if(i_routing_calculate[i])begin
					if(i_x_dest[i] == X_LOC) begin // x坐标到达目的地
						if(i_y_dest[i] > Y_LOC) begin // if（目的地y坐标 > 当前坐标）
							o_avail_directions[i][o_avail_directions[i][`M-1]] = 1-1; // directions.push_back(DIRECTION_NORTH);
							o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
						end else begin // else（目的地y坐标 < 当前坐标）
							o_avail_directions[i][o_avail_directions[i][`M-1]] = 3-1; // directions.push_back(DIRECTION_SOUTH);
							o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
						end
					end else begin
						if(i_x_dest[i] > X_LOC) begin // if（目的地x坐标 > 当前坐标）
							if(i_y_dest[i] == Y_LOC) begin // if（目的地y坐标 == 当前坐标）
								o_avail_directions[i][o_avail_directions[i][`M-1]] = 2-1; // directions.push_back(DIRECTION_EAST);
								o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
							end else begin
								if((X_LOC % 2 == 1) || (X_LOC == i_x_source[i])) begin // if（当前x坐标为奇 或 当前x坐标==源点x坐标）
									if(i_y_dest[i] > Y_LOC) begin // if（目的地y坐标 > 当前坐标）
										o_avail_directions[i][o_avail_directions[i][`M-1]] = 1-1; // directions.push_back(DIRECTION_NORTH);
										o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
									end else begin // else（目的地y坐标 < 当前坐标）
										o_avail_directions[i][o_avail_directions[i][`M-1]] = 3-1; // directions.push_back(DIRECTION_SOUTH);
										o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
									end
								end
								if((i_x_dest[i] % 2 == 1) || ((i_x_dest[i] - X_LOC != 1) && (X_LOC - i_x_dest[i] != 1))) begin
									o_avail_directions[i][o_avail_directions[i][`M-1]] = 2-1; // directions.push_back(DIRECTION_EAST);
									o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
								end
							end
						end else begin// else（目的地x坐标 < 当前坐标）
							o_avail_directions[i][o_avail_directions[i][`M-1]] = 4-1; // directions.push_back(DIRECTION_WEST);
							o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
							if(X_LOC % 2 == 0) begin // if（当前x坐标为偶)
								if(i_y_dest[i] > Y_LOC) begin // if（目的地y坐标 > 当前坐标）
									o_avail_directions[i][o_avail_directions[i][`M-1]] = 1-1; // directions.push_back(DIRECTION_NORTH);
									o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
								end
								if(i_y_dest[i] < Y_LOC) begin // if（目的地y坐标 < 当前坐标）
									o_avail_directions[i][o_avail_directions[i][`M-1]] = 3-1; // directions.push_back(DIRECTION_SOUTH);
									o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
								end
							end
						end
					end
					o_select_neighbor[i] = 1; // routing calculate 结束就发送 select信号
				end // if(i_routing_calculate[i])
			end // for
		end
   end // always_comb

endmodule
