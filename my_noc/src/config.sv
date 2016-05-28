`define X_NODES 4 // k(x,y)-ary.  结点的列数  (必须 > 0)
`define Y_NODES 4 // k(x,y)-ary.  结点的行数 (必须 > 0)
`define NODES `X_NODES * `Y_NODES // 总共的结点数

`define INPUT_QUEUE_DEPTH 8 // 输入缓存队列的深度
`define N 5 // 输入端口的数目
`define M `N // 输出端口的数目

`define TIME_STAMP_SIZE 32 // 时间戳变量的位宽
`define PH_TABLE_DEPTH 4 // 信息素表中值的位宽
`define PH_MIN_VALUE 0 // 信息素表中值的最小值
`define PH_MAX_VALUE 4'b1111 // 信息素表中的最大值

`define CREATE_ANT_PERIOD 1 // 创建 ant packet 的周期
`define warmup_packets_num 1000 // 仿真中warmup阶段要发送的数据包数目

//`define routing_type_num = 2'b01
//`define traffic_type_num = 2'b10

// 网络中数据包的格式设计
typedef struct packed {
   logic [7:0] id; // 仿真时记录packet id
	
   logic [$clog2(`X_NODES)-1:0] x_source;
   logic [$clog2(`Y_NODES)-1:0] y_source;   
   logic [$clog2(`X_NODES)-1:0] x_dest;
   logic [$clog2(`Y_NODES)-1:0] y_dest;
	
   logic ant; // 标记包的类型: 1: ant packet; 0: normal packet.
   logic backward; // 标记ant包的类型（仅为ant包时有效）: 1: backward packet; 0: forward packet.
	
   logic [0:`NODES-1][$clog2(`X_NODES)-1:0] x_memory; // 包走过的路径队列（X坐标）
   logic [0:`NODES-1][$clog2(`Y_NODES)-1:0] y_memory; // 包走过的路径队列（Y坐标）
   logic [$clog2(`NODES)-1:0] num_memories; // memory中记录的路径的结点数目
	
   logic [0:`NODES-1][$clog2(`X_NODES)-1:0] b_x_memory; // ant包在返回时 走过的路径队列（X坐标）
   logic [0:`NODES-1][$clog2(`Y_NODES)-1:0] b_y_memory; // ant包在返回时 走过的路径队列（X坐标）
   logic [$clog2(`NODES)-1:0] b_num_memories; // b_memory中记录的返回路径的结点数目（仅为ant包时有效）
	
   logic measure; // 在仿真时记录测试状态
   logic [`TIME_STAMP_SIZE-1:0] timestamp; // 记录数据包进入网络时的时间
} packet_t;
