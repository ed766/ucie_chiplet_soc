`ifndef CHIPLET_UVM_IF_SV
`define CHIPLET_UVM_IF_SV

`include "tb_params.svh"

interface chiplet_csr_if(input logic clk);
    logic        cfg_valid;
    logic        cfg_write;
    logic [7:0]  cfg_addr;
    logic [31:0] cfg_wdata;
    logic [31:0] cfg_rdata;
    logic        cfg_ready;

    task automatic init();
        cfg_valid = 1'b0;
        cfg_write = 1'b0;
        cfg_addr  = '0;
        cfg_wdata = '0;
    endtask

    task automatic write32(input logic [7:0] addr, input logic [31:0] data);
        #10;
        cfg_valid <= 1'b1;
        cfg_write <= 1'b1;
        cfg_addr  <= addr;
        cfg_wdata <= data;
        do begin
            #10;
        end while (!cfg_ready);
        cfg_valid <= 1'b0;
        cfg_write <= 1'b0;
        cfg_addr  <= '0;
        cfg_wdata <= '0;
    endtask

    task automatic read32(input logic [7:0] addr, output logic [31:0] data);
        #10;
        cfg_valid <= 1'b1;
        cfg_write <= 1'b0;
        cfg_addr  <= addr;
        cfg_wdata <= '0;
        do begin
            #10;
        end while (!cfg_ready);
        data = cfg_rdata;
        cfg_valid <= 1'b0;
        cfg_addr  <= '0;
    endtask
endinterface : chiplet_csr_if

interface chiplet_power_if(input logic clk);
    logic       rst_n;
    logic [1:0] power_state;
    logic       dma_mode_force;
    logic       sw_pd_a_traffic;
    logic       sw_pd_a_dma;
    logic       sw_pd_a_link;
    logic       sw_pd_b_crypto;
    logic       sw_pd_b_link;
    logic       sw_pd_channel;
    logic       iso_pd_a_traffic_n;
    logic       iso_pd_a_dma_n;
    logic       iso_pd_a_link_n;
    logic       iso_pd_b_crypto_n;
    logic       iso_pd_b_link_n;
    logic       iso_pd_channel_n;
    logic       save_dma_sleep;
    logic       restore_dma_sleep;
    logic       save_dma_mem;
    logic       restore_dma_mem;

    task automatic init();
        rst_n = 1'b0;
        power_state = 2'd0;
        dma_mode_force = 1'b0;
    endtask

    task automatic apply_reset(input int unsigned cycles = 8);
        rst_n <= 1'b0;
        repeat (cycles) #10;
        rst_n <= 1'b1;
    endtask

    task automatic set_power_state(input logic [1:0] state);
        #10;
        power_state <= state;
    endtask
endinterface : chiplet_power_if

interface ucie_stream_if(input logic clk);
    logic rst_n;
    logic [`TB_FLIT_WIDTH-1:0] a_tx_data;
    logic                     a_tx_valid;
    logic                     a_tx_ready;
    logic [`TB_FLIT_WIDTH-1:0] b_tx_data;
    logic                     b_tx_valid;
    logic                     b_tx_ready;
    logic [`TB_FLIT_WIDTH-1:0] a_rx_data;
    logic                     a_rx_valid;
    logic [`TB_FLIT_WIDTH-1:0] b_rx_data;
    logic                     b_rx_valid;
endinterface : ucie_stream_if

interface chiplet_obs_if(input logic clk);
    logic        rst_n;
    logic [63:0] plaintext_monitor;
    logic [63:0] ciphertext_monitor;
    logic [63:0] die_b_ciphertext_monitor;
    logic        crypto_error_flag;
    logic        dma_busy_monitor;
    logic        dma_done_monitor;
    logic        dma_error_monitor;
    logic        irq_done_monitor;
    logic [15:0] dma_tag_monitor;
endinterface : chiplet_obs_if

`endif
