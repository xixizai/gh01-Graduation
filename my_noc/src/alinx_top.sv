`include "config.sv"

// 生成（还是链接）network模块
module alinx_top(
   input logic clk,
   input logic reset_n,

   output logic [3:0] led
);

   packet_t [0:`NODES-1] i_data; // PE结点 -> network
   logic [0:`NODES-1] i_data_val; // PE结点 -> network
   logic [0:`NODES-1][3:0] o_en; // network -> PE结点

   packet_t [0:`NODES-1] o_data; // network -> PE结点
   logic [0:`NODES-1][3:0] o_data_val; // network -> PE结点
   
   
   // ===================================================== 从子模块引出的变量 =====================================================
	
   logic    [0:`NODES-1][0:`N-1] test_en_SCtoFF;
   // FFtoAA ---------------------------------------------------------------------
   packet_t [0:`NODES-1][0:`N-1] test_data_FFtoAA;
   logic    [0:`NODES-1][0:`N-1] test_data_val_FFtoAA;
   // AAtoSW ---------------------------------------------------------------------
   packet_t [0:`NODES-1][0:`N-1] test_data_AAtoSW;
   // AAtoRC ---------------------------------------------------------------------
   logic    [0:`NODES-1][0:`N-1] test_data_val_AAtoSC;
   // SC.sv ----------------------------------------------------------------------
   logic    [0:`NODES-1][0:`N-1][0:`M-1] test_l_req_matrix_SC;
   // AA.sv ----------------------------------------------------------------------
   logic    [0:`NODES-1][0:`N-1][0:`M-1] test_l_output_req;
   logic    [0:`NODES-1][0:`N-1] test_routing_calculate;
   logic    [0:`NODES-1][0:`N-1] test_update;
   logic    [0:`NODES-1][0:`N-1] test_select_neighbor;
   logic    [0:`NODES-1][0:`N-1][0:`M-1] test_tb_o_output_req;
   // ant_routing_table.sv --------------------------------------------------------
   logic    [0:`NODES-1][0:`NODES-1][0:`N-2][`PH_TABLE_DEPTH-1:0] test_pheromones;
   logic    [0:`NODES-1][0:`N-1][0:`PH_TABLE_DEPTH-1] test_max_pheromone_value;
   logic    [0:`NODES-1][0:`N-1][0:`PH_TABLE_DEPTH-1] test_min_pheromone_value;
   logic [0:`NODES-1][0:`N-1][$clog2(`N)-1:0] test_max_pheromone_column;
   logic [0:`NODES-1][0:`N-1][$clog2(`N)-1:0] test_min_pheromone_column;
   logic    [0:`NODES-1][0:`N-1][0:`M-1][1:0] test_avail_directions;
	
   // ============================================================ network ====================================================
   network network(
                   .clk(clk), 
                   .reset_n(reset_n), 
                   .i_data(i_data), 
                   .i_data_val(i_data_val),
                   .o_en(o_en),
                   .o_data(o_data),
                   .o_data_val(o_data_val),
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
			
endmodule
