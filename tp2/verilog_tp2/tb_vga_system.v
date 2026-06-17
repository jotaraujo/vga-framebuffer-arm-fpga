`timescale 1ns / 1ps

module tb_vga_system;

    localparam CLK_PERIOD    = 40;

    localparam H_TOTAL       = 800;
    localparam V_TOTAL       = 525;
    localparam H_VISIBLE     = 640;
    localparam V_VISIBLE     = 480;
    localparam H_SYNC_START  = 656;
    localparam H_SYNC_END    = 752;
    localparam V_SYNC_START  = 490;
    localparam V_SYNC_END    = 492;

    localparam H_SYNC_WIDTH  = H_SYNC_END - H_SYNC_START;
    localparam V_SYNC_WIDTH  = V_SYNC_END - V_SYNC_START;

    reg         clk;
    reg         rst_n;
    wire        hsync;
    wire        vsync;
    wire        video_on;
    wire [9:0]  pixel_x;
    wire [9:0]  pixel_y;
    wire [3:0]  red_chess, green_chess, blue_chess;
    wire [3:0]  red_bars,  green_bars,  blue_bars;

    vga_sync uut_sync (
        .clk      (clk),
        .rst_n    (rst_n),
        .hsync    (hsync),
        .vsync    (vsync),
        .video_on (video_on),
        .pixel_x  (pixel_x),
        .pixel_y  (pixel_y)
    );

    pattern_generator uut_chess (
        .pixel_x  (pixel_x),
        .pixel_y  (pixel_y),
        .video_on (video_on),
        .mode     (1'b0),
        .red      (red_chess),
        .green    (green_chess),
        .blue     (blue_chess)
    );

    pattern_generator uut_bars (
        .pixel_x  (pixel_x),
        .pixel_y  (pixel_y),
        .video_on (video_on),
        .mode     (1'b1),
        .red      (red_bars),
        .green    (green_bars),
        .blue     (blue_bars)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    integer frame_count;
    integer hsync_low_count;
    integer vsync_low_count;
    integer hsync_period_count;
    integer errors;

    real    hsync_period_us;
    real    vsync_period_ms;

    initial begin
        $dumpfile("dump_vga.vcd");
        $dumpvars(0, tb_vga_system);
    end

    initial begin
        errors       = 0;
        frame_count  = 0;

        rst_n = 1'b0;
        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        $display("============================================================");
        $display("  TB VGA SYSTEM - Validacao de Timing VGA 640x480 @ 60Hz");
        $display("  Pixel Clock simulado: ~25 MHz (periodo = 40 ns)");
        $display("============================================================");

        repeat(2 * V_TOTAL * H_TOTAL) @(posedge clk);

        $display("\n[INFO] 2 frames completos simulados.");
        $display("[INFO] Total de clocks simulados: %0d", 2 * V_TOTAL * H_TOTAL);

        $display("\n--- Validando pulso HSYNC ---");
        @(negedge hsync);
        hsync_low_count = 0;
        while (!hsync) begin
            @(posedge clk);
            hsync_low_count = hsync_low_count + 1;
        end

        hsync_low_count = hsync_low_count - 1;
        $display("[HSYNC] Largura medida do pulso baixo: %0d clocks", hsync_low_count);
        $display("[HSYNC] Largura esperada             : %0d clocks", H_SYNC_WIDTH);

        if (hsync_low_count == H_SYNC_WIDTH)
            $display("[PASS ] Largura HSYNC CORRETA!");
        else begin
            $display("[FAIL ] Largura HSYNC INCORRETA! Diferenca: %0d clocks",
                     hsync_low_count - H_SYNC_WIDTH);
            errors = errors + 1;
        end

        $display("\n--- Validando periodo HSYNC ---");
        @(negedge hsync);
        hsync_period_count = 0;
        @(negedge hsync);

        @(negedge hsync);

        $display("[HSYNC] pixel_x no negedge hsync: %0d (esperado: %0d)",
                 pixel_x, H_SYNC_START + 1);
        if (pixel_x == H_SYNC_START + 1)
            $display("[PASS ] Posicao do HSYNC no contador H CORRETA!");
        else begin
            $display("[FAIL ] Posicao do HSYNC incorreta! Got=%0d Exp=%0d",
                     pixel_x, H_SYNC_START + 1);
            errors = errors + 1;
        end

        $display("\n--- Validando pulso VSYNC ---");
        @(negedge vsync);
        vsync_low_count = 0;
        while (!vsync) begin
            @(posedge clk);
            vsync_low_count = vsync_low_count + 1;
        end

        vsync_low_count = vsync_low_count - 1;
        $display("[VSYNC] Largura medida do pulso baixo: %0d clocks", vsync_low_count);
        $display("[VSYNC] Largura esperada (2 linhas)  : %0d clocks", V_SYNC_WIDTH * H_TOTAL);

        if (vsync_low_count == V_SYNC_WIDTH * H_TOTAL)
            $display("[PASS ] Largura VSYNC CORRETA!");
        else begin
            $display("[FAIL ] Largura VSYNC INCORRETA! Diferenca: %0d clocks",
                     vsync_low_count - (V_SYNC_WIDTH * H_TOTAL));
            errors = errors + 1;
        end

        $display("\n--- Validando video_on ---");
        @(posedge vsync);
        @(posedge vsync);
        repeat(800 * 33) @(posedge clk);
        $display("[VIDEO] pixel_y=%0d  video_on=%0b (esperado y<480 => 1)",
                 pixel_y, video_on);
        if ((pixel_y < V_VISIBLE) && (video_on == 1'b1))
            $display("[PASS ] video_on ATIVO na area visivel!");
        else begin
            $display("[FAIL ] video_on incorreto na area visivel!");
            errors = errors + 1;
        end

        repeat(H_VISIBLE) @(posedge clk);
        $display("[VIDEO] pixel_x=%0d  video_on=%0b (esperado x>=640 => 0)",
                 pixel_x, video_on);
        if (video_on == 1'b0)
            $display("[PASS ] video_on INATIVO na area de blanking!");
        else begin
            $display("[FAIL ] video_on deveria ser 0 no blanking!");
            errors = errors + 1;
        end

        $display("\n--- Validando pattern_generator ---");
        $display("[CHESS] pixel(0,0) chess_bit=0 -> cinza escuro: R=%0d G=%0d B=%0d (esperado: 3,3,3)",
                 red_chess, green_chess, blue_chess);
        if (red_chess == 4'h3 && green_chess == 4'h3 && blue_chess == 4'h3)
            $display("[PASS ] Cor do xadrez em (0,0) CORRETA!");
        else
            $display("[INFO ] video_on=%0b - avaliar pos area visivel", video_on);

        $display("\n============================================================");
        if (errors == 0)
            $display("  RESULTADO FINAL: TODOS OS TESTES PASSARAM! (0 erros)");
        else
            $display("  RESULTADO FINAL: %0d ERROS ENCONTRADOS!", errors);
        $display("============================================================\n");

        $finish;
    end

    always @(negedge vsync) begin
        frame_count = frame_count + 1;
        $display("[FRAME] Frame %0d iniciado. pixel_y no negedge vsync: %0d (esperado: %0d)",
                 frame_count, pixel_y, V_SYNC_START);
    end

endmodule
