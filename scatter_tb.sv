// Code your testbench here
// or browse Examples
/******************************************************************************
Test bench module for pagerank scatter

Authors:
    Kevin Rohan (krohan@andrew.cmu.edu)
    Eric Chen (echen2@andrew.cmu.edu)
    Deepak Pallerla (dpallerl@andrew.cmu.edu) 

*******************************************************************************/
module scatter_tb 
  #(
      //PARAMETERS
    parameter int NODES_IN_PARTITION = 4,
    parameter int STREAM_SIZE = 3,
    parameter int NODES_IN_GRAPH = 4
    
  )
  ();

 
    //Circuit inputs
    logic clock;
    logic reset_n;
    logic pagerank_enable;

    //For new iteration of pagerank
    logic nextIteration;

    //Graph Inputs
    logic [31:0] source_id [NODES_IN_PARTITION];
    logic [31:0] out_degree [NODES_IN_PARTITION];
    logic [31:0] dest_id [NODES_IN_PARTITION][STREAM_SIZE];
    logic [63:0] page_rank_old [NODES_IN_GRAPH];

    //Output
  	logic [63:0] pagerank_scatter_op;
    logic [31:0] node_id;
    logic output_ready;
    logic operation_complete;

  pagerank_scatter #(NODES_IN_PARTITION, STREAM_SIZE, NODES_IN_GRAPH) test_scatter(.*);

    initial begin
  		forever begin
        	#5 clock = ~clock;
    	end
    end

    initial begin
        clock = 0;
        reset_n = 1;
        nextIteration = 0;

        source_id = {1,2,3,4};
        out_degree = {2,1,3,1};
        dest_id = '{'{2,3,0},'{4,1,1},'{1,2,4},'{3,0,0}};

        page_rank_old = {0.25,0.25,0.25,0.25};
        
        #1 reset_n = 0;
        #1 reset_n = 1;
        
      	pagerank_enable <= 1;
        @(posedge clock);
        $display("CurrentState = %s", test_scatter.currentState.name());
       
        
        repeat(50) begin
             @(posedge clock);
        $display("CurrentState = %s", test_scatter.currentState.name());
        end
     
		$finish;
    end
endmodule