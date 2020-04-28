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
module pagerank_DMP_serial
    #(
        parameter int NUM_HW_THREADS = 8, //Should be same as number of partitions
        parameter int NODES_IN_PARTITION = 4, 
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
    input logic [63:0] damping_factor,
    input logic [63:0] threshold,
    
    //Output
    output logic [63:0] pagerank[NODES_IN_GRAPH],
    output logic pagerank_complete
);

    //General signals
    logic [63:0] page_rank_init [NODES_IN_GRAPH];
    logic [63:0] pagerank_final [NODES_IN_GRAPH];
    logic [31:0] iteration_number;
    logic nextIteration;

    //Scatter phase signals
    logic [63:0] pagerank_scatter[NUM_HW_THREADS] ;
    logic [31:0] node_id[NUM_HW_THREADS];
    logic output_ready[NUM_HW_THREADS];
    logic operation_complete[NUM_HW_THREADS];
    logic scatter_operation_complete[NUM_HW_THREADS];

    //Gather signals
    logic [63:0] pagerank_pre_damp [NUM_HW_THREADS][NODES_IN_GRAPH];
    logic gather_operation_complete[NUM_HW_THREADS]; 

    //DMP serial signals
    logic [63 : 0] page_rank_gather[NUM_HW_THREADS][NODES_IN_GRAPH];
    logic [63:0] pagerank_serial_stream [NODES_IN_GRAPH];
    logic stream_start;
    logic stream_done;

    generate
    genvar i;
        for (i=0; i<NUM_HW_THREADS; i=i+1) begin : par
            pagerank_scatter #(NODES_IN_PARTITION, STREAM_SIZE, NODES_IN_GRAPH) scatter_threads (  .clock(clock), .reset_n(reset_n), .pagerank_enable(pagerank_enable), .nextIteration(nextIteration),
                                                .source_id(source_id[i]), .out_degree(out_degree[i]), .dest_id(dest_id[i]), .page_rank_old(page_rank_init),
                                                
                                                .pagerank_scatter_op(pagerank_scatter[i]), .node_id(node_id[i]), .output_ready(output_ready[i]), 
                                                .operation_complete(operation_complete[i])
                                             );

            pagerank_local_update #(NODES_IN_GRAPH) local_update_threads (  .clock(clock), .reset_n(reset_n), .pagerank_enable(pagerank_enable), .nextIteration(nextIteration),
                                                .page_rank_scatter(pagerank_scatter[i]), .dest_id(node_id[i]), .pagerank_ready(output_ready[i]), 
                                                .scatter_operation_complete(scatter_operation_complete[i]),
                                                
                                                .pagerank_pre_damp(pagerank_pre_damp[i]), .gather_operation_complete(gather_operation_complete[i])
                                             );

            assign page_rank_gather[i] = pagerank_pre_damp[i];

            DMP_serial #(NUM_HW_THREADS, NODES_IN_GRAPH) serialization_of_threads (   .clock(clock), .reset_n(reset_n), .nextIteration(nextIteration),
                                                    .page_rank_gather(page_rank_gather), .done(gather_operation_complete),
                                                    
                                                    .pagerank_serial_stream(pagerank_serial_stream), .stream_start(stream_start), .stream_done(stream_done)
                                                );            
        end
    endgenerate

    pagerank_comp #(NODES_IN_GRAPH) pagerank_computation ( .clock(clock), .reset_n(reset_n),
                                                            .pagerank_serial_stream(pagerank_serial_stream), .stream_start(stream_start), .stream_done(stream_done),
                                                            .damping_factor(damping_factor), .threshold(threshold),
                                                            
                                                            .pagerank_final(pagerank_final), .iteration_number(iteration_number), .pagerank_complete(pagerank_complete),
                                                            .nextIteration(nextIteration)
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


