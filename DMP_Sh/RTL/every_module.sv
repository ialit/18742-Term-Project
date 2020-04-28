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
  input logic [31:0] sharing_structure [NUM_HW_THREADS][MAX_PARTITION_SIZE],
  input logic [31:0] num_nodes[NUM_HW_THREADS],
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
  real pagerank_scatter_op[NUM_HW_THREADS];
  logic [31:0] node_id [NUM_HW_THREADS];
  logic scatter_output_ready[NUM_HW_THREADS];
  logic scatter_operation_complete[NUM_HW_THREADS]; 

    //Inputs from scatter phase
    real pagerank_scatter_op_s [NUM_HW_THREADS];
    logic [31:0] node_id_s [NUM_HW_THREADS];
    logic scatter_output_ready_s [NUM_HW_THREADS];
    logic scatter_operation_complete_s [NUM_HW_THREADS];

    //Output
    real pagerank_stream [NUM_HW_THREADS];
    logic [31:0] dest_update[NUM_HW_THREADS];
    logic stream_valid[NUM_HW_THREADS];

    logic DMP_operation_complete;

    generate
    genvar i;
        for (i=0; i<NUM_HW_THREADS; i=i+1) begin : par
            pagerank_scatter #(NODES_IN_PARTITION, STREAM_SIZE, NODES_IN_GRAPH) scatter_threads 
				(.clock(clock), .reset_n(reset_n), .pagerank_enable(pagerank_enable), 
				 .nextIteration(nextIteration),
                 .source_id(source_id[i]), .out_degree(out_degree[i]), .dest_id(dest_id[i]), 
				 .page_rank_old(page_rank_init), .stall_scatter(stall_scatter),
                                                
                 .pagerank_scatter_op(pagearank_scatter_op[i]), .node_id(node_id[i]), 
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
     .stream_start(1), .stream_done(DMP_operation_complete),
                                                            
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


module pagerank_scatter 
    #(
        parameter int NODES_IN_PARTITION = 4,
        parameter int STREAM_SIZE = 20,
        parameter int NODES_IN_GRAPH = 32
    )
(
    //Circuit inputs
    input logic clock,
    input logic reset_n,
    input logic pagerank_enable,

    //For new iteration of pagerank
    input logic nextIteration,
                                    
    //Graph Inputs
    input logic [31:0] source_id [NODES_IN_PARTITION],
    input logic [31:0] out_degree [NODES_IN_PARTITION],
    input logic [31:0] dest_id [NODES_IN_PARTITION][STREAM_SIZE],
    input real page_rank_old [NODES_IN_GRAPH],
    input logic stall_scatter,

    //Output
    output real pagerank_scatter_op,
    output logic [31:0] node_id,
    output logic scatter_output_ready,
    output logic scatter_operation_complete 
);
    real page_rank_init [NODES_IN_GRAPH];
    logic [31:0] i,j;
    logic outer_loop_enable, inner_loop_enable;
    logic inner_loop_clear, outer_loop_clear;

    counter32_bit source_id_counter (.clock(clock), .reset_n(reset_n), .enable(outer_loop_enable), .clear(outer_loop_clear), .count_val(i));
    counter32_bit dest_id_counter (.clock(clock), .reset_n(reset_n), .enable(inner_loop_enable), .clear(inner_loop_clear), .count_val(j));

    typedef enum logic [2:0] {START, SCAN_LINK, QUEUE, INC, END} states_t;

    states_t currentState, nextState;

    always_comb begin
        nextState = SCAN_LINK;
        pagerank_scatter_op = 0;
        node_id = 0;
        scatter_output_ready = 0;
        scatter_operation_complete = 0;
        outer_loop_enable = 0;
        inner_loop_enable = 0;
        outer_loop_clear = 0;
        inner_loop_clear = 0;
        unique case (currentState)
            START: begin
                nextState = (pagerank_enable)?SCAN_LINK:START;
            end
            SCAN_LINK: begin
                nextState = (i < NODES_IN_PARTITION) ? QUEUE : END;
            end
            QUEUE: begin
              if (j >= out_degree[i])
                    nextState = INC;
                else begin
                    if (stall_scatter)
                        nextState = QUEUE;
                    else begin
                        pagerank_scatter_op = page_rank_init[source_id[i]] / out_degree[source_id[i]]; //Need to figure out how to do it
                        node_id = dest_id[i][j];
                        scatter_output_ready = 1;
                        inner_loop_enable = 1;
                        nextState = QUEUE;
                    end
                end
            end
            INC: begin
                outer_loop_enable = 1;
                inner_loop_clear = 1;
                nextState = SCAN_LINK;
            end
            END: begin
                nextState = (nextIteration) ? START : END;
                outer_loop_clear = 1;
                scatter_operation_complete = 1;
            end

        endcase
    end

    //FSM driver
    always_ff @(posedge clock, negedge reset_n) begin
        if (~reset_n) begin
            currentState <= START;
            for (int k=0; k<NODES_IN_PARTITION; k=k+1) begin
                page_rank_init[k] <= page_rank_old[k];
            end
        end
        else if (pagerank_enable) begin
            currentState <= nextState;
        end
    end
