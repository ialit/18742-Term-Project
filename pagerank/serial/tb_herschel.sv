/******************************************************************************
Test Bench for testing DMP shared
*******************************************************************************/
module TestBench_Serial();
  
  //Circuit inputs
  logic clock;
  logic reset_n;
  logic pagerank_enable;
  logic counter_enable;

  logic [31:0] counter_val;

    //Graph Inputs
  logic [31:0] source_id [11][1];
  logic [31:0] out_degree [11][1];
  logic [31:0] dest_id [11][1][4];

  //Pagerank Inputs
  real damping_factor;
  real threshold;
    
  int clock_cycles;
  
  //Output
  real pagerank[11];
  logic pagerank_complete;
	
	//DMP signals
  
  const int NUM_HW_THREADS = 11;
	const int NODES_IN_PARTITION =1;
	const int MAX_PARTITION_SIZE = 1;
	const int NODES_IN_GRAPH = 11;
	const int STREAM_SIZE = 4;
	
  pagerank_DMP_serial #(11, 1, 11, 4)
  	obj
	( 
    .clock(clock), .reset_n(reset_n), 
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
    clock_cycles = 0;		
		
		clock = 0;
		reset_n = 0;
		#1 reset_n <= 1;
		
		
        
      source_id = '{'{0},'{1},'{2},'{3},'{4},'{5},'{6},'{7},'{8},'{9},'{10}};
      out_degree = '{'{4},'{4},'{1},'{1},'{2},'{2},'{2},'{2},'{0},'{0},'{0}};
      
      dest_id = '{
                  '{'{2,3,4,5}},
                  '{'{2,3,6,7}},
                  '{'{10,0,0,0}},
                  '{'{9,0,0,0}},
                  '{'{8,9,0,0}},
                  '{'{8,10,0,0}},
                  '{'{8,9,0,0}},
                  '{'{8,10,0,0}},
                  '{'{0,0,0,0}},
                  '{'{0,0,0,0}},
                  '{'{0,0,0,0}}
                  };


		pagerank_enable <= 1;
    damping_factor <= 0.85;
	  threshold <= 0.00001;
      
      while (pagerank_complete != 1) begin
        @(posedge clock);
        clock_cycles <= clock_cycles+1;
      end
      #1
      
      for (int i=0; i<NODES_IN_GRAPH; i++) begin
        $display("pagerank[%d] = %f",i,pagerank[i]);
      end
      
      $display("Delta %f",obj.pagerank_computation.delta);
      $display("Iterations elapsed %f",obj.pagerank_computation.iteration_number + 1);
      $display("Clock cycles %d",clock_cycles);

      $display("DONE");
      $finish;
     end
endmodule
