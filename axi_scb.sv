class axi_scb #(
        parameter ADDR_WIDTH = 16,
        parameter DATA_WIDTH = 32,
        parameter LEN_WIDTH = 8,
        parameter SIZE_WIDTH = 3,
        parameter BURST_WIDTH = 2,
        parameter RESP_WIDTH = 2,
        parameter ID_WIDTH = 4,
        parameter STROBE_WIDTH = DATA_WIDTH/8,
        parameter ADDR_BYTE_SIZE = 1
    ) extends uvm_scoreboard;

    `uvm_component_param_utils(axi_scb #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ))

    // Use implementation port to receive transactions
    //uvm_analysis_imp #(axi_trans, axi_scb) scb_imp;
    uvm_analysis_imp_AW #(axi_write_trans, axi_scb) scb_wr_req_imp;
    uvm_analysis_imp_W #(axi_write_trans, axi_scb) scb_wr_data_imp;
    uvm_analysis_imp_B #(axi_write_trans, axi_scb) scb_wr_resp_imp;
    uvm_analysis_imp_AR #(axi_read_trans, axi_scb) scb_rd_req_imp;
    uvm_analysis_imp_R #(axi_read_trans, axi_scb) scb_rd_data_imp;

    int passed_count = 0;
    int failed_count = 0;

    //localparam MEM_DEPTH = 256;
    localparam MEM_DEPTH = (1 << ADDR_WIDTH) - 1; //optimal for sim: ADDR_WIDTH = 16
    //Static reference memory model. Size fixed at compilation
    reg [DATA_WIDTH-1:0] mem_array_ref [MEM_DEPTH-1:0];

    logic [DATA_WIDTH-1:0] read_data_storage [LEN_WIDTH-1:0];
    logic [ADDR_WIDTH-1:0] current_aw_addr;
    logic [SIZE_WIDTH-1:0] current_awsize;
    logic [LEN_WIDTH-1:0] current_awlen;
    logic [ID_WIDTH-1:0] current_awid;
    logic [STROBE_WIDTH-1:0] strobe;
    logic [DATA_WIDTH-1:0] data_out;
    logic current_wlast;

    logic [ADDR_WIDTH-1:0] current_ar_addr;
    logic [SIZE_WIDTH-1:0] current_arsize;
    logic [LEN_WIDTH-1:0] current_arlen;

    real num_bytes_mem_row_store = DATA_WIDTH / 8;
    real num_bytes_addr_store = ADDR_BYTE_SIZE;
    logic [ADDR_WIDTH-1:0] min_hex_addr = '0;
    logic [ADDR_WIDTH-1:0] max_hex_addr = (MEM_DEPTH-1) * num_bytes_mem_row_store / num_bytes_addr_store;
    integer index = 0;
    logic [LEN_WIDTH-1:0] num_beats = '0;

    function automatic int convert_hex_addr_to_mem_index_num(
        input logic [ADDR_WIDTH-1:0] addr
    );
        return addr * (num_bytes_addr_store / num_bytes_mem_row_store);
    endfunction

    // EXTRA: Explore usage of dynamic array (ref_mem[]; ref_mem = new[MEM_DEPTH];):
    // Where size can be decided at runtime from config or command line +UVM_SET_CONFIG_INT

    function new(string name, uvm_component parent);
        super.new(name, parent);
        //scb_imp = new("scb_imp", this); // do not place here
    endfunction

    function void build_phase (uvm_phase phase);
        //Why is instantiation of ports and exports in the build_phase?
        //All components (uvm_component and its derivatives, including monitors, scoreboards, and sequence drivers) and their sub-components (like analysis ports and exports) should be instantiated in the build_phase
        //build_phase runs hierarchically (top-down), ensuring that a parent component is fully constructed before its children components are constructed
        // Components instantiated in the build_phase can access run-time configuration information via the uvm_config_db
        super.build_phase(phase);

        //Create the implementation exports
        scb_wr_req_imp = new("scb_wr_req_imp", this);
        scb_wr_data_imp = new("scb_wr_data_imp", this);
        scb_wr_resp_imp = new("scb_wr_resp_imp", this);
        scb_rd_req_imp = new("scb_rd_req_imp", this);
        scb_rd_data_imp = new("scb_rd_data_imp", this);

    endfunction

    // This is the UVM standard write method that the analysis port calls
    // Using uvm_analysis_imp_decl macros creates unique write functions
    function void write_AW(axi_write_trans wr_req);
        if ((wr_req.axi_tb_ADDR < min_hex_addr) || (wr_req.axi_tb_ADDR > max_hex_addr)) begin
            `uvm_error(get_type_name(), $sformatf("Write waddr=0x%0h out of range", wr_req.axi_tb_ADDR))
        end else begin
            `uvm_info(get_type_name(), $sformatf("Scoreboard received WRITE REQ: awaddr=0x%0h, awsize=0x%0h, awlen=0x%0h",  wr_req.axi_tb_ADDR, wr_req.axi_tb_SIZE, wr_req.axi_tb_LEN), UVM_MEDIUM)
            current_aw_addr = wr_req.axi_tb_ADDR;
            current_awid = wr_req.axi_tb_ID;
            current_awsize = wr_req.axi_tb_SIZE;
            current_awlen = wr_req.axi_tb_LEN;
        end
    endfunction

    function void write_W(axi_write_trans wr_data);
        strobe = wr_data.axi_tb_WSTRB;
        data_out = wr_data.axi_tb_WDATA;
        current_wlast = wr_data.axi_tb_WLAST;

        for (integer i = 0; i < STROBE_WIDTH; i++) begin
            if (strobe[i]) begin
                index = convert_hex_addr_to_mem_index_num(current_aw_addr);
                mem_array_ref[index][i*8 +: 8] <= data_out[i*8 +: 8];
            end
        end

        if (!current_wlast && (num_beats !== (current_awlen-1))) begin
            current_aw_addr <= current_aw_addr + (1 << current_awsize) / num_bytes_addr_store;
            num_beats = num_beats + 1;
        end else begin
            num_beats = '0;
        end

    endfunction

    function void write_B(axi_write_trans wr_resp);
        logic [RESP_WIDTH-1:0] expected_bresp = 2'b00; //OKAY

        if (wr_resp.axi_tb_BRESP !== expected_bresp) begin
            `uvm_error(get_type_name(), $sformatf("WRITE FAIL: Expected bresp: %0b, Received Resp: %0b", expected_bresp, wr_resp.axi_tb_BRESP))
        end else begin
            `uvm_info(get_type_name(), $sformatf("WRITE PASS: Received bresp == 2'b00!"), UVM_MEDIUM)
        end

    endfunction

    function void write_AR(axi_read_trans rd_req);
        if ((rd_req.axi_tb_ADDR < min_hex_addr) || (rd_req.axi_tb_ADDR > max_hex_addr)) begin
            `uvm_error(get_type_name(), $sformatf("READ araddr=0x%0h out of range", rd_req.axi_tb_ADDR))
        end else begin
            `uvm_info(get_type_name(), $sformatf("Scoreboard received READ REQ: araddr=0x%0h, arsize=0x%0h, arlen=0x%0h",  rd_req.axi_tb_ADDR, rd_req.axi_tb_SIZE, rd_req.axi_tb_LEN), UVM_MEDIUM)
            current_ar_addr = rd_req.axi_tb_ADDR;
            //current_arid = rd_req.axi_tb_ARID;
            current_arsize = rd_req.axi_tb_SIZE;
            current_arlen = rd_req.axi_tb_LEN;
            num_beats = '0;
        end
    endfunction

    function void write_R(axi_read_trans rd_data);
        read_data_storage[num_beats] = rd_data.axi_tb_RDATA;

        `uvm_info(get_type_name(), $sformatf("READ DATA: rdata=%0h, rid=%0h, rresp=%0h, rlast=%0h", rd_data.axi_tb_RDATA, rd_data.axi_tb_RID, rd_data.axi_tb_RRESP, rd_data.axi_tb_RLAST), UVM_MEDIUM)

        compare_write_read_data(current_ar_addr,num_beats);

        if (num_beats == (current_arlen-1)) begin
                if (rd_data.axi_tb_RLAST !== 1'b1) begin
                    `uvm_error(get_type_name(), $sformatf("RLAST fail to assert on last beat (%0d/%0d)", num_beats, current_arlen-1))
                end else
                    `uvm_info(get_type_name(), $sformatf("RLAST asserted on last beat (%0d/%0d)", num_beats, current_arlen-1), UVM_MEDIUM)
            end
        else begin
            `uvm_info(get_type_name(), $sformatf("Waiting RLAST to be asserted on last beat (%0d/%0d)", num_beats, current_arlen), UVM_MEDIUM)
            num_beats = num_beats + 1;
            current_ar_addr = current_ar_addr + (1 << current_arsize) / num_bytes_addr_store;
        end

        if (rd_data.axi_tb_RRESP !== 2'b00) begin
            `uvm_error(get_type_name(), $sformatf("axi_tb_RRESP !== 2'b00, Received axi_tb_RRESP = 2'b%0b", rd_data.axi_tb_RRESP))
        end

    endfunction

    function void compare_write_read_data (input logic [ADDR_WIDTH-1:0] addr, input int num_beats);
        logic [DATA_WIDTH-1:0] write_data_cmp;

        index = convert_hex_addr_to_mem_index_num(addr);
        write_data_cmp = mem_array_ref[index];

        if (write_data_cmp !== read_data_storage[num_beats]) begin
            `uvm_info(get_type_name(), $sformatf("[DEBUG_WRITE_SCB] beat = %0d, addr = 0x%h, index = %d, data = 0x%h", num_beats, addr, index, write_data_cmp), UVM_MEDIUM)
            `uvm_error(get_type_name(), $sformatf("[COMPARE_FAIL] Beat %0d, Wrote 0x%h, Read 0x%h", num_beats, write_data_cmp, read_data_storage[num_beats]))
            failed_count++;
        end
        else begin
            `uvm_info(get_type_name(), $sformatf("[COMPARE_PASS] Beat %0d, Wrote 0x%h, Read 0x%h", num_beats, write_data_cmp, read_data_storage[num_beats]), UVM_MEDIUM)
            passed_count++;
        end

    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf("Test Complete. Passed: %0d Failed: %0d", passed_count, failed_count), UVM_NONE)
    endfunction
endclass