/******************************************************************************
Test bench module for pagerank comp

Authors:
    Kevin Rohan (krohan@andrew.cmu.edu)
    Eric Chen (echen2@andrew.cmu.edu)
    Deepak Pallerla (dpallerl@andrew.cmu.edu) 

*******************************************************************************/
module scatter_tb 
  #(
      //PARAMETERS
    parameter int NODES_IN_GRAPH = 4   
  )
  ();
    //Circuit inputs
    logic clock;
    logic reset_n;

    //Input from DMP phase
    logic [63:0] pagerank_serial_stream [NODES_IN_GRAPH];
    logic stream_start;
    logic stream_done;
    logic [63:0] threshold;

    //Input related to the damping factor
    logic [63:0] damping_factor;

    //Output logic of all nodes
    logic [63:0] pagerank_final[NODES_IN_GRAPH];
    logic [31:0] iteration_number;
    logic pagerank_complete;
    logic nextIteration;


  pagerank_comp #(NODES_IN_GRAPH) test_comp(.*);

    initial begin
  		forever begin
        	#5 clock = ~clock;
    	end
    end

    initial begin
        clock = 0;
        reset_n = 1;
      	pagerank_serial_stream = {1,2,3,4};
        stream_done = 0;
        #1 reset_n = 0;
        #1 reset_n = 1;

        stream_start <= 0;
        @(posedge clock);
        #1 $display("state = %s, pagerank_intermediate[0] %d",test_comp.currentState.name(),test_comp.pagerank_intermediate[3]);
      
      	stream_start<=1;
     	@(posedge clock);
        #1 $display("state = %s, pagerank_intermediate[0] %d",test_comp.currentState.name(),test_comp.pagerank_intermediate[3]);
      
      @(posedge clock);
        #1 $display("state = %s, pagerank_intermediate[0] %d",test_comp.currentState.name(),test_comp.pagerank_intermediate[3]);
		$finish;
    end
endmodule