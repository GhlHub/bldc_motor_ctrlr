module bldc_motor_ctrl_domain (
    input  logic        clk_motor,
    input  logic        rst_n,
    input  logic        HA,
    input  logic        HB,
    input  logic        HC,
    output logic        AL,
    output logic        AH,
    output logic        BL,
    output logic        BH,
    output logic        CL,
    output logic        CH,
    output logic        irq_motor,
    input  logic [7:0]  cmd_addr_async,
    input  logic [31:0] cmd_wdata_async,
    input  logic [3:0]  cmd_wstrb_async,
    input  logic        cmd_write_async,
    input  logic        cmd_req_toggle_async,
    output logic [31:0] rsp_rdata_async,
    output logic        rsp_toggle_async
);

    localparam logic [31:0] ID_VALUE          = 32'h424C_4443;
    localparam int unsigned PWM_PERIOD_MIN    = 16'd695;
    localparam int unsigned PWM_PERIOD_MAX    = 16'd12500;
    localparam int unsigned DEADTIME_MIN      = 8'd1;
    localparam int unsigned DEADTIME_MAX      = 8'd90;

    localparam logic [7:0] ADDR_ID            = 8'h00;
    localparam logic [7:0] ADDR_CONTROL       = 8'h04;
    localparam logic [7:0] ADDR_PWM_CFG       = 8'h08;
    localparam logic [7:0] ADDR_DEADTIME      = 8'h0C;
    localparam logic [7:0] ADDR_COMM_CFG      = 8'h10;
    localparam logic [7:0] ADDR_IRQ_MASK      = 8'h14;
    localparam logic [7:0] ADDR_IRQ_STATUS    = 8'h18;
    localparam logic [7:0] ADDR_MAIN_WINDOW   = 8'h1C;
    localparam logic [7:0] ADDR_FIFO_DATA     = 8'h20;
    localparam logic [7:0] ADDR_FIFO_STATUS   = 8'h24;
    localparam logic [7:0] ADDR_SPEED_TARGET  = 8'h28;
    localparam logic [7:0] ADDR_SPEED_WINDOW  = 8'h2C;
    localparam logic [7:0] ADDR_SPEED_STATUS  = 8'h30;
    localparam logic [7:0] ADDR_STATUS        = 8'h34;
    localparam logic [7:0] ADDR_BRAKE_CFG     = 8'h38;

    logic        drive_enable_reg;
    logic        auto_comm_enable_reg;
    logic        direction_reg;
    logic        speed_ctrl_enable_reg;
    logic        brake_enable_reg;
    logic [11:0] duty_cmd_reg;
    logic [11:0] brake_duty_reg;
    logic [15:0] pwm_period_reg;
    logic [7:0]  deadtime_reg;
    logic [7:0]  low_overlap_reg;
    logic [2:0]  manual_comm_state_reg;
    logic [6:0]  irq_mask_reg;
    logic [31:0] main_window_cfg_reg;
    logic [15:0] speed_target_count_reg;
    logic [11:0] speed_step_reg;
    logic [31:0] speed_window_cfg_reg;

    logic [5:0]  clear_hall_irq;
    logic        main_window_load;
    logic        speed_window_load;
    logic        fifo_pop;

    logic [5:0]  hall_irq_pending_reg;
    logic        fifo_irq_level;
    logic [15:0] fifo_data;
    logic [4:0]  fifo_level;
    logic [15:0] speed_last_count_reg;
    logic [11:0] current_duty;
    logic [2:0]  hall_sync;
    logic [2:0]  requested_comm_state;
    logic [2:0]  active_comm_state;
    logic        deadtime_active;
    logic        brake_active;
    logic        pwm_high;
    logic [2:0]  hall_mapped_state;
    logic [7:0]  deadtime_count;

    logic        cmd_req_meta;
    logic        cmd_req_sync;
    logic        cmd_req_sync_d;

    function automatic logic [31:0] apply_wstrb(
        input logic [31:0] prior_data,
        input logic [31:0] write_data,
        input logic [3:0]  write_strb
    );
        logic [31:0] merged_data;
        begin
            merged_data = prior_data;
            if (write_strb[0]) merged_data[7:0]   = write_data[7:0];
            if (write_strb[1]) merged_data[15:8]  = write_data[15:8];
            if (write_strb[2]) merged_data[23:16] = write_data[23:16];
            if (write_strb[3]) merged_data[31:24] = write_data[31:24];
            apply_wstrb = merged_data;
        end
    endfunction

    bldc_motor_core u_motor_core (
        .clk(clk_motor),
        .rst_n(rst_n),
        .HA(HA),
        .HB(HB),
        .HC(HC),
        .drive_enable_reg(drive_enable_reg),
        .auto_comm_enable_reg(auto_comm_enable_reg),
        .direction_reg(direction_reg),
        .speed_ctrl_enable_reg(speed_ctrl_enable_reg),
        .brake_enable_reg(brake_enable_reg),
        .duty_cmd_reg(duty_cmd_reg),
        .brake_duty_reg(brake_duty_reg),
        .pwm_period_reg(pwm_period_reg),
        .deadtime_reg(deadtime_reg),
        .low_overlap_reg(low_overlap_reg),
        .manual_comm_state_reg(manual_comm_state_reg),
        .irq_mask_reg(irq_mask_reg),
        .main_window_cfg_reg(main_window_cfg_reg),
        .speed_target_count_reg(speed_target_count_reg),
        .speed_step_reg(speed_step_reg),
        .speed_window_cfg_reg(speed_window_cfg_reg),
        .clear_hall_irq(clear_hall_irq),
        .main_window_load(main_window_load),
        .speed_window_load(speed_window_load),
        .fifo_pop(fifo_pop),
        .AL(AL),
        .AH(AH),
        .BL(BL),
        .BH(BH),
        .CL(CL),
        .CH(CH),
        .irq(irq_motor),
        .hall_irq_pending_reg(hall_irq_pending_reg),
        .fifo_irq_level(fifo_irq_level),
        .fifo_data(fifo_data),
        .fifo_level(fifo_level),
        .speed_last_count_reg(speed_last_count_reg),
        .current_duty(current_duty),
        .hall_sync(hall_sync),
        .requested_comm_state(requested_comm_state),
        .active_comm_state(active_comm_state),
        .deadtime_active(deadtime_active),
        .brake_active(brake_active),
        .pwm_high(pwm_high),
        .hall_mapped_state(hall_mapped_state),
        .deadtime_count(deadtime_count)
    );

    always_ff @(posedge clk_motor) begin
        logic       cmd_edge;
        logic [31:0] merged_write_data;
        logic [31:0] read_data;

        if (!rst_n) begin
            drive_enable_reg       <= 1'b0;
            auto_comm_enable_reg   <= 1'b0;
            direction_reg          <= 1'b0;
            speed_ctrl_enable_reg  <= 1'b0;
            brake_enable_reg       <= 1'b0;
            duty_cmd_reg           <= 12'd0;
            brake_duty_reg         <= 12'hFFF;
            pwm_period_reg         <= 16'd12500;
            deadtime_reg           <= 8'd1;
            low_overlap_reg        <= 8'd0;
            manual_comm_state_reg  <= 3'd0;
            irq_mask_reg           <= 7'h7F;
            main_window_cfg_reg    <= 32'd0;
            speed_target_count_reg <= 16'd0;
            speed_step_reg         <= 12'd1;
            speed_window_cfg_reg   <= 32'd0;

            clear_hall_irq         <= 6'd0;
            main_window_load       <= 1'b0;
            speed_window_load      <= 1'b0;
            fifo_pop               <= 1'b0;

            cmd_req_meta           <= 1'b0;
            cmd_req_sync           <= 1'b0;
            cmd_req_sync_d         <= 1'b0;
            rsp_rdata_async        <= 32'd0;
            rsp_toggle_async       <= 1'b0;
        end else begin
            cmd_req_meta      <= cmd_req_toggle_async;
            cmd_req_sync      <= cmd_req_meta;
            cmd_req_sync_d    <= cmd_req_sync;
            cmd_edge          = cmd_req_sync ^ cmd_req_sync_d;
            merged_write_data = 32'd0;
            read_data         = 32'd0;

            clear_hall_irq    <= 6'd0;
            main_window_load  <= 1'b0;
            speed_window_load <= 1'b0;
            fifo_pop          <= 1'b0;

            if (cmd_edge) begin
                if (cmd_write_async) begin
                    case (cmd_addr_async)
                        ADDR_CONTROL: begin
                            merged_write_data = apply_wstrb(
                                {27'd0, brake_enable_reg, speed_ctrl_enable_reg, direction_reg, auto_comm_enable_reg, drive_enable_reg},
                                cmd_wdata_async,
                                cmd_wstrb_async
                            );
                            drive_enable_reg      <= merged_write_data[0];
                            auto_comm_enable_reg  <= merged_write_data[1];
                            direction_reg         <= merged_write_data[2];
                            speed_ctrl_enable_reg <= merged_write_data[3];
                            brake_enable_reg      <= merged_write_data[4];
                        end
                        ADDR_PWM_CFG: begin
                            merged_write_data = apply_wstrb(
                                {pwm_period_reg, 4'd0, duty_cmd_reg},
                                cmd_wdata_async,
                                cmd_wstrb_async
                            );
                            duty_cmd_reg <= merged_write_data[11:0];
                            if (merged_write_data[31:16] < PWM_PERIOD_MIN[15:0]) begin
                                pwm_period_reg <= PWM_PERIOD_MIN[15:0];
                            end else if (merged_write_data[31:16] > PWM_PERIOD_MAX[15:0]) begin
                                pwm_period_reg <= PWM_PERIOD_MAX[15:0];
                            end else begin
                                pwm_period_reg <= merged_write_data[31:16];
                            end
                        end
                        ADDR_DEADTIME: begin
                            merged_write_data = apply_wstrb(
                                {16'd0, low_overlap_reg, deadtime_reg},
                                cmd_wdata_async,
                                cmd_wstrb_async
                            );
                            if (merged_write_data[7:0] < DEADTIME_MIN[7:0]) begin
                                deadtime_reg <= DEADTIME_MIN[7:0];
                            end else if (merged_write_data[7:0] > DEADTIME_MAX[7:0]) begin
                                deadtime_reg <= DEADTIME_MAX[7:0];
                            end else begin
                                deadtime_reg <= merged_write_data[7:0];
                            end
                            if (merged_write_data[15:8] > DEADTIME_MAX[7:0]) begin
                                low_overlap_reg <= DEADTIME_MAX[7:0];
                            end else begin
                                low_overlap_reg <= merged_write_data[15:8];
                            end
                        end
                        ADDR_COMM_CFG: begin
                            merged_write_data = apply_wstrb(
                                {29'd0, manual_comm_state_reg},
                                cmd_wdata_async,
                                cmd_wstrb_async
                            );
                            manual_comm_state_reg <= merged_write_data[2:0];
                        end
                        ADDR_IRQ_MASK: begin
                            merged_write_data = apply_wstrb(
                                {25'd0, irq_mask_reg},
                                cmd_wdata_async,
                                cmd_wstrb_async
                            );
                            irq_mask_reg <= merged_write_data[6:0];
                        end
                        ADDR_IRQ_STATUS: begin
                            merged_write_data = apply_wstrb(32'd0, cmd_wdata_async, cmd_wstrb_async);
                            clear_hall_irq    <= merged_write_data[5:0];
                        end
                        ADDR_MAIN_WINDOW: begin
                            merged_write_data   = apply_wstrb(main_window_cfg_reg, cmd_wdata_async, cmd_wstrb_async);
                            main_window_cfg_reg <= merged_write_data;
                            main_window_load    <= 1'b1;
                        end
                        ADDR_SPEED_TARGET: begin
                            merged_write_data = apply_wstrb(
                                {4'd0, speed_step_reg, speed_target_count_reg},
                                cmd_wdata_async,
                                cmd_wstrb_async
                            );
                            speed_target_count_reg <= merged_write_data[15:0];
                            speed_step_reg         <= merged_write_data[27:16];
                        end
                        ADDR_SPEED_WINDOW: begin
                            merged_write_data    = apply_wstrb(speed_window_cfg_reg, cmd_wdata_async, cmd_wstrb_async);
                            speed_window_cfg_reg <= merged_write_data;
                            speed_window_load    <= 1'b1;
                        end
                        ADDR_BRAKE_CFG: begin
                            merged_write_data = apply_wstrb(
                                {20'd0, brake_duty_reg},
                                cmd_wdata_async,
                                cmd_wstrb_async
                            );
                            brake_duty_reg <= merged_write_data[11:0];
                        end
                        default: begin
                        end
                    endcase

                    rsp_rdata_async  <= 32'd0;
                    rsp_toggle_async <= ~rsp_toggle_async;
                end else begin
                    case (cmd_addr_async)
                        ADDR_ID: begin
                            read_data = ID_VALUE;
                        end
                        ADDR_CONTROL: begin
                            read_data = {27'd0, brake_enable_reg, speed_ctrl_enable_reg, direction_reg, auto_comm_enable_reg, drive_enable_reg};
                        end
                        ADDR_PWM_CFG: begin
                            read_data = {pwm_period_reg, 4'd0, duty_cmd_reg};
                        end
                        ADDR_DEADTIME: begin
                            read_data = {16'd0, low_overlap_reg, deadtime_reg};
                        end
                        ADDR_COMM_CFG: begin
                            read_data = {29'd0, manual_comm_state_reg};
                        end
                        ADDR_IRQ_MASK: begin
                            read_data = {25'd0, irq_mask_reg};
                        end
                        ADDR_IRQ_STATUS: begin
                            read_data = {25'd0, fifo_irq_level, hall_irq_pending_reg};
                        end
                        ADDR_MAIN_WINDOW: begin
                            read_data = main_window_cfg_reg;
                        end
                        ADDR_FIFO_DATA: begin
                            if (fifo_level != 5'd0) begin
                                read_data = {16'd0, fifo_data};
                                fifo_pop  <= 1'b1;
                            end else begin
                                read_data = 32'd0;
                            end
                        end
                        ADDR_FIFO_STATUS: begin
                            read_data = {22'd0, (fifo_level == 5'd16), (fifo_level == 5'd0), fifo_level};
                        end
                        ADDR_SPEED_TARGET: begin
                            read_data = {4'd0, speed_step_reg, speed_target_count_reg};
                        end
                        ADDR_SPEED_WINDOW: begin
                            read_data = speed_window_cfg_reg;
                        end
                        ADDR_SPEED_STATUS: begin
                            read_data = {4'd0, speed_last_count_reg, current_duty};
                        end
                        ADDR_STATUS: begin
                            read_data = {
                                18'd0,
                                brake_active,
                                pwm_high,
                                deadtime_active,
                                active_comm_state,
                                1'b0,
                                requested_comm_state,
                                1'b0,
                                hall_sync
                            };
                        end
                        ADDR_BRAKE_CFG: begin
                            read_data = {20'd0, brake_duty_reg};
                        end
                        default: begin
                            read_data = 32'd0;
                        end
                    endcase

                    rsp_rdata_async  <= read_data;
                    rsp_toggle_async <= ~rsp_toggle_async;
                end
            end
        end
    end

endmodule
