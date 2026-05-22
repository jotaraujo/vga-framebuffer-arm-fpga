// ============================================================
// Projeto  : Controlador VGA com Framebuffer ARM->FPGA
// Arquivo  : tb_color_selector.v
// Modulo   : tb_color_selector (Testbench)
// Descricao: Testbench para verificacao do modulo color_selector
//            Varre todas as 8 regioes horizontais e verifica
//            as saidas RGB esperadas para cada barra de cor
// TP       : TP1 - Concepcao e Fundamentos
// Simulador: Icarus Verilog (iverilog) ou Gowin IDE
// ============================================================

`timescale 1ns / 1ps

module tb_color_selector;

    // --- Sinais de estimulo (inputs do DUT) ---
    reg  [9:0] pixel_x;
    reg  [8:0] pixel_y;

    // --- Sinais de observacao (outputs do DUT) ---
    wire [3:0] red;
    wire [3:0] green;
    wire [3:0] blue;

    // --- Instancia do Design Under Test ---
    color_selector DUT (
        .pixel_x (pixel_x),
        .pixel_y (pixel_y),
        .red     (red),
        .green   (green),
        .blue    (blue)
    );

    // --- Contadores de teste ---
    integer pass_count;
    integer fail_count;

    // --- Tarefa de verificacao ---
    task check_color;
        input [9:0] test_x;
        input [8:0] test_y;
        input [3:0] exp_r, exp_g, exp_b;
        input [127:0] bar_name; // nome da barra (para log)
        begin
            pixel_x = test_x;
            pixel_y = test_y;
            #5; // aguarda propagacao combinacional
            if (red === exp_r && green === exp_g && blue === exp_b) begin
                $display("[PASS] Barra %-8s x=%3d -> R=%h G=%h B=%h",
                         bar_name, test_x, red, green, blue);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Barra %-8s x=%3d -> Esperado R=%h G=%h B=%h | Obtido R=%h G=%h B=%h",
                         bar_name, test_x, exp_r, exp_g, exp_b, red, green, blue);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // --- Procedimento principal de teste ---
    initial begin
        // Dump de forma de onda para visualizacao
        $dumpfile("tb_color_selector.vcd");
        $dumpvars(0, tb_color_selector);

        // Inicializacao
        pass_count = 0;
        fail_count = 0;
        pixel_x    = 0;
        pixel_y    = 10'd240; // Linha do meio da tela (y=240)

        $display("=================================================");
        $display("  Testbench: color_selector - VGA Color Bars     ");
        $display("  Resolucao: 640x480 | 8 barras de 80px          ");
        $display("=================================================");
        #10;

        // --- Teste 1: Barra Branca (x = 0..79) ---
        check_color(10'd0,   9'd240, 4'hF, 4'hF, 4'hF, "BRANCO");
        check_color(10'd40,  9'd240, 4'hF, 4'hF, 4'hF, "BRANCO");
        check_color(10'd79,  9'd240, 4'hF, 4'hF, 4'hF, "BRANCO");

        // --- Teste 2: Barra Amarela (x = 80..159) ---
        check_color(10'd80,  9'd240, 4'hF, 4'hF, 4'h0, "AMARELO");
        check_color(10'd120, 9'd240, 4'hF, 4'hF, 4'h0, "AMARELO");

        // --- Teste 3: Barra Ciano (x = 160..239) ---
        check_color(10'd160, 9'd240, 4'h0, 4'hF, 4'hF, "CIANO");
        check_color(10'd200, 9'd240, 4'h0, 4'hF, 4'hF, "CIANO");

        // --- Teste 4: Barra Verde (x = 240..319) ---
        check_color(10'd240, 9'd240, 4'h0, 4'hF, 4'h0, "VERDE");
        check_color(10'd280, 9'd240, 4'h0, 4'hF, 4'h0, "VERDE");

        // --- Teste 5: Barra Magenta (x = 320..399) ---
        check_color(10'd320, 9'd240, 4'hF, 4'h0, 4'hF, "MAGENTA");
        check_color(10'd360, 9'd240, 4'hF, 4'h0, 4'hF, "MAGENTA");

        // --- Teste 6: Barra Vermelha (x = 400..479) ---
        check_color(10'd400, 9'd240, 4'hF, 4'h0, 4'h0, "VERMELHO");
        check_color(10'd440, 9'd240, 4'hF, 4'h0, 4'h0, "VERMELHO");

        // --- Teste 7: Barra Azul (x = 480..559) ---
        check_color(10'd480, 9'd240, 4'h0, 4'h0, 4'hF, "AZUL");
        check_color(10'd520, 9'd240, 4'h0, 4'h0, 4'hF, "AZUL");

        // --- Teste 8: Barra Preta (x = 560..639) ---
        check_color(10'd560, 9'd240, 4'h0, 4'h0, 4'h0, "PRETO");
        check_color(10'd639, 9'd240, 4'h0, 4'h0, 4'h0, "PRETO");

        // --- Teste de independencia da coordenada Y ---
        pixel_y = 9'd0;   check_color(10'd0, 9'd0,   4'hF, 4'hF, 4'hF, "Y=0");
        pixel_y = 9'd479; check_color(10'd0, 9'd479, 4'hF, 4'hF, 4'hF, "Y=479");

        // --- Relatorio final ---
        #10;
        $display("=================================================");
        $display("  Resultado: %0d PASS | %0d FAIL", pass_count, fail_count);
        if (fail_count == 0)
            $display("  STATUS: TODOS OS TESTES PASSARAM");
        else
            $display("  STATUS: FALHA EM %0d TESTE(S)", fail_count);
        $display("=================================================");

        $finish;
    end

endmodule