endmodule

module counter32_bit 
    (
        input clock, 
        input reset_n, 
        input enable, 
        input clear,

        output logic [31:0] count_val
    );

    logic [31:0] counter;

    assign count_val = counter;

    always_ff @(posedge clock, negedge reset_n) begin
        if (~reset_n)
            counter <=0;
        else if (clear)
            counter <=0;
        else if (~enable)
            counter <= counter;
        else 
            counter <= counter + 1;
    end

endmodule

/******************************************************************************
Module that syncronizes between threads for execution in a deterministic order.
Allows update if the thread posseses the address of the destination.
If there is not address then executes in a serial fashion

Authors:
    Kevin Rohan (krohan@andrew.cmu.edu)
    Eric Chen (echen2@andrew.cmu.edu)
    Deepak Pallerla (dpallerl@andrew.cmu.edu) 

- Use Parameter to set the following 2 parameters

    a. NUM_HW_THREADS - 
        Number of partitions in the garph

    b. NODES_IN_GRAPH - 
        The number of nodes in the graph partition

INPUT FORMAT:

    clock and reset_n : for functioning of the circuit

    nextIteration : compute nextIteration of pagerank

    page_rank_gather[PARTITIONS] :
        Pagerank of a particular destination ID from all partitions

    done[NUM_HW_THREADS]:
        gather stage done for each thread

OUTPUT FORMAT:

    pagerank_serial_stream[NODES_IN_GRAPH]:
        Pagerank of a thread ID
        
    stream_start:
        Start of stream

    stream_end:
        End of stream

*******************************************************************************/
module DMP_Sh
    #(
        parameter int NUM_HW_THREADS = 8,
        parameter int MAX_PARTITION_SIZE = 20,
        parameter int NODES_IN_GRAPH = 32
    )
