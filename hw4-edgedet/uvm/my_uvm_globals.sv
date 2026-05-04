`ifndef __GLOBALS__
`define __GLOBALS__

// UVM Globals
localparam string IMG_IN_NAME  = "image.bmp";
localparam string IMG_OUT_NAME = "output.bmp";
localparam string IMG_CMP_NAME = "stage2_sobel.bmp";

//localparam int FRAME_WIDTH  = 612;
//localparam int FRAME_HEIGHT = 350;
localparam int FRAME_WIDTH  = 720;
localparam int FRAME_HEIGHT = 540;

localparam int BMP_HEADER_SIZE = 54;
localparam int BYTES_PER_PIXEL = 3;
localparam int BMP_DATA_SIZE = ( FRAME_WIDTH * FRAME_HEIGHT * BYTES_PER_PIXEL );
localparam int CLOCK_PERIOD = 10;

`endif
