`include "config.sv"

// N x M packet_t 交换开关（N个输入端口，M个输出端口）。输入端口的选择过程采用one-hot编码，即一位二进制数只对应一个输入端口且同一时刻最多一位为1.
module switch_onehot_packet
(
  input  logic [0:`M-1][0:`N-1] i_sel, // M个输出端口分别对应一个N位（对应N个输入）的数，输出端口可根据自己对应的N位数选择一个输入端口
  input  packet_t [0:`N-1] i_data, // N个数据输入端口

  output packet_t [0:`M-1] o_data // M个数据输出端口
);

   packet_t [0:`M-1] l_data; // 用于流水线
    
   always_comb begin
      l_data = '0;
      for(int i=0; i<`M; i++) begin
         // 比较i_sel[i]的值，以确定哪个输入端口需要从第i输出端口输出
         for(int j=0; j<`N; j++) begin
            if(i_sel[i] == (1<<(`N-1)-j)) l_data[i] = i_data[j];
         end
      end
   end

   // 流水线控制
   assign o_data = l_data;

endmodule