(
    //Circuit inputs
    input logic clock,
    input logic reset_n,

    //For next iteration
    input logic nextIteration,

    //Graph Inputs
    input logic [31:0] sharing_structure [NUM_HW_THREADS][MAX_PARTITION_SIZE],
    input logic [31:0] num_nodes[NUM_HW_THREADS],

    //Inputs from scatter phase
    input real pagerank_scatter_op [NUM_HW_THREADS],
    input logic [31:0] node_id [NUM_HW_THREADS],
    input logic scatter_output_ready [NUM_HW_THREADS],
    input logic scatter_operation_complete [NUM_HW_THREADS],

    //Output
    output real pagerank_stream [NUM_HW_THREADS],
    output logic [31:0] dest_update[NUM_HW_THREADS],
    output logic stream_valid[NUM_HW_THREADS],

    output logic stall_scatter,
    output logic DMP_operation_complete
);

    typedef enum logic[2:0] {WAIT_FOR_SCATTER, CHECK_SHARED, SEND_QUEUE, WAIT_FOR_UPDATE, END} states_t;
    states_t currentState, nextState;

    logic DMP_start;
    real scatter_vals[NUM_HW_THREADS];
    logic [31:0] scatter_dest_ids[NUM_HW_THREADS];
    logic scatter_ready_reg[NUM_HW_THREADS];

    logic in_ready, clear_dest;
    logic [31:0] tid_for_clear;
    logic [31:0] tid_q;
    logic [31:0] dest_in;
    real q_val;
    real queue_thread[NUM_HW_THREADS];
    logic [31:0] dest_queue[NUM_HW_THREADS];
    logic valid[NUM_HW_THREADS];

    logic q_empty;
    logic DMP_complete;
    logic scatter_complete_reg[NUM_HW_THREADS];

    queue #(NUM_HW_THREADS) not_shared_queue
    (
        .clock(clock), .reset_n(reset_n),
        .in_ready(in_ready), .tid(tid_q), .val(q_val),
        .tid_for_clear(tid_for_clear), .clear_dest(clear_dest), 
        .dest_in(dest_in),

        .queue_thread(queue_thread),
        .dest_queue(dest_queue),
        .valid(valid)
    );

    always_comb begin
        for (int i=0; i<NUM_HW_THREADS; i++) begin
            if ( ((scatter_output_ready[i]) || (scatter_operation_complete[i])) == 0)
                DMP_start = 1;
            else 
                DMP_start = 0;
            
            if (scatter_complete_reg[i] == 0)
                DMP_complete = 0;
            else
                DMP_complete = 1;
        end
    end
    always_comb begin
        stall_scatter = 0;
        q_empty = 1;
        for (int i=0; i<NUM_HW_THREADS; i++) begin
          stream_valid[i] = 0;
        end
        unique case (currentState) 
            WAIT_FOR_SCATTER: begin
                nextState = (DMP_start) ? CHECK_SHARED : WAIT_FOR_SCATTER;
            end
            CHECK_SHARED: begin
                stall_scatter = 1;
                nextState = SEND_QUEUE;
                for (int tid=0; tid<NUM_HW_THREADS; tid++) begin
                    if (scatter_ready_reg[tid] == 1) begin
                        for (int i=0; i<num_nodes[tid]; i++) begin
                          if (sharing_structure[tid][i] == node_id[tid]) begin
                                pagerank_stream[tid] = scatter_vals[tid];
                                dest_update[tid] = scatter_dest_ids[tid];
                                stream_valid[tid] = 1;
                            end
                            else begin
                                tid_q = tid;
                                in_ready = 1;
                                q_val = scatter_vals[tid];
                                dest_in = scatter_dest_ids[tid];
                            end
                        end
                    end
                end
            end
            SEND_QUEUE: begin
                stall_scatter = 1;
                nextState = (DMP_complete)?END:WAIT_FOR_SCATTER;
              for (int tid=NUM_HW_THREADS-1; tid>=0 ; tid --) begin
                if (valid[tid] == 1) begin
                        pagerank_stream[tid] = queue_thread[tid];
                        dest_update[tid] = dest_queue[tid];
                        stream_valid[tid] = 1;

                        tid_for_clear = tid;
                        clear_dest = 1;
                        nextState = SEND_QUEUE;
                    end 
                end
            end
            END: begin
                DMP_operation_complete = 1;
                nextState = (nextIteration) ? WAIT_FOR_SCATTER : END;
            end
        endcase
    end

    always_ff @(posedge clock, negedge reset_n) begin
        if (~reset_n) begin
            currentState <= WAIT_FOR_SCATTER;
        end 
        else begin
            currentState <= nextState;
        end
    end
    always_ff @(posedge clock, negedge reset_n) begin
        if (DMP_start) begin
            for (int i=0; i<NUM_HW_THREADS; i++) begin
                scatter_vals[i] <= pagerank_scatter_op[i];
                scatter_ready_reg[i] <= scatter_output_ready[i];
                scatter_dest_ids[i] <= node_id[i];
            end
        end
        for(int i=0;i<NUM_HW_THREADS; i++)
            scatter_complete_reg[i] <= scatter_operation_complete[i];
    end
endmodule

module queue #(parameter int NUM_HW_THREADS = 8)
    (
        input logic clock, input reset_n,
        input logic in_ready, input logic [31:0] tid, input real val,
        input logic [31:0] tid_for_clear, input logic clear_dest, input logic [31:0] dest_in,

        output real queue_thread[NUM_HW_THREADS],
        output logic [31:0] dest_queue[NUM_HW_THREADS],
        output logic valid[NUM_HW_THREADS]
    );
    always_ff @(posedge clock, negedge reset_n) begin
        if (~reset_n) begin
            for (int i=0; i < NUM_HW_THREADS; i++)
            begin
                queue_thread[i] <= 0;
                valid[i] <= 0;
                dest_queue[i] <= 0;
            end
        end
        else if (clear_dest) begin
            valid[tid_for_clear] <= 0;
            queue_thread[tid_for_clear] <= 0;
            dest_queue[tid_for_clear] <= 0;
        end
        else if (in_ready) begin
            queue_thread[tid] <= val;
            dest_queue[tid] <= dest_in;
            valid[tid] <= 1;
        end
    end
endmodule


