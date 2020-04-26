`default_nettype none

module double_divider_tb();

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

    dawson_if dut_if(.*);
    double_divider dut(.*);

    initial begin
        $monitor($time,,"a = %f, b = %f, ready_in = %b, out = %f, ready_out = %b",
                 $bitstoreal(a), $bitstoreal(b), ready_in, $bitstoreal(out), ready_out);
        clock = 0;
        reset_n = 0;
        reset_n <= #1 1;
        forever #5 clock = ~clock;
    end

    // Test
    initial begin
        a = 64'd0;
        b = 64'd0;
        ready_in = 0;

        @(posedge clock);
        @(posedge clock);

        a = 64'h3FF3AE147AE147AE; // 1.23
        b = 64'h40123D70A3D70A3D; // 4.56
        ready_in = 1;

        @(posedge clock);
        
        ready_in = 0;

        @(posedge ready_out);

        #1 assert(out == 64'h3FD1435E50D79436); // 0.269737

        @(posedge clock);

        a = 64'h409ED5ECFBFC6541; // 1973.48143
        b = 64'h40C201336E2EB1C4; // 9218.4018
        ready_in = 1;

        @(posedge clock);

        ready_in = 0;

        @(posedge ready_out);

        #1 assert(out == 64'h3FCB66FEA2BB1FB6); // 0.214081

        @(posedge clock);

        a = 64'h40E7FF26B851EB85; // 49145.21
        b = 64'hC0DBBC53851EB852; // -28401.305
        ready_in = 1;

        @(posedge clock);

        ready_in = 0;

        @(posedge ready_out);

        #1 assert(out == 64'hBFFBAFA8D7379D3D); // -1.730386

        @(posedge clock);
        @(posedge clock);

        $finish;
    end

endmodule: double_divider_tb