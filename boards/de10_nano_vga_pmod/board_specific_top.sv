`include "config.svh"
`include "lab_specific_config.svh"

//--- VGA external ---
//   `define VGA666_BOARD
 `define PMOD_VGA_BOARD
// `define MISTER_IO_BOARD

module board_specific_top
# (
    parameter clk_mhz  = 50,
              w_key    = 2,
              w_sw     = 4,
              w_led    = 8,
              w_digit  = 0,
              w_gpio   = 36                   // GPIO_0 [31], [33], [35] reserved for tm1638, GPIO_0[5:0] reserved for mic
)
(
    input                    FPGA_CLK1_50,

    input  [w_key     - 1:0] KEY,
    input  [w_sw      - 1:0] SW,
    output [w_led     - 1:0] LED,             // LEDG onboard

    inout  [w_gpio    - 1:0] GPIO_0,
    inout  [w_gpio    - 1:0] GPIO_1
);

    //------------------------------------------------------------------------

    localparam w_top_sw   = w_sw - 1;                             // One onboard SW is used as a reset

    wire                  clk    = FPGA_CLK1_50;

   `ifdef MISTER_IO_BOARD
        wire              rst    = SW [w_top_sw] | ~ GPIO_1 [14]; // GPIO_1 [14] (JP7 pin 17) is BTN_RESET key on MiSTer I/O board, internal FGPA weak pull-up enabled;
    `else
        wire              rst    = SW [w_top_sw];
    `endif

    wire [w_top_sw - 1:0] top_sw = SW [w_top_sw - 1:0];

    //------------------------------------------------------------------------

    wire [           7:0] abcdefgh;

    wire                  vga_vs, vga_hs;
    wire [           3:0] vga_r, vga_g, vga_b;

    wire [          23:0] mic;

    //------------------------------------------------------------------------

    localparam w_tm_key     = 8,
               w_tm_led     = 8,
               w_tm_digit   = 8;

    //------------------------------------------------------------------------

    `ifdef DUPLICATE_TM_SIGNALS_WITH_REGULAR

        localparam w_top_key   = w_tm_key   > w_key   ? w_tm_key   : w_key   ,
                   w_top_led   = w_tm_led   > w_led   ? w_tm_led   : w_led   ,
                   w_top_digit = w_tm_digit > w_digit ? w_tm_digit : w_digit ;

    `else  // Concatenate the signals

        localparam w_top_key   = w_tm_key   + w_key   ,
                   w_top_led   = w_tm_led   + w_led   ,
                   w_top_digit = w_tm_digit + w_digit ;
    `endif

    //------------------------------------------------------------------------

    wire  [w_tm_key    - 1:0] tm_key;
    wire  [w_tm_led    - 1:0] tm_led;
    wire  [w_tm_digit  - 1:0] tm_digit;

    logic [w_top_key   - 1:0] top_key;
    wire  [w_top_led   - 1:0] top_led;
    wire  [w_top_digit - 1:0] top_digit;

    //------------------------------------------------------------------------

    `ifdef CONCAT_TM_SIGNALS_AND_REGULAR

        assign top_key = { tm_key, ~ KEY };

        assign { tm_led   , LED   } = top_led;
        assign             tm_digit = top_digit;

    `elsif CONCAT_REGULAR_SIGNALS_AND_TM

        assign top_key = { ~ KEY, tm_key };

        assign { LED   , tm_led   } = top_led;
        assign             tm_digit = top_digit;

    `else  // DUPLICATE_TM_SIGNALS_WITH_REGULAR

        always_comb
        begin
            top_key = '0;

            top_key [w_key    - 1:0] |= ~ KEY;
            top_key [w_tm_key - 1:0] |= tm_key;
        end

        assign LED      = top_led   [w_led      - 1:0];
        assign tm_led   = top_led   [w_tm_led   - 1:0];

        assign tm_digit = top_digit [w_tm_digit - 1:0];

    `endif

    //------------------------------------------------------------------------

    top
    # (
        .clk_mhz ( clk_mhz     ),
        .w_key   ( w_top_key   ),
        .w_sw    ( w_top_sw    ),
        .w_led   ( w_top_led   ),
        .w_digit ( w_top_digit ),
        .w_gpio  ( w_gpio      )      // GPIO_0 [31], [33], [35] reserved for tm1638, GPIO_0[5:0] reserved for mic
    )
    i_top
    (
        .clk      ( clk        ),
        .rst      ( rst        ),

        .key      ( top_key    ),
        .sw       ( top_sw     ),

        .led      ( top_led    ),

        .abcdefgh ( abcdefgh   ),
        .digit    ( top_digit  ),

        .vsync    ( vga_vs     ),
        .hsync    ( vga_hs     ),

        .red      ( vga_r      ),
        .green    ( vga_g      ),
        .blue     ( vga_b      ),

        .mic      ( mic        ),
        .gpio     ( GPIO_0     )
    );

    //------------------------------------------------------------------------

    logic [    3:0] reg_vga_r, reg_vga_g, reg_vga_b;
    logic           reg_vga_vs, reg_vga_hs;

    // Registers remove combinational logic noise
    always_ff @( posedge clk or posedge rst)
    begin
        if (rst)
        begin
            reg_vga_r  <= '0;
            reg_vga_g  <= '0;
            reg_vga_b  <= '0;
            reg_vga_vs <= '0;
            reg_vga_hs <= '0;
        end
        else
        begin
            reg_vga_r  <= vga_r;
            reg_vga_g  <= vga_g;
            reg_vga_b  <= vga_b;
            reg_vga_vs <= vga_vs;
            reg_vga_hs <= vga_hs;
        end
    end

    // External VGA out at GPIO_1
    `ifdef  VGA666_BOARD

        // 4 bit color used
        assign GPIO_1 [35] = reg_vga_vs;        // vga666_pi_Vsync - JP7 pin 40
        assign GPIO_1 [33] = reg_vga_hs;        // vga666_pi_Hsync - JP7 pin 38
        // R
        assign GPIO_1 [13] = reg_vga_r [0];     // vga666_red[4]   - JP7 pin 16
        assign GPIO_1 [19] = reg_vga_r [1];     // vga666_red[5]   - JP7 pin 22
        assign GPIO_1 [ 5] = reg_vga_r [2];     // vga666_red[6]   - JP7 pin 6
        assign GPIO_1 [ 3] = reg_vga_r [3];     // vga666_red[7]   - JP7 pin 4
        // G
        assign GPIO_1 [ 7] = reg_vga_g [0];     // vga666_green[4] - JP7 pin 8
        assign GPIO_1 [21] = reg_vga_g [1];     // vga666_green[5] - JP7 pin 24
        assign GPIO_1 [17] = reg_vga_g [2];     // vga666_green[6] - JP7 pin 20
        assign GPIO_1 [15] = reg_vga_g [3];     // vga666_green[7] - JP7 pin 18
        // B
        assign GPIO_1 [23] = reg_vga_b [0];     // vga666_blue[4]  - JP7 pin 26
        assign GPIO_1 [ 9] = reg_vga_b [1];     // vga666_blue[5]  - JP7 pin 10
        assign GPIO_1 [11] = reg_vga_b [2];     // vga666_blue[6]  - JP7 pin 14
        assign GPIO_1 [25] = reg_vga_b [3];     // vga666_blue[7]  - JP7 pin 28
                                                // vga666_GND      - JP7 pin 30

    `elsif PMOD_VGA_BOARD

        assign GPIO_1 [ 7] = reg_vga_vs;        // JP7 pin  8
        assign GPIO_1 [ 5] = reg_vga_hs;        // JP7 pin  6
        // R
        assign GPIO_1 [35] = reg_vga_r [0];     // JP7 pin 40
        assign GPIO_1 [33] = reg_vga_r [1];     // JP7 pin 38
        assign GPIO_1 [31] = reg_vga_r [2];     // JP7 pin 36
        assign GPIO_1 [29] = reg_vga_r [3];     // JP7 pin 34
        // G
        assign GPIO_1 [25] = reg_vga_g [0];     // JP7 pin 28
        assign GPIO_1 [23] = reg_vga_g [1];     // JP7 pin 26
        assign GPIO_1 [21] = reg_vga_g [2];     // JP7 pin 24
        assign GPIO_1 [19] = reg_vga_g [3];     // JP7 pin 22
        // B
        assign GPIO_1 [17] = reg_vga_b [0];     // JP7 pin 20
        assign GPIO_1 [15] = reg_vga_b [1];     // JP7 pin 18
        assign GPIO_1 [13] = reg_vga_b [2];     // JP7 pin 16
        assign GPIO_1 [11] = reg_vga_b [3];     // JP7 pin 14
                                                // GND  - JP7 pin 30
                                                // 3.3V - JP7 pin 29

    `elsif MISTER_IO_BOARD

        // VGA out of MiSTer I/O board, 4 bit color used
        assign GPIO_1 [16] = reg_vga_vs;        // JP7 pin 19
        assign GPIO_1 [17] = reg_vga_hs;        // JP7 pin 20
        // R
        assign GPIO_1 [35] = 1'b1;              // JP7 pin 40
        assign GPIO_1 [33] = 1'b1;              // JP7 pin 38
        assign GPIO_1 [31] = reg_vga_r [0];     // JP7 pin 36
        assign GPIO_1 [29] = reg_vga_r [1];     // JP7 pin 34
        assign GPIO_1 [27] = reg_vga_r [2];     // JP7 pin 32
        assign GPIO_1 [25] = reg_vga_r [3];     // JP7 pin 28
        // G
        assign GPIO_1 [34] = 1'b1;              // JP7 pin 39
        assign GPIO_1 [32] = 1'b1;              // JP7 pin 37
        assign GPIO_1 [30] = reg_vga_g [0];     // JP7 pin 35
        assign GPIO_1 [28] = reg_vga_g [1];     // JP7 pin 33
        assign GPIO_1 [26] = reg_vga_g [2];     // JP7 pin 31
        assign GPIO_1 [24] = reg_vga_g [3];     // JP7 pin 27
        // B
        assign GPIO_1 [19] = 1'b1;              // JP7 pin 22
        assign GPIO_1 [21] = 1'b1;              // JP7 pin 24
        assign GPIO_1 [23] = reg_vga_b [0];     // JP7 pin 26
        assign GPIO_1 [22] = reg_vga_b [1];     // JP7 pin 25
        assign GPIO_1 [20] = reg_vga_b [2];     // JP7 pin 23
        assign GPIO_1 [18] = reg_vga_b [3];     // JP7 pin 21

    `endif

    //------------------------------------------------------------------------

    wire [$left (abcdefgh):0] hgfedcba;

    generate
        genvar i;

        for (i = 0; i < $bits (abcdefgh); i ++)
        begin : abc
            assign hgfedcba [i] = abcdefgh [$left (abcdefgh) - i];
        end
    endgenerate

    //------------------------------------------------------------------------

    tm1638_board_controller
    # (
        .clk_mhz ( clk_mhz    ),
        .w_digit ( w_tm_digit )        // fake parameter, digit count is hardcode in tm1638_board_controller
    )
    i_ledkey
    (
        .clk        ( clk           ),
        .rst        ( rst           ), // Don't make reset tm1638_board_controller by it's tm_key
        .hgfedcba   ( hgfedcba      ),
        .digit      ( tm_digit      ),
        .ledr       ( tm_led        ),
        .keys       ( tm_key        ),
        .sio_stb    ( GPIO_0 [27]   ), // JP1 pin 32
        .sio_clk    ( GPIO_0 [29]   ), // JP1 pin 34
        .sio_data   ( GPIO_0 [31]   )  // JP1 pin 36
    );                                 // JP1 pin 30 - GND, pin 29 - VCC 3.3V

    //------------------------------------------------------------------------

    inmp441_mic_i2s_receiver i_microphone
    (
        .clk   ( clk        ),
        .rst   ( rst        ),
        .lr    ( GPIO_0 [0] ),  // JP1 pin 1
        .ws    ( GPIO_0 [2] ),  // JP1 pin 3
        .sck   ( GPIO_0 [4] ),  // JP1 pin 5
        .sd    ( GPIO_0 [5] ),  // JP1 pin 6
        .value ( mic        )
    );

    assign GPIO_0 [1] = 1'b0;   // GND - JP1 pin 2
    assign GPIO_0 [3] = 1'b1;   // VCC - JP1 pin 4

endmodule
