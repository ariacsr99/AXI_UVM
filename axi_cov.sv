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

    logic [ADDR_WIDTH-1:0] sampled_addr;
    logic [BURST_WIDTH-1:0] sampled_burst;
    logic [LEN_WIDTH-1:0] sampled_len;
    logic [SIZE_WIDTH-1:0] sampled_size;
    logic [DATA_WIDTH-1:0] sampled_data; // Used for WDATA and RDATA sampling

    // Write Configuration Coverage (Sampled on AW)
    covergroup axi_wr_cfg_cg;
        option.per_instance = 1;

        awaddr_cp : coverpoint sampled_addr {
            bins low  = {['h0:'h5555]};
            bins mid  = {['h5556:'hAAAA]};
            bins high = {['hAAAB:'hFFFF]};
        }

        awburst_cp : coverpoint sampled_burst {
            bins FIXED = {0};
            bins INCR  = {1};
            bins WRAP  = {2};
        }

        awlen_cp : coverpoint sampled_len {
            bins single  = {0};
            bins short_burst[] = {[1:7]};
            bins long_burst[]  = {[8:15]};
        }

        awsize_cp : coverpoint sampled_size {
            bins size_1BYTE = {0};
            bins size_2BYTES = {1};
            bins size_4BYTES = {2};
            bins size_8BYTES = {3};
            bins size_16BYTES = {4};
        }

        awaddr_X_burst : cross awaddr_cp, awburst_cp;
        awburst_X_len  : cross awburst_cp, awlen_cp;
        awlen_X_size   : cross awlen_cp, awsize_cp;

    endgroup // axi_wr_cfg_cg

    // Write Data Coverage (Sampled on W beat)
    covergroup axi_wdata_cg;
        option.per_instance = 1;

        wdata_cp : coverpoint sampled_data {
            bins low  = {['h0000_0000:'h5555_5555]};
            bins mid  = {['h5555_5556:'hAAAA_AAAA]};
            bins high = {['hAAAA_AAAB:'hFFFF_FFFF]};
        }
    endgroup // axi_wdata_cg


    // Read Configuration Coverage (Sampled on AR)
    covergroup axi_rd_cfg_cg;
        option.per_instance = 1;

        araddr_cp : coverpoint sampled_addr {
            bins low  = {['h0:'h5555]};
            bins mid  = {['h5556:'hAAAA]};
            bins high = {['hAAAB:'hFFFF]};
        }

        arburst_cp : coverpoint sampled_burst {
            bins FIXED = {0};
            bins INCR  = {1};
            bins WRAP  = {2};
        }

        arlen_cp : coverpoint sampled_len {
            bins single  = {0};
            bins short_burst[] = {[1:7]};
            bins long_burst[]  = {[8:15]};
        }

        arsize_cp : coverpoint sampled_size {
            bins size_1BYTE = {0};
            bins size_2BYTES = {1};
            bins size_4BYTES = {2};
            bins size_8BYTES = {3};
            bins size_16BYTES = {4};
        }

        araddr_X_burst : cross araddr_cp, arburst_cp;
        arburst_X_len  : cross arburst_cp, arlen_cp;
        arlen_X_size   : cross arlen_cp, arsize_cp;

    endgroup // axi_rd_cfg_cg

    // Read Data Coverage (Sampled on R beat)
    covergroup axi_rdata_cg;
        option.per_instance = 1;

        rdata_cp : coverpoint sampled_data {
            bins low  = {['h0000_0000:'h5555_5555]};
            bins mid  = {['h5555_5556:'hAAAA_AAAA]};
            bins high = {['hAAAA_AAAB:'hFFFF_FFFF]};
        }
    endgroup // axi_rdata_cg


    function new(string name, uvm_component parent);
        super.new(name, parent);
        // Instantiate all covergroups
        axi_wr_cfg_cg = new();
        axi_wdata_cg  = new();
        axi_rd_cfg_cg = new();
        axi_rdata_cg  = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Instantiate IMPs
        cov_wr_req_imp  = new("cov_wr_req_imp", this);
        cov_wr_data_imp = new("cov_wr_data_imp", this);
        cov_wr_resp_imp = new("cov_wr_resp_imp", this);
        cov_rd_req_imp  = new("cov_rd_req_imp", this);
        cov_rd_data_imp = new("cov_rd_data_imp", this);
    endfunction


    // WRITE Channel IMP Implementations
    // AW Channel: Samples Write Configuration (ADDR, LEN, BURST, SIZE)
    function void write_AW(axi_write_trans trans);
        `uvm_info(get_type_name(), "Received write AW req, sampling configuration coverage.", UVM_LOW)

        // Load sampled variables from the transaction
        sampled_addr  = trans.axi_tb_ADDR;
        sampled_burst = trans.axi_tb_BURST;
        sampled_len   = trans.axi_tb_LEN;
        sampled_size  = trans.axi_tb_SIZE;

        // Sample the configuration covergroup
        axi_wr_cfg_cg.sample();
    endfunction

    // W Channel: Samples Write Data (WDATA) on every beat
    function void write_W(axi_write_trans trans);
        `uvm_info(get_type_name(), "Received write W data beat, sampling data coverage.", UVM_LOW)

        // Access index [0] as the monitor passes individual data beats in a dynamic array of size 1.
        sampled_data = trans.axi_tb_WDATA[0];

        // Sample the data covergroup
        axi_wdata_cg.sample();
    endfunction

    // B Channel: Usually only used for logging/error reporting
    function void write_B(axi_write_trans trans);
        `uvm_info(get_type_name(), "Received write B resp.", UVM_LOW)
        // No coverage sampling required
    endfunction


    // READ Channel IMP Implementations
    // AR Channel: Samples Read Configuration (ADDR, LEN, BURST, SIZE)
    function void write_AR(axi_read_trans trans);
        `uvm_info(get_type_name(), "Received read AR req, sampling configuration coverage.", UVM_LOW)

        // Load sampled variables from the transaction
        sampled_addr  = trans.axi_tb_ADDR;
        sampled_burst = trans.axi_tb_BURST;
        sampled_len   = trans.axi_tb_LEN;
        sampled_size  = trans.axi_tb_SIZE;

        // Sample the configuration covergroup
        axi_rd_cfg_cg.sample();
    endfunction

    // R Channel: Samples Read Data (RDATA) on every beat
    function void write_R(axi_read_trans trans);
        `uvm_info(get_type_name(), "Received read R data beat, sampling data coverage.", UVM_LOW)

        // Access the scalar element at index [0]
        sampled_data = trans.axi_tb_RDATA[0];

        // Sample the data covergroup
        axi_rdata_cg.sample();
    endfunction

endclass