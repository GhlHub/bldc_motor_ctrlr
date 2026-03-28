module bldc_axi_controller #(
    parameter int AXIL_ADDR_WIDTH = 8
) (
    input  logic                        clk_axi,
    input  logic                        clk_motor,
    input  logic                        rst_axi_n,
    input  logic                        rst_motor_n,
    input  logic                        HA,
    input  logic                        HB,
    input  logic                        HC,
    output logic                        AL,
    output logic                        AH,
    output logic                        BL,
    output logic                        BH,
    output logic                        CL,
    output logic                        CH,
    output logic                        irq,
    input  logic [AXIL_ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  logic                        s_axil_awvalid,
    output logic                        s_axil_awready,
    input  logic [31:0]                 s_axil_wdata,
    input  logic [3:0]                  s_axil_wstrb,
    input  logic                        s_axil_wvalid,
    output logic                        s_axil_wready,
    output logic [1:0]                  s_axil_bresp,
    output logic                        s_axil_bvalid,
    input  logic                        s_axil_bready,
    input  logic [AXIL_ADDR_WIDTH-1:0]  s_axil_araddr,
    input  logic                        s_axil_arvalid,
    output logic                        s_axil_arready,
    output logic [31:0]                 s_axil_rdata,
    output logic [1:0]                  s_axil_rresp,
    output logic                        s_axil_rvalid,
    input  logic                        s_axil_rready
);

    logic [7:0]  cmd_addr_async;
    logic [31:0] cmd_wdata_async;
    logic [3:0]  cmd_wstrb_async;
    logic        cmd_write_async;
    logic        cmd_req_toggle_async;

    logic [31:0] rsp_rdata_async;
    logic        rsp_toggle_async;
    logic        irq_motor;
    logic        irq_meta_axi;

    bldc_axi_slave #(
        .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH)
    ) u_axi_slave (
        .clk_axi(clk_axi),
        .rst_n(rst_axi_n),
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
        .s_axil_rready(s_axil_rready),
        .cmd_addr_async(cmd_addr_async),
        .cmd_wdata_async(cmd_wdata_async),
        .cmd_wstrb_async(cmd_wstrb_async),
        .cmd_write_async(cmd_write_async),
        .cmd_req_toggle_async(cmd_req_toggle_async),
        .rsp_rdata_async(rsp_rdata_async),
        .rsp_toggle_async(rsp_toggle_async)
    );

    bldc_motor_ctrl_domain u_motor_ctrl_domain (
        .clk_motor(clk_motor),
        .rst_n(rst_motor_n),
        .HA(HA),
        .HB(HB),
        .HC(HC),
        .AL(AL),
        .AH(AH),
        .BL(BL),
        .BH(BH),
        .CL(CL),
        .CH(CH),
        .irq_motor(irq_motor),
        .cmd_addr_async(cmd_addr_async),
        .cmd_wdata_async(cmd_wdata_async),
        .cmd_wstrb_async(cmd_wstrb_async),
        .cmd_write_async(cmd_write_async),
        .cmd_req_toggle_async(cmd_req_toggle_async),
        .rsp_rdata_async(rsp_rdata_async),
        .rsp_toggle_async(rsp_toggle_async)
    );

    always_ff @(posedge clk_axi) begin
        if (!rst_axi_n) begin
            irq_meta_axi <= 1'b0;
            irq          <= 1'b0;
        end else begin
            irq_meta_axi <= irq_motor;
            irq          <= irq_meta_axi;
        end
    end

endmodule

