class axi_monitor #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter LEN_WIDTH = 8,
    parameter SIZE_WIDTH = 3,
    parameter BURST_WIDTH = 2,
    parameter RESP_WIDTH = 2,
    parameter ID_WIDTH = 4,
    parameter STROBE_WIDTH = DATA_WIDTH/8,
    parameter ADDR_BYTE_SIZE = 1
)extends uvm_monitor;

    `uvm_component_param_utils(axi_monitor #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ))

    virtual axi_if.mon_mp vif; // Virtual interface handle

    // Analysis Ports for Write Channels
    uvm_analysis_port #(axi_write_trans) mon_wr_req_ap;  // AW Channel
    uvm_analysis_port #(axi_write_trans) mon_wr_data_ap; // W Channel
    uvm_analysis_port #(axi_write_trans) mon_wr_resp_ap; // B Channel

    // Analysis Ports for Read Channels
    uvm_analysis_port #(axi_read_trans) mon_rd_req_ap;  // AR Channel
    uvm_analysis_port #(axi_read_trans) mon_rd_data_ap; // R Channel

    function new(string name = "axi_monitor", uvm_component parent);
        super.new(name, parent);
        mon_wr_req_ap = new("mon_wr_req_ap", this);
        mon_wr_data_ap = new("mon_wr_data_ap", this);
        mon_wr_resp_ap = new("mon_wr_resp_ap", this);
        mon_rd_req_ap = new("mon_rd_req_ap", this);
        mon_rd_data_ap = new("mon_rd_data_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual axi_if.mon_mp)::get(this, "", "vif", vif)) begin
            `uvm_error(get_type_name(), "Virtual interface (mon_mp) not found in config db")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        fork
            collect_aw_channel(); // Write Address Request
            collect_w_channel();  // Write Data
            collect_b_channel();  // Write Response
            collect_ar_channel(); // Read Address Request
            collect_r_channel();  // Read Data
        join_none
    endtask

    // Write Address Request (AW Channel)
    virtual protected task collect_aw_channel();
        forever begin
            axi_write_trans wr_req_dut;

            // Wait for the AW handshake: AWVALID AND AWREADY
            @(posedge vif.axi_tb_ACLK);

            if (vif.axi_tb_AWVALID && vif.axi_tb_AWREADY) begin
            // Sample the signals right after the handshake
            wr_req_dut = axi_write_trans#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                                             .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                                             .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE))::type_id::create("wr_req_dut");

            wr_req_dut.axi_tb_ADDR = vif.axi_tb_AWADDR;
            wr_req_dut.axi_tb_ID = vif.axi_tb_AWID;
            wr_req_dut.axi_tb_LEN = vif.axi_tb_AWLEN;
            wr_req_dut.axi_tb_SIZE = vif.axi_tb_AWSIZE;
            wr_req_dut.axi_tb_BURST = vif.axi_tb_AWBURST;

            `uvm_info(get_type_name(), $sformatf("Monitored WRITE REQ: AWADDR=0x%0h, AWID=0x%0h, AWLEN=0x%0h, AWSIZE=0x%0h, AWBURST=0x%0h", wr_req_dut.axi_tb_ADDR, wr_req_dut.axi_tb_ID, wr_req_dut.axi_tb_LEN, wr_req_dut.axi_tb_SIZE, wr_req_dut.axi_tb_BURST), UVM_MEDIUM)

            mon_wr_req_ap.write(wr_req_dut);
            end
        end
    endtask

    // Write Data (W Channel)
    virtual protected task collect_w_channel();
        forever begin
            axi_write_trans wr_data_dut;

            // Wait for the W handshake
            @(posedge vif.axi_tb_ACLK);

            if(vif.axi_tb_WVALID && vif.axi_tb_WREADY) begin
                wr_data_dut = axi_write_trans#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                                                 .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                                                 .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE))::type_id::create("wr_data_dut");

                // axi_write_trans can hold a burst (dynamic array),
                // but the monitor captures one beat, so allocate one slot.
                wr_data_dut.axi_tb_WDATA = new[1];
                wr_data_dut.axi_tb_WDATA[0] = vif.axi_tb_WDATA;

                wr_data_dut.axi_tb_WSTRB = new[1];
                wr_data_dut.axi_tb_WSTRB[0] = vif.axi_tb_WSTRB;

                wr_data_dut.axi_tb_WLAST = vif.axi_tb_WLAST;
                // Note: Using AWID here for tracking
                wr_data_dut.axi_tb_ID = vif.axi_tb_AWID;

                `uvm_info(get_type_name(), $sformatf("Monitored WRITE DATA: WDATA=0x%0h, WSTRB=0x%0h, WLAST=0x%0h, AWID=0x%0h", wr_data_dut.axi_tb_WDATA[0], wr_data_dut.axi_tb_WSTRB[0], wr_data_dut.axi_tb_WLAST, wr_data_dut.axi_tb_ID), UVM_MEDIUM)
                mon_wr_data_ap.write(wr_data_dut);
            end
        end
    endtask

    // Write Response (B Channel)
    virtual protected task collect_b_channel();
        forever begin
            axi_write_trans wr_resp_dut;

            // Wait for the B handshake
            @(posedge vif.axi_tb_ACLK);

            if (vif.axi_tb_BVALID && vif.axi_tb_BREADY) begin
                wr_resp_dut = axi_write_trans#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                                                 .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                                                 .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE))::type_id::create("wr_resp_dut");

                wr_resp_dut.axi_tb_BID = vif.axi_tb_BID;
                wr_resp_dut.axi_tb_BRESP = vif.axi_tb_BRESP;

                `uvm_info(get_type_name(), $sformatf("Monitored WRITE RESP: BID=0x%0h, BRESP=0x%0h", wr_resp_dut.axi_tb_BID, wr_resp_dut.axi_tb_BRESP), UVM_MEDIUM)

                mon_wr_resp_ap.write(wr_resp_dut);
            end
        end
    endtask

    // Read Address Request (AR Channel)
    virtual protected task collect_ar_channel();
        forever begin
            axi_read_trans rd_req_dut;

            // Wait for the AR handshake
            @(posedge vif.axi_tb_ACLK);
                if (vif.axi_tb_ARVALID && vif.axi_tb_ARREADY) begin
                rd_req_dut = axi_read_trans#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                                                 .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                                                 .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE))::type_id::create("rd_req_dut");

                rd_req_dut.axi_tb_ADDR = vif.axi_tb_ARADDR;
                rd_req_dut.axi_tb_ID = vif.axi_tb_ARID;
                rd_req_dut.axi_tb_LEN = vif.axi_tb_ARLEN;
                rd_req_dut.axi_tb_SIZE = vif.axi_tb_ARSIZE;
                rd_req_dut.axi_tb_BURST = vif.axi_tb_ARBURST;

                `uvm_info(get_type_name(), $sformatf("Monitored READ REQ: ARADDR=0x%0h, ARID=0x%0h, ARLEN=0x%0h, ARSIZE=0x%0h, ARBURST=0x%0h", rd_req_dut.axi_tb_ADDR, rd_req_dut.axi_tb_ID, rd_req_dut.axi_tb_LEN, rd_req_dut.axi_tb_SIZE, rd_req_dut.axi_tb_BURST), UVM_MEDIUM)
                mon_rd_req_ap.write(rd_req_dut);
            end
        end
    endtask

    // Read Data (R Channel)
    virtual protected task collect_r_channel();
        forever begin
            axi_read_trans rd_data_dut;

            // Wait for the R handshake
            @(posedge vif.axi_tb_ACLK);

            if (vif.axi_tb_RVALID && vif.axi_tb_RREADY) begin
                rd_data_dut = axi_read_trans#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                                                 .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                                                 .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE))::type_id::create("rd_data_dut");

                // axi_read_trans can hold a burst (dynamic array),
                // but the monitor captures one beat, so allocate one slot.
                rd_data_dut.axi_tb_RDATA = new[1];
                rd_data_dut.axi_tb_RDATA[0] = vif.axi_tb_RDATA;

                rd_data_dut.axi_tb_RRESP = new[1];
                rd_data_dut.axi_tb_RRESP[0] = vif.axi_tb_RRESP;

                rd_data_dut.axi_tb_RID = vif.axi_tb_RID;
                rd_data_dut.axi_tb_RLAST = vif.axi_tb_RLAST;

                `uvm_info(get_type_name(), $sformatf("Monitored READ DATA: RDATA=0x%0h, RID=0x%0h, RRESP=0x%0h, RLAST=0x%0h", rd_data_dut.axi_tb_RDATA[0], rd_data_dut.axi_tb_RID, rd_data_dut.axi_tb_RRESP[0], rd_data_dut.axi_tb_RLAST), UVM_MEDIUM)
                mon_rd_data_ap.write(rd_data_dut);
            end
        end
    endtask

endclass