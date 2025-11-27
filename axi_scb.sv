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

    // implementation ports (IMPs) connected to monitor
    uvm_analysis_imp_AW #(axi_write_trans, axi_scb) scb_wr_req_imp;
    uvm_analysis_imp_W #(axi_write_trans, axi_scb) scb_wr_data_imp;
    uvm_analysis_imp_B #(axi_write_trans, axi_scb) scb_wr_resp_imp;
    uvm_analysis_imp_AR #(axi_read_trans, axi_scb) scb_rd_req_imp;
    uvm_analysis_imp_R #(axi_read_trans, axi_scb) scb_rd_data_imp;

    // Associative arrays for concurrent burst tracking
    // Accessible by AXI ID to track multiple bursts simultaneously
    axi_burst_trans wr_bursts [logic [ID_WIDTH-1:0]];
    axi_burst_trans rd_bursts [logic [ID_WIDTH-1:0]];

    int passed_count = 0;
    int failed_count = 0;

    // Reference memory model
    // The memory array size is based on the address width parameter.
    localparam MEM_DEPTH = (1 << ADDR_WIDTH);
    reg [DATA_WIDTH-1:0] mem_array_ref [MEM_DEPTH-1:0];

    // Parameters for mem index calculation
    real num_bytes_mem_row_store = DATA_WIDTH / 8;
    real num_bytes_addr_store = ADDR_BYTE_SIZE;
    logic [ADDR_WIDTH-1:0] min_hex_addr = '0;
    logic [ADDR_WIDTH-1:0] max_hex_addr = ((MEM_DEPTH) * num_bytes_mem_row_store / num_bytes_addr_store) - 1;

    // convert hex AXI address to a word index for the reference memory
    function automatic int convert_hex_addr_to_mem_index_num(
        input logic [ADDR_WIDTH-1:0] addr
    );
        return (addr * num_bytes_addr_store) / num_bytes_mem_row_store;
    endfunction

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase (uvm_phase phase);
        super.build_phase(phase);

        // Create the implementation imports
        scb_wr_req_imp = new("scb_wr_req_imp", this);
        scb_wr_data_imp = new("scb_wr_data_imp", this);
        scb_wr_resp_imp = new("scb_wr_resp_imp", this);
        scb_rd_req_imp = new("scb_rd_req_imp", this);
        scb_rd_data_imp = new("scb_rd_data_imp", this);
    endfunction

    // AW Channel: Receives the write address request (Start of a burst)
    function void write_AW(axi_write_trans wr_req);
        if (!((wr_req.axi_tb_ADDR < min_hex_addr) || (wr_req.axi_tb_ADDR > max_hex_addr))) begin

            axi_burst_trans current_burst;
            int num_beats = wr_req.axi_tb_LEN + 1;

            `uvm_info(get_type_name(), $sformatf("Scoreboard received AW_REQ: AWADDR=0x%0h, AWID=0x%h, AWLEN=0x%0h, AWSIZE=0x%0h, AWBURST=0x%0h, num_beats=%0d beats", wr_req.axi_tb_ADDR, wr_req.axi_tb_ID, wr_req.axi_tb_LEN, wr_req.axi_tb_SIZE, wr_req.axi_tb_BURST, num_beats), UVM_MEDIUM)

            // Create new burst transaction
            current_burst = axi_burst_trans#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                                             .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                                             .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH))::type_id::create("current_write_burst");
            current_burst.is_write = 1;
            current_burst.addr = wr_req.axi_tb_ADDR;
            current_burst.id   = wr_req.axi_tb_ID;
            current_burst.len  = wr_req.axi_tb_LEN;
            current_burst.size = wr_req.axi_tb_SIZE;
            current_burst.burst = wr_req.axi_tb_BURST;

            // Pre-allocate dynamic arrays using (LEN + 1 beats total)
            current_burst.w_data_beats = new[num_beats];
            current_burst.w_strobe_beats = new[num_beats];

            // Store the transaction using the ID as the key
            wr_bursts[current_burst.id] = current_burst;

            `uvm_info(get_type_name(), $sformatf("Stored AW_REQ into wr_bursts[%0h]:\n%s", current_burst.id, wr_bursts[current_burst.id].sprint()), UVM_MEDIUM)

        end
        else begin
            `uvm_error(get_type_name(), $sformatf("Write addr=0x%0h out of range", wr_req.axi_tb_ADDR))
        end
    endfunction

    // W Channel: Receives a single write data beat
    function void write_W(axi_write_trans wr_data);
        logic [ID_WIDTH-1:0] id = wr_data.axi_tb_ID;
        axi_burst_trans current_burst;
        int beat_num;

        if (!wr_bursts.exists(id)) begin
            `uvm_error(get_type_name(), $sformatf("WDATA received for unknown ID 0x%h. AW was missed.", id))
            return;
        end

        current_burst = wr_bursts[id]; //current_burst is pointing to object wr_bursts[id], updates on current_burst will reflect on wr_bursts[id]
        beat_num = current_burst.beats_received;

        `uvm_info(get_type_name(), $sformatf("Scoreboard received WDATA: AWID=0x%h, Beat=%0d, WDATA=0x%h, WSTRB=0x%h", id, beat_num, wr_data.axi_tb_WDATA[0], wr_data.axi_tb_WSTRB[0]), UVM_MEDIUM)

        // Check for beat limit (LEN + 1)
        if (beat_num > current_burst.len) begin
            `uvm_error(get_type_name(), $sformatf("WDATA overflow on ID 0x%h. Expected %0d beats, received %0d.", id, current_burst.len + 1, beat_num + 1))
            return;
        end

        // Access index[0] from monitor. Monitor samples each individual beat
        current_burst.w_data_beats[beat_num] = wr_data.axi_tb_WDATA[0];
        current_burst.w_strobe_beats[beat_num] = wr_data.axi_tb_WSTRB[0];

        `uvm_info(get_type_name(), $sformatf("Stored WDATA into wr_bursts[%0h]:\n%s", current_burst.id, wr_bursts[current_burst.id].sprint()), UVM_MEDIUM)

        // Update the reference memory model
        update_ref_memory(current_burst, wr_data.axi_tb_WDATA[0], wr_data.axi_tb_WSTRB[0]);

        // Update beat counter and check WLAST
        current_burst.beats_received++;

        if (wr_data.axi_tb_WLAST) begin
            if (current_burst.beats_received != (current_burst.len + 1)) begin
                `uvm_error(get_type_name(), $sformatf("WLAST asserted early on ID 0x%h. Expected %0d beats, got %0d.", id, current_burst.len + 1, current_burst.beats_received))
            end else begin
                `uvm_info(get_type_name(), $sformatf("WLAST asserted correctly on ID 0x%h. Waiting for BRESP.", id), UVM_MEDIUM)
            end
        end
        else if (current_burst.beats_received == (current_burst.len + 1)) begin
            `uvm_error(get_type_name(), $sformatf("WLAST not asserted on last beat for ID 0x%h. Beat %0d/%0d.", id, current_burst.beats_received, current_burst.len + 1))
        end

    endfunction

    virtual protected function void update_ref_memory(
        axi_burst_trans burst,
        input logic [DATA_WIDTH-1:0] data,
        input logic [STROBE_WIDTH-1:0] strobe
    );
        logic [ADDR_WIDTH-1:0] current_addr;
        // burst.beats_received is the index of the beat being written (0 for the first beat)
        int beat_offset_bytes = (burst.beats_received * (1 << burst.size));
        int index;

        // Calculate the address for the current beat (assuming INCR burst)
        current_addr = burst.addr + (beat_offset_bytes / num_bytes_addr_store);

        index = convert_hex_addr_to_mem_index_num(current_addr);

        if (index >= MEM_DEPTH) begin
            `uvm_error(get_type_name(), $sformatf("Memory Index 0x%h out of bounds (max %0d)", index, MEM_DEPTH-1))
            return;
        end

        // Apply byte strobes to update the reference memory
        for (integer i = 0; i < STROBE_WIDTH; i++) begin
            if (strobe[i]) begin
                mem_array_ref[index][i*8 +: 8] = data[i*8 +: 8];
            end
        end

        `uvm_info(get_type_name(), $sformatf("WRITE to mem_array_ref: AWADDR=0x%h, Index=%0d, WDATA=0x%h, WSTRB=0x%h", current_addr, index, data, strobe), UVM_MEDIUM)

    endfunction

    // B Channel: Receives the write response (End of a burst)
    function void write_B(axi_write_trans wr_resp);
        logic [ID_WIDTH-1:0] id = wr_resp.axi_tb_BID;
        logic [RESP_WIDTH-1:0] expected_bresp = 2'b00; // OKAY

        if (!wr_bursts.exists(id)) begin
            `uvm_error(get_type_name(), $sformatf("BRESP received for unknown ID 0x%h.", id))
            return;
        end

        // Check for expected response
        if (wr_resp.axi_tb_BRESP !== expected_bresp) begin
            `uvm_error(get_type_name(), $sformatf("WRITE FAIL (BID 0x%h): Expected BRESP 0x%h, Received 0x%h", id, expected_bresp, wr_resp.axi_tb_BRESP))
            failed_count++;
        end else begin
            `uvm_info(get_type_name(), $sformatf("WRITE PASS (BID 0x%h): BRESP OKAY (0x%h)", id, wr_resp.axi_tb_BRESP), UVM_MEDIUM)
            passed_count++;
        end

        wr_bursts[id].b_resp = wr_resp.axi_tb_BRESP;

        `uvm_info(get_type_name(), $sformatf("Check wr_bursts[%0h]:\n%s", id, wr_bursts[id].sprint()), UVM_MEDIUM)

        // Remove the completed transaction from the wr_bursts list
        void'(wr_bursts.delete(id));
    endfunction

    // AR Channel: Receives the read address request (Start of a burst)
    function void write_AR(axi_read_trans rd_req);
        if (!((rd_req.axi_tb_ADDR < min_hex_addr) || (rd_req.axi_tb_ADDR > max_hex_addr))) begin

            axi_burst_trans current_burst;
            int num_beats = rd_req.axi_tb_LEN + 1;

            `uvm_info(get_type_name(), $sformatf("Scoreboard received AR REQ: ARID=0x%h, ARADDR=0x%0h, ARLEN=0x%0h, num_beats=%0d", rd_req.axi_tb_ID, rd_req.axi_tb_ADDR, rd_req.axi_tb_LEN, num_beats), UVM_MEDIUM)

            // Create new burst transaction
            current_burst = axi_burst_trans#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                                             .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                                             .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH))::type_id::create("current_read_burst");
            current_burst.is_write = 0;
            current_burst.addr = rd_req.axi_tb_ADDR;
            current_burst.id   = rd_req.axi_tb_ID;
            current_burst.len  = rd_req.axi_tb_LEN;
            current_burst.size = rd_req.axi_tb_SIZE;
            current_burst.burst = rd_req.axi_tb_BURST;

            // Pre-allocate dynamic arrays for received data and responses
            current_burst.r_data_beats = new[num_beats]; // Used for expected and received data storage
            current_burst.r_resp_beats = new[num_beats];

            // Pre-fetch the expected data from the reference memory
            fetch_expected_read_data(current_burst);

            // Store the incoming transaction
            rd_bursts[current_burst.id] = current_burst;

            `uvm_info(get_type_name(), $sformatf("Stored AR_REQ into rd_bursts[%0h]:\n%s", current_burst.id, rd_bursts[current_burst.id].sprint()), UVM_MEDIUM)
        end
        else begin
            `uvm_error(get_type_name(), $sformatf("ARADDR=0x%0h out of range", rd_req.axi_tb_ADDR))
        end
    endfunction

    virtual protected function void fetch_expected_read_data(axi_burst_trans burst);
        logic [ADDR_WIDTH-1:0] current_addr = burst.addr;
        int num_beats = burst.len + 1;
        int index;

        for (int beat = 0; beat < num_beats; beat++) begin
            index = convert_hex_addr_to_mem_index_num(current_addr);

            if (index >= MEM_DEPTH) begin
                `uvm_warning(get_type_name(), $sformatf("Read fetch index 0x%h out of bounds. Using 0.", index))
                burst.r_data_beats[beat] = '0;
            end else begin
                // r_data_beats array to store expected data for comparison
                burst.r_data_beats[beat] = mem_array_ref[index];
            end

            // Calculate next address (assuming INCR burst)
            current_addr += (1 << burst.size) / num_bytes_addr_store;
        end

        `uvm_info(get_type_name(), $sformatf("READ from mem_array_ref: ID 0x%h, Expected first data 0x%h", burst.id, burst.r_data_beats[0]), UVM_MEDIUM)
    endfunction


    // R Channel: Receives a single read data beat
    function void write_R(axi_read_trans rd_data);
        logic [ID_WIDTH-1:0] id = rd_data.axi_tb_RID;
        axi_burst_trans current_burst;
        logic [DATA_WIDTH-1:0] expected_data;
        int beat_num;

        if (!rd_bursts.exists(id)) begin
            `uvm_error(get_type_name(), $sformatf("RDATA received for unknown ID 0x%h. AR was missed.", id))
            return;
        end

        current_burst = rd_bursts[id];
        beat_num = current_burst.beats_received;

        // Check for beat limit
        if (beat_num > current_burst.len) begin
            `uvm_error(get_type_name(), $sformatf("RDATA overflow on ID 0x%h. Expected %0d beats, received %0d.", id, current_burst.len + 1, beat_num + 1))
            return;
        end

        // Data Comparison (compare received data against pre-fetched expected data)
        expected_data = current_burst.r_data_beats[beat_num];
        // Access the scalar element at index [0] from the monitor's transaction
        if (expected_data !== rd_data.axi_tb_RDATA[0]) begin
            `uvm_error(get_type_name(), $sformatf("[COMPARE_FAIL] RID 0x%h, Beat %0d: Expected 0x%h, Received 0x%h", id, beat_num, expected_data, rd_data.axi_tb_RDATA[0]))
            failed_count++;
        end else begin
            `uvm_info(get_type_name(), $sformatf("[COMPARE_PASS] MATCH! RID 0x%h, Beat %0d: Expected 0x%h, Received 0x%h", id, beat_num, expected_data, rd_data.axi_tb_RDATA[0]), UVM_MEDIUM)
            passed_count++;
        end

        // Store the received response for later checks
        // Access index [0] from the monitor's transaction
        current_burst.r_resp_beats[beat_num] = rd_data.axi_tb_RRESP[0];

        `uvm_info(get_type_name(), $sformatf("Stored RDATA into rd_bursts[%0h]:\n%s", current_burst.id, rd_bursts[current_burst.id].sprint()), UVM_MEDIUM)

        // Update beat counter and check RLAST
        current_burst.beats_received++;

        if (rd_data.axi_tb_RLAST) begin
            if (current_burst.beats_received != (current_burst.len + 1)) begin
                `uvm_error(get_type_name(), $sformatf("RLAST asserted early on RID 0x%h. Expected %0d beats, got %0d.", id, current_burst.len + 1, current_burst.beats_received))
            end else begin
                `uvm_info(get_type_name(), $sformatf("RLAST asserted correctly on RID 0x%h. Burst Complete.", id), UVM_MEDIUM)
                // Remove the completed transaction
                void'(rd_bursts.delete(id));
            end
        end
        else if (current_burst.beats_received == (current_burst.len + 1)) begin
            `uvm_error(get_type_name(), $sformatf("RLAST not asserted on last beat for RID 0x%h. Beat %0d/%0d.", id, current_burst.beats_received, current_burst.len + 1))
        end

    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf("Test Complete. Passed: %0d Failed: %0d", passed_count, failed_count), UVM_MEDIUM)
    endfunction
endclass