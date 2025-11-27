class axi_read_driver #(
        parameter ADDR_WIDTH = 16,
        parameter DATA_WIDTH = 32,
        parameter LEN_WIDTH = 8,
        parameter SIZE_WIDTH = 3,
        parameter BURST_WIDTH = 2,
        parameter RESP_WIDTH = 2,
        parameter ID_WIDTH = 4,
        parameter STROBE_WIDTH = DATA_WIDTH/8,
        parameter ADDR_BYTE_SIZE = 1
    ) extends uvm_driver #(axi_read_trans #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE))
        );

    `uvm_component_param_utils(axi_read_driver #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ))

    virtual axi_if.drv_mp vif;

    uvm_analysis_port #(
        axi_read_trans #(
            .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
            .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
            .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
        )
        ) rd_drv_ap;

    logic [LEN_WIDTH+1:0] num_beats; // Must be LEN_WIDTH+1 bits wide
    reg [ADDR_WIDTH-1:0] current_ar_addr;
    real num_bytes_addr_store = ADDR_BYTE_SIZE;

    function new(string name = "axi_read_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        rd_drv_ap = new("rd_drv_ap", this);

        if(!uvm_config_db#(virtual axi_if.drv_mp)::get(this, "", "vif", vif)) begin
            `uvm_error(get_type_name(), "Virtual interface (drv_mp) not found in config db")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        axi_read_trans rd_tr;

        // initialize interface signals
        init_read(rd_tr);

        forever begin
            seq_item_port.get_next_item(rd_tr);
            send_read(rd_tr);
            seq_item_port.item_done();
        end
    endtask

    virtual task send_read(axi_read_trans rd_tr);

        `uvm_info(get_type_name(), $sformatf("Starting READ Burst from addr = 0x%h, LEN = %0d", rd_tr.axi_tb_ADDR, rd_tr.axi_tb_LEN), UVM_MEDIUM)

        // total number of beats in the burst: LEN + 1
        num_beats = rd_tr.axi_tb_LEN + 1;

        // data array to store the response
        rd_tr.axi_tb_RDATA = new[num_beats];
        rd_tr.axi_tb_RRESP = new[num_beats];

        // RREADY should be high before AR request
        vif.axi_tb_RREADY <= 1'b1;

        // AR Channel (Read Address Request)
        @(posedge vif.axi_tb_ACLK);
        vif.axi_tb_ARVALID <= 1'b1;

        vif.axi_tb_ARADDR <= rd_tr.axi_tb_ADDR;
        vif.axi_tb_ARID <= rd_tr.axi_tb_ID;
        vif.axi_tb_ARLEN <= rd_tr.axi_tb_LEN;
        vif.axi_tb_ARSIZE <= rd_tr.axi_tb_SIZE;
        vif.axi_tb_ARBURST <= rd_tr.axi_tb_BURST;

        current_ar_addr <= rd_tr.axi_tb_ADDR; // Store start address to determine next addr

        @(posedge vif.axi_tb_ACLK);
        while (vif.axi_tb_ARREADY !== 1'b1) begin
            @(posedge vif.axi_tb_ACLK);
            `uvm_info(get_type_name(), $sformatf("Waiting for ARREADY to be 1..."), UVM_DEBUG)
        end

        // AR Handshake Complete: Deassert ARVALID
        vif.axi_tb_ARVALID <= 1'b0;

        // R Channel (Read Data)
        for (int i = 0; i < num_beats; i++) begin
            // Wait for RVALID (Data available from the DUT)
            while (!(vif.axi_tb_RVALID)) begin
                @(posedge vif.axi_tb_ACLK);
                `uvm_info(get_type_name(), "Waiting for RVALID...", UVM_DEBUG)
            end

            rd_tr.axi_tb_RDATA[i] = vif.axi_tb_RDATA;
            rd_tr.axi_tb_RRESP[i] = vif.axi_tb_RRESP;

            `uvm_info(get_type_name(), $sformatf("[READ_TB] beat=%0d/%0d, addr=0x%h, data=0x%h, RLAST=%0b, RRESP=0x%h",
                                                 i, num_beats - 1, current_ar_addr, rd_tr.axi_tb_RDATA[i], vif.axi_tb_RLAST, rd_tr.axi_tb_RRESP[i]), UVM_MEDIUM)

            // Check for RLAST assertion on the expected final beat
            if (i == (num_beats - 1)) begin
                if (vif.axi_tb_RLAST !== 1'b1) begin
                    `uvm_error(get_type_name(), $sformatf("ERROR: RLAST failed to assert on last beat (%0d/%0d)", i, num_beats - 1))
                end

                // Final RRESP check
                if (rd_tr.axi_tb_RRESP[i] !== 2'b00) begin
                    `uvm_error(get_type_name(), $sformatf("ERROR: RRESP !== 2'b00, Received RRESP = 2'b%0b", rd_tr.axi_tb_RRESP[i]))
                end else begin
                    `uvm_info(get_type_name(), $sformatf("READ PASS: Final RRESP 0x00 OKAY received."), UVM_MEDIUM)
                end

                // De-assert RREADY one cycle after accepting the RLAST beat
                @(posedge vif.axi_tb_ACLK);
                vif.axi_tb_RREADY <= 1'b0;

            end else begin
                // RLAST must NOT be asserted on intermediate beats
                if (vif.axi_tb_RLAST !== 1'b0) begin
                    `uvm_error(get_type_name(), $sformatf("ERROR: RLAST asserted prematurely on beat %0d", i))
                end
            end

            // Address increments by the size of the beat (2^AXI_SIZE)
            current_ar_addr <= current_ar_addr + (1 << rd_tr.axi_tb_SIZE) / num_bytes_addr_store;
            @(posedge vif.axi_tb_ACLK);
        end

        // Notify the analysis port that the transaction is fully complete
        rd_drv_ap.write(rd_tr);

        `uvm_info(get_type_name(), $sformatf("READ Burst complete: %s", rd_tr.convert2string()), UVM_MEDIUM)

    endtask

    virtual task init_read(axi_read_trans rd_tr);
        @(posedge vif.axi_tb_ACLK);

        vif.axi_tb_ARVALID <= 1'b0;
        vif.axi_tb_ARADDR <= '0;
        vif.axi_tb_ARID <= '0;
        vif.axi_tb_ARLEN <= '0;
        vif.axi_tb_ARSIZE <= '0;
        vif.axi_tb_ARBURST <= '0;

        vif.axi_tb_RREADY <= 1'b1;

        num_beats <= '0;
        current_ar_addr <= '0;
    endtask

endclass