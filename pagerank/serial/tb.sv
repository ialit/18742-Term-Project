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
		forever begin
      #5 clock = ~clock; 
    end
  end
	
	initial begin
		
		
		clock = 0;
		reset_n = 0;
		#1 reset_n <= 1;
		
		pagerank_enable <= 1;
        
      source_id <= '{'{0,1,2,3}};
      out_degree <= '{'{2,1,3,1}};
      dest_id <= '{'{'{1,2,0},'{3,0,0},'{0,1,3},'{2,0,0}}};
		
      	damping_factor <= 0.85;
		    threshold <= 0.00001;
      
      while (obj.local_update_threads.gather_operation_complete  != 1) begin
        @(posedge clock);
      end
      

      $display("DONE");
      $finish;
     end
endmodule
