// ============================================================
// Projeto  : Controlador VGA com Framebuffer ARM->FPGA
// Arquivo  : spi_emulator.s
// Descricao: Programa Assembly AArch64 que simula a escrita
//            sequencial de pixels num buffer de transmissao
//            (ensaio inicial de comunicacao ARM->FPGA via SPI)
//
//            Estrutura:
//              - Buffer de 640x480 = 307200 bytes na secao .bss
//              - Loop duplo Y(0..479) x X(0..639)
//              - Formula: addr = y * 640 + x
//              - Aplica padrão de cor via decisoes condicionais:
//                  * Borda (x=0 | x=639 | y=0 | y=479) -> cor 0xFF (branco)
//                  * Cruz central (|x-320|<4 | |y-240|<4) -> cor 0xE0 (vermelho)
//                  * Xadrez 32x32 (x[5]^y[5])           -> cor 0x1C ou 0x03
//              - Ao final: imprime estatisticas via SYS_WRITE
//              - Usa x29/x30 para frame pointer e link register
//
// Plataforma: Raspberry Pi Zero 2W | AArch64 Linux
// Compilar  : gcc -o spi_emulator spi_emulator.s -no-pie
// Executar  : ./spi_emulator
// Depurar   : gdb ./spi_emulator
// ============================================================

// --- Constantes do framebuffer ---
.equ FB_WIDTH,      640
.equ FB_HEIGHT,     480
.equ FB_SIZE,       307200          // 640 * 480

// --- Constantes de cores (formato 8bpp: RRRGGGBB) ---
.equ COLOR_WHITE,   0xFF            // 11111111 - borda branca
.equ COLOR_RED,     0xE0            // 11100000 - cruz central vermelha
.equ COLOR_LIGHT,   0x1C           // 00011100 - xadrez claro (verde)
.equ COLOR_DARK,    0x03            // 00000011 - xadrez escuro (azul)

// --- Syscalls Linux AArch64 ---
.equ SYS_WRITE,     64
.equ SYS_EXIT,      93
.equ STDOUT,        1

// ============================================================
.section .bss
.align 12                           // Alinha em 4KB (pagina de memoria)
// ============================================================

tx_buffer:
    .space FB_SIZE                  // Buffer de transmissao: 307200 bytes

// ============================================================
.section .data
.align 3
// ============================================================

msg_header:
    .ascii "============================================\n"
    .ascii "  SPI Emulator TP2 - ARM64 Assembly\n"
    .ascii "  Framebuffer: 640x480 @ 8bpp = 307200 bytes\n"
    .ascii "============================================\n"
msg_header_len = . - msg_header

msg_filling:
    .ascii "\n[INFO] Preenchendo buffer de transmissao...\n"
msg_filling_len = . - msg_filling

msg_done:
    .ascii "[OK]   Buffer preenchido com sucesso.\n"
msg_done_len = . - msg_done

msg_stats_hdr:
    .ascii "\n--- Verificacao de amostras do buffer ---\n"
msg_stats_hdr_len = . - msg_stats_hdr

msg_pixel_prefix:
    .ascii "  buffer["
msg_pixel_prefix_len = . - msg_pixel_prefix

msg_pixel_eq:
    .ascii "] = 0x"
msg_pixel_eq_len = . - msg_pixel_eq

msg_newline:
    .ascii "\n"

msg_footer:
    .ascii "\n[OK] Ensaio de comunicacao ARM->FPGA concluido.\n"
    .ascii "[OK] Dados prontos para transmissao SPI.\n\n"
msg_footer_len = . - msg_footer

// Buffer para conversao numerica
num_buf:    .space 24
hex_buf:    .space 10

// ============================================================
.section .text
.global _start
// ============================================================

// ------------------------------------------------------------
// _start: ponto de entrada
// Salva x29 (frame pointer) e x30 (link register) na stack
// conforme ABI AArch64
// ------------------------------------------------------------
_start:
    // Prologue: establece frame pointer
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    // --- Imprime cabecalho ---
    mov     x0, #STDOUT
    ldr     x1, =msg_header
    mov     x2, #msg_header_len
    mov     x8, #SYS_WRITE
    svc     #0

    // --- Imprime mensagem de inicio ---
    mov     x0, #STDOUT
    ldr     x1, =msg_filling
    mov     x2, #msg_filling_len
    mov     x8, #SYS_WRITE
    svc     #0

    // --- Chama rotina de preenchimento do buffer ---
    bl      fill_buffer

    // --- Imprime mensagem de conclusao ---
    mov     x0, #STDOUT
    ldr     x1, =msg_done
    mov     x2, #msg_done_len
    mov     x8, #SYS_WRITE
    svc     #0

    // --- Chama rotina de verificacao de amostras ---
    bl      verify_samples

    // --- Imprime rodape ---
    mov     x0, #STDOUT
    ldr     x1, =msg_footer
    mov     x2, #msg_footer_len
    mov     x8, #SYS_WRITE
    svc     #0

    // Epilogue e saida
    ldp     x29, x30, [sp], #16
    mov     x0, #0
    mov     x8, #SYS_EXIT
    svc     #0


