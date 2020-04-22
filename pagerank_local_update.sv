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
        parameter int NODES_IN_GRAPH = 32;
    )
(
    //Circuit inputs
    input logic clock,
    input logic reset_n,

    //Inputs from scatter phase
    input logic [63:0] page_rank_scatter,
    input logic [31:0] dest_id,
    input logic pagerank_ready,

    //Output
    output logic [63:0] pagerank_pre_damp [NODES_IN_GRAPH],
    output logic gather_operation_complete 
);
    int i, j;

    logic [63:0] pagerank_register [NODES_IN_GRAPH];

    always_ff @(posedge clock, negedge reset_n) begin
        if (~reset_n) begin
            for (int i=0; i<NODES_IN_GRAPH; i++)
                pagerank_register[i] <= 0;
            gather_operation_complete <= 0; 
        end
        else begin
            if (pagerank_ready) begin
                pagerank_register[dest_id] <= pagerank_register[dest_id] + page_rank_scatter;
            end
            if (scatter_operation_complete)
                gather_operation_complete <= 1;
        end
    end
endmodule
