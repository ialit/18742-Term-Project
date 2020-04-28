module pagerank_DMP_serial
    #(
        parameter int NUM_HW_THREADS = 8, //Should be same as number of partitions
        parameter int NODES_IN_PARTITION = 8, 
        parameter int NODES_IN_GRAPH = 64,
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
    
    //Output
    output real pagerank[NODES_IN_GRAPH],
    output logic pagerank_complete
);

    //General signals
    real page_rank_init [NODES_IN_GRAPH]/* synthesis noprune keep preserve */; 
    real pagerank_final [NODES_IN_GRAPH]/* synthesis noprune keep preserve */; 
    logic [31:0] iteration_number/* synthesis noprune keep preserve */; 
    logic nextIteration/* synthesis noprune keep preserve */; 

    //Scatter phase signals
    real pagerank_scatter[NUM_HW_THREADS] /* synthesis noprune keep preserve */; 
    logic [31:0] node_id[NUM_HW_THREADS]/* synthesis noprune keep preserve */; 
    logic output_ready[NUM_HW_THREADS]/* synthesis noprune keep preserve */;  
    logic operation_complete[NUM_HW_THREADS]/* synthesis noprune keep preserve */; 
    logic scatter_operation_complete[NUM_HW_THREADS]/* synthesis noprune keep preserve */; 

    //Gather signals
    real pagerank_pre_damp [NUM_HW_THREADS][NODES_IN_GRAPH]/* synthesis noprune keep preserve */; 
    logic gather_operation_complete[NUM_HW_THREADS]/* synthesis noprune keep preserve */;  

    //DMP serial signals
    real page_rank_gather[NUM_HW_THREADS][NODES_IN_GRAPH]/* synthesis noprune keep preserve */; 
    real pagerank_serial_stream [NODES_IN_GRAPH]/* synthesis noprune keep preserve */; 
    logic stream_start/* synthesis noprune keep preserve */; 
    logic stream_done/* synthesis noprune keep preserve */; 

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
        end
    endgenerate

    DMP_serial #(NUM_HW_THREADS, NODES_IN_GRAPH) serialization_of_threads (   .clock(clock), .reset_n(reset_n), .nextIteration(nextIteration),
                                                    .page_rank_gather(page_rank_gather), .done(gather_operation_complete),
                                                    
                                                    .pagerank_serial_stream(pagerank_serial_stream), .stream_start(stream_start), .stream_done(stream_done)
                                                );            

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

    //Output
    output real pagerank_scatter_op,
    output logic [31:0] node_id,
    output logic output_ready,
    output logic operation_complete 
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
        output_ready = 0;
        operation_complete = 0;
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
                    pagerank_scatter_op = page_rank_init[source_id[i]] / out_degree[source_id[i]]; //Need to figure out how to do it
                    node_id = dest_id[i][j];
                    output_ready = 1;
                    inner_loop_enable = 1;
                    nextState = QUEUE;
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
                operation_complete = 1;
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

module pagerank_local_update
    #(
        parameter int NODES_IN_GRAPH = 32
    )
(
    //Circuit inputs
    input logic clock,
    input logic reset_n,
    input logic pagerank_enable,

    //Input for computation of nextIteration 
    input logic nextIteration,

    //Inputs from scatter phase
    input real page_rank_scatter,
    input logic [31:0] dest_id,
    input logic pagerank_ready,
    input logic scatter_operation_complete,

    //Output
    output real pagerank_pre_damp [NODES_IN_GRAPH],
    output logic gather_operation_complete 
);
    int i, j;

    real pagerank_register [NODES_IN_GRAPH];
    
  	assign pagerank_pre_damp = pagerank_register;
  
    always_ff @(posedge clock, negedge reset_n) begin
        if (~reset_n) begin
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                pagerank_register[i] <= 0;
            end
            gather_operation_complete <= 0; 
        end
        else if(nextIteration) begin
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                pagerank_register[i] <= 0;
            end
            gather_operation_complete <= 0; 
        end
        else if (pagerank_enable) begin
            if (pagerank_ready) begin
                pagerank_register[dest_id] <= pagerank_register[dest_id] + page_rank_scatter;
            end
            gather_operation_complete <= scatter_operation_complete;
        end
    end
endmodule

