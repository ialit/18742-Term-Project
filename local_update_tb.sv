/******************************************************************************
Test bench for pagerank_local_update

Authors:
    Kevin Rohan (krohan@andrew.cmu.edu)
    Eric Chen (echen2@andrew.cmu.edu)
    Deepak Pallerla (dpallerl@andrew.cmu.edu) 

*******************************************************************************/
module local_update_tb 
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

    //Input for computation of nextIteration 
    logic nextIteration;

    //Inputs from scatter phase
    logic [63:0] page_rank_scatter;
    logic [31:0] dest_id;
    logic pagerank_ready;
    logic scatter_operation_complete;

    //Output
    logic [63:0] pagerank_pre_damp [NODES_IN_GRAPH];
    logic gather_operation_complete;

    pagerank_local_update #(NODES_IN_GRAPH) test_local_update(.*);

    initial begin
  		forever begin
        	#5 clock = ~clock;
    	end
    end

    initial begin
      clock <= 0;
      reset_n <= 1;
      nextIteration <= 0;
		  dest_id <= 2;
        
        
      #1 reset_n <= 0;
      #1 reset_n <= 1;
        
      page_rank_scatter <= 4;
      pagerank_enable <= 1;
      pagerank_ready <= 1;
      
      @(posedge clock);
      
      #1$display("Sum = %d, op_com = %b pagerank_ready = %b pagerank_enable %b", pagerank_pre_damp[dest_id], gather_operation_complete,pagerank_ready, pagerank_enable);
        
      repeat(5) begin
        page_rank_scatter <= 10;
        pagerank_ready <= 1;
        @(posedge clock);
        #1$display("Sum = %d, op_com = %b", pagerank_pre_damp[dest_id], gather_operation_complete);
      
      end
      page_rank_scatter <= 3;
      pagerank_ready <= 1;
      scatter_operation_complete <= 1;
      @(posedge clock);
      #1 $display("Sum = %d, op_com = %b", pagerank_pre_damp[dest_id], gather_operation_complete);
      @(posedge clock);
      #1$display("Sum = %d, op_com = %b", pagerank_pre_damp[dest_id], gather_operation_complete); 
	    $finish;
    end
endmodule