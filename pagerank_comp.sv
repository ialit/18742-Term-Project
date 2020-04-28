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
    input logic [63:0] threshold,

    //Input related to the damping factor
    input logic [63:0] damping_factor,

    //Output logic of all nodes
    output logic [63:0] pagerank_final[NODES_IN_GRAPH],
    output logic [31:0] iteration_number,
    output logic pagerank_complete,
    output logic nextIteration
);

    typedef enum logic[2:0] {WAIT_FOR_READY, ACCUMILATE_SUM, DAMP, DELTA, END} states_t;

    states_t currentState, nextState;
    logic [63:0] pagerank_intermediate[NODES_IN_GRAPH];
    logic [63:0] delta;
    logic [31:0] iteration_count;
  	logic next_itr;

    counter32_bit_final iteration_counter (.clock(clock), .reset_n(reset_n), .enable(next_itr), .count_val(iteration_count), .clear(1'b0));

    assign nextIteration = next_itr;
    assign iteration_number = iteration_count;
    
    function logic[63:0] float_absolute (logic [63:0] ip_val);
        //float_absolute = 64'd420;             //NOT sure what this was for 
        float_absolute = ((ip_val[63] == 1) ? (-ip_val) : ip_val);
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