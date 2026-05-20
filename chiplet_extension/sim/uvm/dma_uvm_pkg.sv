`ifndef DMA_UVM_PKG_SV
`define DMA_UVM_PKG_SV

package dma_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    typedef enum int unsigned {
        DMA_CSR_WRITE = 0,
        DMA_CSR_READ  = 1,
        DMA_WAIT_IRQ  = 2
    } dma_op_e;

    typedef enum int unsigned {
        DMA_EVENT_DONE  = 0,
        DMA_EVENT_ERROR = 1,
        DMA_EVENT_IRQ   = 2
    } dma_event_e;

    localparam bit [7:0] DMA_UVM_CTRL_ADDR   = 8'h00;
    localparam bit [7:0] DMA_UVM_SRC_ADDR    = 8'h08;
    localparam bit [7:0] DMA_UVM_DST_ADDR    = 8'h0c;
    localparam bit [7:0] DMA_UVM_LEN_ADDR    = 8'h10;
    localparam bit [7:0] DMA_UVM_TAG_ADDR    = 8'h14;
    localparam bit [7:0] DMA_UVM_IRQ_EN_ADDR = 8'h18;

    virtual chiplet_csr_if g_csr_vif;
    virtual chiplet_obs_if g_obs_vif;
    int unsigned g_done_events;
    int unsigned g_error_events;
    int unsigned g_irq_events;

    class dma_csr_item extends uvm_sequence_item;
        rand dma_op_e op;
        rand bit [7:0] addr;
        rand bit [31:0] wdata;
        bit [31:0] rdata;
        int unsigned timeout_cycles;

        `uvm_object_utils(dma_csr_item)

        function new(string name = "dma_csr_item");
            super.new(name);
            timeout_cycles = 4096;
        endfunction
    endclass

    class dma_event_item extends uvm_sequence_item;
        dma_event_e kind;
        bit [15:0] tag;

        `uvm_object_utils(dma_event_item)

        function new(string name = "dma_event_item");
            super.new(name);
        endfunction
    endclass

    class dma_sequencer extends uvm_sequencer #(dma_csr_item);
        `uvm_component_utils(dma_sequencer)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
    endclass

    class dma_csr_driver extends uvm_driver #(dma_csr_item);
        `uvm_component_utils(dma_csr_driver)

        virtual chiplet_csr_if csr_vif;
        virtual chiplet_obs_if obs_vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            csr_vif = g_csr_vif;
            obs_vif = g_obs_vif;
            if (csr_vif == null) begin
                `uvm_fatal(get_type_name(), "Missing virtual interface chiplet_csr_if")
            end
            if (obs_vif == null) begin
                `uvm_fatal(get_type_name(), "Missing virtual interface chiplet_obs_if")
            end
        endfunction

        task run_phase(uvm_phase phase);
            dma_csr_item item;
            forever begin
                seq_item_port.get_next_item(item);
                case (item.op)
                    DMA_CSR_WRITE: csr_vif.write32(item.addr, item.wdata);
                    DMA_CSR_READ:  csr_vif.read32(item.addr, item.rdata);
                    DMA_WAIT_IRQ:  wait_irq(item.timeout_cycles);
                    default: `uvm_error(get_type_name(), "Unsupported DMA CSR operation")
                endcase
                seq_item_port.item_done();
            end
        endtask

        task wait_irq(input int unsigned timeout_cycles);
            int unsigned waited;
            waited = 0;
            while (!obs_vif.irq_done_monitor && waited < timeout_cycles) begin
                waited++;
                #10;
            end
            if (!obs_vif.irq_done_monitor) begin
                `uvm_error(get_type_name(), $sformatf("Timed out waiting for DMA IRQ after %0d cycles", timeout_cycles))
            end
        endtask
    endclass

    class dma_monitor extends uvm_monitor;
        `uvm_component_utils(dma_monitor)

        virtual chiplet_obs_if obs_vif;
`ifndef VERILATOR
        uvm_analysis_port #(dma_event_item) ap;
`endif
        bit last_done;
        bit last_error;
        bit last_irq;

        function new(string name, uvm_component parent);
            super.new(name, parent);
`ifndef VERILATOR
            ap = new("ap", this);
