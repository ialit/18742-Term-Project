/******************************************************************************
Sums the stream, determines the computes the pagerank using the damping factor

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

    stream_start:
        Start of stream

    stream_end:
        End of stream

    damping_factor:
        The damping factor for computing page rank

OUTPUT FORMAT:

    pagerank_final[NODES_IN_GRAPH]:
        Pagerank final of all the nodes in the iteration.

    delta:
        (Damping - Undamped) - determines the convergences criteria

*******************************************************************************/
module DMP_serial_final
    #(
        parameter int NUM_HW_THREADS = 8,
        parameter int NODES_IN_GRAPH = 32
    )
(
    //Circuit inputs
    input logic clock,
    input logic reset_n,

    //Input from DMP phase
    input logic [63:0] pagerank_serial_stream [NODES_IN_GRAPH],
    input logic stream_start,
    input logic stream_done,

    //Input related to the damping factor
    input logic [63:0] damping_factor,

    //Output logic of all nodes
    output logic [63:0] pagerank_final[NODES_IN_GRAPH],
    output logic [63:0] delta,
    output logic pagerank_iteration_complete
);

    typedef enum logic[2:0] {WAIT_FOR_READY, ACCUMILATE_SUM, DAMP, DELTA, END} states_t;

    states_t currentState, nextState;
    logic [31:0] thread_id;
    logic next_thread;
    logic [31:0] pagerank_intermediate;

    counter32_bit_final thread_counter (.clock(clock), .reset_n(reset_n), .enable(next_thread), .count_val(thread_id));

    function logic[63:0] float_absolute (logic [63:0] ip_val);
        // float_absolute = (((shortreal)ip_val) < 1) ? (-((shortreal)ip_val)) : ip_val;
        float_absolute = 64'd420;
    endfunction

    always_comb begin
        next_thread = 0;
        pagerank_iteration_complete = 0;
        unique case(currentState) 
            WAIT_FOR_READY: begin
                nextState = (stream_start) ? ACCUMILATE_SUM : WAIT_FOR_READY;
            end
            ACCUMILATE_SUM: begin
                next_thread = 1;
                nextState = (thread_id == NODES_IN_GRAPH) ? DAMP : ACCUMILATE_SUM;
            end
            DAMP: begin
                nextState = DELTA;
            end
            DELTA: begin
                nextState = END;
            end
            END: begin
                nextState = END;
                pagerank_iteration_complete = 1;
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
        if (~reset_n) begin
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                pagerank_intermediate [i] <= 0;
            end
            delta <= 64'd0; // Presumably this is what was intended
        end
        if (currentState == ACCUMILATE_SUM) begin
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                pagerank_intermediate[i] <= pagerank_intermediate[i] + pagerank_serial_stream[i];
            end
        end
        else if (currentState == DAMP) begin
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                pagerank_final[i] <= (1-damping_factor)/(NODES_IN_GRAPH) + (damping_factor)*(pagerank_intermediate[i]);
            end
        end
        else if (currentState == DELTA) begin
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

    output logic [31:0] count_val
);

    logic [31:0] counter;

    assign count_val = counter;

    always_ff @(posedge clock, negedge reset_n) begin
        if (~reset_n)
            counter <=0;
        else if (~enable)
            counter <= counter;
        else 
            counter <= counter + 1;
    end

endmodule