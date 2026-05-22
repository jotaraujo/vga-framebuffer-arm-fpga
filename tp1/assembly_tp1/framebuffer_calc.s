// ============================================================
// Projeto  : Controlador VGA com Framebuffer ARM->FPGA
// Arquivo  : framebuffer_calc.s
// Descricao: Programa em Assembly ARM 64-bit (AArch64)
//            Calcula enderecos de pixels num framebuffer VGA
//            Resolucao: 640x480 | 1 byte por pixel (modo 8bpp)
//            Demonstra: aritmetica de registradores, loops,
//                       chamadas de sistema (syscall) e saida
//                       de texto formatado via write()
// Plataforma: Raspberry Pi Zero 2W | ARM Cortex-A53 | Linux
// Compilar  : gcc -o framebuffer_calc framebuffer_calc.s -no-pie
// Executar  : ./framebuffer_calc
// ============================================================

// --- Constantes do framebuffer ---
.equ FB_WIDTH,   640        // largura em pixels
.equ FB_HEIGHT,  480        // altura em pixels
.equ FB_BPP,     1          // bytes por pixel (8bpp)
.equ FB_SIZE,    (FB_WIDTH * FB_HEIGHT * FB_BPP)   // 307200 bytes

// --- Syscalls Linux AArch64 ---
.equ SYS_WRITE,  64
.equ SYS_EXIT,   93
.equ STDOUT,     1

// ============================================================
.section .data
// ============================================================

header:
    .ascii "============================================\n"
    .ascii "  VGA Framebuffer TP1 - ARM64 Assembly      \n"
    .ascii "  Resolucao: 640x480 | Modo: 8bpp            \n"
    .ascii "============================================\n"
header_len = . - header

lbl_fb_size:
    .ascii "\n[INFO] Tamanho total do framebuffer: 307200 bytes\n"
lbl_fb_size_len = . - lbl_fb_size

lbl_table_hdr:
    .ascii "\n Pixel (x,   y)  |  Endereco (dec)  | Offset hex\n"
    .ascii " ---------------+------------------+-----------\n"
lbl_table_hdr_len = . - lbl_table_hdr

lbl_result:
    .ascii " Pixel ("
lbl_result_len = . - lbl_result

lbl_comma:
    .ascii ", "
lbl_comma_len = . - lbl_comma

lbl_sep1:
    .ascii ") | addr = "
lbl_sep1_len = . - lbl_sep1

lbl_sep2:
    .ascii " | 0x"
lbl_sep2_len = . - lbl_sep2

lbl_newline:
    .ascii "\n"

lbl_footer:
    .ascii "\n[OK] Formula: addr = y * FB_WIDTH + x\n"
    .ascii "[OK] Programa encerrado com sucesso.\n\n"
lbl_footer_len = . - lbl_footer

// Buffer para conversao de inteiro -> ASCII (20 digitos max)
num_buf:    .space 24
hex_buf:    .space 12

// ============================================================
.section .text
.global _start
// ============================================================

// ------------------------------------------------------------
// _start: ponto de entrada principal
// ------------------------------------------------------------
_start:
    // Imprime cabecalho
    mov     x0, STDOUT
    ldr     x1, =header
    mov     x2, header_len
    mov     x8, SYS_WRITE
    svc     #0

    // Imprime tamanho do framebuffer
    mov     x0, STDOUT
    ldr     x1, =lbl_fb_size
    mov     x2, lbl_fb_size_len
    mov     x8, SYS_WRITE
    svc     #0

    // Imprime cabecalho da tabela
    mov     x0, STDOUT
    ldr     x1, =lbl_table_hdr
    mov     x2, lbl_table_hdr_len
    mov     x8, SYS_WRITE
    svc     #0

    // --------------------------------------------------------
    // Loop principal: calcula enderecos para 8 pixels de teste
    // Pixels: (0,0), (320,240), (639,479), (10,5),
    //         (100,100), (200,300), (0,479), (639,0)
    // --------------------------------------------------------
    adr     x19, pixel_table     // ponteiro para tabela de pixels
    mov     x20, #8              // contador de iteracoes

