`include "config.sv"
//d != LOC时执行
// 通过路由算法，计算出可选择的输出端口队列。路由算法可包括X-Y路由、奇偶转弯模型路由（odd even turn model routing）等，根据具体的路由算法进行路由计算时需要的具体信息条件可再创建更多的输入端口以输入需要的信息。
module routing_xy#(
  parameter integer X_LOC, // 当前结点的X坐标
  parameter integer Y_LOC  // 当前结点的Y坐标
)
(
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

   always_comb begin
	   o_select_neighbor = '0;
      o_avail_directions = '0;
		for(int i=0;i<`N;i++)begin
         if(i_routing_calculate[i]) begin
            if(i_x_dest[i] != X_LOC) begin
               o_avail_directions[i][o_avail_directions[i][`M-1]] = (i_x_dest[i] > X_LOC) ? 2-1 : 4-1; // directions.push_back(DIRECTION_NORTH);
               o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
				   //o_output_req = (i_x_dest > X_LOC) ? 5'b00100 : 5'b00001;
            end else begin//if (i_y_dest[i] != Y_LOC)
				   o_avail_directions[i][o_avail_directions[i][`M-1]] = (i_y_dest[i] > Y_LOC) ? 1-1 : 3-1; // directions.push_back(DIRECTION_NORTH);
               o_avail_directions[i][`M-1] = o_avail_directions[i][`M-1] + 1;
               //o_output_req = (i_y_dest > Y_LOC) ? 5'b01000 : 5'b00010;
				end //else
            //   o_output_req = 5'b10000;
         end
		   o_select_neighbor[i] = 1;
		end
   end
endmodule
