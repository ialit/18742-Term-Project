/******************************************************************************
Module to compute page-rank scatter phase of a partition of a graph. It involes
sending the value of pagerank_old[parent-node]/outdegree[parent-node] for
corresponding child node id.

Authors:
    Kevin Rohan (krohan@andrew.cmu.edu)
    Eric Chen (echen2@andrew.cmu.edu)
    Deepak Pallerla (dpallerl@andrew.cmu.edu) 

- Use Parameter to set the following 2 parameters

    a. NODES_IN_PARTITION - 
        The number of nodes in the graph partition
    b. MAX_OUT_DEGREE - 
        This part is used to indictate the maximum out degree.
        This is used to set the stream size for the destination stream

INPUT FORMAT:

    clock and reset_n : for functioning of the circuit

    pagerank_enable : pagerank enabled to perform operation

    nextIteration : compute nextIteration of pagerank

    The graph partition is inputed by:
        source_id[NODES_IN_PARTITION] | out_degree[NODES_IN_PARTITION] | dest_id[NODES_IN_PARTITION][MAX_DEGREE]

    source_id:
        Source ID indicates the ID of the vertex.

    out_degree:
        The number of NODES_IN_PARTITION connected to the corresponding source vector.

    dest_id:
        The IDs of vertices connected to the corresponding source vector.
        If the numbers of IDs less than max degree, add a dest_id < 0 to signify end of stream.

OUTPUT FORMAT:

    pagerank_scatter_op:
        Provides the intermediate result of pagerank corresponding to the node ID from scatter phase.
        
    node_id:
        The node_id of the corresponding intermediate result of pagerank from scatter phase.

    output_ready:
        Signifies to the gather stage of pagerank to queue the results for updating

    operation_complete:
        Signifies every loop has completed in the pagerank algorithm for the current iteration

*******************************************************************************/
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
    input logic [63:0] page_rank_old [NODES_IN_GRAPH],

    //Handshaking 
    input logic update_complete,

    //Output
    output logic [63:0] pagerank_scatter_op,
    output logic [31:0] node_id,
    output logic output_ready,
    output logic operation_complete 
);
    logic [63:0] page_rank_init [NODES_IN_GRAPH];
    logic [31:0] i,j;
    logic outer_loop_enable, inner_loop_enable;
    logic inner_loop_clear, outer_loop_clear;

    logic [63:0] divider_ip_a;
    logic [63:0] divider_ip_b;
    logic divider_start;
    

    counter32_bit source_id_counter (.clock(clock), .reset_n(reset_n), .enable(outer_loop_enable), .clear(outer_loop_clear), .count_val(i));
    counter32_bit dest_id_counter (.clock(clock), .reset_n(reset_n), .enable(inner_loop_enable), .clear(inner_loop_clear), .count_val(j));
    dawson_divider scatter_divider (.clock(clock), .reset_n(reset_n), .ready_in(divider_start), .a(divider_ip_a),.b(divider_ip_b), .out(pagerank_scatter_op), .ready_out(output_ready));

    typedef enum logic [2:0] {START, SCAN_LINK, QUEUE, WAIT_FOR_DIVIDER, WAIT_FOR_UPDATE, INC, END} states_t;

    states_t currentState, nextState;

    always_comb begin
        nextState = SCAN_LINK;
        pagerank_scatter_op = 0;
        node_id = 0;
        operation_complete = 0;
        outer_loop_enable = 0;
        inner_loop_enable = 0;
        outer_loop_clear = 0;
        inner_loop_clear = 0;

        divider_ip_a = 0;
        divider_ip_b = 0;
        divider_start = 0;
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
                    //pagerank_scatter_op = page_rank_init[source_id[i]] / out_degree[source_id[i]]; //Need to figure out how to do it
                    divider_ip_a = page_rank_init[source_id[i]];
                    divider_ip_b = out_degree[i];
                    divider_start = 1;
                    nextState = WAIT_FOR_DIVIDER;
                end
            end
            WAIT_FOR_DIVIDER: begin
                if(output_ready) begin
                    node_id = dest_id[i][j];
                    inner_loop_enable = 1;
                    nextState = WAIT_FOR_UPDATE;
                end
                else begin
                    nextState = WAIT_FOR_DIVIDER;
                end
            end
            WAIT_FOR_UPDATE: begin
                nextState = (update_complete) ? QUEUE : WAIT_FOR_UPDATE;
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


