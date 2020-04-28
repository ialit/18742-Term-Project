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
                for (int i=NUM_HW_THREADS-1; i>=0 ; i++) begin
                    if (valid[i] == 1) begin
                        pagerank_stream[tid] = queue_thread[tid];
                        dest_update[tid] = dest_queue[tid];
                        stream_valid[tid] = 1;

                        tid_for_clear = i;
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
