`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.10.2026 17:21:09
// Design Name: 
// Module Name: bin_to_gray
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

module bin_to_gray # (
    parameter WIDTH = 8
) (
    input wire [WIDTH-1:0]      in,
    output reg [WIDTH-1:0]     out
);

always_comb
  begin
    for (int a = 0; a < WIDTH; a = a + 1)
      begin
        if (a == WIDTH-1) out[a] = in[a];
        else              out[a] = in[a] ^ in[a+1];
      end
  end

endmodule

`default_nettype wire
