# Commutation Transition Graph

This document shows both:

- the external commutation state-to-state behavior
- the internal transition-phase FSM used to implement overlap and deadtime

- All high sides are off during deadtime.
- `X+Y→Y` means old and new low sides overlap for `low_overlap`, then only the new low side remains on until deadtime ends.
- `X` means the low side does not change, so it stays on for the full deadtime.

## State-To-State Graph

```mermaid
graph LR
    S1["S1\nRun: AH=PWM, BL=1"]
    S2["S2\nRun: AH=PWM, CL=1"]
    S3["S3\nRun: BH=PWM, CL=1"]
    S4["S4\nRun: BH=PWM, AL=1"]
    S5["S5\nRun: CH=PWM, AL=1"]
    S6["S6\nRun: CH=PWM, BL=1"]

    S1 -->|Deadtime: BL+CL→CL\nThen S2| S2
    S1 -->|Deadtime: BL+CL→CL\nThen S3| S3
    S1 -->|Deadtime: BL+AL→AL\nThen S4| S4
    S1 -->|Deadtime: BL+AL→AL\nThen S5| S5
    S1 -->|Deadtime: BL\nThen S6| S6

    S2 -->|Deadtime: CL+BL→BL\nThen S1| S1
    S2 -->|Deadtime: CL\nThen S3| S3
    S2 -->|Deadtime: CL+AL→AL\nThen S4| S4
    S2 -->|Deadtime: CL+AL→AL\nThen S5| S5
    S2 -->|Deadtime: CL+BL→BL\nThen S6| S6

    S3 -->|Deadtime: CL+BL→BL\nThen S1| S1
    S3 -->|Deadtime: CL\nThen S2| S2
    S3 -->|Deadtime: CL+AL→AL\nThen S4| S4
    S3 -->|Deadtime: CL+AL→AL\nThen S5| S5
    S3 -->|Deadtime: CL+BL→BL\nThen S6| S6

    S4 -->|Deadtime: AL+BL→BL\nThen S1| S1
    S4 -->|Deadtime: AL+CL→CL\nThen S2| S2
    S4 -->|Deadtime: AL+CL→CL\nThen S3| S3
    S4 -->|Deadtime: AL\nThen S5| S5
    S4 -->|Deadtime: AL+BL→BL\nThen S6| S6

    S5 -->|Deadtime: AL+BL→BL\nThen S1| S1
    S5 -->|Deadtime: AL+CL→CL\nThen S2| S2
    S5 -->|Deadtime: AL+CL→CL\nThen S3| S3
    S5 -->|Deadtime: AL\nThen S4| S4
    S5 -->|Deadtime: AL+BL→BL\nThen S6| S6

    S6 -->|Deadtime: BL\nThen S1| S1
    S6 -->|Deadtime: BL+CL→CL\nThen S2| S2
    S6 -->|Deadtime: BL+CL→CL\nThen S3| S3
    S6 -->|Deadtime: BL+AL→AL\nThen S4| S4
    S6 -->|Deadtime: BL+AL→AL\nThen S5| S5
```

## Internal Phase FSM

This is the structure used in `bldc_motor_core.sv` to realize the transition behavior:

- `PH_RUN`: normal commutation state pattern, including PWM on the active high side
- `PH_OVERLAP`: all high sides off, old and new low sides both on
- `PH_DEADTIME`: all high sides off, only the new low side on

If the low-side leg does not change, the controller skips `PH_OVERLAP` and moves directly from `PH_RUN` to `PH_DEADTIME`.

```mermaid
stateDiagram-v2
    [*] --> PH_RUN
    PH_RUN --> PH_OVERLAP: new state requested\nlow side changes\nlow_overlap > 0
    PH_RUN --> PH_DEADTIME: new state requested\nsame low side or low_overlap = 0
    PH_OVERLAP --> PH_DEADTIME: overlap counter expires
    PH_DEADTIME --> PH_RUN: deadtime counter expires\nactive_comm_state = requested_comm_state
```
