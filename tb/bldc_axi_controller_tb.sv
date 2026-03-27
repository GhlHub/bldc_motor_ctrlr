`timescale 1ns/1ps

module bldc_axi_controller_tb;
    localparam realtime AXI_CLK_PERIOD_NS   = 16.666;
    localparam realtime MOTOR_CLK_PERIOD_NS = 10.0;

    localparam logic [7:0] ADDR_ID           = 8'h00;
    localparam logic [7:0] ADDR_CONTROL      = 8'h04;
    localparam logic [7:0] ADDR_PWM_CFG      = 8'h08;
    localparam logic [7:0] ADDR_DEADTIME     = 8'h0C;
    localparam logic [7:0] ADDR_COMM_CFG     = 8'h10;
    localparam logic [7:0] ADDR_IRQ_MASK     = 8'h14;
    localparam logic [7:0] ADDR_IRQ_STATUS   = 8'h18;
    localparam logic [7:0] ADDR_MAIN_WINDOW  = 8'h1C;
    localparam logic [7:0] ADDR_FIFO_DATA    = 8'h20;
    localparam logic [7:0] ADDR_FIFO_STATUS  = 8'h24;
    localparam logic [7:0] ADDR_SPEED_TARGET = 8'h28;
    localparam logic [7:0] ADDR_SPEED_WINDOW = 8'h2C;
    localparam logic [7:0] ADDR_SPEED_STATUS = 8'h30;
    localparam logic [7:0] ADDR_STATUS       = 8'h34;

    logic        clk_axi;
    logic        clk_motor;
    logic        rst_n;
    logic        HA;
    logic        HB;
    logic        HC;
    logic        AL;
    logic        AH;
    logic        BL;
    logic        BH;
    logic        CL;
    logic        CH;
    logic        irq;

    logic [7:0]  s_axil_awaddr;
    logic        s_axil_awvalid;
    logic        s_axil_awready;
    logic [31:0] s_axil_wdata;
    logic [3:0]  s_axil_wstrb;
    logic        s_axil_wvalid;
    logic        s_axil_wready;
    logic [1:0]  s_axil_bresp;
    logic        s_axil_bvalid;
    logic        s_axil_bready;
    logic [7:0]  s_axil_araddr;
    logic        s_axil_arvalid;
    logic        s_axil_arready;
    logic [31:0] s_axil_rdata;
    logic [1:0]  s_axil_rresp;
    logic        s_axil_rvalid;
    logic        s_axil_rready;

    bldc_axi_controller dut (
        .clk_axi(clk_axi),
        .clk_motor(clk_motor),
        .rst_n(rst_n),
        .HA(HA),
        .HB(HB),
        .HC(HC),
        .AL(AL),
        .AH(AH),
        .BL(BL),
        .BH(BH),
        .CL(CL),
        .CH(CH),
        .irq(irq),
        .s_axil_awaddr(s_axil_awaddr),
        .s_axil_awvalid(s_axil_awvalid),
        .s_axil_awready(s_axil_awready),
        .s_axil_wdata(s_axil_wdata),
        .s_axil_wstrb(s_axil_wstrb),
        .s_axil_wvalid(s_axil_wvalid),
        .s_axil_wready(s_axil_wready),
        .s_axil_bresp(s_axil_bresp),
        .s_axil_bvalid(s_axil_bvalid),
        .s_axil_bready(s_axil_bready),
        .s_axil_araddr(s_axil_araddr),
        .s_axil_arvalid(s_axil_arvalid),
        .s_axil_arready(s_axil_arready),
        .s_axil_rdata(s_axil_rdata),
        .s_axil_rresp(s_axil_rresp),
        .s_axil_rvalid(s_axil_rvalid),
        .s_axil_rready(s_axil_rready)
    );

    initial begin
        clk_axi = 1'b0;
        forever #(AXI_CLK_PERIOD_NS/2.0) clk_axi = ~clk_axi;
    end

    initial begin
        clk_motor = 1'b0;
        forever #(MOTOR_CLK_PERIOD_NS/2.0) clk_motor = ~clk_motor;
    end

    task automatic fail(input string msg);
        begin
            $display("FAIL: %s", msg);
            $fatal(1);
        end
    endtask

    task automatic expect_equal(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string       msg
    );
        begin
            if (actual !== expected) begin
                $display("Expected 0x%08x, got 0x%08x", expected, actual);
                fail(msg);
            end
        end
    endtask

    task automatic axi_write(
        input logic [7:0]  addr,
        input logic [31:0] data
    );
        begin
            @(posedge clk_axi);
            s_axil_awaddr  <= addr;
            s_axil_awvalid <= 1'b1;
            s_axil_wdata   <= data;
            s_axil_wstrb   <= 4'hF;
            s_axil_wvalid  <= 1'b1;
            s_axil_bready  <= 1'b1;
            do begin
                @(posedge clk_axi);
            end while (!(s_axil_awready && s_axil_wready));
            s_axil_awvalid <= 1'b0;
            s_axil_wvalid  <= 1'b0;
            do begin
                @(posedge clk_axi);
            end while (!s_axil_bvalid);
            @(posedge clk_axi);
            s_axil_bready <= 1'b0;
        end
    endtask

    task automatic axi_read(
        input  logic [7:0]  addr,
        output logic [31:0] data
    );
        begin
            @(posedge clk_axi);
            s_axil_araddr  <= addr;
            s_axil_arvalid <= 1'b1;
            s_axil_rready  <= 1'b1;
            do begin
                @(posedge clk_axi);
            end while (!s_axil_arready);
            s_axil_arvalid <= 1'b0;
            do begin
                @(posedge clk_axi);
            end while (!s_axil_rvalid);
            data = s_axil_rdata;
            @(posedge clk_axi);
            s_axil_rready <= 1'b0;
        end
    endtask

    task automatic set_hall(input logic [2:0] hall_value);
        begin
            HA <= hall_value[0];
            HB <= hall_value[1];
            HC <= hall_value[2];
        end
    endtask

    task automatic wait_axi_cycles(input int cycles);
        repeat (cycles) @(posedge clk_axi);
    endtask

    task automatic wait_motor_cycles(input int cycles);
        repeat (cycles) @(posedge clk_motor);
    endtask

    task automatic wait_for_active_state(
        input logic [2:0] expected_state,
        input int         timeout_cycles,
        input string      msg
    );
        logic [31:0] status_word;
        int i;
        bit seen;
        begin
            seen = 1'b0;
            for (i = 0; i < timeout_cycles; i++) begin
                axi_read(ADDR_STATUS, status_word);
                if (status_word[10:8] == expected_state) begin
                    seen = 1'b1;
                    i = timeout_cycles;
                end
            end
            if (!seen) begin
                $display(
                    "STATUS timeout expected=%0d hall=%0d requested=%0d active=%0d deadtime=%0b pwm=%0b",
                    expected_state,
                    status_word[2:0],
                    status_word[6:4],
                    status_word[10:8],
                    status_word[11],
                    status_word[12]
                );
                fail(msg);
            end
        end
    endtask

    task automatic wait_for_irq_high(
        input int timeout_cycles,
        input string msg
    );
        int i;
        bit seen;
        begin
            seen = 1'b0;
            for (i = 0; i < timeout_cycles; i++) begin
                @(posedge clk_axi);
                if (irq) begin
                    seen = 1'b1;
                    i = timeout_cycles;
                end
            end
            if (!seen) begin
                fail(msg);
            end
        end
    endtask

    logic [31:0] rd_data;
    logic [31:0] status_word;
    logic [31:0] speed_status_1;
    logic [31:0] speed_status_2;
    bit          saw_same_low_deadtime;
    bit          saw_selective_deadtime;
    bit          saw_post_overlap_deadtime;
    bit          saw_pwm_high;
    bit          saw_pwm_low;

    initial begin
        rst_n          = 1'b0;
        HA             = 1'b0;
        HB             = 1'b0;
        HC             = 1'b0;
        s_axil_awaddr  = '0;
        s_axil_awvalid = 1'b0;
        s_axil_wdata   = '0;
        s_axil_wstrb   = '0;
        s_axil_wvalid  = 1'b0;
        s_axil_bready  = 1'b0;
        s_axil_araddr  = '0;
        s_axil_arvalid = 1'b0;
        s_axil_rready  = 1'b0;

        wait_axi_cycles(5);
        wait_motor_cycles(5);
        rst_n = 1'b1;
        wait_axi_cycles(5);
        wait_motor_cycles(5);

        axi_read(ADDR_ID, rd_data);
        expect_equal(rd_data, 32'h424C_4443, "ID register mismatch");

        axi_write(ADDR_PWM_CFG, {16'd695, 4'd0, 12'd2048});
        axi_write(ADDR_DEADTIME, {16'd0, 8'd10, 8'd20});
        axi_write(ADDR_COMM_CFG, 32'd1);
        axi_write(ADDR_CONTROL, 32'h0000_0001);

        wait_motor_cycles(24);
        if (BL !== 1'b1) begin
            fail("BL should be asserted in commutation state 1");
        end

        saw_pwm_high = 1'b0;
        saw_pwm_low  = 1'b0;
        repeat (500) begin
            @(posedge clk_motor);
            if (AH === 1'b1) saw_pwm_high = 1'b1;
            if (AH === 1'b0) saw_pwm_low  = 1'b1;
        end
        if (!saw_pwm_high) begin
            fail("AH never asserted during PWM");
        end
        if (!saw_pwm_low) begin
            fail("AH never deasserted during PWM");
        end

        axi_write(ADDR_COMM_CFG, 32'd2);
        wait_motor_cycles(24);
        if ((CL !== 1'b1) || (BL !== 1'b0)) begin
            fail("Manual commutation state 2 output mapping is wrong");
        end

        axi_write(ADDR_COMM_CFG, 32'd3);
        saw_same_low_deadtime = 1'b0;
        repeat (24) begin
            @(posedge clk_motor);
            if ((CL === 1'b1) && (AH === 1'b0) && (BH === 1'b0)) begin
                saw_same_low_deadtime = 1'b1;
            end
        end
        if (!saw_same_low_deadtime) begin
            fail("Deadtime should blank high sides while preserving the unchanged low side");
        end
        wait_motor_cycles(24);
        if (CL !== 1'b1) begin
            fail("Manual commutation state 3 should keep CL asserted");
        end
        if (BH !== 1'b1 && BH !== 1'b0) begin
            fail("BH should be a driven registered signal in state 3");
        end

        axi_write(ADDR_COMM_CFG, 32'd4);
        saw_selective_deadtime    = 1'b0;
        saw_post_overlap_deadtime = 1'b0;
        repeat (40) begin
            @(posedge clk_motor);
            if ((AL === 1'b1) && (CL === 1'b1) && (AH === 1'b0) && (BH === 1'b0) && (CH === 1'b0)) begin
                saw_selective_deadtime = 1'b1;
            end
            if ((AL === 1'b1) && (CL === 1'b0) && (AH === 1'b0) && (BH === 1'b0) && (CH === 1'b0)) begin
                saw_post_overlap_deadtime = 1'b1;
            end
        end
        if (!saw_selective_deadtime) begin
            fail("Low-side overlap phase missing when the low-side leg changes");
        end
        if (!saw_post_overlap_deadtime) begin
            fail("After overlap, only the new low side should remain on until deadtime ends");
        end
        wait_motor_cycles(24);
        if (AL !== 1'b1) begin
            fail("Manual commutation state 4 should drive AL high");
        end

        axi_write(ADDR_IRQ_MASK, 32'd0);
        set_hall(3'b001);
        wait_for_irq_high(32, "Hall edge interrupt did not assert");
        axi_read(ADDR_IRQ_STATUS, rd_data);
        expect_equal(rd_data[5:0], 6'b000001, "HA rising edge pending bit missing");
        axi_write(ADDR_IRQ_STATUS, 32'h0000_0001);
        wait_axi_cycles(4);
        if (irq) begin
            fail("IRQ should clear after W1C when FIFO is empty");
        end

        axi_write(ADDR_DEADTIME, {16'd0, 8'd0, 8'd1});
        axi_write(ADDR_CONTROL, 32'h0000_0003);

        set_hall(3'b101);
        wait_for_active_state(3'd2, 20, "Auto-commutation did not track hall 101");
        if (CL !== 1'b1) begin
            fail("State 2 should drive CL high");
        end

        set_hall(3'b100);
        wait_for_active_state(3'd3, 20, "Auto-commutation did not advance to state 3");
        if (CL !== 1'b1) begin
            fail("State 3 should keep CL high");
        end

        axi_write(ADDR_IRQ_MASK, 32'h0000_003F);
        axi_write(ADDR_CONTROL, 32'h0000_0001);
        axi_write(ADDR_MAIN_WINDOW, 32'd96);
        axi_write(ADDR_COMM_CFG, 32'd1);
        wait_motor_cycles(2);
        axi_write(ADDR_COMM_CFG, 32'd2);
        wait_motor_cycles(2);
        axi_write(ADDR_COMM_CFG, 32'd3);
        wait_motor_cycles(150);

        axi_read(ADDR_FIFO_STATUS, rd_data);
        if (rd_data[4:0] == 5'd0) begin
            fail("Transition FIFO should contain one entry after the window expires");
        end
        if (!irq) begin
            fail("FIFO not-empty interrupt did not assert");
        end

        axi_write(ADDR_MAIN_WINDOW, 32'd0);
        axi_read(ADDR_FIFO_DATA, rd_data);
        expect_equal(rd_data[15:0], 16'd3, "Transition FIFO count is wrong");
        axi_read(ADDR_FIFO_STATUS, rd_data);
        while (rd_data[4:0] != 5'd0) begin
            axi_read(ADDR_FIFO_DATA, rd_data);
            axi_read(ADDR_FIFO_STATUS, rd_data);
        end
        wait_axi_cycles(12);
        if (irq) begin
            fail("FIFO interrupt should deassert after draining the FIFO");
        end

        axi_write(ADDR_PWM_CFG, {16'd695, 4'd0, 12'd100});
        axi_write(ADDR_SPEED_TARGET, {4'd0, 12'd16, 16'd3});
        axi_write(ADDR_SPEED_WINDOW, 32'd400);
        axi_write(ADDR_CONTROL, 32'h0000_000B);

        set_hall(3'b001);
        wait_for_active_state(3'd1, 20, "Failed to seed auto-duty test in state 1");
        set_hall(3'b101);
        wait_for_active_state(3'd2, 20, "Expected one transition in first auto-duty window");
        wait_motor_cycles(450);
        axi_read(ADDR_SPEED_STATUS, speed_status_1);
        if (speed_status_1[11:0] <= 12'd100) begin
            fail("Auto-duty control should increase duty when rate is below target");
        end

        set_hall(3'b100);
        wait_for_active_state(3'd3, 20, "Missing transition 1 in second auto-duty window");
        set_hall(3'b110);
        wait_for_active_state(3'd4, 20, "Missing transition 2 in second auto-duty window");
        set_hall(3'b010);
        wait_for_active_state(3'd5, 20, "Missing transition 3 in second auto-duty window");
        set_hall(3'b011);
        wait_for_active_state(3'd6, 20, "Missing transition 4 in second auto-duty window");
        set_hall(3'b001);
        wait_for_active_state(3'd1, 20, "Missing transition 5 in second auto-duty window");
        wait_motor_cycles(450);
        axi_read(ADDR_SPEED_STATUS, speed_status_2);
        if (speed_status_2[11:0] >= speed_status_1[11:0]) begin
            fail("Auto-duty control should reduce duty when rate is above target");
        end
        if (speed_status_2[27:12] != 16'd5) begin
            fail("Auto-duty status should report the measured transition count");
        end

        $display("PASS");
        $finish;
    end

endmodule
