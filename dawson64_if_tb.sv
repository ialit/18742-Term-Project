module dawson64_if_tb();

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

    dawson64_if dut(.*);

    initial begin
        clock = 0;
        reset_n = 0;
        reset_n <= #1 1;
        forever #5 clock = ~clock;
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
        @(posedge clock); #1 assert(clk == clock);  // RESET -> IDLE
        @(posedge clock); #1 assert(clk == clock);  // IDLE -> IDLE

        a = 64'd1;
        b = 64'd2;

        @(posedge clock);   // IDLE -> IDLE
        
        ready_in = 1;
        
        @(posedge clock);   // IDLE -> TX_A
        
        ready_in = 0;

        #1
        assert(input_a == a);
        assert(input_a_stb);
        assert(~output_z_ack);

        @(posedge clock);   // TX_A -> TX_A
        
        input_a_ack = 1;
        
        #1 
        assert(input_a == a);
        assert(input_a_stb);
        assert(~input_b_stb);
        assert(~output_z_ack);

        @(posedge clock);   // TX_A -> TX_B

        input_a_ack = 0;

        #1
        assert(input_b == b);
        assert(input_b_stb);
        assert(~input_a_stb);
        assert(~output_z_ack);

        @(posedge clock);   // TX_B -> TX_B

        input_b_ack = 1;

        @(posedge clock);   // TX_B -> WAIT_RX

        input_b_ack = 0;

        @(posedge clock);   // WAIT_RX -> WAIT_RX
        @(posedge clock);   // WAIT_RX -> WAIT_RX
        @(posedge clock);   // WAIT_RX -> WAIT_RX
        @(posedge clock);   // WAIT_RX -> WAIT_RX

        output_z = 64'd3;
        output_z_stb = 1;

        #1
        assert(~output_z_ack);

        @(posedge clock);   // WAIT_RX -> RX

        #1
        assert(output_z_ack);
        assert(~ready_out);

        @(posedge clock);   // RX -> USER_RX

        output_z_stb = 0;

        #1
        assert(~output_z_ack);
        assert(ready_out);
        assert(out == output_z);

        @(posedge clock);   // USER_RX -> IDLE
        @(posedge clock);   // IDLE -> IDLE

        $finish;
    end

endmodule: dawson64_if_tb