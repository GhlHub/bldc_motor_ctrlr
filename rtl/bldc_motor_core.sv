module bldc_motor_core (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        HA,
    input  logic        HB,
    input  logic        HC,
    input  logic        drive_enable_reg,
    input  logic        auto_comm_enable_reg,
    input  logic        direction_reg,
    input  logic        speed_ctrl_enable_reg,
    input  logic [11:0] duty_cmd_reg,
    input  logic [15:0] pwm_period_reg,
    input  logic [7:0]  deadtime_reg,
    input  logic [7:0]  low_overlap_reg,
    input  logic [2:0]  manual_comm_state_reg,
    input  logic [6:0]  irq_mask_reg,
    input  logic [31:0] main_window_cfg_reg,
    input  logic [15:0] speed_target_count_reg,
    input  logic [11:0] speed_step_reg,
    input  logic [31:0] speed_window_cfg_reg,
    input  logic [5:0]  clear_hall_irq,
    input  logic        main_window_load,
    input  logic        speed_window_load,
    input  logic        fifo_pop,
    output logic        AL,
    output logic        AH,
    output logic        BL,
    output logic        BH,
    output logic        CL,
    output logic        CH,
    output logic        irq,
    output logic [5:0]  hall_irq_pending_reg,
    output logic        fifo_irq_level,
    output logic [15:0] fifo_data,
    output logic [4:0]  fifo_level,
    output logic [15:0] speed_last_count_reg,
    output logic [11:0] current_duty,
    output logic [2:0]  hall_sync,
    output logic [2:0]  requested_comm_state,
    output logic [2:0]  active_comm_state,
    output logic        deadtime_active,
    output logic        pwm_high,
    output logic [2:0]  hall_mapped_state,
    output logic [7:0]  deadtime_count
);

    typedef enum logic [1:0] {
        PH_RUN      = 2'd0,
        PH_OVERLAP  = 2'd1,
        PH_DEADTIME = 2'd2
    } comm_phase_t;

    logic [2:0]  hall_meta;
    logic [2:0]  hall_sync_raw;
    logic [2:0]  hall_prev;
    logic [4:0]  ha_hist;
    logic [4:0]  hb_hist;
    logic [4:0]  hc_hist;
    logic [15:0] main_transition_count;
    logic [31:0] main_window_count;
    logic [15:0] auto_transition_count;
    logic [31:0] speed_window_count;
    logic [11:0] auto_duty_reg;
    logic [7:0]  low_overlap_count;
    logic [15:0] transition_fifo [0:15];
    logic [3:0]  fifo_wr_ptr;
    logic [3:0]  fifo_rd_ptr;
    logic [15:0] pwm_counter;
    logic [15:0] pwm_on_counts;
    logic [27:0] pwm_product;
    logic [5:0]  drive_outputs_next;
    comm_phase_t comm_phase;

    function automatic logic [2:0] hall_to_comm_state(
        input logic direction,
        input logic [2:0] hall_value
    );
        begin
            case ({direction, hall_value})
                4'b0_001: hall_to_comm_state = 3'd1;
                4'b0_101: hall_to_comm_state = 3'd2;
                4'b0_100: hall_to_comm_state = 3'd3;
                4'b0_110: hall_to_comm_state = 3'd4;
                4'b0_010: hall_to_comm_state = 3'd5;
                4'b0_011: hall_to_comm_state = 3'd6;
                4'b1_001: hall_to_comm_state = 3'd6;
                4'b1_101: hall_to_comm_state = 3'd5;
                4'b1_100: hall_to_comm_state = 3'd4;
                4'b1_110: hall_to_comm_state = 3'd3;
                4'b1_010: hall_to_comm_state = 3'd2;
                4'b1_011: hall_to_comm_state = 3'd1;
                default:  hall_to_comm_state = 3'd0;
            endcase
        end
    endfunction

    function automatic logic [15:0] sat_add_u16(
        input logic [15:0] value,
        input logic        add_one
    );
        begin
            if (!add_one) begin
                sat_add_u16 = value;
            end else if (value == 16'hFFFF) begin
                sat_add_u16 = value;
            end else begin
                sat_add_u16 = value + 16'd1;
            end
        end
    endfunction

    function automatic logic [5:0] comm_drive_pattern(
        input logic [2:0] state,
        input logic       pwm_gate
    );
        begin
            case (state)
                3'd1: comm_drive_pattern = {pwm_gate, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0};
                3'd2: comm_drive_pattern = {pwm_gate, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1};
                3'd3: comm_drive_pattern = {1'b0, 1'b0, pwm_gate, 1'b0, 1'b0, 1'b1};
                3'd4: comm_drive_pattern = {1'b0, 1'b1, pwm_gate, 1'b0, 1'b0, 1'b0};
                3'd5: comm_drive_pattern = {1'b0, 1'b1, 1'b0, 1'b0, pwm_gate, 1'b0};
                3'd6: comm_drive_pattern = {1'b0, 1'b0, 1'b0, 1'b1, pwm_gate, 1'b0};
                default: comm_drive_pattern = 6'b0;
            endcase
        end
    endfunction

    function automatic logic [5:0] comm_low_pattern(
        input logic [2:0] state
    );
        begin
            case (state)
                3'd1: comm_low_pattern = {1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0};
                3'd2: comm_low_pattern = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1};
                3'd3: comm_low_pattern = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1};
                3'd4: comm_low_pattern = {1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0};
                3'd5: comm_low_pattern = {1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0};
                3'd6: comm_low_pattern = {1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0};
                default: comm_low_pattern = 6'b0;
            endcase
        end
    endfunction

    function automatic logic majority5(
        input logic [4:0] samples
    );
        logic [2:0] sample_sum;
        begin
            sample_sum =
                {2'd0, samples[0]} +
                {2'd0, samples[1]} +
                {2'd0, samples[2]} +
                {2'd0, samples[3]} +
                {2'd0, samples[4]};
            majority5 = (sample_sum >= 3'd3);
        end
    endfunction

    assign current_duty     = speed_ctrl_enable_reg ? auto_duty_reg : duty_cmd_reg;
    assign hall_mapped_state = hall_to_comm_state(direction_reg, hall_sync);
    assign fifo_irq_level   = (fifo_level != 5'd0);
    assign fifo_data        = (fifo_level != 5'd0) ? transition_fifo[fifo_rd_ptr] : 16'd0;
    assign deadtime_active  = (comm_phase != PH_RUN);

    always @* begin
        pwm_product = current_duty * pwm_period_reg;
        if (current_duty == 12'd0) begin
            pwm_on_counts = 16'd0;
        end else if (current_duty == 12'hFFF) begin
            pwm_on_counts = pwm_period_reg;
        end else begin
            pwm_on_counts = pwm_product[27:12];
        end
    end

    assign pwm_high = (pwm_counter < pwm_on_counts);

    assign irq =
        ((hall_irq_pending_reg[0] && !irq_mask_reg[0]) ||
         (hall_irq_pending_reg[1] && !irq_mask_reg[1]) ||
         (hall_irq_pending_reg[2] && !irq_mask_reg[2]) ||
         (hall_irq_pending_reg[3] && !irq_mask_reg[3]) ||
         (hall_irq_pending_reg[4] && !irq_mask_reg[4]) ||
         (hall_irq_pending_reg[5] && !irq_mask_reg[5]) ||
         (fifo_irq_level           && !irq_mask_reg[6]));

    always @* begin
        drive_outputs_next = 6'b0;

        if (drive_enable_reg) begin
            case (comm_phase)
                PH_OVERLAP: begin
                    drive_outputs_next =
                        comm_low_pattern(active_comm_state) |
                        comm_low_pattern(requested_comm_state);
                end
                PH_DEADTIME: begin
                    drive_outputs_next = comm_low_pattern(requested_comm_state);
                end
                default: begin
                    drive_outputs_next = comm_drive_pattern(active_comm_state, pwm_high);
                end
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        logic [5:0] hall_edge_bits;
        logic [5:0] hall_irq_pending_next;
        logic [2:0] next_requested_state;
        logic       comm_transition_pulse;
        logic [15:0] main_count_sample;
        logic [15:0] auto_count_sample;
        logic [11:0] auto_duty_next;
        logic [3:0] fifo_rd_ptr_next;
        logic [3:0] fifo_wr_ptr_next;
        logic [4:0] fifo_level_next;
        logic       low_side_changes;
        logic [7:0] overlap_load;

        if (!rst_n) begin
            hall_meta              <= 3'd0;
            hall_sync_raw          <= 3'd0;
            hall_sync              <= 3'd0;
            hall_prev              <= 3'd0;
            ha_hist                <= 5'd0;
            hb_hist                <= 5'd0;
            hc_hist                <= 5'd0;
            hall_irq_pending_reg   <= 6'd0;
            requested_comm_state   <= 3'd0;
            active_comm_state      <= 3'd0;
            comm_phase             <= PH_RUN;
            deadtime_count         <= 8'd0;
            main_transition_count  <= 16'd0;
            main_window_count      <= 32'd0;
            auto_transition_count  <= 16'd0;
            speed_window_count     <= 32'd0;
            speed_last_count_reg   <= 16'd0;
            auto_duty_reg          <= 12'd0;
            low_overlap_count      <= 8'd0;
            fifo_wr_ptr            <= 4'd0;
            fifo_rd_ptr            <= 4'd0;
            fifo_level             <= 5'd0;
            pwm_counter            <= 16'd0;
            AL                     <= 1'b0;
            AH                     <= 1'b0;
            BL                     <= 1'b0;
            BH                     <= 1'b0;
            CL                     <= 1'b0;
            CH                     <= 1'b0;
        end else begin
            hall_edge_bits = {
                !hall_sync[2] && hall_prev[2],
                hall_sync[2] && !hall_prev[2],
                !hall_sync[1] && hall_prev[1],
                hall_sync[1] && !hall_prev[1],
                !hall_sync[0] && hall_prev[0],
                hall_sync[0] && !hall_prev[0]
            };
            hall_irq_pending_next = (hall_irq_pending_reg | hall_edge_bits) & ~clear_hall_irq;
            next_requested_state  = requested_comm_state;
            comm_transition_pulse = 1'b0;
            main_count_sample     = main_transition_count;
            auto_count_sample     = auto_transition_count;
            auto_duty_next        = auto_duty_reg;
            fifo_rd_ptr_next      = fifo_rd_ptr;
            fifo_wr_ptr_next      = fifo_wr_ptr;
            fifo_level_next       = fifo_level;
            low_side_changes      = 1'b0;
            overlap_load          = 8'd0;

            hall_meta <= {HC, HB, HA};
            hall_sync_raw <= hall_meta;
            ha_hist <= {ha_hist[3:0], hall_sync_raw[0]};
            hb_hist <= {hb_hist[3:0], hall_sync_raw[1]};
            hc_hist <= {hc_hist[3:0], hall_sync_raw[2]};
            hall_sync <= {majority5(hc_hist), majority5(hb_hist), majority5(ha_hist)};
            hall_prev <= hall_sync;
            hall_irq_pending_reg <= hall_irq_pending_next;

            if (auto_comm_enable_reg) begin
                if ((hall_mapped_state != 3'd0) && (hall_mapped_state != requested_comm_state)) begin
                    next_requested_state  = hall_mapped_state;
                    comm_transition_pulse = 1'b1;
                end
            end else if (manual_comm_state_reg != requested_comm_state) begin
                next_requested_state  = manual_comm_state_reg;
                comm_transition_pulse = 1'b1;
            end

            if (comm_transition_pulse) begin
                if (next_requested_state != active_comm_state) begin
                    requested_comm_state <= next_requested_state;
                    deadtime_count       <= deadtime_reg;
                    low_side_changes     = (comm_low_pattern(active_comm_state) != comm_low_pattern(next_requested_state));
                    if (low_overlap_reg < deadtime_reg) begin
                        overlap_load = low_overlap_reg;
                    end else begin
                        overlap_load = deadtime_reg;
                    end
                    if (low_side_changes && (overlap_load != 8'd0)) begin
                        low_overlap_count <= overlap_load;
                        comm_phase        <= PH_OVERLAP;
                    end else begin
                        low_overlap_count <= 8'd0;
                        comm_phase        <= PH_DEADTIME;
                    end
                end
            end else begin
                case (comm_phase)
                    PH_OVERLAP: begin
                        if (low_overlap_count > 8'd1) begin
                            low_overlap_count <= low_overlap_count - 8'd1;
                        end else begin
                            low_overlap_count <= 8'd0;
                            comm_phase        <= PH_DEADTIME;
                        end

                        if (deadtime_count != 8'd0) begin
                            deadtime_count <= deadtime_count - 8'd1;
                        end
                    end
                    PH_DEADTIME: begin
                        if (deadtime_count > 8'd1) begin
                            deadtime_count <= deadtime_count - 8'd1;
                        end else begin
                            deadtime_count     <= 8'd0;
                            active_comm_state  <= requested_comm_state;
                            low_overlap_count  <= 8'd0;
                            comm_phase         <= PH_RUN;
                        end
                    end
                    default: begin
                    end
                endcase
            end

            if (pwm_counter == (pwm_period_reg - 16'd1)) begin
                pwm_counter <= 16'd0;
            end else begin
                pwm_counter <= pwm_counter + 16'd1;
            end

            main_count_sample = sat_add_u16(main_transition_count, comm_transition_pulse);
            if (main_window_load) begin
                main_window_count     <= (main_window_cfg_reg == 32'd0) ? 32'd0 : (main_window_cfg_reg - 32'd1);
                main_transition_count <= 16'd0;
            end else if (main_window_cfg_reg == 32'd0) begin
                main_window_count     <= 32'd0;
                main_transition_count <= 16'd0;
            end else if (main_window_count == 32'd0) begin
                if (fifo_level_next != 5'd16) begin
                    transition_fifo[fifo_wr_ptr_next] <= main_count_sample;
                    fifo_wr_ptr_next = fifo_wr_ptr_next + 4'd1;
                    fifo_level_next  = fifo_level_next + 5'd1;
                end
                main_window_count     <= main_window_cfg_reg - 32'd1;
                main_transition_count <= 16'd0;
            end else begin
                main_window_count     <= main_window_count - 32'd1;
                main_transition_count <= main_count_sample;
            end

            if (!speed_ctrl_enable_reg) begin
                auto_duty_reg         <= duty_cmd_reg;
                auto_transition_count <= 16'd0;
                speed_last_count_reg  <= speed_last_count_reg;
                if (speed_window_load) begin
                    speed_window_count <= (speed_window_cfg_reg == 32'd0) ? 32'd0 : (speed_window_cfg_reg - 32'd1);
                end else if (speed_window_cfg_reg != 32'd0) begin
                    speed_window_count <= speed_window_cfg_reg - 32'd1;
                end else begin
                    speed_window_count <= 32'd0;
                end
            end else begin
                auto_count_sample = sat_add_u16(auto_transition_count, comm_transition_pulse);
                if (speed_window_load) begin
                    speed_window_count    <= (speed_window_cfg_reg == 32'd0) ? 32'd0 : (speed_window_cfg_reg - 32'd1);
                    auto_transition_count <= 16'd0;
                    speed_last_count_reg  <= 16'd0;
                end else if (speed_window_cfg_reg == 32'd0) begin
                    speed_window_count    <= 32'd0;
                    auto_transition_count <= 16'd0;
                end else if (speed_window_count == 32'd0) begin
                    speed_last_count_reg  <= auto_count_sample;
                    auto_transition_count <= 16'd0;
                    speed_window_count    <= speed_window_cfg_reg - 32'd1;

                    auto_duty_next = auto_duty_reg;
                    if ((auto_count_sample < speed_target_count_reg) && (speed_step_reg != 12'd0)) begin
                        if ((12'hFFF - auto_duty_reg) < speed_step_reg) begin
                            auto_duty_next = 12'hFFF;
                        end else begin
                            auto_duty_next = auto_duty_reg + speed_step_reg;
                        end
                    end else if ((auto_count_sample > speed_target_count_reg) && (speed_step_reg != 12'd0)) begin
                        if (auto_duty_reg < speed_step_reg) begin
                            auto_duty_next = 12'd0;
                        end else begin
                            auto_duty_next = auto_duty_reg - speed_step_reg;
                        end
                    end
                    auto_duty_reg <= auto_duty_next;
                end else begin
                    speed_window_count    <= speed_window_count - 32'd1;
                    auto_transition_count <= auto_count_sample;
                end
            end

            if (fifo_pop && (fifo_level_next != 5'd0)) begin
                fifo_rd_ptr_next = fifo_rd_ptr_next + 4'd1;
                fifo_level_next  = fifo_level_next - 5'd1;
            end

            fifo_rd_ptr <= fifo_rd_ptr_next;
            fifo_wr_ptr <= fifo_wr_ptr_next;
            fifo_level  <= fifo_level_next;
            {AH, AL, BH, BL, CH, CL} <= drive_outputs_next;
        end
    end

endmodule
