# Tutorial de Validação — TP2
## Controlador VGA com Framebuffer ARM→FPGA
### João Paulo Fonseca de Araújo | Infnet — Sistemas Digitais Embarcados

---

## Estrutura do Projeto TP2

```
tp2/
├── verilog_tp2/
│   ├── vga_sync.v            ← Módulo 1: gerador de sincronismo VGA
│   ├── pattern_generator.v   ← Módulo 2: gerador combinacional de padrões
│   └── tb_vga_system.v       ← Testbench unificado
├── assembly_tp2/
│   └── spi_emulator.s        ← Programa ARM64 - ensaio de escrita no framebuffer
└── docs_tp2/
    └── TUTORIAL.md           ← Este arquivo
```

---

## Parte 1 — Lado FPGA (Icarus Verilog + GTKWave)

### 1.1 Pré-requisitos

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y iverilog gtkwave

# Verificar versões
iverilog -V
gtkwave --version
```

### 1.2 Compilação com Icarus Verilog

Entre na pasta dos fontes Verilog:

```bash
cd tp2/verilog_tp2
```

Compile todos os módulos junto ao testbench em um único comando:

```bash
iverilog -o tb_vga_system \
         tb_vga_system.v \
         vga_sync.v \
         pattern_generator.v
```

Saída esperada: nenhuma mensagem de erro. O arquivo binário `tb_vga_system` será gerado.

### 1.3 Execução da Simulação

```bash
vvp tb_vga_system
```

**Saída esperada no terminal:**

```
VCD info: dumpfile dump_vga.vcd opened for output.
============================================================
  TB VGA SYSTEM - Validacao de Timing VGA 640x480 @ 60Hz
  Pixel Clock simulado: ~25 MHz (periodo = 40 ns)
============================================================
[FRAME] Frame 1 iniciado. pixel_y no negedge vsync: 490 (esperado: 490)
[FRAME] Frame 2 iniciado. pixel_y no negedge vsync: 490 (esperado: 490)

[INFO] 2 frames completos simulados.
[INFO] Total de clocks simulados: 840000

--- Validando pulso HSYNC ---
[HSYNC] Largura medida do pulso baixo: 96 clocks
[HSYNC] Largura esperada             : 96 clocks
[PASS ] Largura HSYNC CORRETA!

--- Validando periodo HSYNC ---
[HSYNC] pixel_x no negedge hsync: 657 (esperado: 657)
[PASS ] Posicao do HSYNC no contador H CORRETA!

--- Validando pulso VSYNC ---
[VSYNC] Largura medida do pulso baixo: 1600 clocks
[VSYNC] Largura esperada (2 linhas)  : 1600 clocks
[PASS ] Largura VSYNC CORRETA!

--- Validando video_on ---
[PASS ] video_on ATIVO na area visivel!
[PASS ] video_on INATIVO na area de blanking!

============================================================
  RESULTADO FINAL: TODOS OS TESTES PASSARAM! (0 erros)
============================================================
```

> **Screenshot para o relatório:** capture a janela do terminal com toda esta saída.

O arquivo `dump_vga.vcd` será gerado no mesmo diretório.

### 1.4 Análise de Waveforms no GTKWave

```bash
gtkwave dump_vga.vcd &
```

**Sinais obrigatórios a adicionar (para o relatório):**

No painel "SST" (Signal Search Tree), expanda `tb_vga_system` e arraste os sinais na ordem abaixo para a janela de waveform:

| Sinal | O que observar |
|-------|----------------|
| `clk` | Clock de 25 MHz (período 40 ns) |
| `hsync` | Pulso baixo de 96 clocks a cada 800 clocks |
| `vsync` | Pulso baixo de 1600 clocks a cada 420.000 clocks |
| `video_on` | Alto somente quando h_count<640 E v_count<480 |
| `pixel_x[9:0]` | Contador 0→799, reseta em 800 |
| `pixel_y[9:0]` | Contador 0→524, reseta em 525 |
| `red_chess[3:0]` | Alterna 3↔F a cada 32 pixels |
| `green_chess[3:0]` | Idem |

**Como comprimir a view para ver um frame inteiro:**

1. Pressione `Ctrl+A` para selecionar todos os sinais
2. Use o zoom (roleta do mouse ou `+`/`-`) até enxergar o período completo do VSYNC
3. Localize o pulso de HSYNC → confirme que o intervalo baixo é 96 clocks
4. Localize o pulso de VSYNC → confirme que ocorre a cada 525 linhas

**Medição manual no GTKWave:**
- Clique na borda de descida do `hsync` para posicionar o cursor 1
- Use `Ctrl+Click` na borda de subida para o cursor 2
- O delta (∆) mostrado na barra superior deve ser `96 × 40 ns = 3840 ns`

> **Screenshots para o relatório:** (a) visão geral de 1 frame completo, (b) zoom no pulso HSYNC com delta medido, (c) zoom no pulso VSYNC.

---

## Parte 2 — Lado ARM (Assembly AArch64)

### 2.1 Pré-requisitos no Raspberry Pi Zero 2W

```bash
# Verificar arquitetura
uname -m   # deve mostrar: aarch64

