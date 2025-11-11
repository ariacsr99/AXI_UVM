class axi_agt #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter LEN_WIDTH = 8,
    parameter SIZE_WIDTH = 3,
    parameter BURST_WIDTH = 2,
    parameter RESP_WIDTH = 2,
    parameter ID_WIDTH = 4,
    parameter STROBE_WIDTH = DATA_WIDTH/8,
    parameter ADDR_BYTE_SIZE = 1
    )extends uvm_agent;

    `uvm_component_param_utils(axi_agt #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ))
    virtual axi_if vif;

    uvm_analysis_port #(axi_write_trans) agt_wr_req_ap;
    uvm_analysis_port #(axi_write_trans) agt_wr_data_ap;
    uvm_analysis_port #(axi_write_trans) agt_wr_resp_ap;
    uvm_analysis_port #(axi_read_trans) agt_rd_req_ap;
    uvm_analysis_port #(axi_read_trans) agt_rd_data_ap;

    axi_write_driver #(ADDR_WIDTH, DATA_WIDTH, LEN_WIDTH, SIZE_WIDTH, BURST_WIDTH, RESP_WIDTH, ID_WIDTH, STROBE_WIDTH, ADDR_BYTE_SIZE) wr_drv;
    axi_read_driver  #(ADDR_WIDTH, DATA_WIDTH, LEN_WIDTH, SIZE_WIDTH, BURST_WIDTH, RESP_WIDTH, ID_WIDTH, STROBE_WIDTH, ADDR_BYTE_SIZE) rd_drv;
    axi_monitor      #(ADDR_WIDTH, DATA_WIDTH, LEN_WIDTH, SIZE_WIDTH, BURST_WIDTH, RESP_WIDTH, ID_WIDTH, STROBE_WIDTH, ADDR_BYTE_SIZE) mon;
    axi_sqr_write    #(ADDR_WIDTH, DATA_WIDTH, LEN_WIDTH, SIZE_WIDTH, BURST_WIDTH, RESP_WIDTH, ID_WIDTH, STROBE_WIDTH, ADDR_BYTE_SIZE) wr_sqr;
    axi_sqr_read     #(ADDR_WIDTH, DATA_WIDTH, LEN_WIDTH, SIZE_WIDTH, BURST_WIDTH, RESP_WIDTH, ID_WIDTH, STROBE_WIDTH, ADDR_BYTE_SIZE) rd_sqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
            `uvm_fatal("CFG_ERR", "No virtual interface found for agent");

        //Instantiate Ports (Analysis Ports)
        agt_wr_req_ap = new("agt_wr_req_ap", this);
        agt_wr_data_ap = new("agt_wr_data_ap", this);
        agt_wr_resp_ap = new("agt_wr_resp_ap", this);
        agt_rd_req_ap = new("agt_rd_req_ap", this);
        agt_rd_data_ap = new("agt_rd_data_ap", this);

        mon = axi_monitor#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH), .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE))::type_id::create("mon", this);

        // Only create driver and sequencer if agent is active
        if (get_is_active() == UVM_ACTIVE) begin
            wr_drv = axi_write_driver#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH), .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE))::type_id::create("wr_drv", this);
            rd_drv = axi_read_driver#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH), .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE))::type_id::create("rd_drv", this);
            wr_sqr = axi_sqr_write#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH), .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE))::type_id::create("wr_sqr", this);
            rd_sqr = axi_sqr_read#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH), .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE))::type_id::create("rd_sqr", this);
        end

        uvm_config_db#(virtual axi_if.drv_mp)::set(this, "wr_drv", "vif", vif.drv_mp);
        uvm_config_db#(virtual axi_if.drv_mp)::set(this, "rd_drv", "vif", vif.drv_mp);
        uvm_config_db#(virtual axi_if.mon_mp)::set(this, "mon", "vif", vif.mon_mp);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Connect monitor's analysis port to agent's analysis port
        mon.mon_wr_req_ap.connect(agt_wr_req_ap);
        mon.mon_wr_data_ap.connect(agt_wr_data_ap);
        mon.mon_wr_resp_ap.connect(agt_wr_resp_ap);
        mon.mon_rd_req_ap.connect(agt_rd_req_ap);
        mon.mon_rd_data_ap.connect(agt_rd_data_ap);

        // Connect driver to sequencer if agent active
        if (get_is_active() == UVM_ACTIVE) begin
            wr_drv.seq_item_port.connect(wr_sqr.seq_item_export);
            rd_drv.seq_item_port.connect(rd_sqr.seq_item_export);
        end

    endfunction
endclass