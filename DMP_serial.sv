/******************************************************************************
Module that syncronizes between threads for execution in a deterministic order.
Converts the stream of data from multiple threads into an ordered sequence of 
streams. 

After all threads sync, on each clock cycle there is a packet of data

A signal is passed to indicate start and end of packet.

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
    input logic [0 : NUM_HW_THREADS - 1][63 : 0] page_rank_gather[NODES_IN_GRAPH],
    input logic done[NUM_HW_THREADS],

    //Output
    output logic [63:0] pagerank_serial_stream [NODES_IN_GRAPH],
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
    assign stream_done = (thread_id == NUM_HW_THREADS)?1:0;

    always_comb begin
        pagerank_serial_stream = 0;
        next_thread = 0;
        unique case(currentState) 
            WAIT_FOR_THREADS: begin
                nextState = (sync) ? SEND : WAIT_FOR_THREADS;
            end
            SEND: begin
                for(int i=0; i<NODES_IN_GRAPH; i++) begin
                    pagerank_serial_stream[i] = page_rank_gather[thread_id][i];
                end
                next_thread = 1;
                nextState = (thread_id == NUM_HW_THREADS) ? END : SEND;
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
        if ((~reset_n) || (clear))
            counter <=0;
        else if (~enable)
            counter <= counter;
        else 
            counter <= counter + 1;
    end

endmodule