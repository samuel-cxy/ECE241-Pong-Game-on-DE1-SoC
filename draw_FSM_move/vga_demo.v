
module vga_demo (
CLOCK_50, 
SW, 
LEDR, 
KEY, 
PS2_CLK, PS2_DAT,
VGA_R, VGA_G, VGA_B,
VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK
); 

	
    parameter A = 3'b000, B = 3'b001, C = 3'b010, D = 3'b011; 
    parameter E = 3'b100, F = 3'b101, G = 3'b110, H = 3'b111; 
    parameter XDIM = 1, YDIM = 1;
    parameter X0 = 9'd79, Y0 = 8'd119;       // Updated initial position (centered)
    parameter ALT = 3'b000;                 // Alternate object color
    parameter K = 20;                       // Animation speed: use 20 for hardware, 2 for ModelSim

	input CLOCK_50;	
	input [3:0] SW;  // SW0 is reset for keyboard
	input [1:0] KEY;
	output [7:0] VGA_R;
	output [7:0] VGA_G;
	output [7:0] VGA_B;
	output VGA_HS;
	output VGA_VS;
	output VGA_BLANK_N;
	output VGA_SYNC_N;
	output VGA_CLK;	

	reg [8:0] VGA_X;                        // Updated to 9 bits for 320 pixels
	reg [7:0] VGA_Y;                        // Updated to 8 bits for 240 pixels
	reg [2:0] VGA_COLOR;
   reg plot;
	
    wire [K-1:0] slow;
    wire go, sync;

  output [9:0] LEDR; // LEDR for keyboard inputs
  
  // Game instructions!!! 
  // player1 on the right, player2 on the left
  // Step1: press esc to reset (active-high)
  // Step2: press enter to start (active-high) 
  // Step2: when entering SCORE, repeat Step2 to continue
  // Step3: when entering OVER (score1/2 == WIN_SCORE), repeat Step1 to restart
  
  // keyboard implementation
  inout wire PS2_CLK;
  inout wire PS2_DAT;
  wire up_arrow;
  wire down_arrow;
  wire key_w;
  wire key_s;
  wire key_enter;
  wire key_esc;
  keyboard K0 (SW[1], CLOCK_50, PS2_CLK, PS2_DAT, up_arrow, down_arrow, key_w, key_s, key_enter, key_esc);
  
