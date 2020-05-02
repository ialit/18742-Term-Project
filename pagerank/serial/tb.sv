/******************************************************************************
Test Bench for testing DMP shared
*******************************************************************************/
module TestBench_Sh();
    //Circuit inputs
    logic clock;
    logic reset_n;
    logic pagerank_enable;
	logic counter_enable;

	logic [31:0] counter_val;

    //Graph Inputs
  logic [31:0] source_id [1][4];
  logic [31:0] out_degree [1][4];
  logic [31:0] dest_id [1][4][3];

    //Pagerank Inputs
    real damping_factor;
    real threshold;
    
    //Output
  real pagerank[4];
    logic pagerank_complete;
	
	//DMP signals
  
  	const int NUM_HW_THREADS = 7;
	const int NODES_IN_PARTITION = 3;
	const int MAX_PARTITION_SIZE = 3;
	const int NODES_IN_GRAPH = 20;
	const int STREAM_SIZE = 3;
	
  pagerank_DMP_serial #(1, 4, 4, 3)
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
		reset_n = 0;
		#1 reset_n = 1;
		
		pagerank_enable <= 1;
        
      source_id <= '{'{1,2,3,4}};
      out_degree <= '{'{2,1,3,1}};
      dest_id <= '{'{'{2,3,0},'{4,1,1},'{1,2,4},'{3,0,0}}};
		
      	damping_factor <= 0.85;
		threshold <= 0.00001;
      
      @(posedge clock);
      $display("pagerank in %d",source_id[0][1]);
      $display("pagerank init %d",obj.scatter_threads.out_degree[0]);
      $display("current state %s",obj.scatter_threads.currentState.name());
      
      @(posedge clock);
      $display("current state %s",obj.scatter_threads.currentState.name());
      
      @(posedge clock);
      $display("current state %s",obj.scatter_threads.currentState.name());
      
      @(posedge clock);
      $display("current state %s",obj.scatter_threads.currentState.name());
      
      @(posedge clock);
      $display("current state %s",obj.scatter_threads.currentState.name());
      
      @(posedge clock);
      $display("current state %s",obj.scatter_threads.currentState.name());
            @(posedge clock);
      $display("current state %s",obj.scatter_threads.currentState.name());
            @(posedge clock);
      $display("current state %s",obj.scatter_threads.currentState.name());
     
    end
endmodule