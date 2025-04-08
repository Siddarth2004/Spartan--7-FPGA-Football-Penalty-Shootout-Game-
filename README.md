# Spartan--7-FPGA-Football-Penalty-Shootout-Game-



**Idea and Overview:**
It is a multiplayer game with penalty shoot-out scoring, graphics, and animations for two players
taking turns either as shooter or goalkeeper, with pushing buttons controlling the direction and
power of the shots and the goalie directing his dive to save the goal. The final result is the
animated screen showing two players and a ball on the football ground to provide the most
entertaining and accessible multiplayer experience. A tournament-like play structure or selection
dialogs would help to add a touch of entertainment for the game. Shooting directions will be
varied based on the button combination used, which indeed will add a level of strategy to the
game.

**List of Features:**
Multiplayer: Two-player mode wherein players alternate shooting and goalkeeping turns.
Scoreboard: Displays the live score and updates with a goal. Button Controls: Buttons control
the shooting direction and goalkeeper movements.
Simple Graphics: A football field is displayed with simple animations to depict movement of
players and ball tracing. Sound Effects: Audio that plays when a goal is scored or a shot is
taken.
Shooting Directions: The controlling shooter determines shooting directions with different
button combinations.
Goalkeeper's diving technique: The player controlling the keeper selects a diving direction,
and the chances of saving would, of course, depend on the timing vis-à-vis the shooter.
Advanced Animations: This involves adding animations for various actions, such as a
goalkeeper diving to save a shot.
Ball Power Mechanics: This involves adding the ability to control the power or speed of the
shot with different button combinations or the amount of time for which the button is pressed

The Penalty Shootout Game emulates a real-life penalty kick situation in soccer, in which one
player-the shooter-is supposed to score, and the goalkeeper stops the incoming ball by
controlling the keys. In this game, a player is introduced to a few dynamic features:
Graphical Rendering:
Real-time rendering of the football, player, goalkeeper, goalpost, and scoreboard using the VGA
display interface.

User Interaction:
Players can control the shooter and goalkeeper actions using keyboard inputs, with key
combinations determining shots and saves.

Basic Scoreboard:
A basic scoreboard was attempted which tracks the goals scored by the shooter and saves
made by the goalkeeper, displaying them as colored circles.

Customizable Player Color Selection:
Before entering gameplay, players can customize the shooter's appearance by choosing
between red, green, or blue colors.

Game States and Transitions:
The system features a menu screen, player color selection screen, gameplay mode, and a reset
condition for attempts.

This project makes use of the VGA-to-HDMI modules, BRAM-based sound implementation, and
the VGA display pipeline. Other modules that had to be implemented to realize
smooth gameplay included the ball and goalkeeper control logic, player rendering, and collision
detection. This project demonstrates how to put together FPGA-based graphics processing, input
handling, and FSMs to create a fully functional game that is clear in visual and logical structure.


**Key Modules in the Final Project:**

1. Color Mapper (color_mapper.sv)
○ The central module responsible for coordinating the rendering of all game
components onto the HDMI display.
○ Combines multiple graphical elements, including the ball, player, goalkeeper,
goalpost, net, and scoreboard.
○ Implements state transitions between screens (Main Menu, Player Color
Selection, and Gameplay).
○ Dynamically assigns colors for different components and manages user inputs for
shooting and goalkeeping.

2. Ball Module (ball.sv)
○ Handles the motion of the ball during gameplay.
○ Updates the ball’s position based on the player’s shooting input and simulates
forward movement toward the goal.
○ Provides feedback signals such as player_at_ball_signal to synchronize player
movements with the ball.

3. Player and Goalkeeper Logic
   
Player Movement:
Controls the shooter’s appearance and motion toward the ball when a
shot is initiated.

Allows the user to select the shooter’s color dynamically before gameplay.

Goalkeeper Control:

Responds to user inputs (arrow keys) to move the goalkeeper in the left,
right, or center positions.

Determines whether the goalkeeper successfully blocks a shot based on
the ball’s trajectory.

5. Scoreboard Logic
Implements a graphical scoreboard to display goals and saves as colored
circles.

Updates the player’s goals and goalkeeper’s saves dynamically based on the
outcome of each shot.

Uses on-screen pixel-to-coordinate mapping to accurately render the circles.

6. State Machine (FSM)

Controls the game flow between the following states:

Main Menu: Displays “ENTER TO PLAY” and waits for the user to press enter.

Player Color Selection: Allows the player to choose the shooter’s color (Red, Green, or Blue).

Gameplay: Simulates the penalty shootout, including ball movement, player and goalkeeper control, and scoring and manages transitions based on user inputs (e.g., Enter, Escape, R/G/B keys).

7. Football Background Module (Football_example)
   
Provides the static football field background displayed during gameplay.

Ensures a visually appealing base layer on which all dynamic game components
are rendered.

**State Machine for Game Flow:**
A critical module to manage game transitions between game states will be done through the
implemented game state machine in the color_mapper module. 

The game states will be as follows:

MENU: shows the main menu and waits for a key press, preferably Enter, to start the game.

PLAYER_COLOR_SELECTION: This allows a player to select the shooter color, Red, Green,
or Blue, and initializes a game's state.

GAME: Contains all game logic, moving of the ball, player movement, action of the goalkeeper,
and updates the score. Listens for the Escape key to return to the menu
