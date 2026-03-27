# BLDC Motor Controller

Status: this design is still under development and the RTL, register map, and timing behavior may change.

This repository contains a synthesizable SystemVerilog BLDC motor controller with an AXI-Lite slave and a self-checking simulation testbench.

## Files

- `doc/bldc.txt`: original design brief
- `doc/SpartanESC.asc`: schematic export referenced by the brief
- `rtl/bldc_axi_controller.sv`: thin top-level wrapper
- `rtl/bldc_axi_slave.sv`: 60 MHz AXI-Lite frontend with command/response CDC bridge
- `rtl/bldc_motor_ctrl_domain.sv`: 100 MHz motor-control register domain
- `rtl/bldc_motor_core.sv`: commutation, PWM, interrupt, FIFO, and auto-duty control logic
- `tb/bldc_axi_controller_tb.sv`: self-checking testbench

## Implemented Features

- AXI-Lite slave interface on a 60 MHz clock domain
- Motor-control core running on a separate 100 MHz clock domain
- Three Hall inputs: `HA`, `HB`, `HC`
- Hall inputs are synchronized and filtered with a 5-sample majority voter
- Six bridge control outputs: `AL`, `AH`, `BL`, `BH`, `CL`, `CH`
- Bridge outputs are registered to avoid unintended combinational glitches
- 6-step commutation with:
  - automatic Hall-driven commutation
  - manual software-selected commutation
  - direction reversal
- PWM duty-cycle control using a 12-bit duty command
- Programmable PWM period covering 8 kHz to 144 kHz at 60 MHz
- Programmable deadtime with a practical range of 1 to 90 clocks
  - 1 clock at 60 MHz is 16.667 ns
  - 90 clocks is 1.5 us
- Hall transition interrupts for both positive and negative edges on all Hall inputs
- Interrupt mask register
- Transition counter with programmable time window
- 16-entry FIFO of transition-count samples
- FIFO not-empty interrupt
- Optional closed-loop duty modulation targeting a programmed commutation count per window

## RTL Partition

The design is split into four modules:

- `bldc_axi_controller`: top-level wrapper with wiring only
- `bldc_axi_slave`: AXI-Lite frontend in the AXI clock domain
- `bldc_motor_ctrl_domain`: register ownership and command handling in the motor clock domain
- `bldc_motor_core`: motor-control datapath

The motor-control modules are not instantiated inside the AXI slave. The AXI and motor domains communicate through a request/response CDC boundary.

## Register Map

All registers are 32-bit and word-aligned.

| Address | Name | Description |
| --- | --- | --- |
| `0x00` | `ID` | Fixed ID value `0x424C4443` |
| `0x04` | `CONTROL` | Bit 0 `drive_enable`, bit 1 `auto_comm_enable`, bit 2 `direction`, bit 3 `speed_ctrl_enable` |
| `0x08` | `PWM_CFG` | Bits `[11:0]` duty command, bits `[31:16]` PWM period in clocks |
| `0x0C` | `DEADTIME` | Bits `[7:0]` high-side deadtime in clocks, bits `[15:8]` low-side overlap in clocks |
| `0x10` | `COMM_CFG` | Bits `[2:0]` manual commutation state |
| `0x14` | `IRQ_MASK` | Bits `[5:0]` Hall edge masks, bit `[6]` FIFO interrupt mask. `1` masks the source |
| `0x18` | `IRQ_STATUS` | Bits `[5:0]` pending Hall edge flags, bit `[6]` FIFO not-empty status. Write `1` to clear Hall edge bits |
| `0x1C` | `MAIN_WINDOW` | Transition-count window in 60 MHz clocks |
| `0x20` | `FIFO_DATA` | Pops and returns the oldest transition-count sample in bits `[15:0]` |
| `0x24` | `FIFO_STATUS` | Bits `[4:0]` FIFO level, bit `[8]` empty, bit `[9]` full |
| `0x28` | `SPEED_TARGET` | Bits `[15:0]` target transition count, bits `[27:16]` duty step size |
| `0x2C` | `SPEED_WINDOW` | Auto-duty control window in 60 MHz clocks |
| `0x30` | `SPEED_STATUS` | Bits `[11:0]` current duty, bits `[27:12]` last measured auto-duty transition count |
| `0x34` | `STATUS` | Hall, requested commutation state, active commutation state, deadtime, and PWM activity |

## Hall Mapping

Forward direction uses the standard 6-step Hall sequence:

- `001 -> state 1`
- `101 -> state 2`
- `100 -> state 3`
- `110 -> state 4`
- `010 -> state 5`
- `011 -> state 6`

Reverse direction maps the same Hall codes to the reverse state order.

Before Hall values are used for interrupts or commutation, each input is passed through a 5-clock majority filter. This rejects short glitches at the cost of several clock cycles of detection latency.

State-to-output mapping is:

- `1`: `AH` PWM, `BL` on
- `2`: `AH` PWM, `CL` on
- `3`: `BH` PWM, `CL` on
- `4`: `BH` PWM, `AL` on
- `5`: `CH` PWM, `AL` on
- `6`: `CH` PWM, `BL` on

During commutation transitions:

- all high-side outputs are forced low for the programmed deadtime interval
- low-side outputs are never globally blanked
- if the low-side leg changes, the old and new low sides are both asserted for the programmed overlap interval, then only the new low side remains on until deadtime expires

## Running Simulation

Build and run with Icarus Verilog:

```sh
mkdir -p sim
iverilog -g2012 -o sim/bldc_axi_controller_tb.out rtl/bldc_axi_controller.sv tb/bldc_axi_controller_tb.sv
vvp sim/bldc_axi_controller_tb.out
```

Expected result:

```text
PASS
```

## Testbench Coverage

The self-checking testbench verifies:

- AXI-Lite register read and write behavior
- PWM generation and duty activity
- deadtime blanking on commutation changes
- manual commutation output mapping
- Hall-edge interrupt generation and clear behavior
- auto-commutation response to Hall changes
- transition-count FIFO push, interrupt, and pop behavior
- auto-duty increase when measured rate is below target
- auto-duty decrease when measured rate is above target

## Notes

- The controller is implemented as a single-clock design.
- The FIFO drops new samples when full.
- Invalid Hall combinations map to commutation state `0`, which disables bridge drive until a valid code appears.
