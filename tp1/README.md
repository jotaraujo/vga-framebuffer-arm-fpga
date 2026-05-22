# Controlador VGA com Framebuffer ARM→FPGA

**Projeto de Bloco — Sistemas Digitais Embarcados**
Instituto INFNET — Escola Superior de Tecnologia — Graduação em Engenharia de Software
Turma: 26E2\_2 | Aluno: João Paulo Fonseca de Araújo | `joao.paraujo@al.infnet.edu.br`
Link do repositório: https://github.com/jotaraujo/vga-framebuffer-arm-fpga

\---

## Índice

1. [Visão Geral](#visão-geral)
2. [Arquitetura do Sistema](#arquitetura-do-sistema)
3. [Hardware Utilizado](#hardware-utilizado)
4. [Estrutura do Repositório](#estrutura-do-repositório)
5. [Módulo Verilog — color\_selector](#módulo-verilog--color_selector)
6. [Programa Assembly ARM64 — framebuffer\_calc](#programa-assembly-arm64--framebuffer_calc)
7. [Como Compilar e Executar](#como-compilar-e-executar)
8. [Resultados Esperados](#resultados-esperados)
9. [Planejamento de Entregas](#planejamento-de-entregas)
10. [Referências Técnicas](#referências-técnicas)

\---

## Visão Geral

Este projeto implementa um **controlador VGA com framebuffer híbrido**, onde dois dispositivos cooperam de forma complementar:

* O **Raspberry Pi Zero 2W** (ARM Cortex-A53, AArch64, Linux 64-bit) atua como CPU host, responsável por gerar o conteúdo a ser exibido — padrões geométricos, gradientes, texto e animações.
* A **Tang Nano 4K** (FPGA Gowin GW1NSR-4C) assume o papel de controlador de hardware: gera os sinais de sincronismo VGA (hsync e vsync), mantém o framebuffer em BRAM e realiza a varredura de pixels para o monitor.

A comunicação entre os dois dispositivos ocorre via barramento **SPI** (GPIO do RPi → pinos do FPGA). O sistema produz saída de vídeo estável na resolução **640×480 pixels @ 60 Hz** via conector VGA padrão.

O projeto é desenvolvido progressivamente ao longo de cinco trabalhos práticos (TPs), partindo de módulos combinacionais simples (TP1) até uma integração completa com animação e renderização de texto (TP5).

\---

## Arquitetura do Sistema

```
┌───────────────────────────┐        ┌────────────────────────────────────┐
│    Raspberry Pi Zero 2W   │        │         Tang Nano 4K (FPGA)        │
│    ARM Cortex-A53 64-bit  │        │                                    │
│                           │  SPI   │  ┌─────────────┐  ┌─────────────┐ │
│  • Gera dados de pixel    │───────▶│  │  SPI RX     │  │    BRAM     │ │
│  • Calcula endereços      │        │  │  Controller ├─▶│ Framebuffer │ │
│  • Coordena animações     │        │  └─────────────┘  │ 640×480×8bp │ │
│  • Rotinas SIMD NEON      │        │                   └──────┬──────┘ │
│    (TP4 em diante)        │        │                          │leitura  │
└───────────────────────────┘        │  ┌───────────────────────▼──────┐ │
                                     │  │      VGA Sync Generator      │ │
                                     │  │      FSM de Varredura        │ │
                                     │  │      640×480 @ 60 Hz         │ │
                                     │  │      Pixel Clock 25.175 MHz  │ │
                                     │  └───────────────────────┬──────┘ │
                                     └──────────────────────────│────────┘
                                                                │ VGA
                                                                ▼
                                                    ┌──────────────────┐
                                                    │   Monitor VGA    │
                                                    │  640×480 @ 60Hz  │
                                                    └──────────────────┘
```

### Fluxo de dados

1. O ARM gera os dados de pixel em memória e calcula os endereços via fórmula `addr = y × FB\\\_WIDTH + x`.
2. Os dados são transferidos ao FPGA via SPI (Linux `spidev`).
3. O FPGA armazena os pixels na BRAM interna (framebuffer dual-port).
4. O gerador VGA lê a BRAM em sincronia com o pixel clock de 25.175 MHz e envia os sinais RGB + sincronismo ao monitor.

### Timing VGA 640×480 @ 60 Hz

|Parâmetro|Horizontal (pixels)|Vertical (linhas)|
|-|-:|-:|
|Região visível|640|480|
|Front porch|16|10|
|Sync pulse|96|2|
|Back porch|48|33|
|**Total**|**800**|**525**|

Frequência de pixel clock: **25.175 MHz** | Taxa de refresh: **60 Hz**

\---

## Hardware Utilizado

|Componente|Especificação|
|-|-|
|**CPU Host**|Raspberry Pi Zero 2W — ARM Cortex-A53, AArch64, 512 MB RAM|
|**Sistema Operacional**|Raspberry Pi OS 64-bit (Bookworm, Debian 12)|
|**FPGA**|Tang Nano 4K — Gowin GW1NSR-4C, 4.608 LUTs, 180 Kb BRAM|
|**Saída de vídeo**|Conector VGA nativo na Tang Nano 4K|
|**Comunicação**|Barramento SPI via GPIO (RPi) → pinos FPGA|
|**Monitor**|Qualquer monitor VGA compatível com 640×480 @ 60 Hz|

\---

## Estrutura do Repositório

```
vga-framebuffer-arm-fpga/
├── assembly\\\_tp1/
│   └── framebuffer\\\_calc.s       # Programa ARM64 Assembly — cálculo de endereços de pixel
├── verilog\\\_tp1/
│   ├── color\\\_selector.v         # Módulo combinacional — gerador de barras de cor
│   └── tb\\\_color\\\_selector.v      # Testbench com 18 casos de teste automatizados
├── docs/
│   └── relatorio\\\_tp1.pdf        # Relatório técnico TP1
└── README.md
```

\---

## Módulo Verilog — `color\\\_selector`

### Descrição

Módulo **puramente combinacional** (sem clock, sem estado) que divide a resolução horizontal de 640 pixels em **8 barras verticais de 80 pixels cada**, atribuindo uma cor RGB distinta a cada região. Representa o núcleo da lógica de geração de padrões que evoluirá para o gerador VGA completo nos TPs seguintes.

### Interface

|Sinal|Direção|Largura|Descrição|
|-|-|-|-|
|`pixel\\\_x`|IN|10 bits|Coordenada horizontal do pixel atual (0..639)|
|`pixel\\\_y`|IN|9 bits|Coordenada vertical do pixel atual (0..479)|
|`red`|OUT|4 bits|Canal vermelho (0..15, expandível para 0..255)|
|`green`|OUT|4 bits|Canal verde|
|`blue`|OUT|4 bits|Canal azul|

### Mapeamento de barras de cor

|Região|Faixa X|Cor|R|G|B|
|-|-|-|-|-|-|
|0|0 – 79|Branco|`F`|`F`|`F`|
|1|80 – 159|Amarelo|`F`|`F`|`0`|
|2|160 – 239|Ciano|`0`|`F`|`F`|
|3|240 – 319|Verde|`0`|`F`|`0`|
|4|320 – 399|Magenta|`F`|`0`|`F`|
|5|400 – 479|Vermelho|`F`|`0`|`0`|
|6|480 – 559|Azul|`0`|`0`|`F`|
|7|560 – 639|Preto|`0`|`0`|`0`|

### Lógica de seleção de região

A região é calculada dividindo os bits superiores da coordenada X:

```verilog
wire \\\[3:0] region;
assign region = pixel\\\_x\\\[9:3] / 10; // 8 regiões de \\\~80px em 640px

always @(\\\*) begin
    case (region)
        4'd0: begin red = 4'hF; green = 4'hF; blue = 4'hF; end // Branco
        4'd1: begin red = 4'hF; green = 4'hF; blue = 4'h0; end // Amarelo
        4'd2: begin red = 4'h0; green = 4'hF; blue = 4'hF; end // Ciano
        4'd3: begin red = 4'h0; green = 4'hF; blue = 4'h0; end // Verde
        4'd4: begin red = 4'hF; green = 4'h0; blue = 4'hF; end // Magenta
        4'd5: begin red = 4'hF; green = 4'h0; blue = 4'h0; end // Vermelho
        4'd6: begin red = 4'h0; green = 4'h0; blue = 4'hF; end // Azul
        default: begin red = 4'h0; green = 4'h0; blue = 4'h0; end // Preto
    endcase
end
```

### Testbench — `tb\\\_color\\\_selector`

O testbench verifica **18 casos de teste** cobrindo:

* Todas as 8 barras de cor (valores de borda e centro de cada faixa)
* Independência da coordenada Y (saídas devem ser idênticas para Y=0, Y=240 e Y=479)
* Geração automática de arquivo `.vcd` para visualização de formas de onda no GTKWave

\---

## Programa Assembly ARM64 — `framebuffer\\\_calc`

### Descrição

Programa escrito em **Assembly AArch64 puro**, executado nativamente no Raspberry Pi Zero 2W. Demonstra operações fundamentais de cálculo de endereços de pixel em um framebuffer linear — a base de toda a comunicação ARM→FPGA nos TPs subsequentes.

**Fórmula central:**

```
addr = y × FB\\\_WIDTH + x
```

onde `FB\\\_WIDTH = 640` e o resultado é o deslocamento em bytes no framebuffer de **307.200 bytes** (640 × 480 × 1 byte/pixel).

### Conceitos ARM64 demonstrados

|Conceito|Instrução / Mecanismo|Uso no programa|
|-|-|-|
|Multiplicação|`MUL x24, x22, x23`|Calcula `y × FB\\\_WIDTH`|
|Adição|`ADD x24, x24, x21`|Soma o offset X ao resultado|
|Load imediato|`MOV x23, #640`|Carrega constante FB\_WIDTH|
|Endereçamento de label|`LDR x1, =label`|Carrega endereço de string para syscall|
|Loop com contador|`SUB x20, x20, #1` + `CBZ`|Itera 8 vezes sobre tabela de pixels|
|Tabela de dados compacta|`.hword val` + `LDRH \\\[x19],#2`|Acessa pares (x,y) de 16 bits|
|Syscall `write()`|`MOV x8, #64` + `SVC #0`|Saída de texto via Linux AArch64|
|Convenção de chamada AArch64|`STP/LDP x29, x30, \\\[sp]`|Salva/restaura frame pointer e link register|

### Pixels de teste calculados

|Pixel (x, y)|Endereço (decimal)|Offset (hex)|
|-|-|-|
|(0, 0)|0|`0x0`|
|(320, 240)|154.240|`0x25a80`|
|(639, 479)|307.199|`0x4afff`|
|(10, 5)|3.210|`0xc8a`|
|(100, 100)|64.100|`0xfa64`|
|(200, 300)|192.200|`0x2ee48`|
|(0, 479)|306.560|`0x4ad80`|
|(639, 0)|639|`0x27f`|

\---

## Como Compilar e Executar

### Pré-requisitos

**Para o Assembly (Raspberry Pi físico):**

```bash
sudo apt update
sudo apt install -y gcc binutils
```

**Para o Assembly (via WSL2/Linux com emulação ARM64):**

```bash
sudo apt update
sudo apt install -y gcc-aarch64-linux-gnu qemu-user
```

**Para o Verilog (qualquer Linux/WSL2):**

```bash
sudo apt install -y iverilog gtkwave
```

\---

### Assembly — Raspberry Pi Zero 2W (nativo)

```bash
# Compilar
gcc -o framebuffer\\\_calc assembly\\\_tp1/framebuffer\\\_calc.s -no-pie

# Executar
./framebuffer\\\_calc
```

### Assembly — WSL2 / Linux x86 (emulação ARM64)

```bash
# Compilar com cross-compiler (flag -static obrigatória para o QEMU)
aarch64-linux-gnu-as -o framebuffer\\\_calc.o assembly\\\_tp1/framebuffer\\\_calc.s
aarch64-linux-gnu-ld -o framebuffer\\\_calc framebuffer\\\_calc.o

# Executar via emulação
qemu-aarch64 ./framebuffer\\\_calc
```

> \\\*\\\*Nota:\\\*\\\* Usar `as` + `ld` diretamente evita o conflito de `\\\_start` que ocorre quando o `gcc` tenta linkar a libc junto ao assembly puro.

\---

### Verilog — Simulação com Icarus Verilog

```bash
cd verilog\\\_tp1

# Compilar e simular
iverilog -o sim color\\\_selector.v tb\\\_color\\\_selector.v
vvp sim
```

**Saída esperada no terminal:**

```
=================================================
  Testbench: color\\\_selector - VGA Color Bars
  Resolucao: 640x480 | 8 barras de 80px
=================================================
\\\[PASS] Barra BRANCO   x=  0 -> R=f G=f B=f
\\\[PASS] Barra BRANCO   x= 40 -> R=f G=f B=f
\\\[PASS] Barra AMARELO  x= 80 -> R=f G=f B=0
\\\[PASS] Barra CIANO    x=160 -> R=0 G=f B=f
\\\[PASS] Barra VERDE    x=240 -> R=0 G=f B=0
\\\[PASS] Barra MAGENTA  x=320 -> R=f G=0 B=f
\\\[PASS] Barra VERMELHO x=400 -> R=f G=0 B=0
\\\[PASS] Barra AZUL     x=480 -> R=0 G=0 B=f
\\\[PASS] Barra PRETO    x=560 -> R=0 G=0 B=0
...
=================================================
  Resultado: 18 PASS | 0 FAIL
  STATUS: TODOS OS TESTES PASSARAM
=================================================
```

### Visualizar formas de onda (GTKWave)

```bash
gtkwave tb\\\_color\\\_selector.vcd
```

\---

## Resultados Esperados

### Assembly

```
============================================
  VGA Framebuffer TP1 - ARM64 Assembly
  Resolucao: 640x480 | Modo: 8bpp
============================================

\\\[INFO] Tamanho total do framebuffer: 307200 bytes

 Pixel (x,   y)  |  Endereco (dec)  | Offset hex
 ---------------+------------------+-----------
 Pixel (0, 0)       | addr = 0      | 0x0
 Pixel (320, 240)   | addr = 154240 | 0x25a80
 Pixel (639, 479)   | addr = 307199 | 0x4afff
 Pixel (10, 5)      | addr = 3210   | 0xc8a
 Pixel (100, 100)   | addr = 64100  | 0xfa64
 Pixel (200, 300)   | addr = 192200 | 0x2ee48
 Pixel (0, 479)     | addr = 306560 | 0x4ad80
 Pixel (639, 0)     | addr = 639    | 0x27f

\\\[OK] Formula: addr = y \\\* FB\\\_WIDTH + x
\\\[OK] Programa encerrado com sucesso.
```

\---

## Planejamento de Entregas

|TP|Foco Principal|Entregáveis-chave|Status|
|-|-|-|-|
|TP1|Fundamentos e ambiente|Módulo combinacional + Assembly + Relatório técnico|✅ Em andamento|
|TP2|Hardware VGA real|`vga\\\_sync.v` + sinal VGA no monitor + SPI ARM básico|⏳ Pendente|
|TP3|FSM + integração inicial|Framebuffer em FPGA + imagem ARM no monitor|⏳ Pendente|
|TP4|BRAM + DSP + SIMD|Framebuffer completo + rotinas NEON + benchmark|⏳ Pendente|
|TP5|Integração completa e validação|Texto + animação + vídeo de demonstração + repositório final|⏳ Pendente|

### Detalhamento por TP

**TP2 — Estruturas Básicas em FPGA e ARM**

* Módulo `vga\\\_sync.v`: gerador de sincronismo 640×480 @ 60 Hz (hsync, vsync, pixel clock 25.175 MHz via PLL Gowin)
* Testbench de verificação dos parâmetros de timing
* Síntese e gravação na Tang Nano 4K via Gowin IDE
* Exibição de padrões estáticos no monitor (xadrez, barras coloridas)
* Rotina ARM de escrita de valores iniciais via SPI

**TP3 — Controle, FSMs e Primeira Integração**

* FSM de varredura VGA com controle de estados H e V
* Framebuffer simples em FPGA (registradores ou BRAM pequena)
* Protocolo de comunicação SPI ARM→FPGA documentado e testado
* Exibição de imagem simples gerada pelo ARM no monitor real

**TP4 — Aritmética, DSP, BRAM e SIMD**

* Framebuffer completo em BRAM Gowin (640×480×8bpp = 300 KB)
* Módulos DSP para efeitos: gradiente, fade, inversão de cor
* Rotinas SIMD ARM NEON para geração acelerada de padrões de pixel
* Medição de throughput (pixels/segundo com e sem NEON)

**TP5 — Integração Completa e Validação Final**

* Sistema completo: ARM escreve, FPGA exibe em tempo real
* Renderização de texto (fonte bitmap 8×8) no framebuffer
* Animação: objeto em movimento ou transição de cor
* Medição de latência ARM→monitor e estabilidade de sync VGA
* Vídeo de demonstração (até 5 minutos)

\---

## Referências Técnicas

* [VGA Signal Timing — tinyvga.com](http://tinyvga.com/vga-timing/640x480@60Hz)
* [ARM Architecture Reference Manual — AArch64](https://developer.arm.com/documentation/ddi0487/latest)
* [Gowin GW1NSR-4C Datasheet — Gowin Semiconductor](https://www.gowinsemi.com)
* [Linux AArch64 Syscall Table](https://arm64.syscall.sh/)
* [Icarus Verilog Documentation](https://steveicarus.github.io/iverilog/)
* [GTKWave User Guide](https://gtkwave.sourceforge.net/)
* [Raspberry Pi Zero 2W — Datasheet](https://datasheets.raspberrypi.com/rpizero2/raspberry-pi-zero-2-w-product-brief.pdf)

\---

*Projeto desenvolvido para a disciplina Sistemas Digitais Embarcados — Instituto INFNET, 2026.*