# GCC e GDB nativos (já vêm no Raspberry Pi OS de 64 bits)
sudo apt-get install -y gcc gdb
```

### 2.2 Compilação Nativa no Raspberry Pi

Copie o arquivo `spi_emulator.s` para o Pi e execute:

```bash
# Compilação: Assembly puro sem CRT padrão
gcc -o spi_emulator spi_emulator.s -no-pie -nostartfiles

# Verificar o binário gerado
ls -lh spi_emulator
file spi_emulator
```

> **Nota sobre `-no-pie`:** desativa Position Independent Executable — necessário para que os endereços absolutos no Assembly funcionem corretamente e o GDB mostre endereços fixos nos breakpoints.
> **Nota sobre `-nostartfiles`:** o programa define seu próprio `_start`, não usa o `main()` do CRT.

**Alternativa com cross-compiler (em máquina x86):**
```bash
aarch64-linux-gnu-gcc -o spi_emulator spi_emulator.s -no-pie -static -nostartfiles
```

### 2.3 Execução e Captura de Saída

```bash
./spi_emulator
```

**Saída esperada:**

```
============================================
  SPI Emulator TP2 - ARM64 Assembly
  Framebuffer: 640x480 @ 8bpp = 307200 bytes
============================================

[INFO] Preenchendo buffer de transmissao...
[OK]   Buffer preenchido com sucesso.

--- Verificacao de amostras do buffer ---
  buffer[0] = 0xff        ← pixel(0,0): borda → branco
  buffer[639] = 0xff      ← pixel(639,0): borda → branco
  buffer[153920] = 0xe0   ← pixel(320,240): centro → vermelho
  buffer[64320] = 0xe0    ← pixel(320,100): cruz vertical → vermelho
  buffer[153700] = 0xe0   ← pixel(100,240): cruz horizontal → vermelho
  buffer[32050] = 0x03    ← pixel(50,50): xadrez escuro → azul

[OK] Ensaio de comunicacao ARM->FPGA concluido.
[OK] Dados prontos para transmissao SPI.
```

> **Screenshot para o relatório:** capture o terminal com a saída completa.

### 2.4 Verificar código de saída

```bash
./spi_emulator
echo "Exit code: $?"   # deve mostrar: Exit code: 0
```

### 2.5 Sessão de Depuração com GDB — Roteiro Cirúrgico

Este roteiro demonstra: breakpoints no loop, inspeção de registradores que calculam `addr = y*640+x`, e verificação do STRB.

```bash
gdb ./spi_emulator
```

**Dentro do GDB, execute os comandos na ordem:**

#### Passo 1 — Configuração inicial

```gdb
# Exibir Assembly com sintaxe Intel (opcional, mais legível)
set disassembly-flavor intel

# Desabilitar confirmação de quit
set confirm off

# Listar os símbolos do programa
info functions
```

#### Passo 2 — Breakpoint na entrada do loop interno

```gdb
# Breakpoint no início de fill_buffer
break fill_buffer

# Breakpoint logo antes do STRB (write_pixel)
break .write_pixel

# Listar breakpoints configurados
info breakpoints
```

#### Passo 3 — Executar até o primeiro breakpoint

```gdb
run
```

O programa para em `fill_buffer`. Continue até o primeiro pixel:

```gdb
continue
```

#### Passo 4 — Inspecionar registradores no loop (primeiro pixel)

```gdb
# Ver TODOS os registradores de uma vez
info registers

