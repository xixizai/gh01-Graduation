`include "config.sv"
// Switch Control receives N, M-bit words, each word corresponds to an input, each bit corresponds to the requested
   // output.  This is combined with the enable signal from the downstream router, then arbitrated.  The result is
   // M, N-bit words each word corresponding to an output, each bit corresponding to an input (note the transposition).
// 交换控制。分配输入输出信道？分配交换机？
module switch_control
(
   input logic clk,
   input logic ce,
   input logic reset_n,
   
   input logic [0:`M-1] i_en,            // 输入，对应的下游路由结点的使能信号（有空闲）
   input logic [0:`N-1][0:`M-1] i_output_req, // 输入，N个本地的输入单元对M个输出端口的请求情况
   
   output logic [0:`M-1][0:`N-1] o_output_grant, // 输出，M个输出端口分别对N个输入端口的请求作出的应答， -> switch模块
   output logic [0:`N-1] o_input_grant,          // 输出，fifo模块的输出使能信号， -> fifo模块

   output logic [0:`N-1][0:`M-1] test_l_req_matrix_SC 
);

   logic [0:`N-1][0:`M-1] l_req_matrix; // N Packed requests for M available output ports

   assign test_l_req_matrix_SC = l_req_matrix;
   
   // Each input can only request a single output, only need to arbitrate for the output 
   // port. The input 'output_req' is N, M-bit words.  Each word corresponds to an input port, each bit corresponds to 
   // the requested output port.  This is transposed so that each word corresponds to an output port, and each bit 
   // corresponds to an input that requested it.  This also ensures that output port requests will not be made if the 
   // corresponding output enable is low.  This is then fed into M round robin arbiters.
   // ----------------------------------------------------------------------------------------------------------------
   always_comb begin
      l_req_matrix = '0;
      for (int i=0; i<`M; i++) begin
         for (int j=0; j<`N; j++) begin
            l_req_matrix[i][j] = i_output_req[j][i] && i_en[i];
         end
      end
   end
   
   generate
      genvar i;
      for (i=0; i<`M; i++) begin : output_ports
         ppe_roundrobin #(.N(`N)) 
            gen_ppe_roundrobin (
                                .clk(clk),
                                .ce(ce),
                                .reset_n(reset_n),
                                
                                .i_request(l_req_matrix[i]),
                                .o_grant(o_output_grant[i])
                               );
      end
   endgenerate
   
   // indicate to input FIFOs, according to arbitration results, that data will be read. Enable is high if any of the 
   // output_grants indicate they have accepted an input.  This creates one N bit word, which is the logical 'or' of
   // all the output_grants, as each output_grant is an N-bit onehot vector representing a granted input.
   // ----------------------------------------------------------------------------------------------------------------
   always_comb begin
      o_input_grant = '0;
      for(int i=0; i<`N; i++) begin
         o_input_grant = o_input_grant | o_output_grant[i];
      end
   end 
   
endmodule
