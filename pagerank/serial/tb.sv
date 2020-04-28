/******************************************************************************
Test Bench for testing DMP shared
*******************************************************************************/
module TestBench_Sh();
    //Circuit inputs
    logic clock;
    logic reset_n;
    logic pagerank_enable;

    //Graph Inputs
  logic [31:0] source_id [7][3];
  logic [31:0] out_degree [7][3];
  logic [31:0] dest_id [7][3][3];

    //Pagerank Inputs
    real damping_factor;
    real threshold;
    
    //Output
  real pagerank[20];
    logic pagerank_complete;
	
	//DMP signals
  
  	const int NUM_HW_THREADS = 7;
	const int NODES_IN_PARTITION = 3;
	const int MAX_PARTITION_SIZE = 3;
	const int NODES_IN_GRAPH = 20;
	const int STREAM_SIZE = 3;
	
  pagerank_DMP_serial #(7, 3, 20, 3)
  	obj
	(.clock(clock), .reset_n(reset_n), 
     .pagerank_enable(pagerank_enable),
	 
	 .source_id(source_id), .out_degree(out_degree),
	 .dest_id(dest_id),
	 
	 .damping_factor(damping_factor),
     .threshold(threshold),
     
     .pagerank(pagerank),
     .pagerank_complete(pagerank_complete)
	);
	
	initial begin
		#5 clock = ~clock; 
	end
	
	initial begin
		
		
		clock = 0;
		reset_n = 1;
		#1 reset_n = 0;
		#1 reset_n = 1;
		
		pagerank_enable <= 1;
      source_id = '{'{0,1,2},'{3,4,5},'{6,8,10},'{7,9,11},'{12,13,14},'{15,16,17},'{18,19,20}};
      out_degree = '{'{3,2,2},'{2,1,2},'{2,2,1},'{2,2,1},'{1,1,1},'{2,1,1},'{1,0,0}};
      dest_id = '{'{'{1,4,5},'{2,6,0},'{3,7,0}},'{'{9,0,0},'{10,11,0},'{10,14,0}},'{'{10,14,0},'{12,13,0},'{15,0,0}},
                   '{'{13,14,0},'{11,12,0},'{16,0,0}},'{'{17,0,0},'{18,0,0},'{19,0,0}},'{'{16,19,0},'{17,0,0},'{18,0,0}},'{'{19,0,0},'{0,0,0},'{0,0,0}}};

		
		damping_factor = 0.15;
		threshold = 0.001;
		
		wait (pagerank_complete === 1);
		
	end
endmodule