loop_pixels:
    cbz     x20, loop_done

    // Carrega x e y da tabela
    ldrh    w21, [x19], #2       // x (16 bits)
    ldrh    w22, [x19], #2       // y (16 bits)

    // Calcula: addr = y * FB_WIDTH + x
    mov     x23, FB_WIDTH
    mul     x24, x22, x23        // y * FB_WIDTH
    add     x24, x24, x21        // + x  =>  addr final em x24

    // Imprime "Pixel ("
    mov     x0, STDOUT
    ldr     x1, =lbl_result
    mov     x2, lbl_result_len
    mov     x8, SYS_WRITE
    svc     #0

    // Imprime valor de x
    mov     x0, x21
    bl      print_uint

    // Imprime ", "
    mov     x0, STDOUT
    ldr     x1, =lbl_comma
    mov     x2, lbl_comma_len
    mov     x8, SYS_WRITE
    svc     #0

    // Imprime valor de y
    mov     x0, x22
    bl      print_uint

    // Imprime ") | addr = "
    mov     x0, STDOUT
    ldr     x1, =lbl_sep1
    mov     x2, lbl_sep1_len
    mov     x8, SYS_WRITE
    svc     #0

    // Imprime addr (decimal)
    mov     x0, x24
    bl      print_uint

    // Imprime " | 0x"
    mov     x0, STDOUT
    ldr     x1, =lbl_sep2
    mov     x2, lbl_sep2_len
    mov     x8, SYS_WRITE
    svc     #0

    // Imprime addr (hexadecimal)
    mov     x0, x24
    bl      print_hex

    // Newline
    mov     x0, STDOUT
    ldr     x1, =lbl_newline
    mov     x2, #1
    mov     x8, SYS_WRITE
    svc     #0

    sub     x20, x20, #1
    b       loop_pixels

loop_done:
    // Imprime rodape
    mov     x0, STDOUT
    ldr     x1, =lbl_footer
    mov     x2, lbl_footer_len
    mov     x8, SYS_WRITE
    svc     #0

    // exit(0)
    mov     x0, #0
    mov     x8, SYS_EXIT
    svc     #0

// ------------------------------------------------------------
// Tabela de pixels de teste (pares x, y em 16 bits cada)
// ------------------------------------------------------------
.align 2
pixel_table:
    .hword   0,   0        // canto superior esquerdo
    .hword 320, 240        // centro da tela
    .hword 639, 479        // canto inferior direito
    .hword  10,   5        // pixel aleatorio
    .hword 100, 100        // quadrante superior esquerdo
    .hword 200, 300        // quadrante inferior esquerdo
    .hword   0, 479        // canto inferior esquerdo
    .hword 639,   0        // canto superior direito

// ------------------------------------------------------------
// print_uint: converte x0 (uint64) -> ASCII decimal e imprime
// Usa num_buf na secao .data; nao usa stack profunda
// ------------------------------------------------------------
print_uint:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]

    ldr     x19, =num_buf       // buffer de saida
    add     x20, x19, #19       // posicao final (escrita de tras pra frente)
    mov     x1, #0
    strb    w1, [x20]           // null terminator (nao usado, mas seguro)
    sub     x20, x20, #1

    mov     x2, #10             // divisor

    // Trata caso especial: numero == 0
    cbnz    x0, .pu_loop
    mov     w1, #'0'
    strb    w1, [x20]
    mov     x19, x20
    b       .pu_print

.pu_loop:
    cbz     x0, .pu_print
    udiv    x3, x0, x2          // quociente
    msub    x4, x3, x2, x0     // resto = x0 - (x3*10)
    add     x4, x4, #'0'
    strb    w4, [x20]
    sub     x20, x20, #1
    mov     x0, x3
    b       .pu_loop

.pu_print:
    // Calcula comprimento da string resultante
    ldr     x1, =num_buf
    add     x1, x1, #19         // fim do buffer
    sub     x2, x1, x20         // comprimento

    mov     x1, x20             // inicio da string
    add     x1, x1, #1          // ajusta ponteiro (passou 1 alem)
    sub     x2, x2, #1

    mov     x0, STDOUT
    mov     x8, SYS_WRITE
    svc     #0

    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ------------------------------------------------------------
// print_hex: converte x0 (uint64) -> ASCII hex e imprime
// Imprime apenas os nibbles significativos (sem zeros a esquerda)
// ------------------------------------------------------------
print_hex:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]

    ldr     x19, =hex_buf
    mov     x20, #0             // contador de caracteres
    mov     x2, #60             // shift inicial (15 nibbles * 4)

    // Encontra nibble mais significativo nao-zero
    mov     x3, x0
    cbz     x3, .ph_zero

.ph_find_msn:
    lsr     x4, x3, x2
    and     x4, x4, #0xF
    cbnz    x4, .ph_loop
    sub     x2, x2, #4
    cmp     x2, #0
    bge     .ph_find_msn

.ph_zero:
    mov     x2, #0              // so imprime '0'

.ph_loop:
    lsr     x4, x3, x2
    and     x4, x4, #0xF
    cmp     x4, #10
    blt     .ph_digit
    add     x4, x4, #('a' - 10)
    b       .ph_store
.ph_digit:
    add     x4, x4, #'0'
.ph_store:
    strb    w4, [x19, x20]
    add     x20, x20, #1
    cbz     x2, .ph_done
    sub     x2, x2, #4
    b       .ph_loop

.ph_done:
    mov     x0, STDOUT
    ldr     x1, =hex_buf
    mov     x2, x20
    mov     x8, SYS_WRITE
    svc     #0

    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
