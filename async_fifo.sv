`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.10.2026 15:23:07
// Design Name: 
// Module Name: async_fifo
// Project Name: 
// Target Devices: Basys 3
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`default_nettype none

module async_fifo # (
    parameter WIDTH = 16,
    parameter DEPTH = 8
) (
    input wire              wr_clk,
    input wire              rd_clk,
    input wire              areset_n,
    input wire              sreset,

    input wire [WIDTH-1:0]  data_in,
    input wire              wr_en,
    input wire              rd_en,

    output wire [WIDTH-1:0] data_out,
    output wire             full,
    output wire             empty
);

// Internal signals
                                                    logic [WIDTH-1:0]       fifo [DEPTH-1:0];

(* mark_debug = "true" *)                           logic [$clog2(DEPTH):0] wr_ptr_b; // Write pointer in write domain in binary
(* mark_debug = "true" *)                           logic [$clog2(DEPTH):0] rd_ptr_b; // Read pointer in read domain in binary

(* mark_debug = "true" *)                           logic [$clog2(DEPTH):0] wr_ptr_g; // Write pointer in write domain in grey
(* mark_debug = "true" *)                           logic [$clog2(DEPTH):0] rd_ptr_g; // Read pointer in read domain in grey

(* mark_debug = "true" *) (* ASYNC_REG = "TRUE" *)  logic [$clog2(DEPTH):0] wr_ptr_g_meta;
(* mark_debug = "true" *)                           logic [$clog2(DEPTH):0] wr_ptr_g_cdc; // Write pointer in read domain in grey

(* mark_debug = "true" *) (* ASYNC_REG = "TRUE" *)  logic [$clog2(DEPTH):0] rd_ptr_g_meta; 
(* mark_debug = "true" *)                           logic [$clog2(DEPTH):0] rd_ptr_g_cdc; // Read pointer in write domain in grey



// Submodule instantiations
bin_to_gray #(.WIDTH($clog2(DEPTH)+1)) bin_to_gray_wr (.in(wr_ptr_b), .out(wr_ptr_g));
bin_to_gray #(.WIDTH($clog2(DEPTH)+1)) bin_to_gray_rd (.in(rd_ptr_b), .out(rd_ptr_g));

// Wire assignemnts
assign full = (wr_ptr_g[$clog2(DEPTH) -: 2] == ~rd_ptr_g_cdc[$clog2(DEPTH) -: 2]) && // Testing 2 MSBs in gray-coded state
              (wr_ptr_g[$clog2(DEPTH)-2:0]  ==  rd_ptr_g_cdc[$clog2(DEPTH)-2:0]);
              
assign empty = (rd_ptr_g == wr_ptr_g_cdc);

assign data_out = fifo[rd_ptr_b[$clog2(DEPTH)-1:0]];

// Write logic 
always_ff @(posedge wr_clk or negedge areset_n)
  begin
    if (!areset_n)
      begin
        wr_ptr_b        <= '0;
        fifo            <= '{default : '0};
        rd_ptr_g_meta   <= '0;
        rd_ptr_g_cdc    <= '0;
      end
    else if (sreset)
      begin
        wr_ptr_b        <= '0;
        fifo            <= '{default : '0};
        rd_ptr_g_meta   <= '0;
        rd_ptr_g_cdc    <= '0;
      end
    else
      begin
        // Clock domain crossing
        rd_ptr_g_meta <= rd_ptr_g;
        rd_ptr_g_cdc <= rd_ptr_g_meta;
        
        if (wr_en && !full)
          begin
            wr_ptr_b <= wr_ptr_b + 1;
            fifo[wr_ptr_b[$clog2(DEPTH)-1:0]] <= data_in;
          end
      end
  end
  
// Read logic
always_ff @(posedge rd_clk or negedge areset_n)
  begin
    if (!areset_n)
      begin
        rd_ptr_b        <= '0;
        wr_ptr_g_meta   <= '0;
        wr_ptr_g_cdc    <= '0;
      end
    else if (sreset)
      begin
        rd_ptr_b        <= '0;
        wr_ptr_g_meta   <= '0;
        wr_ptr_g_cdc    <= '0;
      end
    else
      begin
        // Clock domain crossing
        wr_ptr_g_meta <= wr_ptr_g;
        wr_ptr_g_cdc  <= wr_ptr_g_meta;
        
        if (rd_en && !empty)
          begin
            rd_ptr_b <= rd_ptr_b + 1;
          end
      end
  end
  
  
endmodule

`default_nettype wire
