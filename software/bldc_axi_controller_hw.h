#ifndef BLDC_AXI_CONTROLLER_HW_H
#define BLDC_AXI_CONTROLLER_HW_H

#include <stdint.h>

#include "bldc_axi_controller_regs.h"

static inline void bldc_axi_controller_write(uintptr_t base, uint32_t reg, uint32_t value)
{
    *(volatile uint32_t *)(base + reg) = value;
}

static inline uint32_t bldc_axi_controller_read(uintptr_t base, uint32_t reg)
{
    return *(volatile const uint32_t *)(base + reg);
}

static inline uint32_t bldc_axi_controller_pack_pwm_cfg(uint16_t period_clks, uint16_t duty)
{
    return (((uint32_t)period_clks << BLDC_AXI_CONTROLLER_PWM_CFG_PERIOD_SHIFT) &
            BLDC_AXI_CONTROLLER_PWM_CFG_PERIOD_MASK) |
           (((uint32_t)duty << BLDC_AXI_CONTROLLER_PWM_CFG_DUTY_SHIFT) &
            BLDC_AXI_CONTROLLER_PWM_CFG_DUTY_MASK);
}

static inline uint32_t bldc_axi_controller_pack_deadtime(uint8_t high_deadtime_clks,
                                                         uint8_t low_overlap_clks)
{
    return (((uint32_t)high_deadtime_clks << BLDC_AXI_CONTROLLER_DEADTIME_HIGH_SHIFT) &
            BLDC_AXI_CONTROLLER_DEADTIME_HIGH_MASK) |
           (((uint32_t)low_overlap_clks << BLDC_AXI_CONTROLLER_DEADTIME_LOW_SHIFT) &
            BLDC_AXI_CONTROLLER_DEADTIME_LOW_MASK);
}

static inline uint32_t bldc_axi_controller_pack_speed_target(uint16_t target_count,
                                                             uint16_t duty_step)
{
    return (((uint32_t)target_count << BLDC_AXI_CONTROLLER_SPEED_TARGET_COUNT_SHIFT) &
            BLDC_AXI_CONTROLLER_SPEED_TARGET_COUNT_MASK) |
           (((uint32_t)duty_step << BLDC_AXI_CONTROLLER_SPEED_TARGET_STEP_SHIFT) &
            BLDC_AXI_CONTROLLER_SPEED_TARGET_STEP_MASK);
}

static inline uint32_t bldc_axi_controller_pack_brake_cfg(uint16_t brake_duty)
{
    return (((uint32_t)brake_duty << BLDC_AXI_CONTROLLER_BRAKE_CFG_DUTY_SHIFT) &
            BLDC_AXI_CONTROLLER_BRAKE_CFG_DUTY_MASK);
}

static inline uint32_t bldc_axi_controller_extract_field(uint32_t value, uint32_t mask, unsigned shift)
{
    return (value & mask) >> shift;
}

#endif
