`define X_NODES 4 // k(x,y)-ary.  Number of node columns  (must be > 0)
`define Y_NODES 4 // k(x,y)-ary.  Number of node rows (must be > 0)
`define NODES `X_NODES * `Y_NODES // Total number of nodes

`define INPUT_QUEUE_DEPTH 4 // Globally set packet depth for input queues
`define N 5 // input ports
`define M `N // output ports

`define TIME_STAMP_SIZE 32 // Size of timestamp variable
`define PH_TABLE_DEPTH 4 // Depth for pheromone table rows
`define PH_MIN_VALUE `PH_TABLE_DEPTH'b0 // Min pheromone value in
`define PH_MAX_VALUE `PH_TABLE_DEPTH'b1111

`define CREATE_ANT_PERIOD 100 // Create ant packet in erver 100 period
`define warmup_packets_num 1000

 // Network packet type for simple addressed designs
typedef struct packed {
    logic [7:0] id; // Record packet's id in simulation
	 
    logic [$clog2(`X_NODES)-1:0] x_source;
    logic [$clog2(`Y_NODES)-1:0] y_source;   
    logic [$clog2(`X_NODES)-1:0] x_dest;
    logic [$clog2(`Y_NODES)-1:0] y_dest;
	 
	 logic ant; // Packet's type: 1:ant packet;0:normal packet.
	 logic backward; // Ant packet's type: 1:backward packet;0:forward packet.
	 
    logic [0:`NODES-1][$clog2(`X_NODES)-1:0] x_memory; // Queues for forward ant packet's path(value of X)
    logic [0:`NODES-1][$clog2(`Y_NODES)-1:0] y_memory; // Queues for forward ant packet's path(value of Y)
	 logic [$clog2(`NODES)-1:0] num_memories; // Number of nodes in path
	 
    logic [0:`NODES-1][$clog2(`X_NODES)-1:0] b_x_memory; // Queues for backward ant packet's path(value of X)
    logic [0:`NODES-1][$clog2(`Y_NODES)-1:0] b_y_memory; // Queues for backward ant packet's path(value of Y)
	 logic [$clog2(`NODES)-1:0] b_num_memories; // Number of nodes in backward path
	 
	 logic measure; // Record the state of packet in simulation.
	 logic [`TIME_STAMP_SIZE-1:0] timestamp; // Record the time when packet enter into network in simulation.
} packet_t;
/*FYI.

[2016-04-26 10:45:11] INFO - Overall:
[2016-04-26 10:45:11] INFO -     # Total cycles: 435
[2016-04-26 10:45:11] INFO -
[2016-04-26 10:45:11] INFO -     # Packets received: 145, # packets transmitted: 145
[2016-04-26 10:45:11] INFO -     Throughput: 0.333333 packets/cycle
[2016-04-26 10:45:11] INFO -     Average packet latency: 118.937931 cycles/packet
[2016-04-26 10:45:11] INFO -     Max packet latency: 314.000000 cycles/packet
[2016-04-26 10:45:11] INFO -
[2016-04-26 10:45:11] INFO - ACOPacket:
[2016-04-26 10:45:11] INFO -     # Packets received: 96, # packets transmitted: 96
[2016-04-26 10:45:11] INFO -     Throughput: 0.220690 packets/cycle
[2016-04-26 10:45:11] INFO -     Average packet latency: 76.517241 cycles/packet
[2016-04-26 10:45:11] INFO -     Max packet latency: 314.000000 cycles/packet
[2016-04-26 10:45:11] INFO -
[2016-04-26 10:45:11] INFO - Packet:
[2016-04-26 10:45:11] INFO -     # Packets received: 49, # packets transmitted: 49
[2016-04-26 10:45:11] INFO -     Throughput: 0.112644 packets/cycle
[2016-04-26 10:45:11] INFO -     Average packet latency: 42.420690 cycles/packet
[2016-04-26 10:45:11] INFO -     Max packet latency: 298.000000 cycles/packet

1. add comments
2. the above statistics
3. record each packet (normal packet and ACO packet) 's memory and debug

forward packet 到了也得打出来以下信息：

[<current_cycle>] packet_id: <>, memory: [,,,], timestamp: <>, latency: <>*/