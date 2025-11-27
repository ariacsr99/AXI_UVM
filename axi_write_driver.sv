class axi_write_driver #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter LEN_WIDTH = 8,
    parameter SIZE_WIDTH = 3,
    parameter BURST_WIDTH = 2,
    parameter RESP_WIDTH = 2,
    parameter ID_WIDTH = 4,
    parameter STROBE_WIDTH = DATA_WIDTH/8,
    parameter ADDR_BYTE_SIZE = 1
) extends uvm_driver #(axi_write_trans #(
    .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
    .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
    .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE))
    );

    `uvm_component_param_utils(axi_write_driver #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ))

    virtual axi_if.drv_mp vif;

    uvm_analysis_port #(
        axi_write_trans #(
            .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
            .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
            .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE))
        ) wr_drv_ap;

    logic [LEN_WIDTH+1:0] num_beats;
    reg [ADDR_WIDTH-1:0] current_aw_addr;
    real num_bytes_addr_store = ADDR_BYTE_SIZE;

    // Synchronization event for W Channel
    event aw_done_event;

    function new(string name = "axi_write_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        wr_drv_ap = new("wr_drv_ap", this);
        if(!uvm_config_db#(virtual axi_if.drv_mp)::get(this, "", "vif", vif)) begin
        `uvm_error(get_type_name(), "Virtual interface (drv_mp) not found in config db")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        axi_write_trans wr_tr;

        // initialize interface signals
        init_write(wr_tr);

        forever begin
            seq_item_port.get_next_item(wr_tr);
            send_write(wr_tr);
            seq_item_port.item_done();
        end
    endtask

    virtual task send_write(axi_write_trans wr_tr);

        `uvm_info(get_type_name(), $sformatf("Starting WRITE Burst to: AWADDR = 0x%0h, AWID = 0x%0h, AWLEN = 0x%0h, AWSIZE = 0x%0h, AWBURST = 0x%0h", wr_tr.axi_tb_ADDR, wr_tr.axi_tb_ID, wr_tr.axi_tb_LEN, wr_tr.axi_tb_SIZE, wr_tr.axi_tb_BURST), UVM_MEDIUM)

        num_beats = wr_tr.axi_tb_LEN + 1; //total number of beats (transfers) in the burst: LEN + 1

        // Fork the AW, W, and B channels to run in parallel
        fork
            // AW Channel (Address Write Request)
            begin
                @(posedge vif.axi_tb_ACLK);

                // Drive AW signals
                vif.axi_tb_AWVALID <= 1'b1;
                vif.axi_tb_AWID <= wr_tr.axi_tb_ID;
                vif.axi_tb_AWADDR <= wr_tr.axi_tb_ADDR;
                vif.axi_tb_AWLEN <= wr_tr.axi_tb_LEN;
                vif.axi_tb_AWSIZE <= wr_tr.axi_tb_SIZE;
                vif.axi_tb_AWBURST <= wr_tr.axi_tb_BURST;

                current_aw_addr <= wr_tr.axi_tb_ADDR;

                // Wait for AW Handshake (AWVALID & AWREADY)
                //@(posedge vif.axi_tb_ACLK iff (vif.axi_tb_AWREADY === 1'b1));
                while (!(vif.axi_tb_AWREADY)) begin
                    @(posedge vif.axi_tb_ACLK);
                    `uvm_info(get_type_name(), "Waiting for AWREADY to be 1", UVM_DEBUG)
                end

                @(posedge vif.axi_tb_ACLK);
                // Handshake complete: Deassert VALID and trigger W channel
                vif.axi_tb_AWVALID <= 1'b0;
                -> aw_done_event;
            end

            // W Channel (Write Data Burst)
            begin
                @aw_done_event;

                vif.axi_tb_WVALID <= 1'b1;

                for (int i = 0; i < num_beats; i++ ) begin
                    vif.axi_tb_WDATA <= wr_tr.axi_tb_WDATA[i];
                    vif.axi_tb_WSTRB <= wr_tr.axi_tb_WSTRB[i];

                    if (i == (num_beats-1)) begin
                        vif.axi_tb_WLAST <= 1'b1;
                    end
                    else begin
                        vif.axi_tb_WLAST <= 1'b0;
                    end

                    `uvm_info(get_type_name(), $sformatf("[WRITE_TB] beat=%0d (LAST=%0d), current_addr=0x%h, data=0x%h, strb=0x%h",
                                                         i, vif.axi_tb_WLAST, current_aw_addr, wr_tr.axi_tb_WDATA[i], wr_tr.axi_tb_WSTRB[i]), UVM_MEDIUM)

                    // Wait for W Handshake (WVALID & WREADY)
                    //@(posedge vif.axi_tb_ACLK iff (vif.axi_tb_WREADY == 1'b1));
                    while (!(vif.axi_tb_WREADY)) begin
                        @(posedge vif.axi_tb_ACLK);
                        `uvm_info(get_type_name(), "Waiting for WREADY to be 1", UVM_DEBUG)
                    end

                    // Update the address for the next beat (assuming INCR burst)
                    current_aw_addr <= current_aw_addr + (1 << wr_tr.axi_tb_SIZE) / num_bytes_addr_store;
                    @(posedge vif.axi_tb_ACLK);

                end

                vif.axi_tb_WVALID <= 1'b0;
                vif.axi_tb_WLAST <= 1'b0;
            end

            // B Channel (Write Response)
            begin
                vif.axi_tb_BREADY <= 1'b1;

                // Wait for B Handshake (BVALID & BREADY)
                //@(posedge vif.axi_tb_ACLK iff (vif.axi_tb_BVALID === 1'b1 && vif.axi_tb_BREADY === 1'b1));
                while (!(vif.axi_tb_BVALID)) begin
                    @(posedge vif.axi_tb_ACLK);
                    `uvm_info(get_type_name(), "Waiting for BVALID to be 1", UVM_DEBUG)
                end
                @(posedge vif.axi_tb_ACLK);

                if (vif.axi_tb_BRESP !== 2'b00) begin
                    `uvm_error(get_type_name(), $sformatf("WRITE FAIL: BRESP returned 0x%h (Expected 0x00 - OKAY)", vif.axi_tb_BRESP))
                end else begin
                    `uvm_info(get_type_name(), $sformatf("WRITE PASS: BRESP 0x00 OKAY received. BID: 0x%h", vif.axi_tb_BID), UVM_MEDIUM)
                end

                `uvm_info(get_type_name(), $sformatf("WRITE Burst complete: %s", wr_tr.convert2string()), UVM_MEDIUM)

                vif.axi_tb_BREADY <= 1'b0;
            end
        join

        wr_drv_ap.write(wr_tr);

    endtask

    virtual task init_write(axi_write_trans wr_tr);
        @(posedge vif.axi_tb_ACLK);
        vif.axi_tb_AWVALID <= 1'b0;
        vif.axi_tb_AWID <= '0;
        vif.axi_tb_AWADDR <= '0;
        vif.axi_tb_AWLEN <= '0;
        vif.axi_tb_AWSIZE <= '0;
        vif.axi_tb_AWBURST <= '0;

        vif.axi_tb_WVALID <= '0;
        vif.axi_tb_WSTRB <= '0;
        vif.axi_tb_WDATA <= '0;
        vif.axi_tb_WLAST <= '0;

        vif.axi_tb_BREADY <= 1'b1;

        current_aw_addr <= '0;
        num_beats <= '0;
    endtask

endclass