module bldc_axi_slave #(
    parameter int AXIL_ADDR_WIDTH = 8
) (
    input  logic                        clk_axi,
    input  logic                        rst_n,
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
    input  logic                        s_axil_rready,
    output logic [7:0]                  cmd_addr_async,
    output logic [31:0]                 cmd_wdata_async,
    output logic [3:0]                  cmd_wstrb_async,
    output logic                        cmd_write_async,
    output logic                        cmd_req_toggle_async,
    input  logic [31:0]                 rsp_rdata_async,
    input  logic                        rsp_toggle_async
);

    logic [AXIL_ADDR_WIDTH-1:0] awaddr_latched;
    logic [31:0]                wdata_latched;
    logic [3:0]                 wstrb_latched;
    logic                       aw_pending;
    logic                       w_pending;
    logic [AXIL_ADDR_WIDTH-1:0] araddr_latched;
    logic                       ar_pending;
    logic                       txn_busy;
    logic                       txn_is_read;
    logic                       rsp_toggle_meta;
    logic                       rsp_toggle_sync;
    logic                       rsp_toggle_sync_d;

    assign s_axil_awready = !aw_pending;
    assign s_axil_wready  = !w_pending;
    assign s_axil_arready = !ar_pending;
    assign s_axil_bresp   = 2'b00;
    assign s_axil_rresp   = 2'b00;

    always_ff @(posedge clk_axi) begin
        logic rsp_edge;

        if (!rst_n) begin
            awaddr_latched      <= '0;
            wdata_latched       <= 32'd0;
            wstrb_latched       <= 4'd0;
            aw_pending          <= 1'b0;
            w_pending           <= 1'b0;
            araddr_latched      <= '0;
            ar_pending          <= 1'b0;
            txn_busy            <= 1'b0;
            txn_is_read         <= 1'b0;
            cmd_addr_async      <= 8'd0;
            cmd_wdata_async     <= 32'd0;
            cmd_wstrb_async     <= 4'd0;
            cmd_write_async     <= 1'b0;
            cmd_req_toggle_async <= 1'b0;
            rsp_toggle_meta     <= 1'b0;
            rsp_toggle_sync     <= 1'b0;
            rsp_toggle_sync_d   <= 1'b0;
            s_axil_bvalid       <= 1'b0;
            s_axil_rvalid       <= 1'b0;
            s_axil_rdata        <= 32'd0;
        end else begin
            rsp_toggle_meta   <= rsp_toggle_async;
            rsp_toggle_sync   <= rsp_toggle_meta;
            rsp_toggle_sync_d <= rsp_toggle_sync;
            rsp_edge          = rsp_toggle_sync ^ rsp_toggle_sync_d;

            if (!aw_pending && s_axil_awvalid) begin
                awaddr_latched <= s_axil_awaddr;
                aw_pending     <= 1'b1;
            end

            if (!w_pending && s_axil_wvalid) begin
                wdata_latched <= s_axil_wdata;
                wstrb_latched <= s_axil_wstrb;
                w_pending     <= 1'b1;
            end

            if (!ar_pending && s_axil_arvalid) begin
                araddr_latched <= s_axil_araddr;
                ar_pending     <= 1'b1;
            end

            if (s_axil_bvalid && s_axil_bready) begin
                s_axil_bvalid <= 1'b0;
            end

            if (s_axil_rvalid && s_axil_rready) begin
                s_axil_rvalid <= 1'b0;
            end

            if (rsp_edge && txn_busy) begin
                txn_busy <= 1'b0;
                if (txn_is_read) begin
                    s_axil_rdata  <= rsp_rdata_async;
                    s_axil_rvalid <= 1'b1;
                end else begin
                    s_axil_bvalid <= 1'b1;
                end
            end

            if (!txn_busy) begin
                if (aw_pending && w_pending && !s_axil_bvalid) begin
                    cmd_addr_async       <= awaddr_latched[7:0];
                    cmd_wdata_async      <= wdata_latched;
                    cmd_wstrb_async      <= wstrb_latched;
                    cmd_write_async      <= 1'b1;
                    cmd_req_toggle_async <= ~cmd_req_toggle_async;
                    txn_busy             <= 1'b1;
                    txn_is_read          <= 1'b0;
                    aw_pending           <= 1'b0;
                    w_pending            <= 1'b0;
                end else if (ar_pending && !s_axil_rvalid) begin
                    cmd_addr_async       <= araddr_latched[7:0];
                    cmd_wdata_async      <= 32'd0;
                    cmd_wstrb_async      <= 4'd0;
                    cmd_write_async      <= 1'b0;
                    cmd_req_toggle_async <= ~cmd_req_toggle_async;
                    txn_busy             <= 1'b1;
                    txn_is_read          <= 1'b1;
                    ar_pending           <= 1'b0;
                end
            end
        end
    end

endmodule
