`default_nettype none

module tt_um_DanielZhu123 (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,      
    input  wire       clk,      
    input  wire       rst_n
);
    // Bus de 11 bits pour éviter l'écrasement du bit de signe lors d'un overflow
    wire [10:0] con_ans;
    wire con_error;

    assign uio_oe = 8'hFF; 

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

    bit_10NT bit_10NTreal (
        .data(con_ans),
        .clk(clk),
        .reset(rst_n),
        .error(con_error),
        .display({uo_out, uio_out[5:0]}),
        .power13(uio_out[6]),
        .power24(uio_out[7])
    );

endmodule

module keyboard (
    input wire clk, reset, modesel, signsel_dispA, positionsel_dispB, 
    input wire numbersel_NOT, bit4_ADD, bit3_AND, bit2_OR, bit1_XOR,
    output reg [10:0] ans, 
    output reg error
);
    reg [8:0] numA, numB;

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

    always @(*) begin
        ans = 11'b0;
        error = 1'b0;
        
        if (modesel) begin
            if ((signsel_dispA + bit4_ADD + bit3_AND + bit2_OR + bit1_XOR) > 1) begin
                error = 1'b1;
            end else begin
                // Le bloc case vérifie uniquement l'opération
                case ({signsel_dispA, bit4_ADD, bit3_AND, bit2_OR, bit1_XOR})
                    5'b01000: ans = {2'b0, numA} + {2'b0, numB}; // ADD
                    5'b00100: ans = {2'b0, numA} & {2'b0, numB}; // AND
                    5'b00010: ans = {2'b0, numA} | {2'b0, numB}; // OR
                    5'b00001: ans = {2'b0, numA} ^ {2'b0, numB}; // XOR
                    default:  ans = (positionsel_dispB) ? {2'b0, numB} : {2'b0, numA}; 
                endcase

                if (numbersel_NOT) ans = ~ans;

                // Application des modificateurs avec le Switch B activé
                if (positionsel_dispB) begin
                    if (bit4_ADD) begin
                        ans = ans >> 4; 
                    end else if (bit3_AND) begin
                        ans = (numA > numB) ? {2'b0, numA} : {2'b0, numB}; 
                    end else if (bit2_OR) begin
                        ans = {2'b0, numA[0], numA[1], numA[2], numA[3], numA[4], numA[5], numA[6], numA[7], numA[8]}; 
                    end
                end
            end
        end else begin
            ans = (!numbersel_NOT) ? {2'b0, numA} : {2'b0, numB};
        end
    end
endmodule

module bit_10NT (
    input wire [10:0] data, 
    input wire clk, reset, error,
    output reg [13:0] display,
    output reg power13, power24
);
    reg [10:0] data_tep;
    reg [3:0] sign, num1, num2, num3;
    reg clk_div;

    always @(posedge clk) begin
        if (!reset) clk_div <= 0;
        else clk_div <= ~clk_div;
    end

    always @(*) begin
        display = 14'h3FFF; 
        power13 = 0; power24 = 0;
        data_tep = 0; sign = 0; num1 = 0; num2 = 0; num3 = 0;

        if (!error) begin
            
            // Le bit de signe est le bit [10]
            if (data[10] == 0) begin
                data_tep = data;
                sign = 0;
            end else begin
                data_tep = ~data + 1;
                sign = 1;
            end

            // GESTION OVERFLOW
            if (data_tep > 999) begin
                if (clk_div == 0) begin
                    power13 = 1;
                    display[13:7] = 7'b0110000; // 'E'
                    display[6:0]  = 7'b1111010; // 'r'
                end else begin
                    power24 = 1;
                    display[13:7] = 7'b1111010; // 'r'
                    display[6:0]  = 7'b1111111; 
                end
            end else begin
                // DECODAGE NORMAL
                num1 = data_tep / 100;
                num2 = (data_tep / 10) % 10;
                num3 = data_tep % 10;

                if (clk_div == 0) begin
                    power13 = 1;
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
    end
endmodule