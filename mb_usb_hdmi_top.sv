//-------------------------------------------------------------------------
//    mb_usb_hdmi_top.sv                                                 --
//    Zuofu Cheng                                                        --
//    2-29-24                                                            --
//                                                                       --
//                                                                       --
//    Spring 2024 Distribution                                           --
//                                                                       --
//    For use with ECE 385 USB + HDMI                                    --
//    University of Illinois ECE Department                              --
//-------------------------------------------------------------------------

module mb_usb_hdmi_top (
    input logic Clk,
    input logic reset_rtl_0,
    // USB signals
    input logic [0:0] gpio_usb_int_tri_i,
    output logic gpio_usb_rst_tri_o,
    input logic usb_spi_miso,
    output logic usb_spi_mosi,
    output logic usb_spi_sclk,
    output logic usb_spi_ss,
    // UART
    input logic uart_rtl_0_rxd,
    output logic uart_rtl_0_txd,
    // HDMI
    output logic hdmi_tmds_clk_n,
    output logic hdmi_tmds_clk_p,
    output logic [2:0] hdmi_tmds_data_n,
    output logic [2:0] hdmi_tmds_data_p,
    // HEX displays
    output logic [7:0] hex_segA,
    output logic [3:0] hex_gridA,
    output logic [7:0] hex_segB,
    output logic [3:0] hex_gridB
);

    // Existing signal declarations
    logic [9:0] drawX, drawY;           // Coordinates for drawing
    logic clk_25MHz, clk_125MHz, clk;   // Clock signals
    logic locked;                       // Clock locking signal
    logic [23:0] field_color;           // Color data from BRAM
    logic [18:0] bram_address;          // BRAM address
    logic [3:0] red, green, blue;       // Color output
    logic reset_ah;
    logic [31:0] keycode0_gpio, keycode1_gpio;
    logic save_detect;

    // New state machine signals
    logic [1:0] current_state;          // 2-bit state: 00 = Main Menu, 01 = Game Mode
    logic start_button_pressed, exit_button_pressed;

    assign reset_ah = reset_rtl_0;

    // State Machine Logic
    always_ff @(posedge Clk or posedge reset_ah) begin
        if (reset_ah) begin
            current_state <= 2'b00; // Default to Main Menu
        end else begin
            case (current_state)
                2'b00: // Main Menu
                    if (start_button_pressed) current_state <= 2'b01; // Transition to Game Mode
                2'b01: // Game Mode
                    if (exit_button_pressed) current_state <= 2'b00; // Transition to Main Menu
            endcase
        end
    end

    // Button Press Detection
    assign start_button_pressed = (keycode0_gpio[7:0] == 8'h28); // Enter key for Start Game
    assign exit_button_pressed = (keycode0_gpio[7:0] == 8'h29);  // ESC key for Exit to Menu

    // Clock wizard configured with a 1x and 5x clock for HDMI
    clk_wiz_0 clk_wiz (
        .clk_out1(clk_25MHz),
        .clk_out2(clk_125MHz),
        .reset(reset_ah),
        .locked(locked),
        .clk_in1(Clk)
    );

    // VGA Sync signal generator
    vga_controller vga (
        .pixel_clk(clk_25MHz),
        .reset(reset_ah),
        .hs(hsync),
        .vs(vsync),
        .active_nblank(vde),
        .drawX(drawX),
        .drawY(drawY)
    );    

    // Real Digital VGA to HDMI converter
    
    hdmi_tx_0 vga_to_hdmi (
        // Clocking and Reset
        .pix_clk(clk_25MHz),
        .pix_clkx5(clk_125MHz),
        .pix_clk_locked(locked),
        // Reset is active LOW
        .rst(reset_ah),
        // Color and Sync Signals
        .red(red),
        .green(green),
        .blue(blue),
        .hsync(hsync),
        .vsync(vsync),
        .vde(vde),
        // Differential outputs
        .TMDS_CLK_P(hdmi_tmds_clk_p),          
        .TMDS_CLK_N(hdmi_tmds_clk_n),          
        .TMDS_DATA_P(hdmi_tmds_data_p),         
        .TMDS_DATA_N(hdmi_tmds_data_n),
        // aux Data (unused)
        .aux0_din(4'b0000),  // Tie unused aux inputs to 0
        .aux1_din(4'b0000),  // Tie unused aux inputs to 0
        .aux2_din(4'b0000),  // Tie unused aux inputs to 0
        .ade(1'b0)           // Tie unused auxiliary enable to 0
    );
    

    // Ball Module
//    ball ball_instance (
//        .Reset(reset_ah),
//        .frame_clk(vsync),
//        .keycode(keycode0_gpio[7:0]),
//        .BallX(ballxsig),
//        .BallY(ballysig),
//        .BallS(ballsizesig)
//    );
    // Keycode HEX drivers
    hex_driver HexA (
        .clk(Clk),
        .reset(reset_ah),
        .in({keycode0_gpio[31:28], keycode0_gpio[27:24], keycode0_gpio[23:20], keycode0_gpio[19:16]}),
        .hex_seg(hex_segA),
        .hex_grid(hex_gridA)
    );
    
    hex_driver HexB (
        .clk(Clk),
        .reset(reset_ah),
        .in({keycode0_gpio[15:12], keycode0_gpio[11:8], keycode0_gpio[7:4], keycode0_gpio[3:0]}),
        .hex_seg(hex_segB),
        .hex_grid(hex_gridB)
    );



     // Instantiate MicroBlaze block
    mb_block mb_block_i (
        .clk_100MHz(Clk),
        .gpio_usb_int_tri_i(gpio_usb_int_tri_i),
        .gpio_usb_keycode_0_tri_o(keycode0_gpio),
        .gpio_usb_keycode_1_tri_o(keycode1_gpio),
        .gpio_usb_rst_tri_o(gpio_usb_rst_tri_o),
        .reset_rtl_0(~reset_ah), // Block designs expect active low reset, all other modules are active high
        .uart_rtl_0_rxd(uart_rtl_0_rxd),
        .uart_rtl_0_txd(uart_rtl_0_txd),
        .usb_spi_miso(usb_spi_miso),
        .usb_spi_mosi(usb_spi_mosi),
        .usb_spi_sclk(usb_spi_sclk),
        .usb_spi_ss(usb_spi_ss)
    );

    // Color Mapper Module
    color_mapper color_instance (
//    .BallX(ballxsig),
//    .BallY(ballysig),
//    .Ball_size(ballsizesig), // Ensure these signals come from the top-level logic
    .DrawX(drawX),
    .DrawY(drawY),
    .clk_25MHz(clk_25MHz),
    .vde(vde),
    .vsync (vsync),
    .reset_ah (reset_ah),
    .keycode (keycode0_gpio),
 //   .current_state(current_state),
    .Red(red),
    .Green(green),
    .Blue(blue),
    .save_detect (save_detect)
);
endmodule