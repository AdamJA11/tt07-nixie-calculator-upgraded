`timescale 1us/1ps

module tb;

  // ── Horloges & contrôle ──
  reg clk;
  reg rst_n;
  reg ena;

  // ── Entrées DUT ──
  reg [7:0] ui_in;
  reg [7:0] uio_in;

  // ── Sorties DUT ──
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  // ── Instanciation du DUT ──
  tt_um_DanielZhu123 user_project (
    .ui_in  (ui_in),
    .uo_out (uo_out),
    .uio_in (uio_in),
    .uio_out(uio_out),
    .uio_oe (uio_oe),
    .ena    (ena),
    .clk    (clk),
    .rst_n  (rst_n)
  );

  // ── Initialisation ──
  initial begin
    clk    = 0;
    rst_n  = 0;
    ena    = 0;
    ui_in  = 8'h00;
    uio_in = 8'h00;
  end

  // ── Horloge 10 µs (50 kHz) — cocotb fixera sa propre période ──
  always #5 clk = ~clk;

  // ── Dump VCD pour GTKWave ──
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);   // 0 = dump récursif de tout le design
  end

endmodule