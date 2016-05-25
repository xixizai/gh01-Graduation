`include "config.sv"

// 路由网络(network)基于2D-mesh拓扑结构，定义了PE结点和路由结点之间的网络连接。

// 每个PE结点（nodes）都拥有一个路由器（router），且PE结点只能和自己的路由器进行直接交流，而路由结点不仅可与PE结点进行通信，还可与符合条件的其它路由结点进行通信，因此，PE结点间只能通过路由结点组成的路由网络进行通信。

// 每个路由结点（router）都有5个输入输出端口，其中一个端口链接PE结点，其余的端口链接周围的路由器。通过 router[结点号i][输入输出端口号j] 结构 表示第i个路由结点第j个端口的输入输出，其中，j=0表示与PE结点链接的端口、j=1表示与北路由链接的端口、j=2表示与东路由链接的端口、j=3表示与南路由链接的端口、j=4表示与西路由链接的端口。

// 2D-mesh拓扑结构的一个例子（4x4）:
   // 12 13 14 15
   // 08 09 10 11
   // 04 05 06 07
   // 00 01 02 03

module network
(
   input logic clk, reset_n,
   
   input packet_t [0:`NODES-1] i_data,  // 输入，PE结点 -> network
   input logic [0:`NODES-1] i_data_val, // 输入，指出输入端口（i_data）是否有数据输入
   
   output packet_t [0:`NODES-1] o_data,  // 输出，network -> PE结点
   output logic [0:`NODES-1] o_data_val, // 输出，指出输出端口（o_data）是否有数据输出
   output logic [0:`NODES-1][3:0] o_en,      // 输出，输入端口（i_data）的使能信号
   
   output logic [0:`NODES-1][0:`N-1] test_en_SCtoFF,
   
   output packet_t [0:`NODES-1][0:`N-1] test_data_FFtoAA,
   output logic [0:`NODES-1][0:`N-1] test_data_val_FFtoAA,
   
   output packet_t [0:`NODES-1][0:`N-1] test_data_AAtoSW,
   
   output logic [0:`NODES-1][0:`N-1][0:`M-1] test_output_req_AAtoSC,
   
   output logic [0:`NODES-1][0:`N-1][0:`M-1] test_l_req_matrix_SC,
   
   output logic [0:`NODES-1][0:`N-1][0:`M-1] test_l_output_req,
   output logic [0:`NODES-1][0:`N-1] test_routing_calculate,
   output logic [0:`NODES-1][0:`N-1] test_update,
   output logic [0:`NODES-1][0:`N-1] test_select_neighbor,
   output logic [0:`NODES-1][0:`N-1][0:`M-1] test_tb_o_output_req,
   
   output logic [0:`NODES-1][0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] test_pheromones,
   output logic [0:`NODES-1][0:`N-1][`PH_TABLE_DEPTH-1:0] test_max_pheromone_value,
   output logic [0:`NODES-1][0:`N-1][`PH_TABLE_DEPTH-1:0] test_min_pheromone_value,
  output logic [0:`NODES-1][0:`N-1][$clog2(`N)-1:0] test_max_pheromone_column,
  output logic [0:`NODES-1][0:`N-1][$clog2(`N)-1:0] test_min_pheromone_column,
   output logic [0:`NODES-1][0:`N-1][0:`M-1][1:0] test_avail_directions
);
   
   // Network connections from which routers will read
   packet_t [0:`NODES-1][0:`N-1] l_datain;
   logic [0:`NODES-1][0:`N-1] l_datain_val;
   logic [0:`NODES-1][0:`N-1][3:0] l_o_en;
   
   // Network connections to which routers will write
   packet_t [0:`NODES-1][0:`M-1] l_dataout;
   logic [0:`NODES-1][0:`M-1] l_dataout_val;
   logic [0:`NODES-1][0:`M-1][3:0] l_i_en;

   always_comb begin
      for(int i=0; i<`NODES; i++) begin
         // 传递，从 当地PE结点 和 上游router 的 输出数据 -> router[i]
         l_datain[i][0] = i_data[i];                                                 // 当地PE结点 -> router[i][0]
         l_datain[i][1] = i < `X_NODES*(`Y_NODES-1) ? l_dataout[i+`X_NODES][3] : '0; // 北路由 -> router[i][1]
         l_datain[i][2] = (i + 1) % `X_NODES == 0 ? '0 : l_dataout[i+1][4];          // 东路由 -> router[i][2]
         l_datain[i][3] = i > (`X_NODES-1) ? l_dataout[i-`X_NODES][1] : '0;          // 南路由 -> router[i][3]
         l_datain[i][4] = i % `X_NODES == 0 ? '0 : l_dataout[i-1][2];                // 西路由 -> router[i][4]
         
         // 传递，从 当地PE结点 和 上游router 的'data valid'信号 -> router[i]
         l_datain_val[i][0] = i_data_val[i];                                                 // 当地PE结点 -> router[i][0]
         l_datain_val[i][1] = i < `X_NODES*(`Y_NODES-1) ? l_dataout_val[i+`X_NODES][3] : '0; // 北路由 -> router[i][1]
         l_datain_val[i][2] = (i + 1)% `X_NODES == 0 ? '0 : l_dataout_val[i+1][4];           // 东路由 -> router[i][2]
         l_datain_val[i][3] = i > (`X_NODES-1) ? l_dataout_val[i-`X_NODES][1] : '0;          // 南路由 -> router[i][3]
         l_datain_val[i][4] = i % `X_NODES == 0 ? '0 : l_dataout_val[i-1][2];                // 西路由 -> router[i][4]
         
         // 传递，从 当地PE结点 和 下游router 的输入使能信号 -> router[i]
         l_i_en[i][0] = 4'b1;                                                     // 当地PE结点 -> router[i][0]
         l_i_en[i][1] = i < `X_NODES*(`Y_NODES-1) ? l_o_en[i+`X_NODES][3] : '0; // 北路由 -> router[i][1]
         l_i_en[i][2] = (i + 1) % `X_NODES == 0 ? '0 : l_o_en[i+1][4];          // 东路由 -> router[i][2]
         l_i_en[i][3] = i > (`X_NODES-1) ? l_o_en[i-`X_NODES][1] : '0;          // 南路由 -> router[i][3]
         l_i_en[i][4] = (i % `X_NODES) == 0 ? '0 : l_o_en[i-1][2];              // 西路由 -> router[i][4]
         
         // 传递，从 router[i] -> PE结点
         o_data[i] = l_dataout[i][0];
         o_data_val[i] = l_dataout_val[i][0];
         o_en[i] = l_o_en[i][0];
      end
   end
  
   // Generate Routers
   // ------------------------------------------------------------------------------------------------------------------
   generate
      genvar y, x;
      for (y=0; y<`Y_NODES; y++) begin : rows
         for(x=0; x<`X_NODES; x++) begin : cols
            router #(.X_LOC(x),.Y_LOC(y))
               router (
                       .clk(clk),
                       .reset_n(reset_n),
                       .i_en(l_i_en[y*`X_NODES+x]),
                       .i_data(l_datain[y*`X_NODES+x]), 
                       .i_data_val(l_datain_val[y*`X_NODES+x]), 
                       .o_en(l_o_en[y*`X_NODES+x]), 
                       .o_data(l_dataout[y*`X_NODES+x]), 
                       .o_data_val(l_dataout_val[y*`X_NODES+x]), 
                       
                       .test_en_SCtoFF(test_en_SCtoFF[y*`X_NODES+x]),
                       
                       .test_data_FFtoAA(test_data_FFtoAA[y*`X_NODES+x]),
                       .test_data_val_FFtoAA(test_data_val_FFtoAA[y*`X_NODES+x]), 
                       
                       .test_data_AAtoSW(test_data_AAtoSW[y*`X_NODES+x]),
                       
                       .test_output_req_AAtoSC(test_output_req_AAtoSC[y*`X_NODES+x]),
                       
                       .test_l_req_matrix_SC(test_l_req_matrix_SC[y*`X_NODES+x]),
                       
                       
		                 .test_l_output_req(test_l_output_req[y*`X_NODES+x]),
                       .test_routing_calculate(test_routing_calculate[y*`X_NODES+x]),
                       .test_update(test_update[y*`X_NODES+x]),
                       .test_select_neighbor(test_select_neighbor[y*`X_NODES+x]),
                       .test_tb_o_output_req(test_tb_o_output_req[y*`X_NODES+x]),
                       
                       .test_pheromones(test_pheromones[y*`X_NODES+x]),
                       .test_max_pheromone_value(test_max_pheromone_value[y*`X_NODES+x]),
                       .test_min_pheromone_value(test_min_pheromone_value[y*`X_NODES+x]),
  .test_max_pheromone_column(test_max_pheromone_column[y*`X_NODES+x]),
  .test_min_pheromone_column(test_min_pheromone_column[y*`X_NODES+x]),
                       .test_avail_directions(test_avail_directions[y*`X_NODES+x])
                      );
         end
      end
   endgenerate
endmodule
