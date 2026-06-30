`ifndef AXI_LITE_RAL_PKG_SV
`define AXI_LITE_RAL_PKG_SV

package axi_lite_ral_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    localparam bit [31:0] CSR_DMA_CTRL          = 32'h00;
    localparam bit [31:0] CSR_DMA_SRC_BASE      = 32'h08;
    localparam bit [31:0] CSR_DMA_DST_BASE      = 32'h0c;
    localparam bit [31:0] CSR_DMA_LEN           = 32'h10;
    localparam bit [31:0] CSR_DMA_TAG           = 32'h14;
    localparam bit [31:0] CSR_DMA_IRQ_EN        = 32'h18;
    localparam bit [31:0] CSR_DMA_SUBMIT_STATUS = 32'h30;
    localparam bit [31:0] CSR_DMA_SUBMIT_RESULT = 32'h50;
    localparam bit [31:0] CSR_MEM_OP_CTRL       = 32'h58;
    localparam bit [31:0] CSR_MEM_OP_STATUS     = 32'h5c;
    localparam bit [31:0] CSR_RET_CFG           = 32'h68;
    localparam bit [31:0] CSR_RET_VALID_STATUS  = 32'h70;
    localparam bit [31:0] CSR_MEM_INJECT_CTRL   = 32'h80;
    localparam bit [31:0] CSR_MEM_INJECT_STATUS = 32'h84;

    virtual axi_lite_uvm_if g_axi_lite_vif;

    class axi_lite_bus_item extends uvm_sequence_item;
        rand bit        write;
        rand bit [31:0] addr;
        rand bit [31:0] data;
        rand bit [3:0]  strb;
        bit [31:0]      rdata;
        bit [1:0]       resp;

        `uvm_object_utils(axi_lite_bus_item)

        function new(string name = "axi_lite_bus_item");
            super.new(name);
            strb = 4'hf;
        endfunction
    endclass

    class axi_lite_ral_sequencer extends uvm_sequencer #(axi_lite_bus_item);
        `uvm_component_utils(axi_lite_ral_sequencer)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
    endclass

    class axi_lite_ral_driver extends uvm_driver #(axi_lite_bus_item);
        `uvm_component_utils(axi_lite_ral_driver)

        virtual axi_lite_uvm_if vif;
        uvm_analysis_port #(axi_lite_bus_item) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            vif = g_axi_lite_vif;
            if (vif == null) begin
                `uvm_fatal(get_type_name(), "Missing virtual interface axi_lite_uvm_if")
            end
        endfunction

        task run_phase(uvm_phase phase);
            axi_lite_bus_item item;
            forever begin
                seq_item_port.get_next_item(item);
                if (item.write) begin
                    vif.write32(item.addr, item.data, item.resp);
                end else begin
                    vif.read32(item.addr, item.rdata, item.resp);
                end
                ap.write(item);
                seq_item_port.item_done();
            end
        endtask
    endclass

    class axi_lite_ral_adapter extends uvm_reg_adapter;
        `uvm_object_utils(axi_lite_ral_adapter)

        function new(string name = "axi_lite_ral_adapter");
            super.new(name);
            supports_byte_enable = 1;
            provides_responses = 1;
        endfunction

        virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
            axi_lite_bus_item item;
            item = axi_lite_bus_item::type_id::create("axi_lite_bus_item");
            item.write = (rw.kind == UVM_WRITE);
            item.addr = rw.addr;
            item.data = rw.data;
            item.strb = (rw.byte_en == 0) ? 4'hf : rw.byte_en[3:0];
            return item;
        endfunction

        virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
            axi_lite_bus_item item;
            if (!$cast(item, bus_item)) begin
                `uvm_fatal(get_type_name(), "bus_item is not axi_lite_bus_item")
            end
            rw.kind = item.write ? UVM_WRITE : UVM_READ;
            rw.addr = item.addr;
            rw.data = item.write ? item.data : item.rdata;
            rw.byte_en = item.strb;
            rw.status = (item.resp == 2'b00) ? UVM_IS_OK : UVM_NOT_OK;
        endfunction
    endclass

    class dma_csr_reg extends uvm_reg;
        `uvm_object_utils(dma_csr_reg)

        uvm_reg_field value;

        function new(string name = "dma_csr_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build(string access = "RW", bit [31:0] reset_value = 32'h0);
            value = uvm_reg_field::type_id::create("value");
            value.configure(this, 32, 0, access, 0, reset_value, 1, 1, 0);
        endfunction
    endclass

    class dma_csr_ral_block extends uvm_reg_block;
        `uvm_object_utils(dma_csr_ral_block)

        dma_csr_reg dma_ctrl;
        dma_csr_reg dma_src_base;
        dma_csr_reg dma_dst_base;
        dma_csr_reg dma_len;
        dma_csr_reg dma_tag;
        dma_csr_reg dma_irq_en;
        dma_csr_reg dma_submit_status;
        dma_csr_reg dma_submit_result;
        dma_csr_reg mem_op_ctrl;
        dma_csr_reg mem_op_status;
        dma_csr_reg ret_cfg;
        dma_csr_reg ret_valid_status;
        dma_csr_reg mem_inject_ctrl;
        dma_csr_reg mem_inject_status;

        function new(string name = "dma_csr_ral_block");
            super.new(name, UVM_NO_COVERAGE);
        endfunction

        virtual function dma_csr_reg make_reg(string name, string access);
            dma_csr_reg reg_h;
            reg_h = dma_csr_reg::type_id::create(name);
            reg_h.configure(this, null, "");
            reg_h.build(access);
            return reg_h;
        endfunction

        virtual function void build();
            default_map = create_map("axi_lite_map", 0, 4, UVM_LITTLE_ENDIAN, 1);

            dma_ctrl = make_reg("dma_ctrl", "RW");
            dma_src_base = make_reg("dma_src_base", "RW");
            dma_dst_base = make_reg("dma_dst_base", "RW");
            dma_len = make_reg("dma_len", "RW");
            dma_tag = make_reg("dma_tag", "RW");
            dma_irq_en = make_reg("dma_irq_en", "RW");
            dma_submit_status = make_reg("dma_submit_status", "RO");
            dma_submit_result = make_reg("dma_submit_result", "RO");
            mem_op_ctrl = make_reg("mem_op_ctrl", "RW");
            mem_op_status = make_reg("mem_op_status", "RO");
            ret_cfg = make_reg("ret_cfg", "RW");
            ret_valid_status = make_reg("ret_valid_status", "RO");
            mem_inject_ctrl = make_reg("mem_inject_ctrl", "RW");
            mem_inject_status = make_reg("mem_inject_status", "RO");

            default_map.add_reg(dma_ctrl, CSR_DMA_CTRL, "RW");
            default_map.add_reg(dma_src_base, CSR_DMA_SRC_BASE, "RW");
            default_map.add_reg(dma_dst_base, CSR_DMA_DST_BASE, "RW");
            default_map.add_reg(dma_len, CSR_DMA_LEN, "RW");
            default_map.add_reg(dma_tag, CSR_DMA_TAG, "RW");
            default_map.add_reg(dma_irq_en, CSR_DMA_IRQ_EN, "RW");
            default_map.add_reg(dma_submit_status, CSR_DMA_SUBMIT_STATUS, "RO");
            default_map.add_reg(dma_submit_result, CSR_DMA_SUBMIT_RESULT, "RO");
            default_map.add_reg(mem_op_ctrl, CSR_MEM_OP_CTRL, "RW");
            default_map.add_reg(mem_op_status, CSR_MEM_OP_STATUS, "RO");
            default_map.add_reg(ret_cfg, CSR_RET_CFG, "RW");
            default_map.add_reg(ret_valid_status, CSR_RET_VALID_STATUS, "RO");
            default_map.add_reg(mem_inject_ctrl, CSR_MEM_INJECT_CTRL, "RW");
            default_map.add_reg(mem_inject_status, CSR_MEM_INJECT_STATUS, "RO");
            lock_model();
        endfunction
    endclass

    class axi_lite_ral_env extends uvm_env;
        `uvm_component_utils(axi_lite_ral_env)

        axi_lite_ral_sequencer sequencer;
        axi_lite_ral_driver driver;
        axi_lite_ral_adapter adapter;
        uvm_reg_predictor #(axi_lite_bus_item) predictor;
        dma_csr_ral_block reg_model;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sequencer = axi_lite_ral_sequencer::type_id::create("sequencer", this);
            driver = axi_lite_ral_driver::type_id::create("driver", this);
            adapter = axi_lite_ral_adapter::type_id::create("adapter");
            predictor = uvm_reg_predictor #(axi_lite_bus_item)::type_id::create("predictor", this);
            reg_model = dma_csr_ral_block::type_id::create("reg_model");
            reg_model.build();
            reg_model.default_map.set_sequencer(sequencer, adapter);
            predictor.map = reg_model.default_map;
            predictor.adapter = adapter;
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
            driver.ap.connect(predictor.bus_in);
        endfunction
    endclass
endpackage : axi_lite_ral_pkg

`endif
