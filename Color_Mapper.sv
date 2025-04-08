//-------------------------------------------------------------------------
//    Color_Mapper.sv                                                    --
//    Stephen Kempf                                                      --
//    3-1-06                                                             --
//                                                                       --
//    Modified by David Kesler  07-16-2008                               --
//    Translated by Joe Meng    07-07-2013                               --
//    Modified by Zuofu Cheng   08-19-2023                               --
//                                                                       --
//    Fall 2023 Distribution                                             --
//                                                                       --
//    For use with ECE 385 USB + HDMI                                    --
//    University of Illinois ECE Department                              --
//-------------------------------------------------------------------------

module color_mapper (
    input logic [9:0] DrawX, DrawY, // Ball and pixel positions
    input logic clk_25MHz, vde, vsync, reset_ah,                           // Clock and blanking signal,                        // Current state: 00 = Menu, 01 = Game
    input logic [31:0] keycode,    // Key input for shooting
    
    output logic [3:0] Red, Green, Blue,                    // Final RGB outputs
    output logic player_at_ball_signal, // NEW OUTPUT SIGNAL
    output logic save_detect
);

    // Signal declarations
    logic ball_on, goalpost_on, net_on, kickspot_on, player_on, goalie_on;
    logic [3:0] ball_red, ball_green, ball_blue;
    logic [3:0] goalpost_red, goalpost_green, goalpost_blue;
    logic [3:0] net_red, net_green, net_blue;
    logic [3:0] player_Red, player_Green, player_Blue;
    logic [3:0] fb_red, fb_green, fb_blue; // Colors from Football_example module
    logic [3:0] kickspot_red, kickspot_green, kickspot_blue;
    logic [3:0] player_red, player_green, player_blue;
    logic [3:0] goalie_red, goalie_green, goalie_blue;
    logic reset_game;       // Signal to reset the game after a goal
    logic [9:0] shooter_pos; // Position of the shooter for motion
    logic shooting;         // Indicate shooting actionic 
    logic [1:0] move_counter;
    logic [9:0] goalie_x, goalie_y;
    logic goal_detected;
    logic [1:0] current_state;
    logic [3:0] score_player, score_keeper; // 4-bit scores for player and keeper
    logic [9:0] BallX, BallY, Ball_size;
    logic vsync_prev;
    logic frame_start;
    logic [3:0] anim_counter;
    logic [7:0] keycode_shooter, keycode_keeper;
    logic player_scren_on;
    
        // New counters for attempts
    logic [2:0] player_goals;   // count of goals scored
    logic [2:0] keeper_saves;   // count of keeper saves

    // Parameters for scoreboard circles
    parameter CIRCLE_RADIUS = 10;
    parameter ATTEMPT_SPACING = 20;  // Vertical spacing between attempts

    
    parameter MENU = 2'b00, PLAYER_COLOR_SELECTION = 2'b10, GAME = 2'b01;
    
    logic [3:0] selected_shooter_red, selected_shooter_green, selected_shooter_blue;

    // Dynamically determine which keycode corresponds to the shooter and the keeper
    always_comb begin
        keycode_shooter = 8'h00;
        keycode_keeper = 8'h00;
    
        // If the first keycode corresponds to a shooter action
        if (keycode[7:0] == 8'h1A || keycode[7:0] == 8'h04 || keycode[7:0] == 8'h07) begin
            keycode_shooter = keycode[7:0];
            keycode_keeper = keycode[15:8]; // Assign keeper to the other keycode
        end
        // If the second keycode corresponds to a shooter action
        else if (keycode[15:8] == 8'h1A || keycode[15:8] == 8'h04 || keycode[15:8] == 8'h07) begin
            keycode_shooter = keycode[15:8];
            keycode_keeper = keycode[7:0]; // Assign keeper to the other keycode
        end
    end
    
    // Multi-key press detection and save logic
    always_comb begin
        save_detect = 1'b0; // Default: no save
        if (keycode_shooter != 8'h00 && keycode_keeper != 8'h00) begin
            // Check specific combinations for save
            if ((keycode_shooter == 8'h1A && keycode_keeper == 8'h52) ||  // W + Up Arrow
                (keycode_shooter == 8'h04 && keycode_keeper == 8'h50) ||  // A + Left Arrow
                (keycode_shooter == 8'h07 && keycode_keeper == 8'h4F)) begin // D + Right Arrow
                save_detect = 1'b1; // Save detected
            end
        end
    end
    
    always_comb begin
        goal_detected = 1'b0; // Default: no goal
        if (!save_detect && BallY <= 110 && BallX >= 220 && BallX <= 420) begin
            goal_detected = 1'b1; // Goal detected
        end
    end
    

    
    assign frame_start = vsync;
    
    logic [1:0] slow_count; // A small counter to divide the animation speed

    always_ff @(posedge clk_25MHz or posedge reset_ah) begin
        if (reset_ah) begin
            anim_counter <= 4'd0;
            slow_count <= 2'd0;
        end else if (frame_start) begin
            slow_count <= slow_count + 2'd1;
            // Only increment anim_counter every 2 frames
            if (slow_count == 2'd1) begin
                anim_counter <= anim_counter + 4'd1;
                slow_count <= 2'd0; 
            end
        end
    end
    
   always_ff @(posedge clk_25MHz or posedge reset_ah) begin
    if (reset_ah) begin
        current_state <= MENU;
        selected_shooter_red <= 4'h0;
        selected_shooter_green <= 4'h0;
        selected_shooter_blue <= 4'hF; // Default color: Blue
    end else begin
        case (current_state)
            MENU: begin
                if (keycode[7:0] == 8'h28) begin // Enter key pressed
                    current_state <= PLAYER_COLOR_SELECTION;
                end
            end
            PLAYER_COLOR_SELECTION: begin
                if (keycode[7:0] == 8'h15) begin // 'R' key pressed
                    selected_shooter_red <= 4'hF;
                    selected_shooter_green <= 4'h0;
                    selected_shooter_blue <= 4'h0;
                    current_state <= GAME;
                end else if (keycode[7:0] == 8'h0A) begin // 'G' key pressed
                    selected_shooter_red <= 4'h0;
                    selected_shooter_green <= 4'hF;
                    selected_shooter_blue <= 4'h0;
                    current_state <= GAME;
                end else if (keycode[7:0] == 8'h05) begin // 'B' key pressed
                    selected_shooter_red <= 4'h0;
                    selected_shooter_green <= 4'h0;
                    selected_shooter_blue <= 4'hF;
                    current_state <= GAME;
                end
            end
            GAME: begin
                if (keycode[7:0] == 8'h29) begin // Escape key pressed
                    current_state <= MENU; // Go back to the Main Menu
                end
            end
        endcase
    end
end
    parameter [9:0] PLAYER_START_X = 150;
    parameter [9:0] PLAYER_START_Y = 420;
    parameter [9:0] BALL_SPOT_X = 320;
    parameter [9:0] BALL_SPOT_Y = 365;
    
    localparam HEAD_OFFSET = -140;
    logic [9:0] player_x, player_y;
    logic run_to_ball;
        
    // Ball Module Instantiation
    ball ball_instance (
    .Reset(reset_ah),            // Adjust reset as needed
    .frame_clk(vsync),   // Clock signal for ball updates
//    .keycode(keycode),          // No key inputs needed for now
    .BallX(BallX),           // Outputs the X-coordinate of the ball
    .BallY(BallY),           // Outputs the Y-coordinate of the ball
    .BallS(Ball_size),        // Outputs the size of the ball
    .player_at_ball (player_at_ball_signal),
    .keycode_shooter (keycode_shooter),
    .keycode_keeper (keycode_keeper)
 //   .save_detected (save_detect) 
    );
    
    logic [9:0] stableBallX, stableBallY;
    
    always_ff @(posedge clk_25MHz or posedge reset_ah) begin
        if (reset_ah) begin
            stableBallX <= BALL_SPOT_X;
            stableBallY <= BALL_SPOT_Y;
        end else if (frame_start) begin
            stableBallX <= BallX;
            stableBallY <= BallY;
        end
    end
    // Detect the rising edge of vsync (assuming vsync pulses once per frame)
    assign frame_start = (~vsync & vsync);
    
    // Latch the ball position at the start of each frame
always_ff @(posedge clk_25MHz or posedge reset_ah) begin
    if (reset_ah) begin
        player_x <= PLAYER_START_X;
        player_y <= PLAYER_START_Y;
        run_to_ball <= 1'b0;
        player_at_ball_signal <= 1'b0;
        move_counter <= 2'd0;
    end else begin
        if (current_state == 2'b01) begin
            // Check if shoot keys pressed
            if ((keycode_shooter == 8'h1A || keycode_shooter == 8'h04 || keycode_shooter == 8'h07) && !run_to_ball)
                run_to_ball <= 1'b1;

            if (run_to_ball) begin
    // Increment move_counter every frame_start
                if (frame_start) begin
                    move_counter <= move_counter + 1'b1;
                    if (move_counter == 2'd1) begin
                        move_counter <= 2'd0;
                        // Move player only once every 4 frames
                        if (player_x < BALL_SPOT_X) player_x <= player_x + 25;
                        if (player_y < BALL_SPOT_Y) player_y <= player_y + 25;
                        
                        if (player_x >= BALL_SPOT_X && player_y >= BALL_SPOT_Y) begin
                            run_to_ball <= 1'b0;
                            player_at_ball_signal <= 1'b1;
                        end else begin
                            player_at_ball_signal <= 1'b0;
                        end
                    end
                end
            end else begin
                // After the ball resets to center, reset player to start
                if (stableBallX == BALL_SPOT_X && stableBallY == BALL_SPOT_Y) begin
                    player_x <= PLAYER_START_X;
                    player_y <= PLAYER_START_Y;
                end
            end
        end else begin
            // Not in game state
            player_x <= PLAYER_START_X;
            player_y <= PLAYER_START_Y;
            run_to_ball <= 1'b0;
            player_at_ball_signal <= 1'b0;
        end
    end
end
    
    // Main Menu Logic (Corrected Text Rendering)
    logic menu_on, text_pixel_on;
    logic [3:0] menu_red, menu_green, menu_blue;
    

    always_comb begin
        // Default signals
        menu_on = 1'b0;
        text_pixel_on = 1'b0;
        player_scren_on = 1'b0;

        if (current_state == MENU) begin
            // Red background for the menu
            menu_on = 1'b1;
            menu_red = 4'hF;   
            menu_green = 4'h0;
            menu_blue = 4'h0;

            // "ENTER TO PLAY"
            // We'll space letters out more clearly:
            // E at X=50..59, n at X=62..71, t at X=74..83, e at X=86..95, r at X=98..107
            // " " (space)
            // t at X=114..123, o at X=126..135
            // " " (space)
            // P at X=142..151, l at X=154..156, a at X=166..175, y at X=178..187

            // Letter 'E'
            if ((DrawX >= 50 && DrawX <= 52 && DrawY >= 60 && DrawY <= 75) ||  // Left vertical
                ((DrawX >= 53 && DrawX <= 59) && (DrawY == 60 || DrawY == 68 || DrawY == 75))) text_pixel_on = 1'b1;

            // Letter 'n'
            if ((DrawX >= 62 && DrawX <= 64 && DrawY >= 60 && DrawY <= 75) ||    // Left vertical
                (DrawX >= 69 && DrawX <= 71 && DrawY >= 60 && DrawY <= 75) ||    // Right vertical
                ((DrawX >= 65 && DrawX <= 68) && (DrawY >= 62 && DrawY <= 65))) text_pixel_on = 1'b1;

            // Letter 't'
            if ((DrawX >= 74 && DrawX <= 83 && DrawY == 60) ||                  // Top horizontal
                ((DrawX >= 78 && DrawX <= 80) && (DrawY >= 60 && DrawY <= 75))) text_pixel_on = 1'b1;

            // Letter 'e'
            if ((DrawX >= 86 && DrawX <= 88 && DrawY >= 60 && DrawY <= 75) ||  // Left vertical
                ((DrawX >= 89 && DrawX <= 95) && (DrawY == 60 || DrawY == 68 || DrawY == 75))) text_pixel_on = 1'b1;

            // Letter 'r'
            if (((DrawX >= 98 && DrawX <= 100) && (DrawY >= 60 && DrawY <= 75)) || // Left vertical
                ((DrawX >= 101 && DrawX <= 107) && DrawY == 60) ||                // Top horizontal
                ((DrawX >= 101 && DrawX <= 103) && DrawY == 68)) text_pixel_on = 1'b1;

            // Letter 't' in "TO"
            if ((DrawX >= 114 && DrawX <= 123 && DrawY == 60) || 
                ((DrawX >= 118 && DrawX <= 120) && (DrawY >= 60 && DrawY <= 75))) text_pixel_on = 1'b1;

            // Letter 'o' in "TO"
            if (((DrawX >= 126 && DrawX <= 135) && (DrawY == 60 || DrawY == 75)) ||
                ((DrawX >= 126 && DrawX <= 128) && (DrawY >= 60 && DrawY <= 75)) ||
                ((DrawX >= 133 && DrawX <= 135) && (DrawY >= 60 && DrawY <= 75))) text_pixel_on = 1'b1;

            // Letter 'P' in "PLAY"
            if (((DrawX >= 142 && DrawX <= 144) && (DrawY >= 60 && DrawY <= 75)) || 
                ((DrawX >= 145 && DrawX <= 151) && (DrawY == 60 || DrawY == 68))) text_pixel_on = 1'b1;

            // Letter 'l'
            if ((DrawX >= 154 && DrawX <= 156 && DrawY >= 60 && DrawY <= 75)) text_pixel_on = 1'b1;

            // Letter 'a'
            if (((DrawX >= 166 && DrawX <= 175) && DrawY == 68) || 
                ((DrawX >= 166 && DrawX <= 168) && (DrawY >= 68 && DrawY <= 75)) ||
                ((DrawX >= 173 && DrawX <= 175) && (DrawY >= 68 && DrawY <= 75))) text_pixel_on = 1'b1;

            // Letter 'y'
            if (((DrawX >= 178 && DrawX <= 180) && (DrawY >= 60 && DrawY <= 75)) ||
                ((DrawX >= 185 && DrawX <= 187) && (DrawY >= 60 && DrawY <= 75)) ||
                ((DrawX >= 181 && DrawX <= 184) && (DrawY >= 68 && DrawY <= 75))) text_pixel_on = 1'b1;

            // If text pixel on, make text white
            if (text_pixel_on) begin
                menu_red = 4'hF;
                menu_green = 4'hF;
                menu_blue = 4'hF;
            end

        end else if (current_state == PLAYER_COLOR_SELECTION) begin
            // Give a distinct background, e.g., Blue background:
            // Full screen blue background
            player_Red = 4'h0;
            player_Green = 4'h0;
            player_Blue = 4'hF;
            player_scren_on = 1'b1;
            text_pixel_on = 1'b0;

            // Render "SELECT A COLOR: R G B"
            // Let's place it starting at X=60, Y=60 and space letters nicely

            // "SELECT A COLOR:"
            // We'll just mark a rectangle where we show text for simplicity
            // S: X=60..62 vertical, X=63..69 top & mid horiz, etc. 
            // To simplify, we can check ranges more coarsely or just trust this pattern:
            // For brevity, let's place a simpler pattern:
            // Instead, let's place simpler conditions to ensure text_pixel_on is easily triggered.
            // We'll trigger text_pixel_on for a certain rectangle representing each letter.

            // We'll just define blocks for each letter to avoid complexity:
            // S (X=60..67, Y=60..75)
            if ((DrawX >= 60 && DrawX <= 67 && DrawY >= 60 && DrawY <= 75)) text_pixel_on = 1'b1;
            // E (X=70..77)
            if ((DrawX >= 70 && DrawX <= 77 && DrawY >= 60 && DrawY <= 75)) text_pixel_on = 1'b1;
            // L (X=80..87)
            if ((DrawX >= 80 && DrawX <= 87 && DrawY >= 60 && DrawY <= 75)) text_pixel_on = 1'b1;
            // E (X=90..97)
            if ((DrawX >= 90 && DrawX <= 97 && DrawY >= 60 && DrawY <= 75)) text_pixel_on = 1'b1;
            // C (X=100..107)
            if ((DrawX >= 100 && DrawX <= 107 && DrawY >= 60 && DrawY <= 75)) text_pixel_on = 1'b1;
            // T (X=110..117)
            if ((DrawX >= 110 && DrawX <= 117 && DrawY >= 60 && DrawY <= 75)) text_pixel_on = 1'b1;

            // SPACE
            // A (X=120..127)
            if ((DrawX >= 120 && DrawX <= 127 && DrawY >= 60 && DrawY <= 75)) text_pixel_on = 1'b1;

            // SPACE
            // C (X=130..137)
            if ((DrawX >= 130 && DrawX <= 137 && DrawY >= 60 && DrawY <= 75)) text_pixel_on = 1'b1;
            // O (X=140..147)
            if ((DrawX >= 140 && DrawX <= 147 && DrawY >= 60 && DrawY <= 75)) text_pixel_on = 1'b1;
            // L (X=150..157)
            if ((DrawX >= 150 && DrawX <= 157 && DrawY >= 60 && DrawY <= 75)) text_pixel_on = 1'b1;
            // O (X=160..167)
            if ((DrawX >= 160 && DrawX <= 167 && DrawY >= 60 && DrawY <= 75)) text_pixel_on = 1'b1;
            // R (X=170..177)
            if ((DrawX >= 170 && DrawX <= 177 && DrawY >= 60 && DrawY <= 75)) text_pixel_on = 1'b1;
            
            // Colon
            if ((DrawX >= 180 && DrawX <= 182 && DrawY >= 60 && DrawY <= 75)) text_pixel_on = 1'b1;

            // SPACE
            // R (X=190..197)
            if ((DrawX >= 190 && DrawX <= 197 && DrawY >= 60 && DrawY <= 75)) text_pixel_on = 1'b1;
            // G (X=200..207)
            if ((DrawX >= 200 && DrawX <= 207 && DrawY >= 60 && DrawY <= 75)) text_pixel_on = 1'b1;
            // B (X=210..217)
            if ((DrawX >= 210 && DrawX <= 217 && DrawY >= 60 && DrawY <= 75)) text_pixel_on = 1'b1;

            if (text_pixel_on) begin
                player_Red = 4'hF;
                player_Green = 4'hF;
                player_Blue = 4'hF;
            end

        end else begin
            menu_on = 1'b0;
            player_scren_on = 1'b0;
        end
    end

//    always_comb begin
//        if (current_state == MENU) begin
//            menu_on = 1'b1;
//            menu_red = 4'hF;   // Red background for menu
//            menu_green = 4'h0;
//            menu_blue = 4'h0;
    
    
//            text_pixel_on = 1'b0;
    
//            // Main Menu: "Enter to Play"
//            if ((DrawX >= 50 && DrawX <= 70 && DrawY >= 60 && DrawY <= 75)) begin // Example text rendering logic
//                text_pixel_on = 1'b1;
//            end
            
//            if ((DrawX >= 50 && DrawX <= 52 && DrawY >= 60 && DrawY <= 75) || // Letter 'E' - Vertical bar
//                (DrawX >= 53 && DrawX <= 59 && (DrawY == 60 || DrawY == 68 || DrawY == 75))) // Horizontal bars
//                text_pixel_on = 1'b1;
//            if ((DrawX >= 62 && DrawX <= 64 && DrawY >= 60 && DrawY <= 75) || // Letter 'n' - Left vertical bar
//                (DrawX >= 69 && DrawX <= 71 && DrawY >= 60 && DrawY <= 75) || // Right vertical bar
//                (DrawX >= 65 && DrawX <= 68 && DrawY >= 62 && DrawY <= 65))   // Connecting diagonal
//                text_pixel_on = 1'b1;
//            if ((DrawX >= 74 && DrawX <= 83 && DrawY == 60) ||                // Letter 't' - Top horizontal bar
//                (DrawX >= 78 && DrawX <= 80 && DrawY >= 60 && DrawY <= 75))  // Vertical bar
//                text_pixel_on = 1'b1;
//            if ((DrawX >= 86 && DrawX <= 88 && DrawY >= 60 && DrawY <= 75) || // Letter 'e' - Left vertical bar
//                (DrawX >= 89 && DrawX <= 95 && (DrawY == 60 || DrawY == 68 || DrawY == 75))) // Horizontal bars
//                text_pixel_on = 1'b1;
//            if ((DrawX >= 98 && DrawX <= 100 && DrawY >= 60 && DrawY <= 75) || // Letter 'r' - Left vertical bar
//                (DrawX >= 101 && DrawX <= 107 && DrawY == 60) ||              // Top horizontal bar
//                (DrawX >= 101 && DrawX <= 103 && DrawY == 68))                // Middle horizontal bar
//                text_pixel_on = 1'b1;
//            if ((DrawX >= 114 && DrawX <= 123 && DrawY == 60) ||              // Letter 't' - Top horizontal bar
//                (DrawX >= 118 && DrawX <= 120 && DrawY >= 60 && DrawY <= 75)) // Vertical bar
//                text_pixel_on = 1'b1;
//            if ((DrawX >= 126 && DrawX <= 135 && (DrawY == 60 || DrawY == 75)) || // Letter 'o' - Top & bottom horizontal bars
//                (DrawX >= 126 && DrawX <= 128 && DrawY >= 60 && DrawY <= 75) ||  // Left vertical bar
//                (DrawX >= 133 && DrawX <= 135 && DrawY >= 60 && DrawY <= 75))    // Right vertical bar
//                text_pixel_on = 1'b1;
//            if ((DrawX >= 142 && DrawX <= 144 && DrawY >= 60 && DrawY <= 75) || // Letter 'P' - Vertical bar
//                (DrawX >= 145 && DrawX <= 151 && (DrawY == 60 || DrawY == 68))) // Top & middle horizontal bars
//                text_pixel_on = 1'b1;
//            if (DrawX >= 154 && DrawX <= 156 && DrawY >= 60 && DrawY <= 75)     // Letter 'l' - Vertical bar
//                text_pixel_on = 1'b1;
//            if ((DrawX >= 166 && DrawX <= 175 && DrawY == 68) ||                // Letter 'a' - Middle horizontal bar
//                (DrawX >= 166 && DrawX <= 168 && DrawY >= 68 && DrawY <= 75) || // Left vertical bar
//                (DrawX >= 173 && DrawX <= 175 && DrawY >= 68 && DrawY <= 75))   // Right vertical bar
//                text_pixel_on = 1'b1;
//            if ((DrawX >= 178 && DrawX <= 180 && DrawY >= 60 && DrawY <= 75) || // Letter 'y' - Left vertical bar
//                (DrawX >= 185 && DrawX <= 187 && DrawY >= 60 && DrawY <= 75) || // Right vertical bar
//                (DrawX >= 181 && DrawX <= 184 && DrawY >= 68 && DrawY <= 75))   // Connecting bottom bar
//                text_pixel_on = 1'b1;
    
//            if (text_pixel_on) begin
//                menu_red = 4'hF;
//                menu_green = 4'hF;
//                menu_blue = 4'hF;
//            end
//        end else if (current_state == PLAYER_COLOR_SELECTION) begin
//            menu_on = 1'b1;
//            menu_red = 4'hF;   // Red background for menu
//            menu_green = 4'h0;
//            menu_blue = 4'h0;
    
//            text_pixel_on = 1'b0;
    
//            // Color Selection Menu: "Select Color: R G B"
//            if ((DrawX >= 50 && DrawX <= 70 && DrawY >= 60 && DrawY <= 75)) // R
//                text_pixel_on = 1'b1;
//            if ((DrawX >= 80 && DrawX <= 100 && DrawY >= 60 && DrawY <= 75)) // G
//                text_pixel_on = 1'b1;
//            if ((DrawX >= 110 && DrawX <= 130 && DrawY >= 60 && DrawY <= 75)) // B
//                text_pixel_on = 1'b1;
    
//            if (text_pixel_on) begin
//                menu_red = 4'hF;
//                menu_green = 4'hF;
//                menu_blue = 4'hF;
//            end
//        end else begin
//            menu_on = 1'b0;
//        end
//    end

    // Kick-off Spot Rendering Logic
    always_comb begin
        kickspot_on = 1'b0;

        if (current_state == 2'b01) begin // Gameplay Mode
            // Render a small circle for the kick-off spot
            if ((DrawX - 320) * (DrawX - 320) + (DrawY - 365) * (DrawY - 365) <= 64) // Radius = 8 pixels
                kickspot_on = 1'b1;
        end

        // Assign color for the kick-off spot (e.g., white)
        if (kickspot_on) begin
            kickspot_red = 4'hF;
            kickspot_green = 4'hF;
            kickspot_blue = 4'hF;
        end else begin
            kickspot_red = 4'h0;
            kickspot_green = 4'h0;
            kickspot_blue = 4'h0;
        end
    end
    
    int arm_offset_left, arm_offset_right;
    int leg_offset_left, leg_offset_right;
    

    // Adjust shooter position and motion
    always_comb begin
    player_on = 1'b0;

    if (current_state == 2'b01) begin // Gameplay Mode
        // Shooter's head (circle)
        // Just keep the original equations for head, body, arms, and legs without any added offsets:
// Head (circle)
        if ((DrawX - player_x)*(DrawX - player_x) + (DrawY - (player_y + HEAD_OFFSET))*(DrawY - (player_y + HEAD_OFFSET)) <= 196)
            player_on = 1'b1;
        
        // Body (vertical line)
        if (DrawX == player_x && DrawY >= (player_y + HEAD_OFFSET + 15) && DrawY <= (player_y + HEAD_OFFSET + 100))
            player_on = 1'b1;
        
        // Arms (diagonal lines)
        if ((DrawY >= (player_y + HEAD_OFFSET + 20)) && (DrawY <= (player_y + HEAD_OFFSET + 50)) &&
            (DrawX == player_x - (DrawY - (player_y + HEAD_OFFSET + 20))))
            player_on = 1'b1; // Left arm
        
        if ((DrawY >= (player_y + HEAD_OFFSET + 20)) && (DrawY <= (player_y + HEAD_OFFSET + 50)) &&
            (DrawX == player_x + (DrawY - (player_y + HEAD_OFFSET + 20))))
            player_on = 1'b1; // Right arm
        
        // Legs (angled lines)
        if ((DrawY >= (player_y + HEAD_OFFSET + 101)) && (DrawY <= (player_y + HEAD_OFFSET + 140)) &&
            ((DrawX - player_x) == ((DrawY - (player_y + HEAD_OFFSET + 100))/2)))
            player_on = 1'b1; // Left leg
        
        if ((DrawY >= (player_y + HEAD_OFFSET + 101)) && (DrawY <= (player_y + HEAD_OFFSET + 140)) &&
            ((DrawX - player_x) == -((DrawY - (player_y + HEAD_OFFSET + 100))/2)))
            player_on = 1'b1; // Right leg
    end

    // Assign shooter color
// Assign shooter color based on selected color
    if (player_on) begin
        player_red = selected_shooter_red;
        player_green = selected_shooter_green;
        player_blue = selected_shooter_blue;
    end else begin
        player_red = 4'h0;
        player_green = 4'h0;
        player_blue = 4'h0; // Default background color
    end
end
always_ff @(posedge clk_25MHz) begin
    if (reset_game) begin
        // Reset shooter and ball positions
        shooter_pos <= 100;     // Reset shooter to initial position
    end else if (shooting) begin
        shooter_pos <= shooter_pos + 1; // Simulate forward motion during shooting
    end
end

   // Goalkeeper Rendering Logic
   
   
// Goalkeeper keycode interpretation
always_comb begin
    case (keycode_keeper)
        8'h52: begin // Up Arrow
            goalie_x = 320; // Stay at center
            goalie_y = 100; // Move upward
        end
        8'h50: begin // Left Arrow
            goalie_x = 265; // Tilt left
            goalie_y = 140;
        end
        8'h4F: begin // Right Arrow
            goalie_x = 370; // Tilt right
            goalie_y = 140;
        end
        default: begin // Down Arrow or no movement
            goalie_x = 320; // Center position
            goalie_y = 140;
        end
    endcase
end
// rendering for goalkeeper be
always_comb begin
    goalie_on = 1'b0;

    if (current_state == 2'b01) begin // Gameplay Mode
        // Goalkeeper's head (circle)
        if ((DrawX - goalie_x) * (DrawX - goalie_x) + (DrawY - goalie_y) * (DrawY - goalie_y) <= 64)
            goalie_on = 1'b1;

        // Goalkeeper's body
        if (DrawX == goalie_x && DrawY >= goalie_y + 10 && DrawY <= goalie_y + 80)
            goalie_on = 1'b1;

        // Goalkeeper's arms
        if ((DrawY == goalie_y + 40) && (DrawX >= goalie_x - 20 && DrawX <= goalie_x + 20))
            goalie_on = 1'b1;

        // Goalkeeper's legs
        if ((DrawX == goalie_x - 5 && DrawY >= goalie_y + 81 && DrawY <= goalie_y + 110) ||
            (DrawX == goalie_x + 5 && DrawY >= goalie_y + 81 && DrawY <= goalie_y + 110))
            goalie_on = 1'b1;
    end

    // Assign color for the goalkeeper
    if (goalie_on) begin
        goalie_red = 4'h0;
        goalie_green = 4'hF;
        goalie_blue = 4'h0; // Green stick figure
    end else begin
        goalie_red = 4'h0;
        goalie_green = 4'h0;
        goalie_blue = 4'h0; // Default black background
    end
end
    
    // Goalpost and Net Rendering Logic
    always_comb begin
    goalpost_on = 1'b0;
    net_on = 1'b0;

    if (current_state == 2'b01) begin // Gameplay Mode
        // Goalpost dimensions
        if ((DrawX >= 210 && DrawX <= 212 && DrawY >= 100 && DrawY <= 250) || // Left post
            (DrawX >= 430 && DrawX <= 432 && DrawY >= 100 && DrawY <= 250))  // Right post
            goalpost_on = 1'b1;

        if (DrawX >= 210 && DrawX <= 430 && DrawY >= 100 && DrawY <= 102) // Crossbar
            goalpost_on = 1'b1;

        // Render net only if not overlapping with the goalkeeper
        if ((DrawX >= 213 && DrawX <= 429) && (DrawY >= 103 && DrawY <= 250) && !goalie_on) begin
            if (((DrawX - 213) % 10 == 0) || ((DrawY - 103) % 10 == 0)) // Grid every 10 pixels
                net_on = 1'b1;
        end
    end

    // Assign colors for the goalpost and net
    goalpost_red = goalpost_on ? 4'hF : 4'h0;
    goalpost_green = goalpost_on ? 4'hF : 4'h0;
    goalpost_blue = goalpost_on ? 4'hF : 4'h0;

    net_red = net_on ? 4'hC : 4'h0;
    net_green = net_on ? 4'hC : 4'h0;
    net_blue = net_on ? 4'hC : 4'h0;
    end
    
// Ball Rendering Logic
always_comb begin
    integer dx, dy;
    dx = $signed({1'b0, DrawX}) - $signed({1'b0, BallX});
    dy = $signed({1'b0, DrawY}) - $signed({1'b0, BallY});

    // Now dx and dy are properly signed, so the radius check is accurate
    if ((dx*dx + dy*dy) <= (Ball_size * Ball_size))
        ball_on = (current_state == 2'b01) && vde;
    else
        ball_on = 1'b0;

    ball_red   = ball_on ? 4'hF : 4'h0; // Orange ball
    ball_green = ball_on ? 4'h7 : 4'h0;
    ball_blue  = ball_on ? 4'h0 : 4'h0;
end
    //SCOREBOARD RENDERING LOGIC 
    // Scoreboard Rendering Logic
    logic score_on_player, score_on_keeper;
    logic [3:0] score_red, score_green, score_blue;
    
    // Constants for stick positions
    parameter PLAYER_SCORE_START_X = 10;
    parameter PLAYER_SCORE_START_Y = 10;
    parameter KEEPER_SCORE_START_X = 550;
    parameter KEEPER_SCORE_START_Y = 10;
    parameter STICK_LENGTH = 10;
    parameter STICK_SPACING = 15;
    
//    always_ff @(posedge clk_25MHz or posedge reset_ah) begin
//        if (reset_ah) begin
//            score_player <= 0; // Reset player score
//            score_keeper <= 0; // Reset keeper score
//        end else if (frame_start) begin
//            if (save_detect) begin
//                score_keeper <= score_keeper + 1; // Increment keeper score
//            end else if (goal_detected) begin
//                score_player <= score_player + 1; // Increment player score for goals
//            end
//        end
//    end

    always_ff @(posedge clk_25MHz or posedge reset_ah) begin
        if (reset_ah) begin
            player_goals <= 0; 
            keeper_saves <= 0;
        end else if (frame_start) begin
            if (save_detect) begin
                keeper_saves <= keeper_saves + 1;
            end else if (goal_detected) begin
                player_goals <= player_goals + 1;
            end
    
            // Reset after 5 attempts total
            if ((player_goals + keeper_saves) == 5) begin
                player_goals <= 0;
                keeper_saves <= 0;
            end
        end
    end



    
    // Enhanced Scoreboard Rendering Logic
 // Logic for drawing scoreboard circles
    logic scoreboard_pixel_on;
    logic [3:0] scoreboard_red, scoreboard_green, scoreboard_blue;
    int dx, dy; // Declare dx, dy here once
    logic in_goals = 1'b0;
    logic in_saves = 1'b0;

    always_comb begin
        scoreboard_pixel_on = 1'b0;
        scoreboard_red = 4'h0;
        scoreboard_green = 4'h0;
        scoreboard_blue = 4'h0;

        // Draw player goals as green circles on the left
        for (int i = 0; i < player_goals; i++) begin
            dx = DrawX - PLAYER_SCORE_START_X;
            dy = DrawY - (PLAYER_SCORE_START_Y + i*ATTEMPT_SPACING);
            if (dx*dx + dy*dy <= CIRCLE_RADIUS*CIRCLE_RADIUS)
                scoreboard_pixel_on = 1'b1;
        end

        // Draw keeper saves as red circles on the right
        for (int j = 0; j < keeper_saves; j++) begin
            dx = DrawX - KEEPER_SCORE_START_X;
            dy = DrawY - (KEEPER_SCORE_START_Y + j*ATTEMPT_SPACING);
            if (dx*dx + dy*dy <= CIRCLE_RADIUS*CIRCLE_RADIUS)
                scoreboard_pixel_on = 1'b1;
        end

        // Determine if pixel belongs to goals

        for (int i = 0; i < player_goals; i++) begin
            dx = DrawX - PLAYER_SCORE_START_X;
            dy = DrawY - (PLAYER_SCORE_START_Y + i*ATTEMPT_SPACING);
            if (dx*dx + dy*dy <= CIRCLE_RADIUS*CIRCLE_RADIUS)
                in_goals = 1'b1;
        end

        // Determine if pixel belongs to saves
        for (int j = 0; j < keeper_saves; j++) begin
            dx = DrawX - KEEPER_SCORE_START_X;
            dy = DrawY - (KEEPER_SCORE_START_Y + j*ATTEMPT_SPACING);
            if (dx*dx + dy*dy <= CIRCLE_RADIUS*CIRCLE_RADIUS)
                in_saves = 1'b1;
        end

        if (scoreboard_pixel_on) begin
            if (in_goals) begin
                scoreboard_red = 4'h0;
                scoreboard_green = 4'hF;
                scoreboard_blue = 4'h0;
            end else if (in_saves) begin
                scoreboard_red = 4'hF;
                scoreboard_green = 4'h0;
                scoreboard_blue = 4'h0;
            end
        end
    end

    
    // Update score lines
   // Update player and keeper scores
    // Ensure score_keeper is only updated in this bloc
    
    
    // Combine Outputs
    always_comb begin
        if (current_state == 2'b01) begin
            if (scoreboard_pixel_on) begin
                Red = scoreboard_red;
                Green = scoreboard_green;
                Blue = scoreboard_blue;
            end else if (goalpost_on) begin
                Red = goalpost_red;
                Green = goalpost_green;
                Blue = goalpost_blue;
            end else if (net_on) begin
                Red = net_red;
                Green = net_green;
                Blue = net_blue;
            end else if (kickspot_on) begin
                Red = kickspot_red;
                Green = kickspot_green;
                Blue = kickspot_blue;
            end else if (player_on) begin
                Red = player_red;
                Green = player_green;
                Blue = player_blue;
            end else if (goalie_on) begin
                Red = goalie_red;
                Green = goalie_green;
                Blue = goalie_blue;
            end else if (ball_on) begin
                Red = ball_red;
                Green = ball_green;
                Blue = ball_blue;
            end else if (player_scren_on) begin
                Red = player_Red;
                Green = player_Green;
                Blue = player_Blue;
            end else if (current_state == PLAYER_COLOR_SELECTION) begin
                // Background (Blue)
                Red = 4'h0;
                Green = 4'h0;
                Blue = 4'hF;
            // Render "SELECT A COLOR: R G B" text
            if (text_pixel_on) begin
                Red = 4'hF;  // White text
                Green = 4'hF;
                Blue = 4'hF;
            end
            end else begin
                Red = fb_red;
                Green = fb_green;
                Blue = fb_blue;
            end
        end else if (current_state == 2'b00) begin
            Red = menu_red;
            Green = menu_green;
            Blue = menu_blue;
            
          
        end else begin
            Red = 4'h0;
            Green = 4'h0;
            Blue = 4'h0;
        end
    end
    
    

    // Football Background Module
    Football_example football_display (
        .vga_clk(clk_25MHz),
        .DrawX(DrawX),
        .DrawY(DrawY),
        .blank(vde),
        .red(fb_red),
        .green(fb_green),
        .blue(fb_blue)
    );

endmodule