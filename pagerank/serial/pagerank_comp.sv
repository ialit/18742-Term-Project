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
    input logic [63:0] damping_factor_sub_1, //damping factor - 1
    input logic [63:0] float_nodes_in_graph, //give float value

    //Output logic of all nodes
    output logic [63:0] pagerank_final[NODES_IN_GRAPH],
    output logic [31:0] iteration_number,
    output logic pagerank_complete,
    output logic nextIteration,
    output logic ack
);

    logic [63:0] pagerank_intermediate[NODES_IN_GRAPH];
    logic [63:0] delta;
    logic [31:0] iteration_count;
  	logic next_itr;

    logic [63:0] divider_ip_a[NODES_IN_GRAPH];
    logic [63:0] divider_ip_b[NODES_IN_GRAPH];
    logic [63:0] divider_op[NODES_IN_GRAPH];
    logic divider_ready_in[NODES_IN_GRAPH];
    logic divider_ready_out[NODES_IN_GRAPH];

    logic [63:0] multiplier_ip_a[NODES_IN_GRAPH];
    logic [63:0] multiplier_ip_b[NODES_IN_GRAPH];
    logic [63:0] multiplier_op[NODES_IN_GRAPH];
    logic multiplier_ready_in[NODES_IN_GRAPH];
    logic multiplier_ready_out[NODES_IN_GRAPH];

    logic [63:0] adder_ip_a[NODES_IN_GRAPH];
    logic [63:0] adder_ip_b[NODES_IN_GRAPH];
    logic [63:0] adder_op[NODES_IN_GRAPH];
    logic adder_ready_in[NODES_IN_GRAPH];
    logic adder_ready_out[NODES_IN_GRAPH];

    logic add_tot_ready;
    logic div_tot_ready;
    logic mul_tot_ready;

    logic add_tot_register[NODES_IN_GRAPH];
    logic div_tot_register;
    logic mul_tot_register[NODES_IN_GRAPH];

    logic [63:0] div_res;
    logic [63:0] mul_res[NODES_IN_GRAPH];
    logic [63:0] add_res[NODES_IN_GRAPH];

    counter32_bit_final iteration_counter (.clock(clock), .reset_n(reset_n), .enable(next_itr), .count_val(iteration_count), .clear(1'b0));

    
    generate
    genvar i;
        for (i=0; i<NODES_IN_GRAPH; i++) begin
            dawson_multiplier scatter_multiplier (.clock(clock), .reset_n(reset_n), .ready_in(multiplier_ready_in[i]), .a(multiplier_ip_a[i]),.b(multiplier_ip_b[i]), 
                                    .out(multiplier_op[i]), .ready_out(multiplier_ready_out[i]));
            dawson_adder scatter_adder ((.clock(clock), .reset_n(reset_n), .ready_in(adder_ready_in[i]), .a(adder_ip_a[i]),.b(adder_ip_b[i]), 
                                    .out(adder_op[i]), .ready_out(adder_ready_out[i]));
        end
    endgenerate
            dawson_divider scatter_divider (.clock(clock), .reset_n(reset_n), .ready_in(divider_ready_in), .a(divider_ip_a),.b(divider_ip_b), 
                                    .out(divider_op), .ready_out(divider_ready_out));

    assign nextIteration = next_itr;
    assign iteration_number = iteration_count;
    
    typedef enum logic[3:0] {WAIT_FOR_READY, ACCUMILATE_SUM, WAIT_FOR_ADD, DAMP, WAIT_FOR_DAMP, 
                            ADD_INT_RES, WAIT_FOR_ADD_INT, DELTA, WAIT_FOR_SUB, COMP_DELTA, 
                            WAIT_FOR_DELTA, CHECK_FOR_STREAM, END} states_t;

    states_t currentState, nextState;

    function logic[63:0] float_absolute (logic [63:0] ip_val);
        //float_absolute = 64'd420;             //NOT sure what this was for 
        if (ip_val[63] == 1)
            ip_val[63] = 0;
        float_absolute = ip_val;
    endfunction

    always_comb begin
        for (int i=0; i<NODES_IN_GRAPH; i++) begin
            add_tot_ready = add_tot_register[i] & 1'b1;
            div_tot_ready = div_tot_register[i] & 1'b1;
            mul_tot_ready = mul_tot_register[i] & 1'b1;
        end
    end
    always_comb begin
        next_itr = 0;
        ack = 0;
        unique case(currentState) 
            WAIT_FOR_READY: begin
                nextState = (stream_start) ? ACCUMILATE_SUM : WAIT_FOR_READY;
            end
            ACCUMILATE_SUM: begin
                nextState =  WAIT_FOR_ADD;
                for (int i=0; i<NODES_IN_GRAPH; i++) begin    
                    adder_ip_a[i] = pagerank_intermediate[i];
                    adder_ip_b[i] = pagerank_serial_stream[i];
                    adder_ready_in[i] = 1;
                end
            end
            WAIT_FOR_ADD: begin
                nextState = (add_tot_ready) ? DAMP : WAIT_FOR_ADD;
            end
            DAMP: begin
                nextState = WAIT_FOR_DAMP;
                divider_ip_a = damping_factor_sub_1;
                divider_ip_b = float_nodes_in_graph;
                divider_ready_in = 1;

                for (int i=0; i<NODES_IN_GRAPH; i++) begin
                    multiplier_ip_a[i] = damping_factor;
                    multiplier_ip_b[i] = pagerank_intermediate[i];
                    multiplier_ready_in[i] = 1;
                end
            end
            WAIT_FOR_DAMP: begin
                nextState = (mul_tot_ready & div_tot_ready) ? ADD_INT_RES : WAIT_FOR_DAMP;
            end
            ADD_INT_RES : begin
                nextState = WAIT_FOR_ADD_INT
                for (int i=0; i<NODES_IN_GRAPH; i++) begin
                    adder_ip_a[i] = div_res;
                    adder_ip_b[i] = mul_res[i];
                    adder_ready_in[i] = 1;
                end
            end
            WAIT_FOR_ADD_INT: begin
                nextState = (add_tot_ready) ? DELTA : WAIT_FOR_ADD_INT;
            end
            DELTA: begin
                nextState = WAIT_FOR_SUB;
                for (int i=0; i<NODES_IN_GRAPH; i++) begin
                    adder_ip_a[i] = pagerank_final[i];
                    adder_ip_b[i] = {~pagerank_intermediate[i][63],pagerank_intermediate[i][62:0]};
                    adder_ready_in[i] = 1;
                end
            end
            WAIT_FOR_SUB: begin
                float_absolute
                nextState = (add_tot_ready) ? COMP_DELTA : WAIT_FOR_SUB; 
            end
            COMP_DELTA: begin
                nextState = WAIT_FOR_DELTA;
                for (int i=0; i<NODES_IN_GRAPH; i++) begin
                    adder_ip_a[i] = add_res[i];
                    adder_ip_b[i] = delta;
                    adder_ready_in[i] = 1;
                end
            end
            WAIT_FOR_DELTA: begin
                nextState = (add_tot_ready) ? CHECK_STREAM : WAIT_FOR_DELTA; 
            end
            CHECK_FOR_STREAM: begin
                nextState = (stream_done) ? END : ACCUMILATE_SUM;
                ack = (stream_done) ? 1'b1 : 1'b0;
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
                add_tot_register [i] <= 0;
                mul_tot_register [i] <= 0;
                div_tot_register [i] <= 0;
            end
            delta <= 64'd0;
        end
        else if (nextState == WAIT_FOR_ADD) begin     
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
               if (adder_ready_out[i] == 1) begin
                    add_tot_register[i] <= adder_ready_out[i];
                    pagerank_intermediate[i] <= adder_op[i]; 
                end
            end
        end
        else if (nextState == DAMP) begin
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                add_tot_register[i] <= 0;
            end
        end
        else if (nextState == WAIT_FOR_DAMP) begin
            if (divider_ready_out) begin
                div_tot_register <= divider_ready_out;
                div_res <= divider_op;
            end
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                if (multiplier_ready_out[i] == 1) begin
                    mul_tot_register[i] <= multiplier_ready_out[i];
                    mul_res[i] <= multiplier_op[i];
                end
            end
        end
        else if (nextState == WAIT_FOR_ADD) begin
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                if (adder_ready_out[i] == 1) begin
                    add_tot_register[i] <= adder_ready_out[i];
                    pagerank_final[i] <= adder_op[i];
                end 
            end
        end
        else if (nextState == DELTA) begin
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                add_tot_register[i] <= 0;
            end
        end
        else if (nextState == WAIT_FOR_SUB) begin
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                if (adder_ready_out[i] == 1) begin
                    add_tot_register[i] <= adder_ready_out[i];
                    add_res[i] <= adder_op[i];
                end
            end
        end
        else if (nextState == COMP_DELTA) begin
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                add_tot_register[i] <= 0;
            end
        end
        else if (nextState == WAIT_FOR_DELTA) begin
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                if (adder_ready_out[i] == 1) begin
                    add_tot_register[i] <= adder_ready_out[i];
                    add_res[i] <= adder_op[i];
                end
            end
        end
        else if (nextState == CHECK_FOR_STREAM) begin
            for (int i=0; i<NODES_IN_GRAPH; i++) begin
                add_tot_register[i] <= 0;
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