module DMP_serial
    #(
        parameter int NUM_HW_THREADS = 8,
        parameter int NODES_IN_GRAPH = 32
    )
(
    //Circuit inputs
    input logic clock,
    input logic reset_n,

    //For next iteration
    input logic nextIteration,

    //Inputs from gather phase
    input real page_rank_gather[NUM_HW_THREADS][NODES_IN_GRAPH],
    input logic done[NUM_HW_THREADS],

    //Output
    output real pagerank_serial_stream [NODES_IN_GRAPH],
    output logic stream_start,
    output logic stream_done
);

    typedef enum logic[1:0] {WAIT_FOR_THREADS, SEND, END} states_t;
    logic sync, sync_r;

    states_t currentState, nextState;
    logic [31:0] thread_id;
    logic next_thread;

    counter32_bit thread_counter (.clock(clock), .reset_n(reset_n), .enable(next_thread), .count_val(thread_id), .clear(nextIteration));

    assign stream_start = sync;
    assign stream_done = (thread_id == NUM_HW_THREADS)? 1'b1 : 1'b0;

    always_comb begin
        for(int i=0; i<NODES_IN_GRAPH; i++)
            pagerank_serial_stream[i] = 0;
        next_thread = 0;
        unique case(currentState) 
            WAIT_FOR_THREADS: begin
                nextState = (sync) ? SEND : WAIT_FOR_THREADS;
            end
            SEND: begin
                if (thread_id == NUM_HW_THREADS) begin
                    nextState = END;
                end
                else begin
                    for(int i=0; i<NODES_IN_GRAPH; i++) begin
                        pagerank_serial_stream[i] = page_rank_gather[thread_id][i];
                    end
                    next_thread = 1;
                    nextState = SEND;
                end
            end
            END: begin
                nextState = (nextIteration) ? WAIT_FOR_THREADS : END;
            end
        endcase
    end

    //Threads ready check
    always_comb begin
        for (int i=0; i<NUM_HW_THREADS; i++)
            sync=done[i]& 1'b1;
    end

    always_ff @(posedge clock, negedge reset_n) begin
        if (~reset_n) begin
            currentState <= WAIT_FOR_THREADS;
        end 
        else begin
            currentState <= nextState;
        end
    end
endmodule

module counter32_bit 
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
        if (~reset_n)
            counter <= 'b0;
        else if(clear)
            counter <= 'b0;
        else if (~enable)
            counter <= counter;
        else 
            counter <= counter + 1;
    end

endmodule

module pagerank_comp
    #(
        parameter int NODES_IN_GRAPH = 32
    )
(
    //Circuit inputs
    input logic clock,
    input logic reset_n,

    //Input from DMP phase
    input real pagerank_serial_stream [NODES_IN_GRAPH],
    input logic stream_start,
    input logic stream_done,
    input real threshold,

    //Input related to the damping factor
    input real damping_factor,

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
        //float_absolute = 64'd420;             //NOT sure what this was for 
        float_absolute = ip_val;
      if (ip_val < 0)
        float_absolute = -ip_val;
    endfunction

    always_comb begin
        unique case(currentState) 
            WAIT_FOR_READY: begin
                nextState = (stream_start) ? ACCUMILATE_SUM : WAIT_FOR_READY;
                next_itr = 0;
                pagerank_complete = 0;
            end
            ACCUMILATE_SUM: begin
                nextState = (stream_done) ? DAMP : ACCUMILATE_SUM;
                next_itr = 0;
                pagerank_complete = 0;
            end
            DAMP: begin
                nextState = DELTA;
                next_itr = 0;
                pagerank_complete = 0;
            end
            DELTA: begin
                nextState = END;
                next_itr = 0;
                pagerank_complete = 0;
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

    always_ff @(posedge clock) begin      
        if (nextState == WAIT_FOR_READY) begin
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                pagerank_intermediate [i] <= 0;
            end
            delta <= 64'd0;
        end
        else if (nextState == ACCUMILATE_SUM) begin     
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                pagerank_intermediate[i] <= pagerank_intermediate[i] + pagerank_serial_stream[i];
              //$display("KEVIN ROHAN %d",pagerank_serial_stream[i]);
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
        if (~reset_n)
            counter <= 0;
        else if (clear)
            counter <= 0;
        else if (~enable)
            counter <= counter;
        else 
            counter <= counter + 1;
    end

endmodule