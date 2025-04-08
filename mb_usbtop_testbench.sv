`timescale 1ns/1ps

module color_mapper_tb;

    // Inputs
    logic clk_25MHz;
    logic vde;
    logic vsync;
    logic reset_ah;
    logic [9:0] DrawX, DrawY;
    logic [31:0] keycode;

    // Outputs
    logic [3:0] Red, Green, Blue;
    logic player_at_ball_signal;
    logic save_detect;

    // Instantiate the Device Under Test (DUT)
    color_mapper dut (
        .DrawX(DrawX),
        .DrawY(DrawY),
        .clk_25MHz(clk_25MHz),
        .vde(vde),
        .vsync(vsync),
        .reset_ah(reset_ah),
        .keycode(keycode),
        .Red(Red),
        .Green(Green),
        .Blue(Blue),
        .player_at_ball_signal(player_at_ball_signal),
        .save_detect(save_detect)
    );

    // Clock: 25 MHz = 40 ns period
    initial begin
        clk_25MHz = 0;
        forever #20 clk_25MHz = ~clk_25MHz;
    end

    initial begin
        // Initial values
        reset_ah = 1'b1;
        vsync = 1'b0;
        vde = 1'b0;
        DrawX = 10'd0;
        DrawY = 10'd0;
        keycode = 32'h00000000;

        // Wait a few cycles then release reset
        repeat (5) @(posedge clk_25MHz);
        reset_ah = 1'b0;

        // Wait for a few cycles with stable signals
        repeat (5) @(posedge clk_25MHz);

        // Toggle vsync once
        vsync = 1'b1;
        @(posedge clk_25MHz);
        vsync = 1'b0;

        // Provide a few increments of DrawX and DrawY
        DrawX = 10'd10;
        DrawY = 10'd20;
        vde = 1'b1;
        @(posedge clk_25MHz);

        DrawX = 10'd11;
        DrawY = 10'd21;
        @(posedge clk_25MHz);

        // Send a sample keycode (e.g. 'Enter' = 8'h28)
        keycode = 32'h00000028;
        @(posedge clk_25MHz);

        // Return keycode to zero
        keycode = 32'h00000000;
        @(posedge clk_25MHz);

        // A few more cycles
        repeat (5) @(posedge clk_25MHz);

        $stop;
    end

endmodule
