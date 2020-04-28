/******************************************************************************
Module that sums page-ranks and accumilates for the destination id for each
individual partition in each thread.

Authors:
    Kevin Rohan (krohan@andrew.cmu.edu)
    Eric Chen (echen2@andrew.cmu.edu)
    Deepak Pallerla (dpallerl@andrew.cmu.edu) 

- Use Parameter to set the following 2 parameters

    a. NODES_IN_GRAPH - 
        The number of nodes in the graph 

INPUT FORMAT:

    clock and reset_n : for functioning of the circuit

    nextIteration : compute nextIteration of pagerank

    pagerank_enable : pagerank enabled to perform operation

    page_rank_scatter:
        page rank from scatter phase. Received from scatter phase.

    destionation id:
        Each pagerank scatter is for a corresponding destination id.
        Received from scatter phase.
    
    pagerank_ready:
        Indicates that value is ready for updating

    scatter_operation_complete:
        Indicates the scatter operation is complete.
        Received from scatter phase.

OUTPUT FORMAT:

    pagerank_pre_damp [NODES_IN_PARTITION]:
        indicates page rank pre damping factor of individual nodes.
        
    gather_operation_complete:
        gather operation has been completed.

*******************************************************************************/
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
    input logic [63:0] page_rank_scatter,
    input logic [31:0] dest_id,
    input logic pagerank_ready,

    //Output
    output logic [63:0] pagerank_pre_damp [NODES_IN_GRAPH],
    output logic update_complete,
    output logic gather_operation_complete //attach to scatte op complete
);
    int i, j;

    logic [63:0] adder_ip_a;
    logic [63:0] adder_ip_b;
    logic [63:0] adder_out;
    logic adder_out_ready;
    logic adder_in_ready;

    dawson_adder update_adder (.clock(clock), .reset_n(reset_n), .ready_in(adder_in_ready), .a(adder_ip_a),.b(adder_ip_b), .out(adder_out), .ready_out(adder_out_ready));
    
    logic [63:0] pagerank_register [NODES_IN_GRAPH];
    logic [63:0] temp_pagerank_scatter;
    logic [31:0] temp_dest_id;

    typedef enum logic [1:0] {WAIT_FOR_VAL,ADD, WAIT_FOR_ADD ,UPDATE} states_t;

    states_t currentState, nextState;
    
  	assign pagerank_pre_damp = pagerank_register;
    
    
    always_comb begin
        adder_in_ready = 0;
        update_complete = 0;
        unique case(currentState)
            WAIT_FOR_VAL: begin 
                nextState = (pagerank_ready) ? ACCEPT_VAL : WAIT_FOR_VAL;
            end
            ADD: begin
                adder_in_ready = 1;
                adder_ip_a = pagerank_register[temp_dest_id];
                adder_ip_b = temp_pagerank_scatter;
                nextState = WAIT_FOR_ADD;
            end
            WAIT_FOR_ADD: begin
                nextState = (adder_out_ready) ? UPDATE : WAIT_FOR_ADD;
            end
            UPDATE: begin
                update_complete = 1;
                nextState = WAIT_FOR_VAL;
            end
        endcase
    end
    always_ff @(posedge clock, negedge reset_n) begin
        if ((~reset_n) || (nextIteration)) begin
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                pagerank_register[i] <= 0;
            end
            currentState <= WAIT_FOR_VAL;
        end
        else if (pagerank_enable) begin
            currentState <= nextState;
            if (pagerank_ready) begin
                temp_dest_id <= dest_id;
                temp_pagerank_scatter <= page_rank_scatter;
            end
            else if (adder_out_ready) begin
                pagerank_register[temp_dest_id] <= adder_out;
            end
            
        end
    end
endmodule

