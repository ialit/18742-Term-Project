// This file shows how to use the dawson interface. Usage must be integrated
// into a state machine by adding a START and WAIT state.

module dawson_example();

    // Inputs from user (your code)
    logic        clock;
    logic        reset_n;
    logic [63:0] a;
    logic [63:0] b;
    logic        ready_in;

    // Outputs to user (your code)
    logic [63:0] out;
    logic        ready_out;

    // Outputs to Dawson unit
    // You don't need to worry what these are, but each
    // Dawson unit needs to have its own set (except clk and rst)
    logic        clk;
    logic        rst;
    logic [63:0] input_a;
    logic [63:0] input_b;
    logic        input_a_stb;
    logic        input_b_stb;
    logic        output_z_ack;

    // Inputs from Dawson unit
    // Again, you don't need to worry what these are, but each
    // Dawson unit needs to have its own set
    logic [63:0] output_z;
    logic        output_z_stb;
    logic        input_a_ack;
    logic        input_b_ack;

    typedef enum logic [3:0] {
        RESET,  // This state only included because Dawson unit needs a full clock cycle to reset.
        START,  // add this to your code
        WAIT,   // add this to your code
        END
    } state_t;

    state_t state, nextState;

    // Constants (for sake of example)
    logic [63:0] in1;
    logic [63:0] in2;
    assign in1 = 64'h3FF3AE147AE147AE; // 1.23
    assign in2 = 64'h40123D70A3D70A3D; // 4.56

    // Register for answer
    logic [63:0] ans;

    dawson_if adder_if(.*); // use one interface for each Dawson unit
    double_adder adder(.*); // replace this with a multiplier or divider as needed

    // Setup clock and reset to run this example
    initial begin
        $monitor($time,,"a = %f, b = %f, ready_in = %b\tout = %f, ready_out=%b",
            $bitstoreal(a), $bitstoreal(b), ready_in, $bitstoreal(out), ready_out);
        clock = 0;
        reset_n = 0;
        reset_n <= #1 1;
        for (int i = 0; i < 50; i++) begin
            #5 clock = ~clock;
        end
    end

    // Drive state machine and store Dawson output
    always_ff @(posedge clock, negedge reset_n) begin
        if (~reset_n) begin
            state <= RESET;
        end
        else begin
            state <= nextState;

            // Store interface output into ans.
            // Note the ready_out condition is the same
            // as the condition for the transition out of
            // the WAIT state.
            if (ready_out) begin
                ans <= out;
            end
        end
    end

    // State outputs and transitions
    always_comb begin
        a = 64'd0;
        b = 64'd0;
        ready_in = 0;
        unique case (state)
            RESET: begin
                nextState = START;
            end
            START: begin    // Add this state to your state machine
                a = in1;
                b = in2;
                ready_in = 1;   // only asserted for 1 clock cycle
                nextState = WAIT;
            end
            WAIT: begin     // Add this state to your state machine
                if (ready_out) begin
                    // computation output captured in always_ff above

                    nextState = END;    // replace this transition to wherever your original
                                        // state machine needs to go to
                end
            end
            END: begin
                nextState = END;
            end
        endcase
    end

endmodule: dawson_example