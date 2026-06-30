// AXI-Lite to simple CSR bridge.
// Role: expose the existing single-cycle cfg_* register interface through a
// standard single-beat AXI-Lite control surface for SoC integration demos.
module axi_lite_csr_bridge #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter logic [7:0] VALID_ADDR_MAX = 8'h84
) (
    input  logic                  aclk,
    input  logic                  aresetn,

    input  logic [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic                  s_axi_awvalid,
    output logic                  s_axi_awready,
    input  logic [DATA_WIDTH-1:0] s_axi_wdata,
    input  logic [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  logic                  s_axi_wvalid,
    output logic                  s_axi_wready,
    output logic [1:0]            s_axi_bresp,
    output logic                  s_axi_bvalid,
    input  logic                  s_axi_bready,

    input  logic [ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic                  s_axi_arvalid,
    output logic                  s_axi_arready,
    output logic [DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]            s_axi_rresp,
    output logic                  s_axi_rvalid,
    input  logic                  s_axi_rready,

    output logic                  cfg_valid,
    output logic                  cfg_write,
    output logic [7:0]            cfg_addr,
    output logic [31:0]           cfg_wdata,
    input  logic [31:0]           cfg_rdata,
    input  logic                  cfg_ready
);

    localparam logic [1:0] RESP_OKAY  = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    logic [ADDR_WIDTH-1:0] awaddr_q;
    logic [DATA_WIDTH-1:0] wdata_q;
    logic [(DATA_WIDTH/8)-1:0] wstrb_q;
    logic [ADDR_WIDTH-1:0] araddr_q;
    logic aw_pending_q;
    logic w_pending_q;
    logic ar_pending_q;
    logic accept_aw;
    logic accept_w;
    logic have_aw;
    logic have_w;
    logic have_ar;
    logic write_fire;
    logic read_fire;
    logic write_complete;
    logic read_complete;
    logic write_addr_ok;
    logic read_addr_ok;
    logic [ADDR_WIDTH-1:0] write_addr;
    logic [ADDR_WIDTH-1:0] read_addr;
    logic [DATA_WIDTH-1:0] write_data;
    logic [(DATA_WIDTH/8)-1:0] write_strb;

    function automatic logic addr_is_valid(input logic [ADDR_WIDTH-1:0] addr);
        addr_is_valid = (addr[1:0] == 2'b00) &&
                        (addr[ADDR_WIDTH-1:8] == '0) &&
                        (addr[7:0] <= VALID_ADDR_MAX);
    endfunction

    assign s_axi_awready = !aw_pending_q && !s_axi_bvalid;
    assign s_axi_wready = !w_pending_q && !s_axi_bvalid;
    assign s_axi_arready = !ar_pending_q && !s_axi_rvalid && !(aw_pending_q && w_pending_q);

    assign accept_aw = s_axi_awvalid && s_axi_awready;
    assign accept_w = s_axi_wvalid && s_axi_wready;
    assign have_aw = aw_pending_q || accept_aw;
    assign have_w = w_pending_q || accept_w;
    assign have_ar = ar_pending_q || read_fire;
    assign write_addr = aw_pending_q ? awaddr_q : s_axi_awaddr;
    assign write_data = w_pending_q ? wdata_q : s_axi_wdata;
    assign write_strb = w_pending_q ? wstrb_q : s_axi_wstrb;
    assign read_addr = ar_pending_q ? araddr_q : s_axi_araddr;
    assign write_fire = have_aw && have_w && !s_axi_bvalid;
    assign read_fire = s_axi_arvalid && s_axi_arready;
    assign write_addr_ok = addr_is_valid(write_addr);
    assign read_addr_ok = addr_is_valid(read_addr);
    assign write_complete = write_fire && (!write_addr_ok || cfg_ready);
    assign read_complete = have_ar && !s_axi_rvalid && (!read_addr_ok || cfg_ready);

    assign cfg_valid = (write_fire && write_addr_ok && (write_strb == '1)) ||
                       (have_ar && read_addr_ok && !s_axi_rvalid);
    assign cfg_write = write_fire && write_addr_ok && (write_strb == '1);
    assign cfg_addr = write_fire ? write_addr[7:0] : read_addr[7:0];
    assign cfg_wdata = write_data;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            awaddr_q <= '0;
            wdata_q <= '0;
            wstrb_q <= '0;
            araddr_q <= '0;
            aw_pending_q <= 1'b0;
            w_pending_q <= 1'b0;
            ar_pending_q <= 1'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_bresp <= RESP_OKAY;
            s_axi_rvalid <= 1'b0;
            s_axi_rresp <= RESP_OKAY;
            s_axi_rdata <= '0;
        end else begin
            if (accept_aw && !(write_complete && !aw_pending_q)) begin
                awaddr_q <= s_axi_awaddr;
                aw_pending_q <= 1'b1;
            end
            if (accept_w && !(write_complete && !w_pending_q)) begin
                wdata_q <= s_axi_wdata;
                wstrb_q <= s_axi_wstrb;
                w_pending_q <= 1'b1;
            end

            if (write_complete) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp <= (write_addr_ok && (write_strb == '1)) ? RESP_OKAY : RESP_SLVERR;
                aw_pending_q <= 1'b0;
                w_pending_q <= 1'b0;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
                s_axi_bresp <= RESP_OKAY;
            end

            if (read_fire && !read_complete) begin
                araddr_q <= s_axi_araddr;
                ar_pending_q <= 1'b1;
            end

            if (read_complete) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp <= read_addr_ok ? RESP_OKAY : RESP_SLVERR;
                s_axi_rdata <= read_addr_ok ? cfg_rdata : '0;
                ar_pending_q <= 1'b0;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
                s_axi_rresp <= RESP_OKAY;
                s_axi_rdata <= '0;
            end
        end
    end

endmodule : axi_lite_csr_bridge
