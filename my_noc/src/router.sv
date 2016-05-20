`include "config.sv"

// 路由（router）模块拥有5个输入端口、5个输出端口，分别用于与PE结点、北路由结点、东路由结点、南路由结点、西路由结点链接。
// router模块对应单个路由结点的完整架构，其中包括输入输出缓存（FIFO）模块、数据中间处理（agent）模块、路由计算(routing)模块、选择策略（selection）模块、开关控制(switch control)模块、交换开关（switch one-hot packet）模块。
module router #(
  parameter integer X_LOC, // 当前结点的X坐标
  parameter integer Y_LOC  // 当前结点的Y坐标
)
(
   input logic clk, reset_n,
   
   // Upstream Bus.
   // ------------------------------------------------------------------------------------------------------------------
   input  packet_t [0:`N-1] i_data,  // 输入，数据端口 [local, north, east, south, west]
   input  logic [0:`N-1] i_data_val, // 输入，指出输入端口（i_data）是否有数据输入 [local, north, east, south, west]
   output logic [0:`M-1] o_en,  // 输出，输入端口（i_data）的使能信号 [local, north, east, south, west]
   
   // Downstream Bus
   // ------------------------------------------------------------------------------------------------------------------
   output packet_t [0:`M-1] o_data,  // 输出，数据端口 [local, north, east, south, west]
   output logic [0:`M-1] o_data_val, // 输出，指出输出端口（o_data）是否有数据输出 [local, north, east, south, west]
   input  logic [0:`N-1] i_en,  // 输入，输出端口（o_data）的使能信号 [local, north, east, south, west]
   
   output logic [0:`N-1] test_en_SCtoFF,
   
   output packet_t [0:`N-1] test_data_FFtoAA,
   output logic [0:`N-1] test_data_val_FFtoAA, 
   
   output packet_t [0:`N-1] test_data_AAtoSW,
   
   output logic [0:`N-1][0:`M-1] test_output_req_AAtoSC,
   
   output logic [0:`N-1][0:`M-1] test_l_req_matrix_SC,
   
   output logic [0:`N-1][0:`M-1] test_l_output_req,
   output logic [0:`N-1]test_routing_calculate,
   output logic [0:`N-1]test_update,
   output logic [0:`N-1]test_select_neighbor,
   output logic [0:`N-1][0:`M-1] test_tb_o_output_req,
   
   output logic [0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] test_pheromones,
   output logic [`PH_TABLE_DEPTH-1:0] test_max_pheromone_value,
   output logic [`PH_TABLE_DEPTH-1:0] test_min_pheromone_value,
   output logic [0:`N-1][0:`M-1][1:0] test_avail_directions
);  
  
   // Clock Enable.  For those modules that require it. ------------------------------------------------------------------------------
   logic ce=1'b1;

   // Local Signals ------------------------------------------------------------------------------------------------------------------

   logic [0:`N-1] l_en_SCtoFF; // 控制fifo输出数据的使能信号en, switch -> fifo

   packet_t [0:`N-1] l_data_FFtoAA; // data, fifo -> agent
   packet_t [0:`N-1] l_data_AAtoSW; // data, agent -> switch

   logic [0:`N-1] l_data_val_FFtoAA; // data val, fifo -> agent

   logic [0:`N-1][0:`M-1] l_output_req_AAtoSC; // Request, agent -> switch control
   logic [0:`M-1][0:`N-1] l_output_grant_SCtoSW; // 控制switch输出数据、通知下游路由接收数据的Grant, switch control -> switch 、o_data_val  

   // --------------------------------------------------------------------------------------------------------------------------------

   generate
      genvar i;
      for (i=0; i<`N; i++) begin : input_ports
         fifo_packet #(.DEPTH(`INPUT_QUEUE_DEPTH))
            input_queue(
                        .clk(clk),
                        .ce(ce),
                        .reset_n(reset_n),
                        .i_data(i_data[i]),
                        .i_data_val(i_data_val[i]),
                        .i_en(l_en_SCtoFF[i]),
                        
                        .o_data(l_data_FFtoAA[i]),
                        .o_data_val(l_data_val_FFtoAA[i]),
                        
                        .o_en(o_en[i])
                       );
      end
   endgenerate

   // ant agent will output 5 packed words, each word corresponds to an input, each bit corresponds to the output requested.
   ant_agent #(.X_LOC(X_LOC), .Y_LOC(Y_LOC))
      ant_agent(
		         .reset_n(reset_n),
               .i_en(i_en),
		         .i_data(l_data_FFtoAA), 
		         .i_data_val(l_data_val_FFtoAA),
		         .o_data(l_data_AAtoSW),
					.o_data_val(),
		         .o_output_req(l_output_req_AAtoSC),
		         
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

   // Switch Control receives N, M-bit words, each word corresponds to an input, each bit corresponds to the requested
   // output.  This is combined with the enable signal from the downstream router, then arbitrated.  The result is
   // M, N-bit words each word corresponding to an output, each bit corresponding to an input (note the transposition).
   // ------------------------------------------------------------------------------------------------------------------  
   switch_control
      switch_control(
                     .clk(clk),
                     .ce(ce),
                     .reset_n(reset_n),
                     .i_en(i_en),
                     .i_output_req(l_output_req_AAtoSC), // From the local VCs or Route Calculator
                     .o_output_grant(l_output_grant_SCtoSW), // To the switch, and to the downstream router
                     .o_input_grant(l_en_SCtoFF), // To the local VCs or FIFOs
                     .test_l_req_matrix_SC(test_l_req_matrix_SC)
                    );
 
   // Switch.  Switch uses onehot input from switch control.
   // ------------------------------------------------------------------------------------------------------------------
  
   switch_onehot_packet
      switch(
            .i_sel(l_output_grant_SCtoSW), // From the Switch Control
            .i_data(l_data_AAtoSW),
            .o_data(o_data)
            );
  
   assign test_en_SCtoFF=l_en_SCtoFF;
   
   assign test_data_FFtoAA=l_data_FFtoAA; // Input data from upstream [local, north, east, south, west]
   assign test_data_val_FFtoAA=l_data_val_FFtoAA; // Validates data from upstream [local, north, east, south, west]
   
   assign test_data_AAtoSW=l_data_AAtoSW;
   
   assign test_output_req_AAtoSC=l_output_req_AAtoSC;
   
   // Output to downstream routers that the switch data is valid.  l_output_grant_SCtoSW[output number] is a onehot vector, thus
   // if any of the bits are high the output referenced by [output number] has valid data.
   // ------------------------------------------------------------------------------------------------------------------                      
   always_comb begin
      o_data_val = '0;
      for (int i=0; i<`M; i++) begin  
         o_data_val[i]  = |l_output_grant_SCtoSW[i];
      end
   end 

endmodule
