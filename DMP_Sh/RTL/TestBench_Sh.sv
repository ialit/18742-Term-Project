/******************************************************************************
Test Bench for testing DMP shared
*******************************************************************************/
module TestBench_Sh();
    //Circuit inputs
    logic clock;
    logic reset_n;
    logic pagerank_enable;

    //Graph Inputs
    logic [31:0] source_id [NUM_HW_THREADS][NODES_IN_PARTITION];
    logic [31:0] out_degree [NUM_HW_THREADS][NODES_IN_PARTITION];
    logic [31:0] dest_id [NUM_HW_THREADS][NODES_IN_PARTITION][STREAM_SIZE];

    //Pagerank Inputs
    real damping_factor;
    real threshold;
    
    //Output
    real pagerank[NODES_IN_GRAPH];
    logic pagerank_complete;
	
	//DMP signals
    logic [31:0] sharing_structure [NUM_HW_THREADS][MAX_PARTITION_SIZE];
    logic [31:0] num_nodes[NUM_HW_THREADS];
	
	int NUM_HW_THREADS; //Should be same as number of partitions
    int NODES_IN_PARTITION; 
	int MAX_PARTITION_SIZE;
    int NODES_IN_GRAPH;
    int STREAM_SIZE;
	
	pagerank_DMP_Sh obj 
	#(NUM_HW_THREADS, NODES_IN_GRAPH, 
	  NODES_IN_PARTITION,
	  MAX_PARTITION_SIZE, STREAM_SIZE);
	(.clock(clock), .reset_n(reset_n), 
	 .pagerank_enable(pagerank_enable)
	 
	 .source_id(source_id), .out_degree(out_degree),
	 .dest_id(dest_id),
	 
	 .sharing_structure(sharing_structure), 
	 .num_nodes(num_nodes),
	 
	 .damping_factor(damping_factor),
	 .threshold(threshold)
	);
	
	initial begin
		#5 clock = ~clock; 
	end
	
	initial begin
		NUM_HW_THREADS = 7;
		NODES_IN_PARTITION = 3;
		MAX_PARTITION_SIZE = 3;
	    NODES_IN_GRAPH = 20;
		STREAM_SIZE = 3;
		
		clock = 0;
		reset_n = 1;
		#1 reset_n = 0;
		#1 reset_n = 1;
		
		pagerank_enable <= 1;
		source_id <= {{0,1,2},{3,4,5},{6,8,10},{7,9,11},{12,13,14},{15,16,17},{18,19,20}};
		out_degree <= {{3,2,2}, {2,1,2},{2,2,1},{2,2,1},{1,1,1},{2,1,1},{1,0,0}};
		dest_id <= {{{1,4,5},{2,6,0},{3,7,0}},{{9,0,0},{10,11,0},{10,14,0}},{{10,14,0},{12,13,0},{15,0,0}},
		{{13,14,0},{11,12,0},{16,0,0}},{{17,0,0},{18,0,0},{19,0,0}},{{16,19,0},{17,0,0},{18,0,0}},{{19,0,0},{0,0,0},{0,0,0}};
		
		sharing_structure <= {{0,1,2},{3,4,5},{6,8,10},{7,9,11},{12,13,14},{15,16,17},{18,19,20}};
		num_nodes <= {3,3,3,3,3,3,3};
		
		damping_factor <= 0.15;
		threshold <= 0.001;
		
		wait (pagerank_complete === 1);
		
	end
endmodule


