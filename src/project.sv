`default_nettype none

module tt_um_DanielZhu123 (
    input  wire [7:0] ui_in,    // Entrées dédiées
    output wire [7:0] uo_out,   // Sorties dédiées (Segments 7-0)
    input  wire [7:0] uio_in,   // E/S : chemin d'entrée
    output wire [7:0] uio_out,  // E/S : chemin de sortie
    output wire [7:0] uio_oe,   // E/S : contrôle de direction
    input  wire       ena,      
    input  wire       clk,      
    input  wire       rst_n     // reset_n - actif à l'état bas
);
    wire [9:0] con_ans;
    wire con_error;

    // Toutes les broches bidirectionnelles sont configurées en sorties pour les Nixie
    assign uio_oe = 8'hFF; 

    // --- MODULE CLAVIER ET ALU ---
    keyboard keyboardreal (
        .clk(clk),
        .reset(rst_n),
        .modesel(ui_in[7]),
        .signsel_dispA(ui_in[6]),
        .positionsel_dispB(ui_in[5]), 
        .numbersel_NOT(ui_in[4]),
        .bit4_ADD(ui_in[3]),
        .bit3_AND(ui_in[2]),
        .bit2_OR(ui_in[1]),
        .bit1_XOR(ui_in[0]),
        .ans(con_ans),
        .error(con_error)
    );

    // --- MODULE AFFICHEUR NIXIE MULTIPLEXÉ ---
    bit_10NT bit_10NTreal (
        .data(con_ans),
        .clk(clk),
        .reset(rst_n),
        .error(con_error),
        .display({uo_out, uio_out[5:0]}), // 14 bits de contrôle total
        .power13(uio_out[6]),            // Anodes tubes 1 et 3
        .power24(uio_out[7])             // Anodes tubes 2 et 4
    );

endmodule

module keyboard (
    input wire clk, reset, modesel, signsel_dispA, positionsel_dispB, 
    input wire numbersel_NOT, bit4_ADD, bit3_AND, bit2_OR, bit1_XOR,
    output reg [9:0] ans, output reg error
);
    reg [8:0] numA, numB;

    // Bloc de mémorisation synchrone (Élimine les 26 erreurs de latches)
    always @(posedge clk) begin
        if (!reset) begin
            numA <= 9'b0;
            numB <= 9'b0;
        end else if (!modesel) begin
            if (!numbersel_NOT) begin
                numA[8] <= signsel_dispA;
                if (!positionsel_dispB) numA[7:4] <= {bit4_ADD, bit3_AND, bit2_OR, bit1_XOR};
                else numA[3:0] <= {bit4_ADD, bit3_AND, bit2_OR, bit1_XOR};
            end else begin
                numB[8] <= signsel_dispA;
                if (!positionsel_dispB) numB[7:4] <= {bit4_ADD, bit3_AND, bit2_OR, bit1_XOR};
                else numB[3:0] <= {bit4_ADD, bit3_AND, bit2_OR, bit1_XOR};
            end
        end
    end

    // Bloc Combinatoire : Calcul et Option Flottante (Division par 16)
    always @(*) begin
        ans = 10'b0;
        error = 1'b0;
        
        if (modesel) begin
            // Sécurité : On vérifie qu'une seule fonction est sélectionnée
            if ((signsel_dispA + bit4_ADD + bit3_AND + bit2_OR + bit1_XOR) > 1) begin
                error = 1'b1;
            end else begin
                case ({signsel_dispA, positionsel_dispB, bit4_ADD, bit3_AND, bit2_OR, bit1_XOR})
                    6'b100000: ans = {1'b0, numA}; // Affiche A
                    6'b010000: ans = {1'b0, numB}; // Affiche B
                    6'b001000: ans = {1'b0, numA} + {1'b0, numB}; // ADD
                    6'b000100: ans = {1'b0, numA} & {1'b0, numB}; // AND
                    6'b001000: ans = {1'b0, numA} | {1'b0, numB}; // OR
                    6'b000001: ans = {1'b0, numA} ^ {1'b0, numB}; // XOR
                    default:   ans = {1'b0, numA}; // Par défaut affiche A
                endcase

                // Logique NOT
                if (numbersel_NOT) ans = ~ans;

                // AMÉLIORATION : Division par 16 (Bit-Shift)
                // Si on est en mode ADD (bit3) et que le switch B (bit5) est ON
                if (bit4_ADD && positionsel_dispB) begin
                    ans = ans >> 4;
                end
            end
        end else begin
            // Mode Saisie : prévisualisation du nombre en cours
            ans = (!numbersel_NOT) ? {1'b0, numA} : {1'b0, numB};
        end
    end
endmodule

module bit_10NT (
    input wire [9:0] data,
    input wire clk, reset, error,
    output reg [13:0] display,
    output reg power13, power24
);
    reg [9:0] data_tep;
    reg [3:0] sign, num1, num2, num3;
    reg clk_div;

    // FIX : Initialisation du clk_div pour supprimer la ligne rouge GTKWave
    always @(posedge clk) begin
        if (!reset) clk_div <= 0;
        else clk_div <= ~clk_div;
    end

    always @(*) begin
        // Valeurs par défaut pour éviter les latches
        display = 14'h3FFF; // Tout éteint (actif bas)
        power13 = 0; power24 = 0;
        data_tep = 0; sign = 0; num1 = 0; num2 = 0; num3 = 0;

        if (!error) begin
            // Gestion du signe
            if (data[9] == 0) begin
                data_tep = data;
                sign = 0;
            end else begin
                data_tep = ~data + 1;
                sign = 1;
            end

            // Décodage des chiffres
            num1 = data_tep / 100;
            num2 = (data_tep / 10) % 10;
            num3 = data_tep % 10;

            if (clk_div == 0) begin
                power13 = 1;
                // Signe et Chiffre 2
                case(sign)
                    4'd0: display[13:7] = 7'b1111111; 
                    4'd1: display[13:7] = 7'b1111110; 
                    default: display[13:7] = 7'b0000000;
                endcase
                case(num2)
                    4'd0:display[6:0]=7'b0000001; 4'd1:display[6:0]=7'b1001111;
                    4'd2:display[6:0]=7'b0010010; 4'd3:display[6:0]=7'b0000011;
                    4'd4:display[6:0]=7'b1001100; 4'd5:display[6:0]=7'b0100100;
                    4'd6:display[6:0]=7'b0100000; 4'd7:display[6:0]=7'b0001111;
                    4'd8:display[6:0]=7'b0000000; 4'd9:display[6:0]=7'b0000100;
                    default:display[6:0]=7'b1111111;
                endcase
            end else begin
                power24 = 1;
                // Chiffre 1 et Chiffre 3
                case(num1)
                    4'd0:display[13:7]=7'b0000001; 4'd1:display[13:7]=7'b1001111;
                    4'd2:display[13:7]=7'b0010010; 4'd3:display[13:7]=7'b0000011;
                    4'd4:display[13:7]=7'b1001100; 4'd5:display[13:7]=7'b0100100;
                    4'd6:display[13:7]=7'b0100000; 4'd7:display[13:7]=7'b0001111;
                    4'd8:display[13:7]=7'b0000000; 4'd9:display[13:7]=7'b0000100;
                    default:display[13:7]=7'b1111111;
                endcase
                case(num3)
                    4'd0:display[6:0]=7'b0000001; 4'd1:display[6:0]=7'b1001111;
                    4'd2:display[6:0]=7'b0010010; 4'd3:display[6:0]=7'b0000011;
                    4'd4:display[6:0]=7'b1001100; 4'd5:display[6:0]=7'b0100100;
                    4'd6:display[6:0]=7'b0100000; 4'd7:display[6:0]=7'b0001111;
                    4'd8:display[6:0]=7'b0000000; 4'd9:display[6:0]=7'b0000100;
                    default:display[6:0]=7'b1111111;
                endcase
            end
        end
    end
endmodule