// ------------------------------------------------------------
// fill_buffer: loop duplo Y x X
//
// Registradores utilizados:
//   x19 = base do tx_buffer
//   x20 = y (linha atual, 0..479)
//   x21 = x (coluna atual, 0..639)
//   x22 = addr = y * 640 + x (offset em bytes)
//   x23 = valor de cor a ser escrito
//   x24 = scratch para calculos condicionais
//   x25 = scratch para valor absoluto (|x-320|, |y-240|)
// ------------------------------------------------------------
fill_buffer:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]

    ldr     x19, =tx_buffer         // Base do buffer
    mov     x20, #0                 // y = 0

loop_y:
    cmp     x20, #FB_HEIGHT         // y < 480 ?
    bge     loop_y_done

    mov     x21, #0                 // x = 0

loop_x:
    cmp     x21, #FB_WIDTH          // x < 640 ?
    bge     loop_x_done

    // ---- Calcula addr = y * 640 + x ----
    mov     x24, #FB_WIDTH
    mul     x22, x20, x24           // x22 = y * 640
    add     x22, x22, x21           // x22 = y * 640 + x

    // ---- Decisao 1: borda? (x==0 | x==639 | y==0 | y==479) ----
    cmp     x21, #0
    beq     .set_white
    cmp     x21, #(FB_WIDTH - 1)
    beq     .set_white
    cmp     x20, #0
    beq     .set_white
    cmp     x20, #(FB_HEIGHT - 1)
    beq     .set_white

    // ---- Decisao 2: cruz central? ----
    // Verifica |x - 320| < 4
    mov     x24, #320
    subs    x25, x21, x24           // x25 = x - 320 (com flags)
    bge     .check_abs_x_pos
    neg     x25, x25                // |x - 320|
.check_abs_x_pos:
    cmp     x25, #4
    blt     .set_red                // |x-320| < 4 -> cruz vertical

    // Verifica |y - 240| < 4
    mov     x24, #240
    subs    x25, x20, x24           // x25 = y - 240
    bge     .check_abs_y_pos
    neg     x25, x25                // |y - 240|
.check_abs_y_pos:
    cmp     x25, #4
    blt     .set_red                // |y-240| < 4 -> cruz horizontal

    // ---- Decisao 3: xadrez 32x32 (bit 5 de x XOR bit 5 de y) ----
    lsr     x24, x21, #5            // x24 = x >> 5
    lsr     x25, x20, #5            // x25 = y >> 5
    eor     x24, x24, x25           // x24 = (x>>5) XOR (y>>5)
    and     x24, x24, #1            // bit 0 apenas
    cbnz    x24, .set_light
    mov     x23, #COLOR_DARK
    b       .write_pixel

.set_light:
    mov     x23, #COLOR_LIGHT
    b       .write_pixel

.set_white:
    mov     x23, #COLOR_WHITE
    b       .write_pixel

.set_red:
    mov     x23, #COLOR_RED

.write_pixel:
    // STRB: escreve 1 byte na posicao tx_buffer[addr]
    strb    w23, [x19, x22]

    add     x21, x21, #1            // x++
    b       loop_x

loop_x_done:
    add     x20, x20, #1            // y++
    b       loop_y

loop_y_done:
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret


// ------------------------------------------------------------
// verify_samples: lê e imprime 6 pixels de referencia
// Pontos: canto(0,0), centro(320,240), borda_dir(639,0),
//         cruz_v(320,100), cruz_h(100,240), xadrez(50,50)
// Registradores:
//   x19 = base do buffer
//   x20 = y do ponto amostrado
//   x21 = x do ponto amostrado
//   x22 = addr calculado
//   x23 = valor lido (LDRB)
// ------------------------------------------------------------
verify_samples:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]

    ldr     x19, =tx_buffer

    // Imprime cabecalho da secao
    mov     x0, #STDOUT
    ldr     x1, =msg_stats_hdr
    mov     x2, #msg_stats_hdr_len
    mov     x8, #SYS_WRITE
    svc     #0

    // Carrega tabela de pontos de amostragem
    adr     x24, sample_table
    mov     x20, #6                 // 6 amostras

