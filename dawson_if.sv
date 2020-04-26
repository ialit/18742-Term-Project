/******************************************************************************

Authors:
    Kevin Rohan (krohan@andrew.cmu.edu)
    Eric Chen (echen2@andrew.cmu.edu)
    Deepak Pallerla (dpallerl@andrew.cmu.edu)

Module that implements Jonathan Dawson's "chips" interconnect, specified at
http://dawsonjon.github.io/Chips-2.0/user_manual/interface.html

This module should be used to interface to Dawson's floating point blocks,
available at https://github.com/dawsonjon/fpu

Use this module with 2 states. In the first state, provide the inputs
a and b, and assert ready_in. In the second state, deassert ready_in
and wait for the module to assert ready_out, then read the output immediately.

INPUT FORMAT:

    clock and reset_n : for functioning of the circuit

    a and b : 64-bit double precision floating point inputs

    ready_in : tells module that a and b are valid values, begin computation

OUTPUT FORMAT:

    out :
        64-bit double precision floating point output

    ready_out :
        indicates that the output is valid (Dawson unit has completed its operation)

*******************************************************************************/


module dawson_if (
    // Inputs from user
    input  logic        clock,
    input  logic        reset_n,
    input  logic [63:0] a,
    input  logic [63:0] b,
    input  logic        ready_in,

    // Outputs to user
    output logic [63:0] out,
    output logic        ready_out,

    // -----------------------------------

    // Outputs to Dawson unit
    output logic clk,
    output logic rst,
    output logic [63:0] input_a,
    output logic [63:0] input_b,
    output logic input_a_stb,
    output logic input_b_stb,
    output logic output_z_ack,

    // Inputs from Dawson unit
    input  logic [63:0] output_z,
    input  logic output_z_stb,
    input  logic input_a_ack,
    input  logic input_b_ack
);

    typedef enum logic [2:0] {
        RESET,
        IDLE,
        TX_A,
        TX_B,
        WAIT_RX,
        RX,
        USER_RX
    } state_t;

    state_t state;
    state_t nextState;

    // Internal copies of a and b
    logic [63:0] a_saved;
    logic [63:0] b_saved;
    logic [63:0] out_saved;

    // State transitions
    always_ff @(posedge clock, negedge reset_n) begin
        if (~reset_n) begin
            state <= RESET;
        end
        else begin
            if (state == IDLE && nextState == TX_A) begin
                a_saved <= a;
                b_saved <= b;
            end

            if (state == RX && nextState == USER_RX) begin
                out_saved <= output_z;
            end

            state <= nextState;
        end
    end

    // State outputs and transitions
    always_comb begin
        out = 64'd0;
        ready_out = 0;

        clk = clock;
        rst = 0;
        input_a = 64'd0;
        input_b = 64'd0;
        input_a_stb = 0;
        input_b_stb = 0;
        output_z_ack = 0;

        nextState = state;

        unique case (state)
            RESET: begin
                rst = 1;
                nextState = IDLE;
            end
            IDLE: begin
                if (ready_in) begin
                    nextState = TX_A;
                end
            end
            TX_A: begin
                input_a = a_saved;
                input_a_stb = 1;
                if (input_a_ack) begin
                    nextState = TX_B;
                end
            end
            TX_B: begin
                input_b = b_saved;
                input_b_stb = 1;
                if (input_b_ack) begin
                    nextState = WAIT_RX;
                end
            end
            WAIT_RX: begin
                if (output_z_stb) begin
                    nextState = RX;
                end
            end
            RX: begin
                output_z_ack = 1;
                nextState = USER_RX;
            end
            USER_RX: begin
                out = out_saved;
                ready_out = 1;
                nextState = IDLE;
            end
        endcase
    end

endmodule: dawson_if