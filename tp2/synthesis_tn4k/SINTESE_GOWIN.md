# Guia de Síntese — Tang Nano 4K

## Arquivos necessários
- `top_vga_tn4k.v` — módulo top-level (este projeto)
- `vga_sync.v` — módulo de sincronismo (copiar de verilog_tp2/)
- `top_vga_tn4k.cst` — mapeamento de pinos

## Passos no GoWin EDA

1. **Abrir GoWin EDA** → File → New Project
2. Nome: `vga_tn4k` | Device: **GW1NSR-LV4CQN48PC6/I5**
3. Add Files: adicionar os 3 arquivos listados acima
4. Definir top-level: `top_vga_tn4k`
5. **Process → Synthesize** → aguardar sem erros
6. **Process → Place & Route** → aguardar sem erros
7. **Process → Generate Bitstream** → gera `vga_tn4k.fs`
8. Conectar Tang Nano 4K via USB-C
9. **Programmer → Program Device** → selecionar `vga_tn4k.fs`

## Resultado esperado ao ligar

| LED | Comportamento | Significado |
|-----|---------------|-------------|
| Vermelho | Pulsa lentamente (~60x/s) | Pulso VSYNC funcionando |
| Verde | Praticamente sempre aceso (pisca ~31 kHz, imperceptível) | Pulso HSYNC funcionando |
| Azul | Aceso ~80% do tempo, apaga rapidamente | Área ativa do frame |

> **Foto para o relatório**: registre o estado dos LEDs com a placa energizada.
> O LED vermelho visível e o LED azul aceso confirmam o circuito sintetizado.