# Registradores-chave a observar:
# x19 = endereço base do tx_buffer
# x20 = y atual (deve ser 0 no primeiro pixel)
# x21 = x atual (deve ser 0 no primeiro pixel)
# x22 = addr calculado (y*640+x = 0)
# x23 = valor de cor a ser gravado (deve ser 0xFF = borda)

# Confirmar valores individuais
p/d $x20    # y = 0
p/d $x21    # x = 0
p/d $x22    # addr = 0
p/x $x23    # cor = 0xff
```

#### Passo 5 — Verificar o byte antes e depois do STRB

```gdb
# Inspecionar 16 bytes a partir do endereço base do buffer
# (antes do STRB, todos devem ser 0x00)
x/16xb $x19

# Avançar 1 instrução (executa o STRB)
stepi

# Inspecionar novamente — o byte [0] agora deve ser 0xFF
x/16xb $x19
```

#### Passo 6 — Avançar ao pixel central (320, 240)

```gdb
# Definir watchpoint para quando x21==320 e x20==240 (pixel do centro)
# Como watchpoint condicional pode ser lento, use breakpoint condicional:
break .write_pixel if $x21==320 && $x20==240

# Continuar até chegar nesse pixel
continue

# Verificar registradores
info registers
p/d $x20    # deve ser 240
p/d $x21    # deve ser 320
p/d $x22    # deve ser 240*640+320 = 153920
p/x $x23    # deve ser 0xe0 (vermelho - cruz central)
```

#### Passo 7 — Inspecionar o byte escrito no centro

```gdb
# O byte na posição 153920 do buffer
x/1xb ($x19 + 153920)   # antes do STRB: 0x00

stepi

x/1xb ($x19 + 153920)   # depois do STRB: 0xe0
```

#### Passo 8 — Verificar o pixel de xadrez (50, 50)

```gdb
# Pixel (50,50): addr = 50*640+50 = 32050
# bit5_x = 50>>5 = 1, bit5_y = 50>>5 = 1, XOR = 0 → COLOR_DARK = 0x03
break .write_pixel if $x21==50 && $x20==50
continue

p/d $x20    # 50
p/d $x21    # 50
p/d $x22    # 32050
p/x $x23    # 0x03
```

#### Passo 9 — Deixar o programa terminar

```gdb
# Remove todos os breakpoints e continua até o fim
delete breakpoints
continue
# Saída normal do programa
quit
```

> **Screenshots para o relatório:**
> - Tela do GDB com `info registers` mostrando x19-x23 no pixel (0,0)
> - Tela do GDB com `x/16xb $x19` antes e depois do STRB
> - Tela do GDB com o pixel central (320,240) confirmando 0xe0
> - Saída final do `echo "Exit code: $?"` mostrando 0

---

## Tabela de Verificação — Resumo dos Valores Esperados

| Pixel (x, y) | addr = y×640+x | Condição | Cor esperada |
|:---:|:---:|:---|:---:|
| (0, 0) | 0 | Borda superior-esquerda | `0xFF` (branco) |
| (639, 0) | 639 | Borda superior-direita | `0xFF` (branco) |
| (320, 240) | 153.920 | Cruz central (ponto de cruzamento) | `0xE0` (vermelho) |
| (320, 100) | 64.320 | Cruz vertical (x≈320) | `0xE0` (vermelho) |
| (100, 240) | 153.700 | Cruz horizontal (y≈240) | `0xE0` (vermelho) |
| (50, 50) | 32.050 | Xadrez escuro (XOR=0) | `0x03` (azul) |

---

## Parâmetros VGA Implementados (Referência)

| Parâmetro | Horizontal | Vertical |
|:---|:---:|:---:|
| Região visível | 640 px | 480 linhas |
| Front Porch | 16 clocks | 10 linhas |
| Sync Pulse | **96 clocks** | **2 linhas** |
| Back Porch | 48 clocks | 33 linhas |
| **Total** | **800 clocks** | **525 linhas** |
| Período (@ 25 MHz) | 32 µs | 16,8 ms |
| Taxa de refresh | — | **≈ 59,94 Hz** |
