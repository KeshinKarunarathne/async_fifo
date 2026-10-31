`timescale 1ps / 1fs
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.10.2026 22:09:33
// Design Name: 
// Module Name: sync_fifo_tb
// Project Name: 
// Target Devices: 
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

module async_fifo_tb;

parameter WIDTH         = 16;
parameter DEPTH         = 64;
parameter MAX_ERRORS    = 32;
parameter WR_CLK_FREQ   = 80; // MHz
parameter RD_CLK_FREQ   = 50; // MHz
parameter SIM_CYCLES    = 100;

// ----------
//  DUT I /O 
// ----------

// General
reg                             wr_clk;
reg                             rd_clk;
reg                             areset_n;
reg                             sreset;
wire [31:0]                     prbs_seed;

// PRBS Gen
wire                            prbs_gen_adv;
wire [WIDTH-1:0]                prbs_gen_out;

// PRBS Check
wire [WIDTH-1:0]                prbs_check_in;
wire                            prbs_check_adv;
wire [$clog2(MAX_ERRORS)-1:0]   errors;
reg                             toggle_check;   // To run toggle coverage of error

// FIFO
reg                             wr_en;
reg                             rd_en;
wire [WIDTH-1:0]                data_out;
wire                            full;
wire                            empty;


// Internal Signals
localparam wr_clk_period = 1000000 / WR_CLK_FREQ ; // ps
localparam rd_clk_period = 1000000 / RD_CLK_FREQ; // ps

integer    cycles;

class wr_en_ctrl;
    rand bit [3:0] wr_en_delay;

        constraint non_zero { wr_en_delay > 0; }
endclass

class rd_en_ctrl;
    rand bit [3:0] rd_en_delay; 

    constraint non_zero { rd_en_delay > 0; }
endclass


// Assignments
assign prbs_seed        = {32{1'b1}};
assign prbs_gen_adv     = wr_en && !full;
assign prbs_check_adv   = rd_en && !empty;
assign prbs_check_in    = toggle_check ?  '0 : data_out;

// Clock generation
always #(wr_clk_period/2) wr_clk = !wr_clk;
always #(rd_clk_period/2) rd_clk = !rd_clk;


// Module instantiations

prbs_gen # (
    .OUT_WIDTH  (WIDTH)
) prbs_gen_inst (
    .clk        (wr_clk),
    .areset_n   (areset_n),
    .sreset     (sreset),
    .advance    (prbs_gen_adv),
    .seed       (prbs_seed),
    .out        (prbs_gen_out)
);

prbs_check # (
    .OUT_WIDTH  (WIDTH),
    .MAX_ERRORS (MAX_ERRORS)
) prbs_check_inst (
    .clk        (rd_clk),
    .areset_n   (areset_n),
    .sreset     (sreset),
    .data_in    (prbs_check_in),
    .advance    (prbs_check_adv),
    .seed       (prbs_seed),
    .errors     (errors)
);


async_fifo # (
    .WIDTH      (WIDTH),
    .DEPTH      (DEPTH)
) async_fifo_inst (
    .wr_clk     (wr_clk),
    .rd_clk     (rd_clk),
    .areset_n   (areset_n),
    .sreset     (sreset),
    .data_in    (prbs_gen_out),
    .wr_en      (wr_en),
    .rd_en      (rd_en),
    .data_out   (data_out),
    .full       (full),
    .empty      (empty) 
);


// Creating class objects
wr_en_ctrl wr_en_ctrl_obj;
rd_en_ctrl rd_en_ctrl_obj;

// Creating FIFO occupancy staten enum
typedef enum {EMPTY, PARTIAL, FULL} occ_state_e;

occ_state_e occ_state;

assign occ_state =  (empty) ? EMPTY    :
                    (full)  ? FULL     :
                              PARTIAL  ;

// ------------
//  ASSERTIONS
// ------------

// Default clocking
default clocking cb_w @(posedge wr_clk); endclocking

// A0 :  Gray pointer checking
a_wr_gray: assert property (@(posedge wr_clk) $countones(async_fifo_inst.wr_ptr_g ^ $past(async_fifo_inst.wr_ptr_g)) <= 1);
a_rd_gray: assert property (@(posedge rd_clk) $countones(async_fifo_inst.rd_ptr_g ^ $past(async_fifo_inst.rd_ptr_g)) <= 1);

// A1: sreset state
a_sreset: assert property (@(posedge wr_clk) disable iff (1'b0) sreset |=> ##[0:2] (empty && !full) );

// A2: mutually exclusive full and empty flags
a_not_full_and_empty: assert property (@(posedge wr_clk) !(full && empty));


// ---------------
//   COVERGROUPS
// ---------------
c_full:          cover property (@(posedge wr_clk) $rose(full));
c_empty_again:   cover property (@(posedge rd_clk) $rose(empty));

covergroup cg_fifo @(posedge wr_clk);
  option.per_instance = 1;

  cp_occ: coverpoint async_fifo_inst.wr_ptr_b {              // from your TB model
    bins empty = {0};
    bins low   = {[1:DEPTH/4]};
    bins mid   = {[DEPTH/4+1 : 3*DEPTH/4]};
    bins high  = {[3*DEPTH/4+1 : DEPTH-2]};
    bins full  = {DEPTH-1};
  }

  cp_winc: coverpoint async_fifo_inst.wr_ptr_g;
  cp_rinc: coverpoint async_fifo_inst.rd_ptr_g_cdc;         // careful with sampling

  cp_trans: coverpoint occ_state {
    bins empty_to_nonempty = (EMPTY => PARTIAL);
    bins full_to_nonfull   = (FULL  => PARTIAL);
    bins fill_then_drain   = (EMPTY => PARTIAL => FULL => EMPTY);
  }
endgroup


cg_fifo cg = new();


initial begin
    if ($test$plusargs("trace") != 0) begin
        $display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
        $dumpfile("logs/vlt_dump.fst");
        $dumpvars();
    end

    // Initialise clk,. areset_n amd sreset
    wr_clk   = 0;
    rd_clk   = 0;
    areset_n = 0;
    sreset   = 1;
    wr_en    = 0;
    rd_en    = 0;

    toggle_check = 0;

    // Initialising class objects
    wr_en_ctrl_obj = new();
    rd_en_ctrl_obj = new();

    # (wr_clk_period*8);
    areset_n = 1;

    # (wr_clk_period*4);
    sreset = 0;

    fork
        // Thread to control wr_en
        forever begin
            wr_en = 0;
            wr_en_ctrl_obj.randomize();
            #(wr_en_ctrl_obj.wr_en_delay*wr_clk_period);
            
            wr_en = 1;
            wr_en_ctrl_obj.randomize();
            #(wr_en_ctrl_obj.wr_en_delay*wr_clk_period);
        end

        // Thread to control rd_en
        forever begin
            rd_en = 0;
            rd_en_ctrl_obj.randomize();
            #(rd_en_ctrl_obj.rd_en_delay*rd_clk_period);
            
            rd_en = 1;
            rd_en_ctrl_obj.randomize();
            #(rd_en_ctrl_obj.rd_en_delay*rd_clk_period);
        end

        // Thread to initiate end of simulation
        begin
            cycles = 0;

            while (cycles < SIM_CYCLES) begin
                if (async_fifo_inst.rd_ptr_b == DEPTH-1) begin
                    cycles ++;
                end
                #(rd_clk_period);

                if (cycles > 3*SIM_CYCLES/4) toggle_check = 1;
            end
        end
    join_any  // Expecting read process to end 

    $display("Simulation has ended");
    $finish;
end


endmodule

`default_nettype wire