`endif
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            obs_vif = g_obs_vif;
            if (obs_vif == null) begin
                `uvm_fatal(get_type_name(), "Missing virtual interface chiplet_obs_if")
            end
        endfunction

        task run_phase(uvm_phase phase);
            forever begin
                #10;
                if (!obs_vif.rst_n) begin
                    last_done = 1'b0;
                    last_error = 1'b0;
                    last_irq = 1'b0;
                end else begin
                    emit_edge(DMA_EVENT_DONE, obs_vif.dma_done_monitor, last_done);
                    emit_edge(DMA_EVENT_ERROR, obs_vif.dma_error_monitor, last_error);
                    emit_edge(DMA_EVENT_IRQ, obs_vif.irq_done_monitor, last_irq);
                    last_done = obs_vif.dma_done_monitor;
                    last_error = obs_vif.dma_error_monitor;
                    last_irq = obs_vif.irq_done_monitor;
                end
            end
        endtask

        function void emit_edge(dma_event_e event_kind, bit value, bit last_value);
            dma_event_item item;
            if (value && !last_value) begin
                item = dma_event_item::type_id::create("item");
                item.kind = event_kind;
                item.tag = obs_vif.dma_tag_monitor;
                case (event_kind)
                    DMA_EVENT_DONE:  g_done_events++;
                    DMA_EVENT_ERROR: g_error_events++;
                    DMA_EVENT_IRQ:   g_irq_events++;
                    default: ;
                endcase
`ifndef VERILATOR
                ap.write(item);
`endif
            end
        endfunction
    endclass

    class dma_agent extends uvm_agent;
        `uvm_component_utils(dma_agent)

        dma_sequencer sequencer;
        dma_csr_driver driver;
        dma_monitor monitor;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
`ifndef VERILATOR
            sequencer = dma_sequencer::type_id::create("sequencer", this);
            driver = dma_csr_driver::type_id::create("driver", this);
`endif
            monitor = dma_monitor::type_id::create("monitor", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
`ifndef VERILATOR
            driver.seq_item_port.connect(sequencer.seq_item_export);
`endif
        endfunction
    endclass

    class dma_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(dma_scoreboard)

        uvm_analysis_imp #(dma_event_item, dma_scoreboard) analysis_export;
        int unsigned done_events;
        int unsigned error_events;
        int unsigned irq_events;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            analysis_export = new("analysis_export", this);
        endfunction

        function void write(dma_event_item t);
            case (t.kind)
                DMA_EVENT_DONE:  done_events++;
                DMA_EVENT_ERROR: error_events++;
                DMA_EVENT_IRQ:   irq_events++;
                default: ;
            endcase
        endfunction

        function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info(get_type_name(),
                      $sformatf("DMA events done=%0d error=%0d irq=%0d",
                                done_events, error_events, irq_events),
                      UVM_LOW)
        endfunction
    endclass

    class dma_queue_smoke_sequence extends uvm_sequence #(dma_csr_item);
        `uvm_object_utils(dma_queue_smoke_sequence)

        function new(string name = "dma_queue_smoke_sequence");
            super.new(name);
        endfunction

        task body();
            write_reg(DMA_UVM_IRQ_EN_ADDR, 32'h1);
            write_reg(DMA_UVM_SRC_ADDR, 32'd0);
            write_reg(DMA_UVM_DST_ADDR, 32'd32);
            write_reg(DMA_UVM_LEN_ADDR, 32'd4);
            write_reg(DMA_UVM_TAG_ADDR, 32'h5001);
            write_reg(DMA_UVM_CTRL_ADDR, 32'h1);
            wait_irq(4096);
        endtask

        task write_reg(bit [7:0] addr, bit [31:0] data);
            dma_csr_item item;
            item = dma_csr_item::type_id::create("write_item");
            start_item(item);
            item.op = DMA_CSR_WRITE;
            item.addr = addr;
            item.wdata = data;
            finish_item(item);
        endtask

        task wait_irq(int unsigned timeout_cycles);
            dma_csr_item item;
            item = dma_csr_item::type_id::create("wait_irq_item");
            start_item(item);
            item.op = DMA_WAIT_IRQ;
            item.timeout_cycles = timeout_cycles;
            finish_item(item);
        endtask
    endclass
endpackage

`endif
