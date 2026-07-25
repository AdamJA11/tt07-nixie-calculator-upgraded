`timescale 1ns/1ps
module test_simple;
    reg clk, rst_n;
    reg [7:0] ui_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;

    // Connexion à ta calculatrice
    tt_um_DanielZhu123 dut (
        .clk(clk), .rst_n(rst_n), .ui_in(ui_in), 
        .uo_out(uo_out), .uio_out(uio_out),
        .ena(1'b1), .uio_in(8'b0), .uio_oe()
    );

    initial begin
        $dumpfile("simulation.vcd"); $dumpvars(0, test_simple);
        clk = 0; rst_n = 0; ui_in = 0;
        #20 rst_n = 1; // Relâche le reset
        #20 ui_in = 8'b00001010; // Exemple : on active des switchs
        #100 $display("Simulation terminée. Ouvre simulation.vcd");
        $finish;
    end
    always #5 clk = ~clk; // Horloge à 100MHz
endmodule
