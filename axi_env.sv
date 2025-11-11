class axi_env #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter LEN_WIDTH = 8,
    parameter SIZE_WIDTH = 3,
    parameter BURST_WIDTH = 2,
    parameter RESP_WIDTH = 2,
    parameter ID_WIDTH = 4,
    parameter STROBE_WIDTH = DATA_WIDTH/8,
    parameter ADDR_BYTE_SIZE = 1
) extends uvm_env;

    `uvm_component_param_utils(axi_env #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ))
    virtual axi_if vif;
    axi_agt #(ADDR_WIDTH, DATA_WIDTH, LEN_WIDTH, SIZE_WIDTH, BURST_WIDTH, RESP_WIDTH, ID_WIDTH, STROBE_WIDTH, ADDR_BYTE_SIZE) agt;
    axi_scb #(ADDR_WIDTH, DATA_WIDTH, LEN_WIDTH, SIZE_WIDTH, BURST_WIDTH, RESP_WIDTH, ID_WIDTH, STROBE_WIDTH, ADDR_BYTE_SIZE) scb;
    axi_cov #(ADDR_WIDTH, DATA_WIDTH, LEN_WIDTH, SIZE_WIDTH, BURST_WIDTH, RESP_WIDTH, ID_WIDTH, STROBE_WIDTH, ADDR_BYTE_SIZE) cov;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
        `uvm_fatal("CFG_ERR", "No virtual interface found for env");

      agt = axi_agt#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
                        )::type_id::create("agt", this);
      scb = axi_scb#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
                        )::type_id::create("scb", this);
      cov = axi_cov#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
                        )::type_id::create("cov", this);

      uvm_config_db#(virtual axi_if)::set(this, "agt", "vif", vif); // Pass vif down to agent
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      agt.agt_wr_req_ap.connect(scb.scb_wr_req_imp);
      agt.agt_wr_data_ap.connect(scb.scb_wr_data_imp);
      agt.agt_wr_resp_ap.connect(scb.scb_wr_resp_imp);
      agt.agt_rd_req_ap.connect(scb.scb_rd_req_imp);
      agt.agt_rd_data_ap.connect(scb.scb_rd_data_imp);

      agt.agt_wr_req_ap.connect(cov.cov_wr_req_imp);
      agt.agt_wr_data_ap.connect(cov.cov_wr_data_imp);
      agt.agt_wr_resp_ap.connect(cov.cov_wr_resp_imp);
      agt.agt_rd_req_ap.connect(cov.cov_rd_req_imp);
      agt.agt_rd_data_ap.connect(cov.cov_rd_data_imp);

      // Pass the dedicated physical sequencer handles from the agent to the config_db so that the Virtual Sequences can retrieve them.
      // The path "*" makes this handle available to ALL components and sequences in the hierarchy, including the Virtual Sequence.
      if (agt.wr_sqr != null)
          uvm_config_db#(axi_sqr_write)::set(this,    // use 'null' instead of 'this' to allow global access
                                              "agt",          // Instance Path (Target Context)
                                              "p_wr_sqr",   // Field Name
                                              agt.wr_sqr    // The actual pointer/handle
                                              );


      if (agt.rd_sqr != null)
          // Pass Read Sequencer Handle
          uvm_config_db#(axi_sqr_read)::set(this,         // Starting scope (null - start frm root)
                                            "agt",        // Instance Path (Target Context) where the config value applies
                                            "p_rd_sqr",   // Field Name
                                            agt.rd_sqr    // The actual pointer/handle (the value being stored)
                                          );

    endfunction
endclass