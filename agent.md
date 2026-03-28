# Agent Notes

## Purpose

This repository implements a BLDC motor controller in SystemVerilog with an AXI-Lite register interface and a self-checking simulation testbench.

## Current Layout

- `doc/`
  - `bldc.txt`: source requirements
  - `SpartanESC.asc`: reference schematic export
- `rtl/`
  - `bldc_axi_controller.sv`: thin top-level wrapper
  - `bldc_axi_slave.sv`: AXI-Lite frontend and CDC command source
  - `bldc_motor_ctrl_domain.sv`: motor-domain register bank and CDC command sink
  - `bldc_motor_core.sv`: motor-control core
- `ip_repo/`
  - `package_bldc_axi_controller_ip.tcl`: Vivado packaged-IP build script
  - `bldc_axi_controller_product_guide.htm`: local product-guide stub that points to the GitHub repo
  - `bldc_axi_controller_1_0/`: generated IP repository output
- `software/`
  - `bldc_axi_controller_regs.h`: register offsets, masks, shifts, and limits
  - `bldc_axi_controller_hw.h`: C MMIO helpers and field packers
- `tb/`
  - `bldc_axi_controller_tb.sv`: self-checking testbench
- `sim/`
  - generated simulation outputs

## Design Summary

- Two clock domains:
  - 60 MHz AXI-Lite domain
  - 100 MHz motor-control domain
- Two synchronous active-low resets:
  - `rst_axi_n` for the AXI domain
  - `rst_motor_n` for the motor domain
- Hall inputs are synchronized internally
- Hall inputs are synchronized and passed through a 5-sample majority filter before edge detection and commutation
- Bridge outputs are registered in the motor core; keep them clocked to avoid drive glitches
- Commutation supports:
  - software-selected manual state
  - automatic Hall-based state selection
  - programmable deadtime and low-side overlap
- Brake supports:
  - low-side-only PWM braking
  - all high sides forced off during brake
  - deadtime on brake entry and exit
  - `CONTROL[4]` brake enable and `BRAKE_CFG[11:0]` brake duty
- The motor core uses an explicit transition-phase FSM:
  - `PH_RUN`
  - `PH_OVERLAP`
  - `PH_DEADTIME`
- PWM frequency is set by register-programmed period
- Interrupts cover:
  - Hall rising and falling edges
  - transition FIFO not-empty
- Transition measurement exists in two paths:
  - main sampling window feeding the FIFO
  - auto-duty control window feeding a simple up/down duty controller

The intended hierarchy is:

- top-level wrapper
- standalone AXI slave
- standalone motor control domain
- standalone control core

Do not instantiate motor-control blocks inside the AXI slave.

## Commutation Behavior

Forward Hall mapping:

- `001 -> 1`
- `101 -> 2`
- `100 -> 3`
- `110 -> 4`
- `010 -> 5`
- `011 -> 6`

Output mapping:

- `1`: `AH` PWM, `BL` on
- `2`: `AH` PWM, `CL` on
- `3`: `BH` PWM, `CL` on
- `4`: `BH` PWM, `AL` on
- `5`: `CH` PWM, `AL` on
- `6`: `CH` PWM, `BL` on

High sides are blanked for the deadtime interval on every state transition.
Low sides are never globally blanked.
If the low-side leg changes, the old and new low sides overlap for a programmable interval before dropping the old low side.

The transition implementation is intentionally explicit:

- `active_comm_state` is the committed run state
- `requested_comm_state` is the pending destination state
- `comm_phase` determines whether outputs are in run, overlap, or deadtime behavior
- `brake_phase` overrides commutation during brake entry, active brake PWM, and brake exit deadtime

Current added register locations to remember:

- `CONTROL[4]`: `brake_enable`
- `BRAKE_CFG` at `0x38`: brake duty
- `STATUS[13]`: `brake_active`

## Validation Command

Use this as the default regression:

```sh
mkdir -p sim
iverilog -g2012 -o sim/bldc_axi_controller_tb.out rtl/bldc_axi_controller.sv tb/bldc_axi_controller_tb.sv
vvp sim/bldc_axi_controller_tb.out
```

The test should end with `PASS`.

Vivado IP packaging command:

```sh
vivado -mode batch -source ip_repo/package_bldc_axi_controller_ip.tcl
```

The packaged IP includes a product-guide entry that points to:

- `https://github.com/GhlHub/bldc_motor_ctrlr`

## Editing Guidance

- Keep the design synthesizable.
- Preserve the AXI-Lite register map unless there is a deliberate interface change.
- If register layout changes, update both:
  - `rtl/bldc_axi_controller.sv`
  - `tb/bldc_axi_controller_tb.sv`
- If the register map changes, also update:
  - `software/bldc_axi_controller_regs.h`
  - `software/bldc_axi_controller_hw.h`
- Prefer adding behavioral checks to the testbench instead of relying on waveform inspection.
- Keep commutation timing explicit:
  high sides off during deadtime
  low sides never globally blanked
  low-side changes use the programmed overlap interval
- If commutation behavior changes, update:
  - `readme.md`
  - `doc/commutation_transition_graph.md`

## Likely Next Extensions

- Separate prescaler or direct frequency register abstraction for PWM
- Better FIFO overflow reporting
- Programmable commutation tables
- Formal assertions for AXI-Lite and deadtime safety
- Investigate regenerative-braking capability in the ESC schematic for the next ESC revision, including battery charge acceptance, current sensing, and bus overvoltage handling
