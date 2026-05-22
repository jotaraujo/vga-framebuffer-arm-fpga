// ============================================================
// Projeto  : Controlador VGA com Framebuffer ARM->FPGA
// Arquivo  : color_selector.v
// Modulo   : color_selector
// Descricao: Modulo combinacional de selecao de cor por regiao
//            Divide a tela em 8 barras verticais coloridas
//            Entrada: coordenada de pixel (x, y)
//            Saida  : componentes RGB de 4 bits
// TP       : TP1 - Concepcao e Fundamentos
// ============================================================

module color_selector (
    input  wire [9:0] pixel_x,   // coordenada X: 0..639
    input  wire [8:0] pixel_y,   // coordenada Y: 0..479
    output reg  [3:0] red,       // canal vermelho 4 bits
    output reg  [3:0] green,     // canal verde    4 bits
    output reg  [3:0] blue       // canal azul     4 bits
);

    // Divide os 640 pixels horizontais em 8 barras de 80px cada
    // pixel_x[9:7] = pixel_x / 128 (5 regioes em 640px com 128px cada)
    // Usamos pixel_x / 80 para 8 barras exatas
    wire [3:0] region;
    assign region = pixel_x[9:3] / 10; // aproximacao: 640/8 = 80px por barra

    // Logica combinacional pura: sem clock, sem estado
    always @(*) begin
        case (region)
            4'd0: begin // Branco
                red   = 4'hF;
                green = 4'hF;
                blue  = 4'hF;
            end
            4'd1: begin // Amarelo
                red   = 4'hF;
                green = 4'hF;
                blue  = 4'h0;
            end
            4'd2: begin // Ciano
                red   = 4'h0;
                green = 4'hF;
                blue  = 4'hF;
            end
            4'd3: begin // Verde
                red   = 4'h0;
                green = 4'hF;
                blue  = 4'h0;
            end
            4'd4: begin // Magenta
                red   = 4'hF;
                green = 4'h0;
                blue  = 4'hF;
            end
            4'd5: begin // Vermelho
                red   = 4'hF;
                green = 4'h0;
                blue  = 4'h0;
            end
            4'd6: begin // Azul
                red   = 4'h0;
                green = 4'h0;
                blue  = 4'hF;
            end
            default: begin // Preto
                red   = 4'h0;
                green = 4'h0;
                blue  = 4'h0;
            end
        endcase
    end

endmodule
