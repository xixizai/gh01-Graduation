`include "config.sv"

// 同步时序逻辑，使用存储阵列缓存由网络仿真框架生成特定的数据包类型。内存中每个单元都关联读和写两种指针，以控制内存的读写。每个指针用一位的二进制数表示，同一时刻读指针和写指针都只有一个能为高位。通过读、写请求，读写指针的高位在内存单元间轮转，使得同一时刻只有一个单元可读和一个可写。并向上游路由结点发送缓存是否已满的信号。
module fifo_packet
#(
  parameter DEPTH = `INPUT_QUEUE_DEPTH // 缓存队列深度
)
 (
  input logic clk,
  input logic ce,
  input logic reset_n,

  input packet_t i_data, // 输入，需存入FIFO的packet_t结构的数据
  input logic i_data_val, // 指出i_data端口是否有数据输入，当i_data_val=1时，表示有数据输入
  input logic i_en, // 输入，数据输出端口（o_data） 的使能信号，控制数据的输出，当一个时钟上升沿来临时，若使能信号为高，则允许数据输出

  output packet_t o_data, // 输出，需从FIFO发送的packet_t结构的数据
  output logic o_data_val, // 指出是否有数据要从o_data端口输出，当o_data_val=1时，表示有数据输出 Validates the data on o_data, held high until input enable received
  output logic o_en // 输出，数据输入端口（i_data） 的使能信号，表示缓存队列是否有空闲，若使能信号为高，则表示输入的数据可以被写入内存 Outputs an enable, if high, i_data is written to memory
);
  
   typedef struct{logic rd_ptr, wr_ptr;} ptr;//读、写指针结构体
   
   ptr l_mem_ptr [DEPTH-1:0];
   packet_t l_mem [DEPTH-1:0];// fifo内 存储数据的 内存（memory）空间
   
   logic l_full;//memory满时 =1
   logic l_empty;//memory空时 =1
   logic l_near_empty;//memory只剩1个数据时 =1
   
   always_ff@(posedge clk) begin
      if(~reset_n) begin//复位
         for(int i=0; i<DEPTH; i++) begin
            l_mem[i] <= 0;//清空
         end
         l_mem_ptr[0].rd_ptr <= 1;//将 读指针的高位 指向坐标0
         l_mem_ptr[0].wr_ptr <= 1;//将 写指针的高位 指向坐标0
         for(int i=1; i<DEPTH; i++) begin
            l_mem_ptr[i].rd_ptr <= 0;
            l_mem_ptr[i].wr_ptr <= 0;
         end
         o_data <= 0;
         
         l_full <= 0;//非满
         l_empty <= 1;//是空
      end else begin
         if(ce) begin
            // 写内存 -------------------------------------------------------------------------------------------------------------
            if(i_data_val && ~l_full) begin//有数据输入 && 非 满
               // 将输入数据写到写指针指向的内存位置
               for(int i=0; i<DEPTH; i++) begin
                  l_mem[i] <= l_mem_ptr[i].wr_ptr ? i_data : l_mem[i];
               end
               // 将 写指针高位 移到下一位 
               for(int i=0; i<DEPTH-1; i++) begin
                  l_mem_ptr[i+1].wr_ptr <= l_mem_ptr[i].wr_ptr;
               end
               l_mem_ptr[0].wr_ptr <= l_mem_ptr[DEPTH-1].wr_ptr;
            end

            //（读内存）输出 --------------------------------------------------------------------------------------------------------
            if(i_en && ~l_empty) begin
            // 允许输出 && 非 空 -------------------------------------------------------------------------
               // 数据已经从内存被读出，Data was read from memory so the next data needs loading into the output.
               if(l_near_empty) begin//快 空
                  // Next memory location is currently empty,
                  if(i_data_val) begin//有数据输入
                     // New data is being loaded
                     o_data <= i_data;//为什么是 将输入数据直接传给输出？还剩的那个数据不需要输出么。。。。
                  end else begin
                     // FIFO has emptied
                     o_data <= o_data;//保持输出不变？
                  end
               end else begin//非 快 空
                  // Next memory location already contains next data
                  for(int i=0; i<DEPTH; i++) begin
                     if (l_mem_ptr[i].rd_ptr) begin//将读指针的下一位输出！
                        if(i<DEPTH-1) begin
                           o_data <= l_mem[i+1];
                        end else begin
                           o_data <= l_mem[0];
                        end
                     end
                  end
               end

               // 将 读指针高位 移到下一位 
               for(int i=0; i<DEPTH-1; i++) begin
                  l_mem_ptr[i+1].rd_ptr <= l_mem_ptr[i].rd_ptr;
               end
               l_mem_ptr[0].rd_ptr <= l_mem_ptr[DEPTH-1].rd_ptr;

            end else if(l_empty && i_data_val) begin
            // 是 空 && 有数据输入
               // 数据被写入空内存，输出应该被立即更新
               o_data <= i_data;// 输入的数据直接保存到输出端口？
            end else begin
               // Data was not read from memory, the output currently holds a valid packet, keep output data the same.
               for(int i=0; i<DEPTH; i++) begin
                  if(l_mem_ptr[i].rd_ptr) o_data <= l_mem[i];//将 读指针高位的数据 保存到输出端口
               end
            end
            
            // Full Flag.
            // ------------------------------------------------------------------------------------------------------------
            if (~l_full) begin//若 非满
               if(i_data_val && ~i_en) begin//有数据输入 && 不允许输出
                  for(int i=0; i<DEPTH; i++) begin
                     if(l_mem_ptr[i].wr_ptr) begin//若可写位置下一位就是可读，说明此clk后memory将满
                        l_full <= (i<DEPTH-1) ? l_mem_ptr[i+1].rd_ptr : l_mem_ptr[0].rd_ptr;
                     end
                  end
               end
            end else if (l_full) begin//若 满
               l_full <= (i_en) ? 1'b0 : 1'b1;//若允许输出（要加上且无数据输入吧？），clk后非满，否则，此clk后还是满
            end
            
            // Empty Flag and Output Valid.
            // ------------------------------------------------------------------------------------------------------------
            if (~l_empty) begin//若 非空
               if(~i_data_val && i_en) begin//无数据输入 && 允许输出
                  for(int i=0; i<DEPTH; i++) begin
                     if(l_mem_ptr[i].rd_ptr) begin//若可读位置下一位就是可写，说明此clk后memory将空
                        l_empty <= (i<DEPTH-1) ? l_mem_ptr[i+1].wr_ptr : l_mem_ptr[0].wr_ptr;
                     end
                  end
               end
            end else if (l_empty) begin//若 空
               l_empty <= (i_data_val) ? 1'b0 : 1'b1;//若有数据输入（要加上且不允许输出吧？还是说此刻输入的数据是不会立即被输出的），clk后非空，否则，此clk后还是空
            end
		      
            // Nearly Empty Flag.
            // ------------------------------------------------------------------------------------------------------------
            if (~l_near_empty) begin//若 非 快 空
               if(l_empty) begin//若 空
                  l_near_empty <= (i_data_val) ? 1'b1 : 1'b0;//若有数据输入（要加上且不允许输出吧？还是说此刻输入的数据是不会立即被输出的），clk后是 快 空，否则，此clk后还是非 快 空（是空）
               end else if(~l_empty) begin//若 非空
                  if(~i_data_val && i_en) begin//无数据输入 && 允许输出
                     for(int i=0; i<DEPTH; i++) begin
                        if(l_mem_ptr[i].rd_ptr) begin//若可读位置下两位就是可写，说明此clk后memory将是 快 空
                           if(i<DEPTH-2) begin
                              l_near_empty <= l_mem_ptr[i+2].wr_ptr;
                           end else if(i==DEPTH-2) begin
                              l_near_empty <= l_mem_ptr[0].wr_ptr;
                           end else begin
                              l_near_empty <= l_mem_ptr[1].wr_ptr;
                           end
                        end
                     end
                  end
               end
            end else if(l_near_empty) begin//是 快 空
               l_near_empty <= (i_en ^~ i_data_val) ? 1'b1 : 1'b0;//（若允许输出 && 有数据输入）或者（不允许输出 && 无数据输入），clk后还是 快 空，否则，此clk后非 快 空
            end
         end
      end
   end
   
   // Valid/Enable.  Note, valid is simply the inverse of empty.  Also, enable is simply the inverse of full.
   assign o_data_val = ~l_empty;
   assign o_en = ~l_full;

endmodule
