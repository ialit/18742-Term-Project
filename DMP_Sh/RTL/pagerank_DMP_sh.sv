/******************************************************************************
Root module for implementing the entire sequence of partitioned based page
rank algorithm. The implementation of the RTL is according to that of shown 
in the figure in the repository - DMP serial pagerank

Authors:
    Kevin Rohan (krohan@andrew.cmu.edu)
    Eric Chen (echen2@andrew.cmu.edu)
    Deepak Pallerla (dpallerl@andrew.cmu.edu) 

- Use Parameter to set the following 2 parameters

    a. NUM_HW_THREADS - 
        The total number of partitions in the graph

    b. NODES_IN_PARTITION - 
        Number of nodes in each partition

    c. NODES_IN_GRAPH - 
        The total number of nodes in the graph
    
    d. STREAM_SIZE -
        Size of the stream of inputs from each thread

INPUT FORMAT:

    clock and reset_n : for functioning of the circuit

    The graph partition is inputed by:
        source_id[NUM_HW_THREADS][NODES_IN_PARTITION] | out_degree[NUM_HW_THREADS][NODES_IN_PARTITION] | dest_id[NUM_HW_THREADS][NODES_IN_PARTITION][MAX_DEGREE]

    source_id:
        Source ID indicates the ID of the vertex.

    out_degree:
        The number of NODES_IN_PARTITION connected to the corresponding source vector.

    dest_id:
        The IDs of vertices connected to the corresponding source vector.
        If the numbers of IDs less than max degree, add a dest_id < 0 to signify end of stream.
    
    pagerank_enable:
        Start computation of pagerank

    damping_factor:
        The damping factor (alpha) of pagerank algorithm

    threshold:
        convergence criteria

OUTPUT FORMAT:

    pagerank[NODES_IN_GRAPH]:
        Pagerank final of all the nodes in the iteration.

    pagerank_complete:
        indicates that the pagerank computation is complete
*******************************************************************************/
module pagerank_DMP_Sh
    #(
        parameter int NUM_HW_THREADS = 8, //Should be same as number of partitions
        parameter int NODES_IN_PARTITION = 4, 
		parameter int MAX_PARTITION_SIZE = 20,
        parameter int NODES_IN_GRAPH = 32,
        parameter int STREAM_SIZE = 20 
    )
(
    //Circuit inputs
    input logic clock,
    input logic reset_n,
    input logic pagerank_enable,

    //Graph Inputs
    input logic [31:0] source_id [NUM_HW_THREADS][NODES_IN_PARTITION],
    input logic [31:0] out_degree [NUM_HW_THREADS][NODES_IN_PARTITION],
    input logic [31:0] dest_id [NUM_HW_THREADS][NODES_IN_PARTITION][STREAM_SIZE],

    //Pagerank Inputs
    input real damping_factor,
    input real threshold,
	
	//DMP signals
    input logic [31:0] sharing_structure [NUM_HW_THREADS][MAX_PARTITION_SIZE];
    input logic [31:0] num_nodes[NUM_HW_THREADS];
    
    //Output
    output real pagerank[NODES_IN_GRAPH],
    output logic pagerank_complete
);

    //General signals
    real page_rank_init [NODES_IN_GRAPH];
    real pagerank_final [NODES_IN_GRAPH];
    logic [31:0] iteration_number;
    logic nextIteration;
                                    
    //Graph Inputs
    real page_rank_old [NODES_IN_GRAPH];
    logic stall_scatter;

    //Output
    real pagerank_scatter_op;
    logic [31:0] node_id;
    logic scatter_output_ready;
    logic scatter_operation_complete; 

    //Inputs from scatter phase
    real pagerank_scatter_op_s [NUM_HW_THREADS];
    logic [31:0] node_id_s [NUM_HW_THREADS];
    logic scatter_output_ready_s [NUM_HW_THREADS];
    logic scatter_operation_complete_s [NUM_HW_THREADS];

    //Output
    real pagerank_stream [NUM_HW_THREADS];
    logic [31:0] dest_update[NUM_HW_THREADS];
    logic stream_valid[NUM_HW_THREADS];

    logic stall_scatter;
    logic DMP_operation_complete;

    generate
    genvar i;
        for (i=0; i<NUM_HW_THREADS; i=i+1) begin : par
            pagearank_scatter #(NODES_IN_PARTITION, STREAM_SIZE, NODES_IN_GRAPH) scatter_threads 
				(.clock(clock), .reset_n(reset_n), .pagerank_enable(pagerank_enable), 
				 .nextIteration(nextIteration),
                 .source_id(source_id[i]), .out_degree(out_degree[i]), .dest_id(dest_id[i]), 
				 .page_rank_old(page_rank_init), .stall_scatter(stall_scatter),
                                                
                 .pagearank_scatter_op(pagearank_scatter_op[i]), .node_id(node_id[i]), 
				 .scatter_output_ready(scatter_output_ready[i]), 
                 .scatter_operation_complete(scatter_operation_complete[i])
                );
		
		assign pagerank_scatter_op_s[i] = pagearank_scatter_op[i];
		assign node_id_s[i] = node_id;
		assign scatter_output_ready_s[i] = scatter_output_ready[i];
		assign scatter_operation_complete_s[i] = scatter_operation_complete[i];
		
        end
    endgenerate
	
	DMP_Sh #(NUM_HW_THREADS, NODES_IN_GRAPH) sharing_based_determinism
	(.clock(clock), .reset_n(reset_n), .nextIteration(nextIteration),
     .sharing_structure(sharing_structure), .num_nodes(num_nodes),
     .pagerank_scatter_op(pagearank_scatter_op), .node_id(node_id),
     .scatter_output_ready(scatter_output_ready_s), 
	 .scatter_operation_complete(scatter_operation_complete_s),
                                                    
     .pagerank_stream(pagerank_stream), .dest_update(dest_update), 
	 .stream_valid(stream_valid), .stall_scatter(stall_scatter),
	 .DMP_operation_complete(DMP_operation_complete)
    );
	
    pagerank_comp #(NODES_IN_GRAPH, NUM_HW_THREADS) pagerank_computation 
	( .clock(clock), .reset_n(reset_n),
      .pagerank_serial_stream(pagerank_stream), .dest_update(dest_update), 
	  .stream_valid(stream_valid),
	  .damping_factor(damping_factor), .threshold(threshold),
                                                            
      .pagerank_final(pagerank_final), .iteration_number(iteration_number), 
	  .pagerank_complete(pagerank_complete),.nextIteration(nextIteration)
    );

    assign pagerank = pagerank_final;

    always_comb begin
        if (iteration_number == 0) begin
            for (int i=0; i<NODES_IN_GRAPH; i++)
                page_rank_init[i] <= 1/NODES_IN_GRAPH;
        end
        else if (nextIteration) begin
            for (int i=0; i<NODES_IN_GRAPH; i++)
                page_rank_init[i] <= pagerank_final[i];
        end
    end
endmodule


