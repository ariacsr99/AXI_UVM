class axi_cov #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter LEN_WIDTH = 8,
    parameter SIZE_WIDTH = 3,
    parameter BURST_WIDTH = 2,
    parameter RESP_WIDTH = 2,
    parameter ID_WIDTH = 4,
    parameter STROBE_WIDTH = DATA_WIDTH/8,
    parameter ADDR_BYTE_SIZE = 1
) extends uvm_component;

    `uvm_component_param_utils(axi_cov #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ))

    // Analysis imp for connecting monitor -> coverage
    uvm_analysis_imp_AW #(axi_write_trans, axi_cov) cov_wr_req_imp;
    uvm_analysis_imp_W #(axi_write_trans, axi_cov) cov_wr_data_imp;
    uvm_analysis_imp_B #(axi_write_trans, axi_cov) cov_wr_resp_imp;
    uvm_analysis_imp_AR #(axi_read_trans, axi_cov) cov_rd_req_imp;
    uvm_analysis_imp_R #(axi_read_trans, axi_cov) cov_rd_data_imp;

    // Variable to store the transaction
    axi_write_trans wr_req;
    axi_write_trans wr_data;
    axi_write_trans wr_resp;
    axi_read_trans rd_req;
    axi_read_trans rd_data;

    covergroup axi_wr_cg;
        option.per_instance = 1;

        awaddr_cp : coverpoint wr_req.axi_tb_ADDR {
            bins low  = {['h0:'h5555]};
            bins mid  = {['h5556:'hAAAA]};
            bins high = {['hAAAB:'hFFFF]};
        }

        wdata_cp : coverpoint wr_data.axi_tb_WDATA {
            bins low  = {['h0000_0000:'h5555_5555]};
            bins mid  = {['h5555_5556:'hAAAA_AAAA]};
            bins high = {['hAAAA_AAAB:'hFFFF_FFFF]};
        }

        awburst_cp : coverpoint wr_req.axi_tb_BURST {
            bins FIXED = {0};
            bins INCR  = {1};
            bins WRAP  = {2};
        }

        awlen_cp : coverpoint wr_req.axi_tb_LEN {
            bins single   = {0};
            bins short_burst[] = {[1:7]};
            bins long_burst[]  = {[8:15]};
        }

        awsize_cp : coverpoint wr_req.axi_tb_SIZE {
            bins size_1BYTE = {0};
            bins size_2BYTES = {1};
            bins size_4BYTES = {2};
            bins size_8BYTES = {3};
            bins size_16BYTES = {4};
        }

        awaddr_X_burst : cross awaddr_cp, awburst_cp;
        awburst_X_len  : cross awburst_cp, awlen_cp;
        awlen_X_size   : cross awlen_cp, awsize_cp;

    endgroup

    covergroup axi_rd_cg;
        option.per_instance = 1;

        araddr_cp : coverpoint rd_req.axi_tb_ADDR {
            bins low  = {['h0:'h5555]};
            bins mid  = {['h5556:'hAAAA]};
            bins high = {['hAAAB:'hFFFF]};
        }

        rdata_cp : coverpoint rd_data.axi_tb_RDATA {
            bins low  = {['h0000_0000:'h5555_5555]};
            bins mid  = {['h5555_5556:'hAAAA_AAAA]};
            bins high = {['hAAAA_AAAB:'hFFFF_FFFF]};
        }

        arburst_cp : coverpoint rd_req.axi_tb_BURST {
            bins FIXED = {0};
            bins INCR  = {1};
            bins WRAP  = {2};
        }

        arlen_cp : coverpoint rd_req.axi_tb_LEN {
            bins single   = {0};
            bins short_burst[] = {[1:7]};
            bins long_burst[]  = {[8:15]};
        }

        arsize_cp : coverpoint rd_req.axi_tb_SIZE {
            bins size_1BYTE = {0};
            bins size_2BYTES = {1};
            bins size_4BYTES = {2};
            bins size_8BYTES = {3};
            bins size_16BYTES = {4};
        }

        araddr_X_burst : cross araddr_cp, arburst_cp;
        arburst_X_len  : cross arburst_cp, arlen_cp;
        arlen_X_size   : cross arlen_cp, arsize_cp;

    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        axi_wr_cg = new();
        axi_rd_cg = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        cov_wr_req_imp = new("cov_wr_req_imp", this);
        cov_wr_data_imp = new("cov_wr_data_imp", this);
        cov_wr_resp_imp = new("cov_wr_resp_imp", this);
        cov_rd_req_imp = new("cov_rd_req_imp", this);
        cov_rd_data_imp = new("cov_rd_data_imp", this);
    endfunction

    // This is the function that the analysis port calls
    function void write_AW(axi_write_trans trans);
        `uvm_info(get_type_name(), "Received write req transaction", UVM_LOW)
        this.wr_req = trans;
        process_write();
    endfunction

    function void write_W(axi_write_trans trans);
        `uvm_info(get_type_name(), "Received write data transaction", UVM_LOW)
        this.wr_data = trans;
        process_write();
    endfunction

    function void write_B(axi_write_trans trans);
        `uvm_info(get_type_name(), "Received write resp transaction", UVM_LOW)
        this.wr_resp = trans;
        process_write();
    endfunction

    function void write_AR(axi_read_trans trans);
        `uvm_info(get_type_name(), "Received read req transaction", UVM_LOW)
        this.rd_req = trans;
        process_read();
    endfunction

    function void write_R(axi_read_trans trans);
        `uvm_info(get_type_name(), "Received read data transaction", UVM_LOW)
        this.rd_data = trans;
        process_read();
    endfunction

    // Write transaction hook
    // Called automatically when monitor writes
    virtual function void process_write();
        if (wr_req == null || wr_data == null || wr_resp == null) begin
            `uvm_warning(get_type_name(), "Incomplete write transaction, skipping coverage sample")
            return;
        end else begin
            `uvm_info(get_type_name(), "Write transaction COMPLETED, sampling coverage", UVM_MEDIUM)
        end
        axi_wr_cg.sample();
    endfunction

    virtual function void process_read();
        if (rd_req == null || rd_data == null) begin
            `uvm_warning(get_type_name(), "Incomplete read transaction, skipping coverage sample")
            return;
        end else begin
            `uvm_info(get_type_name(), "Read transaction COMPLETED, sampling coverage", UVM_MEDIUM)
        end
        axi_rd_cg.sample();
    endfunction

endclass