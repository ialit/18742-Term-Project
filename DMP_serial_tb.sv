/******************************************************************************
Test bench module for DMP serial

Authors:
    Kevin Rohan (krohan@andrew.cmu.edu)
    Eric Chen (echen2@andrew.cmu.edu)
    Deepak Pallerla (dpallerl@andrew.cmu.edu) 

*******************************************************************************/
module DMP_serial_tb 
  #(
      //PARAMETERS
    parameter int NUM_HW_THREADS = 2,
    parameter int NODES_IN_GRAPH = 4
  )
  ();

 
    //Circuit inputs
    logic clock;
    logic reset_n;

    //For next iteration
    logic nextIteration;

    //Inputs from gather phase
    logic [63 : 0] page_rank_gather[NUM_HW_THREADS][NODES_IN_GRAPH];
    logic done[NUM_HW_THREADS];

    //Output
    logic [63:0] pagerank_serial_stream [NODES_IN_GRAPH];
    logic stream_start;
    logic stream_done;
  
    DMP_serial #(NUM_HW_THREADS, NODES_IN_GRAPH) test_DMP(.*);

    initial begin
  		forever begin
        	#5 clock = ~clock;
    	end
    end

    initial begin
        clock = 0;
        reset_n = 1;
        #1 reset_n = 0;
      	#1 reset_n = 1;
        nextIteration = 0;

        done[0] <= 1;
      	done[1] <= 0;
      @(posedge clock);
      $display("state: %s, sync = %d",(test_DMP.currentState.name()),(test_DMP.sync));
     
      done[1] <= 1;
       @(posedge clock);
      #1 $display("state: %s, sync = %d",(test_DMP.currentState.name()),(test_DMP.sync));
      
      @(posedge clock);
      #1 $display("state: %s, sync = %d, tid = %d, done = %d",(test_DMP.currentState.name()),(test_DMP.sync), test_DMP.thread_id,stream_done);
      
      @(posedge clock);
      #1 $display("state: %s, sync = %d, tid = %d, done = %d",(test_DMP.currentState.name()),(test_DMP.sync), test_DMP.thread_id,stream_done);
      
      @(posedge clock);
      #1 $display("state: %s, sync = %d, tid = %d, done = %d",(test_DMP.currentState.name()),(test_DMP.sync), test_DMP.thread_id,stream_done);
      
      @(posedge clock);
      #1 $display("state: %s, sync = %d, tid = %d, done = %d",(test_DMP.currentState.name()),(test_DMP.sync), test_DMP.thread_id,stream_done);
		$finish;
    end
endmodule