/******************************************************************************
Sums the stream, determines the computes the pagerank using the damping factor

Authors:
    Kevin Rohan (krohan@andrew.cmu.edu)
    Eric Chen (echen2@andrew.cmu.edu)
    Deepak Pallerla (dpallerl@andrew.cmu.edu) 

- Use Parameter to set the following 2 parameters

    a. NODES_IN_GRAPH - 
        The number of nodes in the graph partition

INPUT FORMAT:

    clock and reset_n : for functioning of the circuit

    stream_start:
        Start of stream

    stream_done:
        DMP serial finished sending the packets

    damping_factor:
        The damping factor for computing page rank

    threshold:
        convergence condition

OUTPUT FORMAT:

    pagerank_final[NODES_IN_GRAPH]:
        Pagerank final of all the nodes in the iteration.

    pagerank_complete:
        indicates that the pagerank computation is complete

    iteration_number:
        The number of iterations taken
    
    nextIteration:
        Compute next iteration of pagerank

*******************************************************************************/
module pagerank_comp
    #(
        parameter int NODES_IN_GRAPH = 32,
        parameter int NUM_HW_THREADS = 8
    )
(
    //Circuit inputs
    input logic clock,
    input logic reset_n,

    //Input from DMP phase
    input real pagerank_serial_stream [NUM_HW_THREADS],
    input logic [31:0] dest_update[NUM_HW_THREADS],
    input logic stream_valid[NUM_HW_THREADS],
  input logic stream_start,
  input logic stream_done,

    //Input related to the damping factor
    input real damping_factor,
    input real threshold,

    //Output logic of all nodes
    output real pagerank_final[NODES_IN_GRAPH],
    output logic [31:0] iteration_number,
    output logic pagerank_complete,
    output logic nextIteration
);

    typedef enum logic[2:0] {WAIT_FOR_READY, ACCUMILATE_SUM, DAMP, DELTA, END} states_t;

    states_t currentState, nextState;
    real pagerank_intermediate[NODES_IN_GRAPH];
    real delta;
    logic [31:0] iteration_count;
  	logic next_itr;

    counter32_bit_final iteration_counter (.clock(clock), .reset_n(reset_n), .enable(next_itr), .count_val(iteration_count), .clear(1'b0));

    assign nextIteration = next_itr;
    assign iteration_number = iteration_count;
    
    function real float_absolute (real ip_val);
        float_absolute = (ip_val < 0 ) ? (-ip_val) : ip_val;
          
    endfunction

    always_comb begin
        next_itr = 0;
        unique case(currentState) 
            WAIT_FOR_READY: begin
                nextState = (stream_start) ? ACCUMILATE_SUM : WAIT_FOR_READY;
            end
            ACCUMILATE_SUM: begin
                nextState = (stream_done) ? DAMP : ACCUMILATE_SUM;
            end
            DAMP: begin
                nextState = DELTA;
            end
            DELTA: begin
                nextState = END;
            end
            END: begin
                nextState = ((delta < threshold) || (iteration_count >= 500)) ? END : (WAIT_FOR_READY);
                pagerank_complete = ((delta < threshold) || (iteration_count >= 500)) ? 1'b1 : 1'b0;
                next_itr = ((delta < threshold) || (iteration_count >= 500)) ? 1'b0 : 1'b1;
            end
        endcase
    end

    always_ff @(posedge clock, negedge reset_n) begin
        if (~reset_n) begin
            currentState <= WAIT_FOR_READY;
        end 
        else begin
            currentState <= nextState;        
        end
    end

    always_ff @(posedge clock, negedge reset_n) begin      
        if (nextState == WAIT_FOR_READY) begin
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                pagerank_intermediate [i] <= 0;
            end
            delta <= 64'd0;
        end
        else if (nextState == ACCUMILATE_SUM) begin     
            for (int i=0; i<NUM_HW_THREADS; i++) begin
                if (stream_valid[i])
                    pagerank_intermediate[dest_update[i]] <= pagerank_intermediate[dest_update[i]] + pagerank_serial_stream[i];
            end
        end
        else if (nextState == DAMP) begin
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                pagerank_final[i] <= (1-damping_factor)/(NODES_IN_GRAPH) + (damping_factor)*(pagerank_intermediate[i]);
            end
        end
        else if (nextState == DELTA) begin
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                delta <= delta + (float_absolute(pagerank_final[i] - pagerank_intermediate[i]));
            end
        end
    end
endmodule

module counter32_bit_final
(
    input logic clock,
    input logic reset_n,
    input logic enable,
    input logic clear,

    output logic [31:0] count_val
);

    logic [31:0] counter;

    assign count_val = counter;

    always_ff @(posedge clock, negedge reset_n) begin
        if ((~reset_n) || (clear))
            counter <=0;
        else if (~enable)
            counter <= counter;
        else 
            counter <= counter + 1;
    end

endmodule