// game screen size 160x100 (height 100 ~ 120 for score and player# display)
  parameter GAME_WIDTH = 9'd160; // 160
  parameter GAME_HEIGHT = 8'd97; // 100 - 3 so the ball can bounce properly
  
  // paddle size 15x3
  parameter PADDLE_HEIGHT = 6'b001110; // +14
  parameter PADDLE_WIDTH = 3'b010; // +2
  
  // ball size 3x3
  parameter BALL_SIZE = 3'b010; // +2
  
  // speed 
  parameter PADDLE_SPEED = 2'b10; // 2
  parameter BALL_SPEED = 2'b01; // 1
  
  // win score
  parameter WIN_SCORE = 2'b11; // 3

  // game elements
  reg [9:0] paddle1_y, paddle2_y;
  parameter paddle1_x = 9'b010010101; // 149
  parameter paddle2_x = 5'b01010; // 10
  reg [9:0] ball_x, ball_y;
  
  reg [9:0] prev_ball_x, prev_ball_y;
  reg ball_dir_x, ball_dir_y; // 0 is up, 1 is down; 0 is left, 1 is right
  reg [1:0] score1, score2;
  
  // game state FSM
  parameter IDLE = 4'b0000;
  
  parameter DRAW_BALL = 4'b0001; //play state 1- drawing
  parameter ERASE_BALL = 4'b0010; //play state 2- erasing
  
  parameter DRAW_P1 = 4'b0011; //play state 1- drawing
  parameter ERASE_P1 = 4'b0100; //play state 2- erasing
  
  parameter DRAW_P2 = 4'b0101; //play state 1- drawing
  parameter ERASE_P2 = 4'b0110; //play state 2- erasing
  
  
  parameter SCORE = 4'b0111;
  parameter OVER = 4'b1000;
  parameter DRAW_BG = 4'b1001;
  parameter DRAW_COV = 4'b1010;
  
  reg [3:0] y, Y;
  
  reg draw_ball, draw_p1, draw_p2; //drawing flag
  
  
  // CLOCK_60FPS counter
  wire CLOCK_60FPS;
  FPSCounter F0 (CLOCK_50, key_esc, CLOCK_60FPS);
  
  reg FLAG;
  reg prev_FLAG;
  
  always @(posedge CLOCK_60FPS, posedge key_esc)
   begin
		if (key_esc) FLAG = 1'b0;
		else
		FLAG = ~FLAG;
	end
	
  reg [2:0] paddleCounterW; //width counter
  reg [5:0] paddleCounterH; //height counter
  reg finished;
  
  reg [2:0] ballCounterW;
  reg [2:0] ballCounterH;
  
  
  
  reg draw_bg;
  reg draw_cov;
  
  reg [8:0] bgX_Counter;
  reg [7:0] bgY_Counter;      // used to access object memory
  
  // read a pixel color from object memory
  wire [2:0] bgcov_colour,bgP1_colour,bgP2_colour;
  bgCov cov (bgY_Counter*160+bgX_Counter, CLOCK_50,0,0,bgcov_colour);
  
  bgP1Win p1w (bgY_Counter*160+bgX_Counter, CLOCK_50,0,0,bgP1_colour);
  bgP2Win p2w (bgY_Counter*160+bgX_Counter, CLOCK_50,0,0,bgP2_colour);
  
  
  wire [2:0] bg00_colour,bg01_colour,bg02_colour;
  bg0_0 U00 (bgY_Counter*160+bgX_Counter, CLOCK_50,0,0,bg00_colour);
  bg0_1 U01 (bgY_Counter*160+bgX_Counter, CLOCK_50,0,0,bg01_colour);
  bg0_2 U02 (bgY_Counter*160+bgX_Counter, CLOCK_50,0,0,bg02_colour);
  
  wire [2:0] bg10_colour,bg11_colour,bg12_colour;
  bg1_0 U10 (bgY_Counter*160+bgX_Counter, CLOCK_50,0,0,bg10_colour);
  bg1_1 U11 (bgY_Counter*160+bgX_Counter, CLOCK_50,0,0,bg11_colour);
  bg1_2 U12 (bgY_Counter*160+bgX_Counter, CLOCK_50,0,0,bg12_colour);
  
  wire [2:0] bg20_colour,bg21_colour,bg22_colour;
  bg2_0 U20 (bgY_Counter*160+bgX_Counter, CLOCK_50,0,0,bg20_colour);
  bg2_1 U21 (bgY_Counter*160+bgX_Counter, CLOCK_50,0,0,bg21_colour);
  bg2_2 U22 (bgY_Counter*160+bgX_Counter, CLOCK_50,0,0,bg22_colour);
  
  
  // game state table
  always @(*)
  
		  
    case(y)
	   IDLE: 
		  if (key_enter) // active-high start
          Y = DRAW_BG;
		  else 
		    Y = IDLE;
		DRAW_BG:
			begin
			if (draw_bg == 0)
				Y = DRAW_BG;
			else
				Y = DRAW_BALL;
			end
			
		// draw ball state 
	   DRAW_BALL:
			begin
		  if (ball_x >= (GAME_WIDTH - BALL_SIZE) || ball_x <= 1)
				Y = SCORE;
			else
			begin
				if (prev_FLAG == FLAG) Y = ERASE_BALL;
				else
				begin
				if(draw_ball == 0)
					Y = DRAW_BALL;
				else
					Y= DRAW_P1;
				end
			end
			end
		DRAW_P1:
			begin
				if (prev_FLAG == FLAG) Y = ERASE_BALL;
				else
				begin
				if(draw_p1 == 0)
					Y = DRAW_P1;
				else
					Y= DRAW_P2;
				end
			end
		DRAW_P2:
			begin
				if (prev_FLAG == FLAG) Y = ERASE_BALL;
				else
				begin
				if(draw_p2 == 0)
					Y = DRAW_P2;
				else
					Y= DRAW_BALL;
				end
			end
			
						
		ERASE_BALL:
		begin
			
			if (draw_ball == 1)
				Y = ERASE_BALL;
			else
				Y = ERASE_P1;
		end
		ERASE_P1:
		begin
			if (draw_p1 == 1)
				Y = ERASE_P1;
			else
				Y = ERASE_P2;
		end	
		ERASE_P2:
		begin
			if (draw_p2 == 1)
				Y = ERASE_P2;
			else
				Y= DRAW_BALL;
		end
		
		
		
		
		
		SCORE:
		begin
		  if (score1 == WIN_SCORE || score2 == WIN_SCORE) 
		    Y = OVER;
		  else if (score1 != WIN_SCORE && score2 != WIN_SCORE && key_enter) // active-high enter
		    Y = DRAW_BG;
		  else 
		    Y = SCORE;
		end
		OVER:
		  Y = OVER;
		DRAW_COV:
			begin
			if (draw_cov == 0)
				Y = DRAW_COV;
			else
				Y = IDLE;
			end
	 default: Y = IDLE;
  endcase
  
  
  // game state FFs
  always @(posedge CLOCK_50, posedge key_esc) // active-high reset
  begin
    if (key_esc) // active-high reset
        y <= DRAW_COV;
    else
        y <= Y;
  end
  
  
  // VGA display
  always @(posedge CLOCK_50) // active-high reset
  begin 
    case(y)
	   IDLE:
		begin
		
		  // Default assignments
        VGA_COLOR <= 3'b111; plot <= 1'b0;
		  draw_ball <= 1'b0; draw_p1 <= 1'b0; draw_p2 <= 1'b0; draw_bg <= 1'b0; draw_cov <= 1'b0;
		  prev_FLAG <= FLAG;
		  paddleCounterH <= 6'b000000; paddleCounterW <= 3'b000;
		  finished <= 1'b0;
		  VGA_X <= ball_x;
		  VGA_Y <= ball_y;
		  
		  bgX_Counter<=9'b000000000; bgY_Counter<=8'b00000000;
		  
		end
		
		DRAW_BG:

		begin
			
		  plot <= 1'b1;
		  
		  //wire [2:0] bg00_colour,bg01_colour,bg02_colour;
		  
		  if (score1 == 2'b00 && score2 == 2'b00) VGA_COLOR <= bg00_colour;
		  else if (score2 == 2'b00 && score1 == 2'b01) VGA_COLOR <= bg01_colour;
		  else if (score2 == 2'b00 && score1 == 2'b10) VGA_COLOR <= bg02_colour;
		  
		  else if (score2 == 2'b01 && score1 == 2'b00) VGA_COLOR <= bg10_colour;
		  else if (score2 == 2'b01 && score1 == 2'b01) VGA_COLOR <= bg11_colour;
		  else if (score2 == 2'b01 && score1 == 2'b10) VGA_COLOR <= bg12_colour;
		  
		  else if (score2 == 2'b10 && score1 == 2'b00) VGA_COLOR <= bg20_colour;
		  else if (score2 == 2'b10 && score1 == 2'b01) VGA_COLOR <= bg21_colour;
		  else if (score2 == 2'b10 && score1 == 2'b10) VGA_COLOR <= bg22_colour;
        
		  VGA_X <= bgX_Counter;
        VGA_Y <= bgY_Counter;
		  
		  // resets when reaches max size 
        if (bgX_Counter == 8'd160) 
		  begin
            bgX_Counter <= 9'b0;
            if (bgY_Counter == 7'd120) begin
					 bgY_Counter<=8'b00000000;
                draw_bg <= 1'b1; // draw ball sets to 1
            end else begin
                bgY_Counter <= bgY_Counter + 1'b1;
            end
        end else begin
				bgX_Counter <= bgX_Counter + 1'b1;
        end
	   end
		
		DRAW_BALL: 
		begin
			draw_cov <= 1'b0;
		  plot <= 1'b1;
			 
        VGA_COLOR <= 3'b111;
        VGA_X <= ball_x + ballCounterW;
        VGA_Y <= ball_y + ballCounterH;
        
		  // resets when reaches max size 
        if (ballCounterW == BALL_SIZE) 
		  begin
            ballCounterW <= 3'b000;
            if (ballCounterH == BALL_SIZE) begin
                ballCounterH <= 3'b000;
                draw_ball <= 1'b1; // draw ball sets to 1
            end else begin
                ballCounterH <= ballCounterH + 1'b1;
            end
        end else begin
            ballCounterW <= ballCounterW + 1'b1;
        end
	   end
		
		DRAW_P1: 
		draw_p1 <= 1'b1;
		
		DRAW_P2: 
		begin
		if (finished ==0)
		begin
		
		VGA_X <= paddle2_x + paddleCounterW;
		VGA_Y <= paddle2_y + paddleCounterH;
		end
		else
		begin
		VGA_X <= paddle1_x + paddleCounterW;
		VGA_Y <= paddle1_y + paddleCounterH;
		end
		VGA_COLOR <= 3'b000;
		if (paddleCounterH == 0 ||paddleCounterH == 1 ||paddleCounterH == PADDLE_HEIGHT-1 ||paddleCounterH == PADDLE_HEIGHT) //
			VGA_COLOR <= 3'b000;
		else
			VGA_COLOR <= 3'b111;
		
		// if draw counter reached to the right bottom (last pixel)
		if (paddleCounterH == PADDLE_HEIGHT && paddleCounterW == PADDLE_WIDTH) 
		begin
			if (finished == 0)
			begin
			finished <= 1'b1;
			paddleCounterH <= 6'b000000;
			paddleCounterW <= 3'b000;
			end

			
			else
			begin
			finished <= 1'b0;
			draw_p2 <= 1'b1;
			paddleCounterH <= 6'b000000;
			paddleCounterW <= 3'b000;
			end
		end	
		else
			begin 
			// if max width is not reached
			if (paddleCounterW != PADDLE_WIDTH) 
				paddleCounterW <= paddleCounterW + 3'b001;
			// once max width is reached, reset width counter and count up height
			else 
				begin
				paddleCounterH <= paddleCounterH + 6'b000001;
				paddleCounterW <= 3'b000;
				end
			end
		end
		

		
		
		
		ERASE_BALL:
		begin
			//VGA_X <= prev_ball_x;
			//VGA_Y <= prev_ball_y;
			//VGA_COLOR <= 3'b000;
			//draw_ball <= 1'b0;
			VGA_COLOR <= 3'b000;
        
        VGA_X <= prev_ball_x + ballCounterW;
        VGA_Y <= prev_ball_y + ballCounterH;
        
        // reset when reaches max size
        if (ballCounterW == BALL_SIZE) begin
            ballCounterW <= 3'b000;
            if (ballCounterH == BALL_SIZE) begin
                ballCounterH <= 3'b000;
                draw_ball <= 1'b0; // draw ball reset to 0
            end else begin
                ballCounterH <= ballCounterH + 1'b1;
            end
        end else begin
            ballCounterW <= ballCounterW + 1'b1;
        end
			
		end
		
		ERASE_P1:
		begin
			//VGA_X <= paddle1_x;
			//VGA_Y <= paddle1_y;
			//VGA_COLOR <= 3'b000;
			draw_p1 <= 1'b0;
		end
		
		ERASE_P2:
		begin
			//VGA_X <= paddle2_x;
			//VGA_Y <= paddle2_y;
			//VGA_COLOR <= 3'b000;
			draw_p2 <= 1'b0;
			prev_FLAG <= FLAG;
		end	
		
		
		
		SCORE:
		begin

		  plot <= 1'b0;
		  draw_ball <= 1'b0;
		  draw_p1 <= 1'b0;
		  draw_p2 <= 1'b0;
		  draw_bg <= 1'b0;
		  draw_cov <= 1'b0;
		end 
		
		OVER:
		//draw p1 or p2 win screen
		begin
		  plot <= 1'b1;
		  draw_cov <= 1'b0;
		  //wire [2:0] bgP1_colour,bgP2_colour;
		  if (score1 == 2'b11) VGA_COLOR <= bgP2_colour;
		  else VGA_COLOR <= bgP1_colour;
        VGA_X <= bgX_Counter;
		  VGA_Y <= bgY_Counter;
		  // resets when reaches max size 
        if (bgX_Counter == 8'd160) 
		  begin
            bgX_Counter <= 9'b0;
            if (bgY_Counter == 7'd120) begin
					 bgY_Counter<=8'b00000000;
                //draw_bg <= 1'b1; // draw ball sets to 1
            end else begin
                bgY_Counter <= bgY_Counter + 1'b1;
            end
        end else begin
				bgX_Counter <= bgX_Counter + 1'b1;
        end
	   end
		DRAW_COV:
			begin
			plot <= 1'b1;
			VGA_COLOR <= bgcov_colour;
			VGA_X <= bgX_Counter;
		   VGA_Y <= bgY_Counter;
		    // resets when reaches max size 
         if (bgX_Counter == 8'd160) 
		   begin
            bgX_Counter <= 9'b0;
            if (bgY_Counter == 7'd120) begin
					 bgY_Counter<=8'b00000000;
                draw_cov <= 1'b1; // draw ball sets to 1
            end else begin
                bgY_Counter <= bgY_Counter + 1'b1;
            end
          end else begin
				bgX_Counter <= bgX_Counter + 1'b1;
         end
			end
	 endcase
  end

always @(posedge CLOCK_60FPS) 
  begin 
    case(y)
	   IDLE:
		begin 
		  paddle1_y <= 7'b0101011; // 43
        paddle2_y <= 7'b0101011; // 43
        ball_x <= 8'b01001111; // 79
        ball_y <= 7'b0110001; // 49
		  ball_dir_x <= 1'b0; // 0 is left, 1 is right
		  ball_dir_y <= 1'b0; // 0 is up, 1 is down
        score1 <= 2'b0;
        score2 <= 2'b0;
		 prev_ball_x <= ball_x;
		 prev_ball_y <= ball_y;
		end
		ERASE_BALL: 
		begin
			prev_ball_x = ball_x;
			prev_ball_y = ball_y;
        // ball bounces on ceiling
		  if (ball_y <= 2'b10)
		    ball_dir_y <= 1'b1; // down
			 
		  // 	 ball bounces on floor
		  if (ball_y >= GAME_HEIGHT - BALL_SIZE)
		    ball_dir_y <= 1'b0; // up
			 
		  // ball bounces on paddle1
		  if (ball_x + BALL_SIZE >= paddle1_x - 2'b10 && ball_x <= paddle1_x + PADDLE_WIDTH && 
		      ball_y + BALL_SIZE >= paddle1_y && ball_y <= paddle1_y + PADDLE_HEIGHT)
		    ball_dir_x <= 1'b0; // left
			 
		  // ball bounces on paddle2
		  if (ball_x + BALL_SIZE >= paddle2_x && ball_x <= paddle2_x + PADDLE_WIDTH + 2'b10 && 
		      ball_y + BALL_SIZE >= paddle2_y && ball_y <= paddle2_y + PADDLE_HEIGHT)
		    ball_dir_x <= 1'b1; // right
			 
		  // move the ball in x dir 
		  if (ball_dir_x) // right
		    ball_x <= ball_x + BALL_SPEED;
		  else // left
		    ball_x <= ball_x - BALL_SPEED;
			 
		  // move the ball in y dir
        if (ball_dir_y) // down
		    ball_y <= ball_y + BALL_SPEED;
		  else // up
		    ball_y <= ball_y - BALL_SPEED;
		end

		
		ERASE_P2:
		begin
			// move paddle1
        if (down_arrow && paddle1_y < GAME_HEIGHT - PADDLE_HEIGHT - 2'b10) // down
          paddle1_y <= paddle1_y + PADDLE_SPEED;
        if (up_arrow && paddle1_y > 1) // up 
          paddle1_y <= paddle1_y - PADDLE_SPEED; 

		  // move paddle2
        if (key_s && paddle2_y < GAME_HEIGHT - PADDLE_HEIGHT - 2'b10) // down
          paddle2_y <= paddle2_y + PADDLE_SPEED;
        if (key_w && paddle2_y > 1) // up 
          paddle2_y <= paddle2_y - PADDLE_SPEED;
      end
	
		SCORE:
		begin
		  if (ball_x >= (GAME_WIDTH - BALL_SIZE)) // player2 gets 1 point
		    score2 <= score2 + 1'b1;
		  else if (ball_x <= 1) // player1 gets 1 point
		    score1 <= score1 + 1'b1;
			 
		  // reset the elements
		  paddle1_y <= 7'b0101011; // 43
        paddle2_y <= 7'b0101011; // 43
        ball_x <= 8'b01001111; // 79
        ball_y <= 7'b0110001; // 49
		  
		  //ball_dir_x <= 1'b0; // 0 is left, 1 is right
		  //ball_dir_y <= 1'b0; // 0 is up, 1 is down

		  if (score1 + score2 == 2'b01)
		  begin 
		    ball_dir_x <= 1'b1; // 0 is left, 1 is right
		    ball_dir_y <= 1'b0; // 0 is up, 1 is down
		  end 
		  else if (score1 + score2 == 2'b10)
		  begin 
		    ball_dir_x <= 1'b1; // 0 is left, 1 is right
		    ball_dir_y <= 1'b1; // 0 is up, 1 is down
		  end 
		  else if (score1 + score2 == 2'b11)
		  begin 
		    ball_dir_x <= 1'b0; // 0 is left, 1 is right
		    ball_dir_y <= 1'b1; // 0 is up, 1 is down
		  end 
		  else 
		  begin 
		    ball_dir_x <= 1'b0; // 0 is left, 1 is right
		    ball_dir_y <= 1'b0; // 0 is up, 1 is down
		  end

		end  
	 endcase
	 end

	 
//ball
  vga_adapter VGA (
        .resetn(KEY[0]),
        .clock(CLOCK_50),
        .colour(VGA_COLOR),
        .x(VGA_X),
        .y(VGA_Y),
        .plot(plot),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N(VGA_SYNC_N),
        .VGA_CLK(VGA_CLK));
		  
		  
		  
    defparam VGA.RESOLUTION = "160x120";  // Updated resolution
    defparam VGA.MONOCHROME = "FALSE";
    defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
    defparam VGA.BACKGROUND_IMAGE = "cover.mif"; 

  assign LEDR[9:0] = ball_x[9:0];

endmodule 





















////////////////////////////////////////////////////////// FPS Counter

module FPSCounter (CLOCK_50, resetn, CLOCK_60FPS);
  input CLOCK_50, resetn;
  output reg CLOCK_60FPS;
  
  parameter limit = 20'd250000; // 833333--------> 277777
  // parameter limit = 20'b1; // for modelsim test

  reg [19:0] count;
  
  always @(posedge CLOCK_50, posedge resetn) // active-high reset
  begin
    if (resetn) // active-high reset
    begin
      count <= 20'b0; 		
      CLOCK_60FPS <= 1'b0;   
    end  
	 else
	   if (count == limit)
		begin
        count <= 20'b0;    
		  CLOCK_60FPS <= 1'b1;   
		end	  
		else 
		begin
		  count <= count + 1'b1; 
		  CLOCK_60FPS <= 1'b0;   
		end
  end
endmodule 

///////////////////////////////////////////////////////// Keyboard Implementation

module keyboard (
	 input reset,
    input wire CLOCK_50,

    inout wire PS2_CLK,
    inout wire PS2_DAT,

    output reg up_arrow,
    output reg down_arrow,
    output reg key_w,
    output reg key_s,
	 output reg key_enter,
	 output reg key_esc
);
    
    // Internal signals
    wire [7:0] received_data;
    wire received_data_en;
    reg [7:0] last_data;
    
    // Flags to track extended key codes and break code
    reg extended_code;
    reg break_code;  // New flag to track when a break code is received

    // Instantiate PS2_Controller with INITIALIZE_MOUSE set to 0
    PS2_Controller #(0) ps2_keyboard (
        .CLOCK_50(CLOCK_50),
        .reset(reset),
        .the_command(8'h00),            // No command for basic key detection
        .send_command(1'b0),            // Not sending any commands
        .PS2_CLK(PS2_CLK),
        .PS2_DAT(PS2_DAT),
        .command_was_sent(),
        .error_communication_timed_out(),
        .received_data(received_data),
        .received_data_en(received_data_en)
    );

    // Arrow key scan codes
    localparam EXTENDED_CODE       = 8'hE0;
    localparam BREAK_CODE          = 8'hF0;
    localparam UP_ARROW_CODE       = 8'h75;
    localparam DOWN_ARROW_CODE     = 8'h72;
    localparam KEY_W_CODE          = 8'h1D;
    localparam KEY_S_CODE          = 8'h1B;
	 localparam ENTER_CODE          = 8'h5A;
	 localparam ESC_CODE          = 8'h76;

    // Detect key presses and releases
    always @(posedge CLOCK_50 or posedge reset) begin
        if (reset) begin
            up_arrow <= 1'b0;
            down_arrow <= 1'b0;
            key_w <= 1'b0;
            key_s <= 1'b0;
				key_enter <= 1'b0;
				key_esc <= 1'b0;
            extended_code <= 1'b0;
            break_code <= 1'b0;
            last_data <= 8'h00;
        end else if (received_data_en) begin
            if (received_data == EXTENDED_CODE) begin
                // Set extended_code flag if E0 is received
                extended_code <= 1'b1;
            end else if (received_data == BREAK_CODE) begin
                // Set break_code flag when F0 (break code) is received
                break_code <= 1'b1;
            end else if (extended_code) begin
                // Handle extended key codes (arrow keys)
                if (break_code) begin
                    // Clear the signal for the released arrow key
                    case (received_data)
                        UP_ARROW_CODE:    up_arrow <= 1'b0;
                        DOWN_ARROW_CODE:  down_arrow <= 1'b0;
                    endcase
                    break_code <= 1'b0;
                end else begin
                    // Set the signal for the pressed arrow key
                    case (received_data)
                        UP_ARROW_CODE:    up_arrow <= 1'b1;
                        DOWN_ARROW_CODE:  down_arrow <= 1'b1;
                    endcase
                end
                extended_code <= 1'b0;
            end else begin
                // Handle non-extended key codes (W and S keys)
                if (break_code) begin
                    // Clear the signal for the released non-extended keys
                    case (received_data)
                        KEY_W_CODE: key_w <= 1'b0;
                        KEY_S_CODE: key_s <= 1'b0;
								ENTER_CODE: key_enter <= 1'b0;
								ESC_CODE: key_esc <= 1'b0;
                    endcase
                    break_code <= 1'b0;
                end else begin
                    // Set the signal for the pressed non-extended keys
                    case (received_data)
                        KEY_W_CODE: key_w <= 1'b1;
                        KEY_S_CODE: key_s <= 1'b1;
								ENTER_CODE: key_enter <= 1'b1;
								ESC_CODE: key_esc <= 1'b1;
                    endcase
                end
            end
            // Update last_data for future reference if needed
            last_data <= received_data;
        end
    end
    
endmodule


/*****************************************************************************
 *                                                                           *
 * Module:       Altera_UP_PS2                                               *
 * Description:                                                              *
 *      This module communicates with the PS2 core.                          *
 *                                                                           *
 *****************************************************************************/

module PS2_Controller #(parameter INITIALIZE_MOUSE = 0) (
	// Inputs
	CLOCK_50,
	reset,

	the_command,
	send_command,

	// Bidirectionals
	PS2_CLK,					// PS2 Clock
 	PS2_DAT,					// PS2 Data

	// Outputs
	command_was_sent,
	error_communication_timed_out,

	received_data,
	received_data_en			// If 1 - new data has been received
);

/*****************************************************************************
 *                           Parameter Declarations                          *
 *****************************************************************************/


/*****************************************************************************
 *                             Port Declarations                             *
 *****************************************************************************/
// Inputs
input			CLOCK_50;
input			reset;

input	[7:0]	the_command;
input			send_command;

// Bidirectionals
inout			PS2_CLK;
inout		 	PS2_DAT;

// Outputs
output			command_was_sent;
output			error_communication_timed_out;

output	[7:0]	received_data;
output		 	received_data_en;

wire [7:0] the_command_w;
wire send_command_w, command_was_sent_w, error_communication_timed_out_w;

generate
	if(INITIALIZE_MOUSE) begin
		assign the_command_w = init_done ? the_command : 8'hf4;
		assign send_command_w = init_done ? send_command : (!command_was_sent_w && !error_communication_timed_out_w);
		assign command_was_sent = init_done ? command_was_sent_w : 0;
		assign error_communication_timed_out = init_done ? error_communication_timed_out_w : 1;
		
		reg init_done;
		
		always @(posedge CLOCK_50)
			if(reset) init_done <= 0;
			else if(command_was_sent_w) init_done <= 1;
		
	end else begin
		assign the_command_w = the_command;
		assign send_command_w = send_command;
		assign command_was_sent = command_was_sent_w;
		assign error_communication_timed_out = error_communication_timed_out_w;
	end
endgenerate

/*****************************************************************************
 *                           Constant Declarations                           *
 *****************************************************************************/
// states
localparam	PS2_STATE_0_IDLE			= 3'h0,
			PS2_STATE_1_DATA_IN			= 3'h1,
			PS2_STATE_2_COMMAND_OUT		= 3'h2,
			PS2_STATE_3_END_TRANSFER	= 3'h3,
			PS2_STATE_4_END_DELAYED		= 3'h4;

/*****************************************************************************
 *                 Internal wires and registers Declarations                 *
 *****************************************************************************/
// Internal Wires
wire			ps2_clk_posedge;
wire			ps2_clk_negedge;

wire			start_receiving_data;
wire			wait_for_incoming_data;

// Internal Registers
reg		[7:0]	idle_counter;

reg				ps2_clk_reg;
reg				ps2_data_reg;
reg				last_ps2_clk;

// State Machine Registers
reg		[2:0]	ns_ps2_transceiver;
reg		[2:0]	s_ps2_transceiver;

/*****************************************************************************
 *                         Finite State Machine(s)                           *
 *****************************************************************************/

always @(posedge CLOCK_50)
begin
	if (reset == 1'b1)
		s_ps2_transceiver <= PS2_STATE_0_IDLE;
	else
		s_ps2_transceiver <= ns_ps2_transceiver;
end

always @(*)
begin
	// Defaults
	ns_ps2_transceiver = PS2_STATE_0_IDLE;

    case (s_ps2_transceiver)
	PS2_STATE_0_IDLE:
		begin
			if ((idle_counter == 8'hFF) && 
					(send_command == 1'b1))
				ns_ps2_transceiver = PS2_STATE_2_COMMAND_OUT;
			else if ((ps2_data_reg == 1'b0) && (ps2_clk_posedge == 1'b1))
				ns_ps2_transceiver = PS2_STATE_1_DATA_IN;
			else
				ns_ps2_transceiver = PS2_STATE_0_IDLE;
		end
	PS2_STATE_1_DATA_IN:
		begin
			if ((received_data_en == 1'b1)/* && (ps2_clk_posedge == 1'b1)*/)
				ns_ps2_transceiver = PS2_STATE_0_IDLE;
			else
				ns_ps2_transceiver = PS2_STATE_1_DATA_IN;
		end
	PS2_STATE_2_COMMAND_OUT:
		begin
			if ((command_was_sent == 1'b1) ||
				(error_communication_timed_out == 1'b1))
				ns_ps2_transceiver = PS2_STATE_3_END_TRANSFER;
			else
				ns_ps2_transceiver = PS2_STATE_2_COMMAND_OUT;
		end
	PS2_STATE_3_END_TRANSFER:
		begin
			if (send_command == 1'b0)
				ns_ps2_transceiver = PS2_STATE_0_IDLE;
			else if ((ps2_data_reg == 1'b0) && (ps2_clk_posedge == 1'b1))
				ns_ps2_transceiver = PS2_STATE_4_END_DELAYED;
			else
				ns_ps2_transceiver = PS2_STATE_3_END_TRANSFER;
		end
	PS2_STATE_4_END_DELAYED:	
		begin
			if (received_data_en == 1'b1)
			begin
				if (send_command == 1'b0)
					ns_ps2_transceiver = PS2_STATE_0_IDLE;
				else
					ns_ps2_transceiver = PS2_STATE_3_END_TRANSFER;
			end
			else
				ns_ps2_transceiver = PS2_STATE_4_END_DELAYED;
		end	
	default:
			ns_ps2_transceiver = PS2_STATE_0_IDLE;
	endcase
end

/*****************************************************************************
 *                             Sequential logic                              *
 *****************************************************************************/

always @(posedge CLOCK_50)
begin
	if (reset == 1'b1)
	begin
		last_ps2_clk	<= 1'b1;
		ps2_clk_reg		<= 1'b1;

		ps2_data_reg	<= 1'b1;
	end
	else
	begin
		last_ps2_clk	<= ps2_clk_reg;
		ps2_clk_reg		<= PS2_CLK;

		ps2_data_reg	<= PS2_DAT;
	end
end

always @(posedge CLOCK_50)
begin
	if (reset == 1'b1)
		idle_counter <= 6'h00;
	else if ((s_ps2_transceiver == PS2_STATE_0_IDLE) &&
			(idle_counter != 8'hFF))
		idle_counter <= idle_counter + 6'h01;
	else if (s_ps2_transceiver != PS2_STATE_0_IDLE)
		idle_counter <= 6'h00;
end

/*****************************************************************************
 *                            Combinational logic                            *
 *****************************************************************************/

assign ps2_clk_posedge = 
			((ps2_clk_reg == 1'b1) && (last_ps2_clk == 1'b0)) ? 1'b1 : 1'b0;
assign ps2_clk_negedge = 
			((ps2_clk_reg == 1'b0) && (last_ps2_clk == 1'b1)) ? 1'b1 : 1'b0;

assign start_receiving_data		= (s_ps2_transceiver == PS2_STATE_1_DATA_IN);
assign wait_for_incoming_data	= 
			(s_ps2_transceiver == PS2_STATE_3_END_TRANSFER);

/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/

Altera_UP_PS2_Data_In PS2_Data_In (
	// Inputs
	.clk							(CLOCK_50),
	.reset							(reset),

	.wait_for_incoming_data			(wait_for_incoming_data),
	.start_receiving_data			(start_receiving_data),

	.ps2_clk_posedge				(ps2_clk_posedge),
	.ps2_clk_negedge				(ps2_clk_negedge),
	.ps2_data						(ps2_data_reg),

	// Bidirectionals

	// Outputs
	.received_data					(received_data),
	.received_data_en				(received_data_en)
);

Altera_UP_PS2_Command_Out PS2_Command_Out (
	// Inputs
	.clk							(CLOCK_50),
	.reset							(reset),

	.the_command					(the_command_w),
	.send_command					(send_command_w),

	.ps2_clk_posedge				(ps2_clk_posedge),
	.ps2_clk_negedge				(ps2_clk_negedge),

	// Bidirectionals
	.PS2_CLK						(PS2_CLK),
 	.PS2_DAT						(PS2_DAT),

	// Outputs
	.command_was_sent				(command_was_sent_w),
	.error_communication_timed_out	(error_communication_timed_out_w)
);

endmodule

/////////////////////////////////////////////////////////////////////////////////////////////


/*****************************************************************************
 *                                                                           *
 * Module:       Altera_UP_PS2_Command_Out                                   *
 * Description:                                                              *
 *      This module sends commands out to the PS2 core.                      *
 *                                                                           *
 *****************************************************************************/


module Altera_UP_PS2_Command_Out (
	// Inputs
	clk,
	reset,

	the_command,
	send_command,

	ps2_clk_posedge,
	ps2_clk_negedge,

	// Bidirectionals
	PS2_CLK,
 	PS2_DAT,

	// Outputs
	command_was_sent,
	error_communication_timed_out
);

/*****************************************************************************
 *                           Parameter Declarations                          *
 *****************************************************************************/

// Timing info for initiating Host-to-Device communication 
//   when using a 50MHz system clock
parameter	CLOCK_CYCLES_FOR_101US		= 5050;
parameter	NUMBER_OF_BITS_FOR_101US	= 13;
parameter	COUNTER_INCREMENT_FOR_101US	= 13'h0001;

//parameter	CLOCK_CYCLES_FOR_101US		= 50;
//parameter	NUMBER_OF_BITS_FOR_101US	= 6;
//parameter	COUNTER_INCREMENT_FOR_101US	= 6'h01;

// Timing info for start of transmission error 
//   when using a 50MHz system clock
parameter	CLOCK_CYCLES_FOR_15MS		= 750000;
parameter	NUMBER_OF_BITS_FOR_15MS		= 20;
parameter	COUNTER_INCREMENT_FOR_15MS	= 20'h00001;

// Timing info for sending data error 
//   when using a 50MHz system clock
parameter	CLOCK_CYCLES_FOR_2MS		= 100000;
parameter	NUMBER_OF_BITS_FOR_2MS		= 17;
parameter	COUNTER_INCREMENT_FOR_2MS	= 17'h00001;

/*****************************************************************************
 *                             Port Declarations                             *
 *****************************************************************************/
// Inputs
input				clk;
input				reset;

input		[7:0]	the_command;
input				send_command;

input				ps2_clk_posedge;
input				ps2_clk_negedge;

// Bidirectionals
inout				PS2_CLK;
inout			 	PS2_DAT;

// Outputs
output	reg			command_was_sent;
output	reg		 	error_communication_timed_out;

/*****************************************************************************
 *                           Constant Declarations                           *
 *****************************************************************************/
// states
parameter	PS2_STATE_0_IDLE					= 3'h0,
			PS2_STATE_1_INITIATE_COMMUNICATION	= 3'h1,
			PS2_STATE_2_WAIT_FOR_CLOCK			= 3'h2,
			PS2_STATE_3_TRANSMIT_DATA			= 3'h3,
			PS2_STATE_4_TRANSMIT_STOP_BIT		= 3'h4,
			PS2_STATE_5_RECEIVE_ACK_BIT			= 3'h5,
			PS2_STATE_6_COMMAND_WAS_SENT		= 3'h6,
			PS2_STATE_7_TRANSMISSION_ERROR		= 3'h7;

/*****************************************************************************
 *                 Internal wires and registers Declarations                 *
 *****************************************************************************/
// Internal Wires

// Internal Registers
reg			[3:0]	cur_bit;
reg			[8:0]	ps2_command;

reg			[NUMBER_OF_BITS_FOR_101US:1]	command_initiate_counter;

reg			[NUMBER_OF_BITS_FOR_15MS:1]		waiting_counter;
reg			[NUMBER_OF_BITS_FOR_2MS:1]		transfer_counter;

// State Machine Registers
reg			[2:0]	ns_ps2_transmitter;
reg			[2:0]	s_ps2_transmitter;

/*****************************************************************************
 *                         Finite State Machine(s)                           *
 *****************************************************************************/

always @(posedge clk)
begin
	if (reset == 1'b1)
		s_ps2_transmitter <= PS2_STATE_0_IDLE;
	else
		s_ps2_transmitter <= ns_ps2_transmitter;
end

always @(*)
begin
	// Defaults
	ns_ps2_transmitter = PS2_STATE_0_IDLE;

    case (s_ps2_transmitter)
	PS2_STATE_0_IDLE:
		begin
			if (send_command == 1'b1)
				ns_ps2_transmitter = PS2_STATE_1_INITIATE_COMMUNICATION;
			else
				ns_ps2_transmitter = PS2_STATE_0_IDLE;
		end
	PS2_STATE_1_INITIATE_COMMUNICATION:
		begin
			if (command_initiate_counter == CLOCK_CYCLES_FOR_101US)
				ns_ps2_transmitter = PS2_STATE_2_WAIT_FOR_CLOCK;
			else
				ns_ps2_transmitter = PS2_STATE_1_INITIATE_COMMUNICATION;
		end
	PS2_STATE_2_WAIT_FOR_CLOCK:
		begin
			if (ps2_clk_negedge == 1'b1)
				ns_ps2_transmitter = PS2_STATE_3_TRANSMIT_DATA;
			else if (waiting_counter == CLOCK_CYCLES_FOR_15MS)
				ns_ps2_transmitter = PS2_STATE_7_TRANSMISSION_ERROR;
			else
				ns_ps2_transmitter = PS2_STATE_2_WAIT_FOR_CLOCK;
		end
	PS2_STATE_3_TRANSMIT_DATA:
		begin
			if ((cur_bit == 4'd8) && (ps2_clk_negedge == 1'b1))
				ns_ps2_transmitter = PS2_STATE_4_TRANSMIT_STOP_BIT;
			else if (transfer_counter == CLOCK_CYCLES_FOR_2MS)
				ns_ps2_transmitter = PS2_STATE_7_TRANSMISSION_ERROR;
			else
				ns_ps2_transmitter = PS2_STATE_3_TRANSMIT_DATA;
		end
	PS2_STATE_4_TRANSMIT_STOP_BIT:
		begin
			if (ps2_clk_negedge == 1'b1)
				ns_ps2_transmitter = PS2_STATE_5_RECEIVE_ACK_BIT;
			else if (transfer_counter == CLOCK_CYCLES_FOR_2MS)
				ns_ps2_transmitter = PS2_STATE_7_TRANSMISSION_ERROR;
			else
				ns_ps2_transmitter = PS2_STATE_4_TRANSMIT_STOP_BIT;
		end
	PS2_STATE_5_RECEIVE_ACK_BIT:
		begin
			if (ps2_clk_posedge == 1'b1)
				ns_ps2_transmitter = PS2_STATE_6_COMMAND_WAS_SENT;
			else if (transfer_counter == CLOCK_CYCLES_FOR_2MS)
				ns_ps2_transmitter = PS2_STATE_7_TRANSMISSION_ERROR;
			else
				ns_ps2_transmitter = PS2_STATE_5_RECEIVE_ACK_BIT;
		end
	PS2_STATE_6_COMMAND_WAS_SENT:
		begin
			if (send_command == 1'b0)
				ns_ps2_transmitter = PS2_STATE_0_IDLE;
			else
				ns_ps2_transmitter = PS2_STATE_6_COMMAND_WAS_SENT;
		end
	PS2_STATE_7_TRANSMISSION_ERROR:
		begin
			if (send_command == 1'b0)
				ns_ps2_transmitter = PS2_STATE_0_IDLE;
			else
				ns_ps2_transmitter = PS2_STATE_7_TRANSMISSION_ERROR;
		end
	default:
		begin
			ns_ps2_transmitter = PS2_STATE_0_IDLE;
		end
	endcase
end

/*****************************************************************************
 *                             Sequential logic                              *
 *****************************************************************************/

always @(posedge clk)
begin
	if (reset == 1'b1)
		ps2_command <= 9'h000;
	else if (s_ps2_transmitter == PS2_STATE_0_IDLE)
		ps2_command <= {(^the_command) ^ 1'b1, the_command};
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		command_initiate_counter <= {NUMBER_OF_BITS_FOR_101US{1'b0}};
	else if ((s_ps2_transmitter == PS2_STATE_1_INITIATE_COMMUNICATION) &&
			(command_initiate_counter != CLOCK_CYCLES_FOR_101US))
		command_initiate_counter <= 
			command_initiate_counter + COUNTER_INCREMENT_FOR_101US;
	else if (s_ps2_transmitter != PS2_STATE_1_INITIATE_COMMUNICATION)
		command_initiate_counter <= {NUMBER_OF_BITS_FOR_101US{1'b0}};
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		waiting_counter <= {NUMBER_OF_BITS_FOR_15MS{1'b0}};
	else if ((s_ps2_transmitter == PS2_STATE_2_WAIT_FOR_CLOCK) &&
			(waiting_counter != CLOCK_CYCLES_FOR_15MS))
		waiting_counter <= waiting_counter + COUNTER_INCREMENT_FOR_15MS;
	else if (s_ps2_transmitter != PS2_STATE_2_WAIT_FOR_CLOCK)
		waiting_counter <= {NUMBER_OF_BITS_FOR_15MS{1'b0}};
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		transfer_counter <= {NUMBER_OF_BITS_FOR_2MS{1'b0}};
	else
	begin
		if ((s_ps2_transmitter == PS2_STATE_3_TRANSMIT_DATA) ||
			(s_ps2_transmitter == PS2_STATE_4_TRANSMIT_STOP_BIT) ||
			(s_ps2_transmitter == PS2_STATE_5_RECEIVE_ACK_BIT))
		begin
			if (transfer_counter != CLOCK_CYCLES_FOR_2MS)
				transfer_counter <= transfer_counter + COUNTER_INCREMENT_FOR_2MS;
		end
		else
			transfer_counter <= {NUMBER_OF_BITS_FOR_2MS{1'b0}};
	end
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		cur_bit <= 4'h0;
	else if ((s_ps2_transmitter == PS2_STATE_3_TRANSMIT_DATA) &&
			(ps2_clk_negedge == 1'b1))
		cur_bit <= cur_bit + 4'h1;
	else if (s_ps2_transmitter != PS2_STATE_3_TRANSMIT_DATA)
		cur_bit <= 4'h0;
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		command_was_sent <= 1'b0;
	else if (s_ps2_transmitter == PS2_STATE_6_COMMAND_WAS_SENT)
		command_was_sent <= 1'b1;
	else if (send_command == 1'b0)
			command_was_sent <= 1'b0;
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		error_communication_timed_out <= 1'b0;
	else if (s_ps2_transmitter == PS2_STATE_7_TRANSMISSION_ERROR)
		error_communication_timed_out <= 1'b1;
	else if (send_command == 1'b0)
		error_communication_timed_out <= 1'b0;
end

/*****************************************************************************
 *                            Combinational logic                            *
 *****************************************************************************/

assign PS2_CLK	= 
	(s_ps2_transmitter == PS2_STATE_1_INITIATE_COMMUNICATION) ? 
		1'b0 :
		1'bz;

assign PS2_DAT	= 
	(s_ps2_transmitter == PS2_STATE_3_TRANSMIT_DATA) ? ps2_command[cur_bit] :
	(s_ps2_transmitter == PS2_STATE_2_WAIT_FOR_CLOCK) ? 1'b0 :
	((s_ps2_transmitter == PS2_STATE_1_INITIATE_COMMUNICATION) && 
		(command_initiate_counter[NUMBER_OF_BITS_FOR_101US] == 1'b1)) ? 1'b0 : 
			1'bz;

/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/


endmodule


/////////////////////////////////////////////////////////////////////////////////////////////


/*****************************************************************************
 *                                                                           *
 * Module:       Altera_UP_PS2_Data_In                                       *
 * Description:                                                              *
 *      This module accepts incoming data from a PS2 core.                   *
 *                                                                           *
 *****************************************************************************/


module Altera_UP_PS2_Data_In (
	// Inputs
	clk,
	reset,

	wait_for_incoming_data,
	start_receiving_data,

	ps2_clk_posedge,
	ps2_clk_negedge,
	ps2_data,

	// Bidirectionals

	// Outputs
	received_data,
	received_data_en			// If 1 - new data has been received
);


/*****************************************************************************
 *                           Parameter Declarations                          *
 *****************************************************************************/


/*****************************************************************************
 *                             Port Declarations                             *
 *****************************************************************************/
// Inputs
input				clk;
input				reset;

input				wait_for_incoming_data;
input				start_receiving_data;

input				ps2_clk_posedge;
input				ps2_clk_negedge;
input			 	ps2_data;

// Bidirectionals

// Outputs
output reg	[7:0]	received_data;

output reg		 	received_data_en;

/*****************************************************************************
 *                           Constant Declarations                           *
 *****************************************************************************/
// states
localparam	PS2_STATE_0_IDLE			= 3'h0,
			PS2_STATE_1_WAIT_FOR_DATA	= 3'h1,
			PS2_STATE_2_DATA_IN			= 3'h2,
			PS2_STATE_3_PARITY_IN		= 3'h3,
			PS2_STATE_4_STOP_IN			= 3'h4;

/*****************************************************************************
 *                 Internal wires and registers Declarations                 *
 *****************************************************************************/
// Internal Wires
reg			[3:0]	data_count;
reg			[7:0]	data_shift_reg;

// State Machine Registers
reg			[2:0]	ns_ps2_receiver;
reg			[2:0]	s_ps2_receiver;

/*****************************************************************************
 *                         Finite State Machine(s)                           *
 *****************************************************************************/

always @(posedge clk)
begin
	if (reset == 1'b1)
		s_ps2_receiver <= PS2_STATE_0_IDLE;
	else
		s_ps2_receiver <= ns_ps2_receiver;
end

always @(*)
begin
	// Defaults
	ns_ps2_receiver = PS2_STATE_0_IDLE;

    case (s_ps2_receiver)
	PS2_STATE_0_IDLE:
		begin
			if ((wait_for_incoming_data == 1'b1) && 
					(received_data_en == 1'b0))
				ns_ps2_receiver = PS2_STATE_1_WAIT_FOR_DATA;
			else if ((start_receiving_data == 1'b1) && 
					(received_data_en == 1'b0))
				ns_ps2_receiver = PS2_STATE_2_DATA_IN;
			else
				ns_ps2_receiver = PS2_STATE_0_IDLE;
		end
	PS2_STATE_1_WAIT_FOR_DATA:
		begin
			if ((ps2_data == 1'b0) && (ps2_clk_posedge == 1'b1))
				ns_ps2_receiver = PS2_STATE_2_DATA_IN;
			else if (wait_for_incoming_data == 1'b0)
				ns_ps2_receiver = PS2_STATE_0_IDLE;
			else
				ns_ps2_receiver = PS2_STATE_1_WAIT_FOR_DATA;
		end
	PS2_STATE_2_DATA_IN:
		begin
			if ((data_count == 3'h7) && (ps2_clk_posedge == 1'b1))
				ns_ps2_receiver = PS2_STATE_3_PARITY_IN;
			else
				ns_ps2_receiver = PS2_STATE_2_DATA_IN;
		end
	PS2_STATE_3_PARITY_IN:
		begin
			if (ps2_clk_posedge == 1'b1)
				ns_ps2_receiver = PS2_STATE_4_STOP_IN;
			else
				ns_ps2_receiver = PS2_STATE_3_PARITY_IN;
		end
	PS2_STATE_4_STOP_IN:
		begin
			if (ps2_clk_posedge == 1'b1)
				ns_ps2_receiver = PS2_STATE_0_IDLE;
			else
				ns_ps2_receiver = PS2_STATE_4_STOP_IN;
		end
	default:
		begin
			ns_ps2_receiver = PS2_STATE_0_IDLE;
		end
	endcase
end

/*****************************************************************************
 *                             Sequential logic                              *
 *****************************************************************************/


always @(posedge clk)
begin
	if (reset == 1'b1) 
		data_count	<= 3'h0;
	else if ((s_ps2_receiver == PS2_STATE_2_DATA_IN) && 
			(ps2_clk_posedge == 1'b1))
		data_count	<= data_count + 3'h1;
	else if (s_ps2_receiver != PS2_STATE_2_DATA_IN)
		data_count	<= 3'h0;
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		data_shift_reg			<= 8'h00;
	else if ((s_ps2_receiver == PS2_STATE_2_DATA_IN) && 
			(ps2_clk_posedge == 1'b1))
		data_shift_reg	<= {ps2_data, data_shift_reg[7:1]};
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		received_data		<= 8'h00;
	else if (s_ps2_receiver == PS2_STATE_4_STOP_IN)
		received_data	<= data_shift_reg;
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		received_data_en		<= 1'b0;
	else if ((s_ps2_receiver == PS2_STATE_4_STOP_IN) &&
			(ps2_clk_posedge == 1'b1))
		received_data_en	<= 1'b1;
	else
		received_data_en	<= 1'b0;
end

/*****************************************************************************
 *                            Combinational logic                            *
 *****************************************************************************/


/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/


endmodule




/*

  
  

		DRAW_BALL: 
		begin
		  plot <= 1'b1;
			 
        VGA_COLOR <= 3'b111;
        VGA_X <= ball_x + ballCounterW;
        VGA_Y <= ball_y + ballCounterH;
        
		  // resets when reaches max size 
        if (ballCounterW == BALL_SIZE) 
		  begin
            ballCounterW <= 3'b000;
            if (ballCounterH == BALL_SIZE) begin
                ballCounterH <= 3'b000;
                draw_ball <= 1'b1; // draw ball sets to 1
            end else begin
                ballCounterH <= ballCounterH + 1'b1;
            end
        end else begin
            ballCounterW <= ballCounterW + 1'b1;
        end
	   end
		
		DRAW_P1: 
		draw_p1 <= 1'b1;
		
		DRAW_P2: 
		begin
		if (finished ==0)
		begin
		
		VGA_X <= paddle2_x + paddleCounterW;
		VGA_Y <= paddle2_y + paddleCounterH;
		end
		else
		begin
		VGA_X <= paddle1_x + paddleCounterW;
		VGA_Y <= paddle1_y + paddleCounterH;
		end
		VGA_COLOR <= 3'b000;
		if (paddleCounterH == 0 ||paddleCounterH == 1 ||paddleCounterH == PADDLE_HEIGHT-1 ||paddleCounterH == PADDLE_HEIGHT) //
			VGA_COLOR <= 3'b000;
		else
			VGA_COLOR <= 3'b111;
		
		// if draw counter reached to the right bottom (last pixel)
		if (paddleCounterH == PADDLE_HEIGHT && paddleCounterW == PADDLE_WIDTH) 
		begin
			if (finished == 0)
			begin
			finished <= 1'b1;
			paddleCounterH <= 6'b000000;
			paddleCounterW <= 3'b000;
			end

			
			else
			begin
			finished <= 1'b0;
			draw_p2 <= 1'b1;
			paddleCounterH <= 6'b000000;
			paddleCounterW <= 3'b000;
			end
		end	
		else
			begin 
			// if max width is not reached
			if (paddleCounterW != PADDLE_WIDTH) 
				paddleCounterW <= paddleCounterW + 3'b001;
			// once max width is reached, reset width counter and count up height
			else 
				begin
				paddleCounterH <= paddleCounterH + 6'b000001;
				paddleCounterW <= 3'b000;
				end
			end
		end
		

		
		
		
		ERASE_BALL:
		begin
			//VGA_X <= prev_ball_x;
			//VGA_Y <= prev_ball_y;
			//VGA_COLOR <= 3'b000;
			//draw_ball <= 1'b0;
			VGA_COLOR <= 3'b000;
        
        VGA_X <= prev_ball_x + ballCounterW;
        VGA_Y <= prev_ball_y + ballCounterH;
        
        // reset when reaches max size
        if (ballCounterW == BALL_SIZE) begin
            ballCounterW <= 3'b000;
            if (ballCounterH == BALL_SIZE) begin
                ballCounterH <= 3'b000;
                draw_ball <= 1'b0; // draw ball reset to 0
            end else begin
                ballCounterH <= ballCounterH + 1'b1;
            end
        end else begin
            ballCounterW <= ballCounterW + 1'b1;
        end
			
		end
		
		ERASE_P1:
		begin
			//VGA_X <= paddle1_x;
			//VGA_Y <= paddle1_y;
			//VGA_COLOR <= 3'b000;
			draw_p1 <= 1'b0;
		end
		
		ERASE_P2:
		begin
			//VGA_X <= paddle2_x;
			//VGA_Y <= paddle2_y;
			//VGA_COLOR <= 3'b000;
			draw_p2 <= 1'b0;
			prev_FLAG <= FLAG;
		end	
		
		
		
		SCORE:
		begin

		  plot <= 1'b0;
		  draw_ball <= 1'b0;
		  draw_p1 <= 1'b0;
		  draw_p2 <= 1'b0;
		  draw_bg <= 1'b0;
		end  
	 endcase
  end

always @(posedge CLOCK_60FPS) 
  begin 
    case(y)
	   IDLE:
		begin 
		  paddle1_y <= 7'b1000001; // 65
        paddle2_y <= 7'b1000001; // 65
        ball_x <= 8'b10011011; // 155
        ball_y <= 7'b1001011; // 75
		  ball_dir_x <= 1'b0; // 0 is left, 1 is right
		  ball_dir_y <= 1'b0; // 0 is up, 1 is down
        score1 <= 2'b0;
        score2 <= 2'b0;
		 prev_ball_x <= ball_x;
		 prev_ball_y <= ball_y;
		end
		ERASE_BALL: 
		begin
			prev_ball_x = ball_x;
			prev_ball_y = ball_y;
        // ball bounces on ceiling
		  if (ball_y <= 2'b10)
		    ball_dir_y <= 1'b1; // down
			 
		  // 	 ball bounces on floor
		  if (ball_y >= GAME_HEIGHT - BALL_SIZE)
		    ball_dir_y <= 1'b0; // up
			 
		  // ball bounces on paddle1
		  if (ball_x + BALL_SIZE >= paddle1_x - 2'b10 && ball_x <= paddle1_x + PADDLE_WIDTH && 
		      ball_y + BALL_SIZE >= paddle1_y && ball_y <= paddle1_y + PADDLE_HEIGHT)
		    ball_dir_x <= 1'b0; // left
			 
		  // ball bounces on paddle2
		  if (ball_x + BALL_SIZE >= paddle2_x && ball_x <= paddle2_x + PADDLE_WIDTH + 2'b10 && 
		      ball_y + BALL_SIZE >= paddle2_y && ball_y <= paddle2_y + PADDLE_HEIGHT)
		    ball_dir_x <= 1'b1; // right
			 
		  // move the ball in x dir 
		  if (ball_dir_x) // right
		    ball_x <= ball_x + BALL_SPEED;
		  else // left
		    ball_x <= ball_x - BALL_SPEED;
			 
		  // move the ball in y dir
        if (ball_dir_y) // down
		    ball_y <= ball_y + BALL_SPEED;
		  else // up
		    ball_y <= ball_y - BALL_SPEED;
		end

		ERASE_P1:
		begin
			// move paddle1
        if (down_arrow && paddle1_y < GAME_HEIGHT - PADDLE_HEIGHT - 2'b10) // down
          paddle1_y <= paddle1_y + PADDLE_SPEED;
        if (up_arrow && paddle1_y > 1) // up 
          paddle1_y <= paddle1_y - PADDLE_SPEED; 
			// move paddle2
        if (key_s && paddle2_y < GAME_HEIGHT - PADDLE_HEIGHT - 2'b10) // down
          paddle2_y <= paddle2_y + PADDLE_SPEED;
        if (key_w && paddle2_y > 1) // up 
          paddle2_y <= paddle2_y - PADDLE_SPEED;
		end
		//ERASE_P2:
		
	
		SCORE:
		begin
		  if (ball_x >= (GAME_WIDTH - BALL_SIZE)) // player2 gets 1 point
		    score2 <= score2 + 1'b1;
		  else if (ball_x <= 1) // player1 gets 1 point
		    score1 <= score1 + 1'b1;
			 
		  // reset the elements
		  paddle1_y <= 7'b1000001; // 65
        paddle2_y <= 7'b1000001; // 65
        ball_x <= 8'b10011011; // 155
        ball_y <= 7'b1001011; // 75
		  ball_dir_x <= 1'b0; // 0 is left, 1 is right
		  ball_dir_y <= 1'b0; // 0 is up, 1 is down

		end  
	 endcase
	 end

	 */