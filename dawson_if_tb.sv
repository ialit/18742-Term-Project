module dawson_if_tb();

    // Inputs from user
    logic        clock;
    logic        reset_n;
    logic [63:0] a;
    logic [63:0] b;
    logic        ready_in;

    // Outputs to user
    logic [63:0] out;
    logic        ready_out;

    // -----------------------------------

    // Outputs to Dawson unit
    logic        clk;
    logic        rst;
    logic [63:0] input_a;
    logic [63:0] input_b;
    logic        input_a_stb;
    logic        input_b_stb;
    logic        output_z_ack;

    // Inputs from Dawson unit
    logic [63:0] output_z;
    logic        output_z_stb;
    logic        input_a_ack;
    logic        input_b_ack;

    dawson_if dut(.*);

    initial begin
        clock = 0;
        reset_n = 0;
        reset_n <= #1 1;
        forever #5 clock = ~clk;
    end

    initial begin
        a = 64'd0;
        b = 64'd0;
        ready_in = 0;
        output_z = 64'd0;
        output_z_stb = 0;
        input_a_ack = 0;
        input_b_ack = 0;

                                                    // Start in RESET
        @(posedge clock); assert(clk == clock);     // IDLE after this clock
        @(posedge clock); assert(clk == clock);     // IDLE after this clock

        a = 64'd1;
        b = 64'd2;

        @(posedge clock);   // still in IDLE
        
        ready_in = 1;
        
        @(posedge clock);   // WAIT_TX after this clock

        assert(input_a == a);
        assert(input_b == b);
        assert(input_a_stb);
        assert(input_b_stb);
        assert(~output_z_ack);

        @(posedge clock);   // still in WAIT_TX

        assert(input_a == a);
        assert(input_b == b);
        assert(input_a_stb);
        assert(input_b_stb);
        assert(~output_z_ack);

        input_a_ack = 1;
        input_b_ack = 1;

        @(posedge clock);   // WAIT_RX after this clock

        assert(~input_a_stb);
        assert(~input_b_stb);
        assert(~output_z_ack);

        @(posedge clock);   // still in WAIT_RX
        @(posedge clock);   // still in WAIT_RX
        @(posedge clock);   // still in WAIT_RX

        assert(~output_z_ack);

        output_z = 64'd3;
        output_z_stb = 1;

        @(posedge clock);   // RECEIVE after this clock

        assert(output_z_ack);
        assert(~ready_out);

        @(posedge clock);   // RX_USER after this clock

        assert(~output_z_ack);
        assert(ready_out);
        assert(out == output_z);

        @(posedge clock);   // IDLE after this clock
        @(posedge clock);   // still IDLE

        $finish;
    end

endmodule: dawson_if_tb