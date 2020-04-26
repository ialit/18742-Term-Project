`default_nettype none

module multiplier_tb();

    // Inputs from user
    logic        clock;
    logic        reset_n;
    logic [31:0] a;
    logic [31:0] b;
    logic        ready_in;

    // Outputs to user
    logic [31:0] out;
    logic        ready_out;

    // -----------------------------------

    // Outputs to Dawson unit
    logic        clk;
    logic        rst;
    logic [31:0] input_a;
    logic [31:0] input_b;
    logic        input_a_stb;
    logic        input_b_stb;
    logic        output_z_ack;

    // Inputs from Dawson unit
    logic [31:0] output_z;
    logic        output_z_stb;
    logic        input_a_ack;
    logic        input_b_ack;

    dawson32_if dut_if(.*);
    multiplier dut(.*);

    initial begin
        $monitor($time,,"a = %f, b = %f, ready_in = %b, out = %f, ready_out = %b",
                 $bitstoshortreal(a), $bitstoshortreal(b), ready_in, $bitstoshortreal(out), ready_out);
        clock = 0;
        reset_n = 0;
        reset_n <= #1 1;
        forever #5 clock = ~clock;
    end

    // Test
    initial begin
        a = 32'd0;
        b = 32'd0;
        ready_in = 0;

        @(posedge clock);
        @(posedge clock);

        a = 32'h3F9D70A4; // 1.23
        b = 32'h4091EB85; // 4.56
        ready_in = 1;

        @(posedge clock);
        
        ready_in = 0;

        @(posedge ready_out);

        #1 assert(out == 32'h40B37B4A); // 5.6088

        @(posedge clock);

        a = 32'h44F6AF68; // 1973.481445
        b = 32'h4610099B; // 9218.401367
        ready_in = 1;

        @(posedge clock);

        ready_in = 0;

        @(posedge ready_out);

        #1 assert(out == 32'h4B8ACBEC); // 18192344.0

        @(posedge clock);

        a = 32'h473FF936; // 49145.210938
        b = 32'hC6DDE29C; // -28401.304688
        ready_in = 1;

        @(posedge clock);

        ready_in = 0;

        @(posedge ready_out);

        #1 assert(out == 32'hCEA66413); // -1395788160.0

        @(posedge clock);
        @(posedge clock);

        $finish;
    end

endmodule: multiplier_tb