.sample_loop:
    cbz     x20, .sample_done

    // Carrega x e y da tabela (16 bits cada)
    ldrh    w21, [x24], #2          // x
    ldrh    w22, [x24], #2          // y (reutiliza x22 temporariamente)
    mov     x20, x20                // preserva contador (ldrh nao afeta)

    // Recalcula addr e le o byte
    mov     x23, #FB_WIDTH
    mul     x23, x22, x23           // y * 640
    add     x23, x23, x21           // + x = addr

    ldrb    w0, [x19, x23]          // Le o byte do buffer

    // Imprime "  buffer["
    stp     x0, x20, [sp, #-32]!    // salva valor lido e contador
    stp     x21, x22, [sp, #16]

    mov     x0, #STDOUT
    ldr     x1, =msg_pixel_prefix
    mov     x2, #msg_pixel_prefix_len
    mov     x8, #SYS_WRITE
    svc     #0

    // Imprime addr (decimal)
    mov     x0, x23
    bl      print_uint

    // Imprime "] = 0x"
    mov     x0, #STDOUT
    ldr     x1, =msg_pixel_eq
    mov     x2, #msg_pixel_eq_len
    mov     x8, #SYS_WRITE
    svc     #0

    ldp     x21, x22, [sp, #16]
    ldp     x0, x20, [sp], #32      // restaura valor lido e contador

    // Imprime valor em hex
    bl      print_hex_byte

    // Newline
    mov     x0, #STDOUT
    ldr     x1, =msg_newline
    mov     x2, #1
    mov     x8, #SYS_WRITE
    svc     #0

    sub     x20, x20, #1
    b       .sample_loop

.sample_done:
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// Tabela de amostras: pares (x, y) em 16 bits
.align 2
sample_table:
    .hword    0,   0       // canto sup-esq (borda -> 0xFF)
    .hword  639,   0       // canto sup-dir (borda -> 0xFF)
    .hword  320, 240       // centro (cruz -> 0xE0)
    .hword  320, 100       // cruz vertical (-> 0xE0)
    .hword  100, 240       // cruz horizontal (-> 0xE0)
    .hword   50,  50       // xadrez (bit5_x=1, bit5_y=1 -> XOR=0 -> 0x03)


// ------------------------------------------------------------
// print_uint: converte x0 (uint64) para ASCII decimal e imprime
// ------------------------------------------------------------
print_uint:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]

    ldr     x19, =num_buf
    add     x20, x19, #19
    mov     x21, #0
    strb    w21, [x20]
    sub     x20, x20, #1

    mov     x2, #10
    cbnz    x0, .pu_loop2
    mov     w1, #'0'
    strb    w1, [x19]           // escreve '0' no inicio do buffer
    mov     x1, x19             // ponteiro = inicio
    mov     x2, #1              // tamanho = 1
    mov     x0, #STDOUT
    mov     x8, #SYS_WRITE
    svc     #0
    ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.pu_loop2:
    cbz     x0, .pu_print2
    udiv    x3, x0, x2
    msub    x4, x3, x2, x0
    add     x4, x4, #'0'
    strb    w4, [x20]
    sub     x20, x20, #1
    mov     x0, x3
    b       .pu_loop2

.pu_print2:
    ldr     x1, =num_buf
    add     x1, x1, #19
    sub     x2, x1, x20
    mov     x1, x20
    add     x1, x1, #1
    sub     x2, x2, #1
    mov     x0, #STDOUT
    mov     x8, #SYS_WRITE
    svc     #0

    ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret


// ------------------------------------------------------------
// print_hex_byte: imprime x0 (byte 0..255) como 2 digitos hex
// ------------------------------------------------------------
print_hex_byte:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]

    ldr     x19, =hex_buf
    and     x0, x0, #0xFF           // Garante apenas 8 bits

    // Nibble alto
    lsr     x20, x0, #4
    and     x20, x20, #0xF
    cmp     x20, #10
    blt     .phb_hi_digit
    add     x20, x20, #('a' - 10)
    b       .phb_hi_store
.phb_hi_digit:
    add     x20, x20, #'0'
.phb_hi_store:
    strb    w20, [x19, #0]

    // Nibble baixo
    and     x20, x0, #0xF
    cmp     x20, #10
    blt     .phb_lo_digit
    add     x20, x20, #('a' - 10)
    b       .phb_lo_store
.phb_lo_digit:
    add     x20, x20, #'0'
.phb_lo_store:
    strb    w20, [x19, #1]

    mov     x0, #STDOUT
    mov     x1, x19
    mov     x2, #2
    mov     x8, #SYS_WRITE
    svc     #0

    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
