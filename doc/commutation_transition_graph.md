# Commutation Transition Graph

This diagram shows all state-to-state transitions, including the low-side behavior during deadtime.

- All high sides are off during deadtime.
- `X+Y→Y` means old and new low sides overlap for `low_overlap`, then only the new low side remains on until deadtime ends.
- `X` means the low side does not change, so it stays on for the full deadtime.

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
