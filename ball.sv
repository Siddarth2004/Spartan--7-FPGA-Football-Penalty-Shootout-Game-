//-------------------------------------------------------------------------
//    Ball.sv                                                            --
//    Viral Mehta                                                        --
//    Spring 2005                                                        --
//                                                                       --
//    Modified by Stephen Kempf     03-01-2006                           --
//                                  03-12-2007                           --
//    Translated by Joe Meng        07-07-2013                           --
//    Modified by Zuofu Cheng       08-19-2023                           --
//    Modified by Satvik Yellanki   12-17-2023                           --
//    Fall 2024 Distribution                                             --
//    
//    Modified finally by sn28 and vishnu5 for use in our final project  --
//    Fifa Penalty Shootout Game with Animation, Graphics, Sound, and Sprites --                                                              --
//    For use with ECE 385 USB + HDMI Lab                                --
//    UIUC ECE Department                                                 --
//-------------------------------------------------------------------------

//-------------------------------------------------------------------------
//    Ball.sv                                                            --
//    Viral Mehta                                                        --
//    Spring 2005                                                        --
//                                                                       --
//    Modified by Stephen Kempf     03-01-2006                           --
//                                  03-12-2007                           --
//    Translated by Joe Meng        07-07-2013                           --
//    Modified by Zuofu Cheng       08-19-2023                           --
//    Modified by Satvik Yellanki   12-17-2023                           --
//    Fall 2024 Distribution                                             --
//    
//    Modified finally by sn28 and vishnu5 for use in our final project  --
//    Fifa Penalty Shootout Game with Animation, Graphics, Sound, and Sprites --                                                              --
//    For use with ECE 385 USB + HDMI Lab                                --
//    UIUC ECE Department                                                 --
//-------------------------------------------------------------------------

module ball (
    input logic Reset,
    input logic frame_clk,
    input logic [7:0] keycode_shooter,
    input logic [7:0] keycode_keeper,
    input logic player_at_ball, // Shooter at ball

    output logic [9:0] BallX,
    output logic [9:0] BallY,
    output logic [9:0] BallS,
    output logic save_detected // Signal for save detection
);

    // State enumeration
    typedef enum logic [2:0] {IDLE, WAIT_PLAYER, SHOOT_UP, SHOOT_LEFT, SHOOT_RIGHT} ball_state_t;
    ball_state_t ball_state;

    // Ball parameters
    parameter [9:0] Ball_X_Center = 320;
    parameter [9:0] Ball_Y_Center = 365;
    parameter [9:0] Ball_X_Step = 0.5;
    parameter [9:0] Ball_Y_Step = 2;

    // Adjusted parameters for goal shots
    parameter [9:0] LEFT_CORNER_X = 180;  // Top-left corner X position
    parameter [9:0] RIGHT_CORNER_X = 350; // Top-right corner X position

    assign BallS = 16; // Ball size

    // Control signals for shooting directions
    logic shoot_up_req, shoot_left_req, shoot_right_req;

    // Ball state machine
    always_ff @(posedge frame_clk or posedge Reset) begin
        if (Reset) begin
            BallX <= Ball_X_Center;
            BallY <= Ball_Y_Center;
            ball_state <= IDLE;
            shoot_up_req <= 1'b0;
            shoot_left_req <= 1'b0;
            shoot_right_req <= 1'b0;
            save_detected <= 1'b0;
        end else begin
            case (ball_state)
                IDLE: begin
                    // Check for shooter input to start shot preparation
                    if (keycode_shooter == 8'h1A) begin // W
                        shoot_up_req <= 1'b1;
                        ball_state <= WAIT_PLAYER;
                    end else if (keycode_shooter == 8'h04) begin // A
                        shoot_left_req <= 1'b1;
                        ball_state <= WAIT_PLAYER;
                    end else if (keycode_shooter == 8'h07) begin // D
                        shoot_right_req <= 1'b1;
                        ball_state <= WAIT_PLAYER;
                    end
                end

                WAIT_PLAYER: begin
                    // Wait for the player to reach the ball
                    if (player_at_ball) begin
                        if (shoot_up_req) ball_state <= SHOOT_UP;
                        else if (shoot_left_req) ball_state <= SHOOT_LEFT;
                        else if (shoot_right_req) ball_state <= SHOOT_RIGHT;
                    end
                end

                SHOOT_UP: begin
                    BallY <= BallY - Ball_Y_Step;
                    if (BallY <= 110) begin
                        save_detected <= (keycode_keeper == 8'h1A); // Check for keeper save
                        reset_ball();
                    end
                end

                SHOOT_LEFT: begin
                    BallX <= BallX - Ball_X_Step;
                    BallY <= BallY - Ball_Y_Step;
                    if (BallX <= LEFT_CORNER_X && BallY <= 100) begin
                        save_detected <= (keycode_keeper == 8'h04); // Check for keeper save
                        reset_ball();
                    end
                end

                SHOOT_RIGHT: begin
                    BallX <= BallX + Ball_X_Step;
                    BallY <= BallY - Ball_Y_Step;
                    if (BallX >= RIGHT_CORNER_X && BallY <= 100) begin
                        save_detected <= (keycode_keeper == 8'h07); // Check for keeper save
                        reset_ball();
                    end
                end
            endcase
        end
    end

    // Helper task to reset the ball position and state
    task reset_ball();
        BallX <= Ball_X_Center;
        BallY <= Ball_Y_Center;
        ball_state <= IDLE;
        shoot_up_req <= 1'b0;
        shoot_left_req <= 1'b0;
        shoot_right_req <= 1'b0;
    endtask

endmodule
