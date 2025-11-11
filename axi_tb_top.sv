module axi_tb_top ();

    // //AXI parameters
    localparam ADDR_WIDTH = 16;
    localparam DATA_WIDTH = 32;
    localparam LEN_WIDTH = 8;
    localparam SIZE_WIDTH = 3;
    localparam BURST_WIDTH = 2;
    localparam RESP_WIDTH = 2; //2-bit for OKAY, EXOKAY, SLVERR, DECERR
    localparam ID_WIDTH = 4;
    localparam STROBE_WIDTH = DATA_WIDTH/8;
    localparam ADDR_BYTE_SIZE = 1; //num of bytes each addr can store

    //Clock and reset
    logic                       axi_tb_ACLK;
    logic                       axi_tb_ARESETn;

    //Write request channel
    logic                       axi_tb_AWVALID;
    logic                       axi_tb_AWREADY;
    logic [ID_WIDTH-1:0]        axi_tb_AWID; //unique tag to enable out of order transactions
    logic [ADDR_WIDTH-1:0]      axi_tb_AWADDR;
    logic [LEN_WIDTH-1:0]       axi_tb_AWLEN; //burst length, total number of beats
    logic [SIZE_WIDTH-1:0]      axi_tb_AWSIZE; //size in bytes of each individual data transfer (beat) within the burst, 2^AxSIZE
    logic [BURST_WIDTH-1:0]     axi_tb_AWBURST; //Burst type - 2'b00: FIXED, 2'b01: INCR, 2'b10: WRAP, 2'b11: Reserved

    //Write data channel
    logic                       axi_tb_WVALID;
    logic                       axi_tb_WREADY;
    logic [DATA_WIDTH-1:0]      axi_tb_WDATA;
    logic [STROBE_WIDTH-1:0]    axi_tb_WSTRB;
    logic                       axi_tb_WLAST;

    //Write response channel
    logic                       axi_tb_BVALID;
    logic                       axi_tb_BREADY;
    logic [ID_WIDTH-1:0]        axi_tb_BID;
    logic [RESP_WIDTH-1:0]      axi_tb_BRESP;

    //Read request channel
    logic                       axi_tb_ARVALID;
    logic                       axi_tb_ARREADY;
    logic [ID_WIDTH-1:0]        axi_tb_ARID;
    logic [ADDR_WIDTH-1:0]      axi_tb_ARADDR;
    logic [LEN_WIDTH-1:0]       axi_tb_ARLEN;
    logic [SIZE_WIDTH-1:0]      axi_tb_ARSIZE;
    logic [BURST_WIDTH-1:0]     axi_tb_ARBURST;

    //Read data channel
    logic                       axi_tb_RVALID;
    logic                       axi_tb_RREADY;
    logic [ID_WIDTH-1:0]        axi_tb_RID;
    logic [DATA_WIDTH-1:0]      axi_tb_RDATA;
    logic [RESP_WIDTH-1:0]      axi_tb_RRESP;
    logic                       axi_tb_RLAST;

    logic [DATA_WIDTH-1:0] write_data_storage [LEN_WIDTH-1:0];
    logic [DATA_WIDTH-1:0] read_data_storage  [LEN_WIDTH-1:0];
    logic [LEN_WIDTH-1:0] num_beats;

    //localparam MEM_DEPTH = 256;
    localparam MEM_DEPTH = (1 << ADDR_WIDTH) - 1;
    reg [DATA_WIDTH-1:0] mem_array_ref [MEM_DEPTH-1:0]; //0x000 to 0x3fc for MEM_DEPTH = 256
    reg [ADDR_WIDTH-1:0] current_aw_addr;

    // Calculates the number of LSBs to shift to convert byte-address to word-index.  0x0000 -> 0x0003 = index 0, 0x0004 -> 0x0007 = index 1
    // Equivalent to log2(DATA_WIDTH / 8). For 32-bit width, this returns 2.
    function automatic integer get_addr_shift_amount();
        integer shift = 0;
        integer word_bytes = DATA_WIDTH / 8; //num of bytes each mem_array row can store
        while (word_bytes > 1) begin //find N value of log2 (word_bytes) = N
            word_bytes = word_bytes >> 1;
            shift = shift + 1;
        end
        return shift;
    endfunction
    localparam ADDR_SHIFT = get_addr_shift_amount();

    //Alternative to convert hex address to mem_array index
    real num_bytes_mem_row_store = DATA_WIDTH / 8;
    real num_bytes_addr_store = ADDR_BYTE_SIZE;
    logic [ADDR_WIDTH-1:0] min_hex_addr = '0;
    logic [ADDR_WIDTH-1:0] max_hex_addr = (MEM_DEPTH-1) * num_bytes_mem_row_store / num_bytes_addr_store;
    integer index;

    task automatic convert_hex_addr_to_mem_index_num(
        input logic [ADDR_WIDTH-1:0] addr,
        output int index_num
    );
        index_num = addr * (num_bytes_addr_store / num_bytes_mem_row_store);
    endtask


    localparam SIZE = 2;
    localparam LEN = 7;
    localparam BURST_TYPE = 2'b01; //INCR
    localparam ID = 4'hA;

    real ACLK_FREQ = 200;
    real ACLK_PERIOD_NS = 1/ACLK_FREQ*1000;

    initial begin
        axi_tb_ACLK = 0;
        forever begin
            #(ACLK_PERIOD_NS/2 * 1ns) axi_tb_ACLK = ~axi_tb_ACLK;
        end
    end

    axi_dut #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .LEN_WIDTH (LEN_WIDTH),
        .SIZE_WIDTH (SIZE_WIDTH),
        .BURST_WIDTH (BURST_WIDTH),
        .RESP_WIDTH (RESP_WIDTH),
        .ID_WIDTH (ID_WIDTH),
        .STROBE_WIDTH (STROBE_WIDTH),
        .ADDR_BYTE_SIZE (ADDR_BYTE_SIZE)
    ) dut (
        .axi_ACLK(axi_tb_ACLK),
        .axi_ARESETn(axi_tb_ARESETn),
        .axi_AWVALID(axi_tb_AWVALID),
        .axi_AWREADY(axi_tb_AWREADY),
        .axi_AWID(axi_tb_AWID),
        .axi_AWADDR(axi_tb_AWADDR),
        .axi_AWLEN(axi_tb_AWLEN),
        .axi_AWSIZE(axi_tb_AWSIZE),
        .axi_AWBURST(axi_tb_AWBURST),
        .axi_WVALID(axi_tb_WVALID),
        .axi_WREADY(axi_tb_WREADY),
        .axi_WDATA(axi_tb_WDATA),
        .axi_WSTRB(axi_tb_WSTRB),
        .axi_WLAST(axi_tb_WLAST),
        .axi_BVALID(axi_tb_BVALID),
        .axi_BREADY(axi_tb_BREADY),
        .axi_BID(axi_tb_BID),
        .axi_BRESP(axi_tb_BRESP),
        .axi_ARVALID(axi_tb_ARVALID),
        .axi_ARREADY(axi_tb_ARREADY),
        .axi_ARID(axi_tb_ARID),
        .axi_ARADDR(axi_tb_ARADDR),
        .axi_ARLEN(axi_tb_ARLEN),
        .axi_ARSIZE(axi_tb_ARSIZE),
        .axi_ARBURST(axi_tb_ARBURST),
        .axi_RVALID(axi_tb_RVALID),
        .axi_RREADY(axi_tb_RREADY),
        .axi_RID(axi_tb_RID),
        .axi_RDATA(axi_tb_RDATA),
        .axi_RRESP(axi_tb_RRESP),
        .axi_RLAST(axi_tb_RLAST)
    );

    initial begin
        init_write_reg();
        init_read_reg();
        num_beats <= '0;

        start_reset_seq();

        send_write(min_hex_addr, 4'b1111);
        send_write(16'hF0, 4'b1111);
        send_write(max_hex_addr/2, 4'b1111);
        send_write(max_hex_addr, 4'b1111);

        send_read(min_hex_addr);
        compare_write_read_data(min_hex_addr);

        send_read(16'hF0);
        compare_write_read_data(16'hF0);

        send_read(max_hex_addr/2);
        compare_write_read_data(max_hex_addr/2);

        send_read(max_hex_addr);
        compare_write_read_data(max_hex_addr);

        #1000ns;
        $display("--- Test Finished at %0t ---", $time);
        $finish;
    end

    task init_write_reg();
        axi_tb_AWVALID <= '0;
        axi_tb_AWID <= '0;
        axi_tb_AWADDR <= '0;
        axi_tb_AWLEN <= '0;
        axi_tb_AWSIZE <= '0;
        axi_tb_AWBURST <= '0;
        axi_tb_WVALID <= '0;
        axi_tb_WDATA <= '0;
        axi_tb_WSTRB <= '0;
        axi_tb_WLAST <= '0;
        axi_tb_BREADY <= 1'b1;
        current_aw_addr <= '0;
    endtask

    task init_read_reg();
        axi_tb_ARVALID <= '0;
        axi_tb_ARID <= '0;
        axi_tb_ARADDR <= '0;
        axi_tb_ARLEN <= '0;
        axi_tb_ARSIZE <= '0;
        axi_tb_ARBURST <= '0;
        axi_tb_RREADY <= 1'b1;
    endtask

    task start_reset_seq();
        $display("@%0t: Starting reset sequence...", $time);
        axi_tb_ARESETn <= 1'b0;
        repeat(10) @(posedge axi_tb_ACLK);
        axi_tb_ARESETn <= 1'b1;
        $display("@%0t: Reset released.", $time);
    endtask

    task send_write(
        input logic [15:0] addr,
        input logic [3:0] strobe
    );
        logic [DATA_WIDTH-1:0] data_out;

        $display("@%0t: Starting WRITE Burst to addr = 0x%h", $time, addr);
        @(posedge axi_tb_ACLK);
        axi_tb_AWVALID <= 1'b1;
        axi_tb_AWADDR <= {{(ADDR_WIDTH - 16){1'b0}}, addr};
        axi_tb_AWID <= {{(ID_WIDTH - 4){1'b0}}, ID};
        axi_tb_AWLEN <= {{(LEN_WIDTH - 8){1'b0}}, LEN};
        axi_tb_AWSIZE <= {{(SIZE_WIDTH - 3){1'b0}}, SIZE};
        axi_tb_AWBURST <= {{(BURST_WIDTH - 2){1'b0}}, BURST_TYPE};
        axi_tb_WLAST <= 1'b0;
        current_aw_addr <= addr;
        num_beats <= LEN;

        while (axi_tb_AWREADY !== 1'b1) begin
            @(posedge axi_tb_ACLK);
            $display("@%0t: Waiting for axi_AWREADY to be 1.", $time);
        end

        @(posedge axi_tb_ACLK);
        axi_tb_AWVALID <= 1'b0;
        axi_tb_WVALID <= 1'b1;
        axi_tb_WSTRB <= {{(STROBE_WIDTH - 4){1'b0}}, strobe} >>  (STROBE_WIDTH - (1 << SIZE));

        for (int i = 0; i < num_beats; i++ ) begin
            data_out = {$random};
            //write_data_storage[i] = data_out;
            axi_tb_WDATA <= data_out;

            for (integer i = 0; i < STROBE_WIDTH; i++) begin
                if (strobe[i]) begin
                    // Correctly access index memory array using ADDR_SHIFT
                    //mem_array_ref[current_aw_addr >> ADDR_SHIFT][i*8 +: 8] <= data_out[i*8 +: 8];

                    convert_hex_addr_to_mem_index_num(current_aw_addr, index);
                    mem_array_ref[index][i*8 +: 8] <= data_out[i*8 +: 8];
                end
            end
            //$display("@%0t: [WRITE_TB, BEAT %0d] addr=0x%h, index %d, data = 0x%h", $time, i, current_aw_addr, current_aw_addr >> ADDR_SHIFT,  data_out);

            if (i == (num_beats-1)) begin
                axi_tb_WLAST <= 1'b1;
                $display("@%0t: [WRITE_TB] beat = %0d, addr = 0x%h, index = %0d, data = 0x%h, WLAST = %0b", $time, i, current_aw_addr, index, data_out, 1);

            end
            else begin
                $display("@%0t: [WRITE_TB] beat = %0d, addr = 0x%h, index = %0d, data = 0x%h, WLAST = %0b", $time, i, current_aw_addr, index, data_out, axi_tb_WLAST);
                current_aw_addr <= current_aw_addr + (1 << SIZE) / num_bytes_addr_store;
                @(posedge axi_tb_ACLK); //add this to make it loop every posedge clk. Otherwise the for loop ends in 1 clk cycle
            end

            while (axi_tb_WREADY !== 1'b1) begin
                @(posedge axi_tb_ACLK);
                $display("Waiting WREADY == 1.");
            end

        end

        @(posedge axi_tb_ACLK);
        init_write_reg();

        while (axi_tb_BVALID !== 1'b1) begin
            @(posedge axi_tb_ACLK);
            $display("Waiting BVALID == 1.");
        end

        while (axi_tb_BVALID && axi_tb_BREADY) begin
            if (axi_tb_BRESP !== 2'b00) begin
                $error("WRITE FAIL: BRESP returned 0x%h (Expected 0x00)", axi_tb_BRESP);
            end else begin
                $display("WRITE PASS: BRESP 0x00 OKAY received.");
            end
            @(posedge axi_tb_ACLK);
        end

        init_write_reg();

    endtask

    task send_read(
        input logic [15:0] addr
    );
        $display("@%0t: Starting READ Burst from addr = 0x%h", $time, addr);
        @(posedge axi_tb_ACLK);
        axi_tb_ARVALID <= 1'b1;
        axi_tb_ARADDR <= {{(ADDR_WIDTH - 16){1'b0}}, addr};
        axi_tb_ARID <= {{(ID_WIDTH - 4){1'b0}}, ID};
        axi_tb_ARLEN <= {{(LEN_WIDTH - 8){1'b0}}, LEN};
        axi_tb_ARSIZE <= {{(SIZE_WIDTH - 3){1'b0}}, SIZE};
        axi_tb_ARBURST <= {{(BURST_WIDTH - 2){1'b0}}, BURST_TYPE};

        while (axi_tb_ARREADY !== 1'b1) begin
            @(posedge axi_tb_ACLK);
        end

        @(posedge axi_tb_ACLK);
        axi_tb_ARVALID <= 1'b0;

        while (axi_tb_RVALID !== 1'b1) begin
            @(posedge axi_tb_ACLK);
        end

        for (int i = 0; i < num_beats; i++ ) begin
            read_data_storage[i] <= axi_tb_RDATA;

            $display("@%0t: [READ_TB] beat = %0d, data = 0x%h, RLAST = %0b, RRESP = 0x%h", $time, i, axi_tb_RDATA, axi_tb_RLAST, axi_tb_RRESP);

            if (i == (num_beats-1)) begin
                if (axi_tb_RLAST !== 1'b1) begin
                    $error("@%0t: ERROR: RLAST fail to assert on last beat (%0d/%0d)", $time, i, (num_beats-1));
                end else
                    $display("@%0t: RLAST asserted on last beat (%0d/%0d)", $time, i, (num_beats-1));
                if (axi_tb_RRESP !== 2'b00) begin
                    $error("@%0t: ERROR: axi_tb_RRESP !== 2'b00", $time);
                    //$fatal;
                end
            end
            else begin
                $display("@%0t: Waiting RLAST to be asserted on last beat (%0d/%0d)", $time, i, (num_beats-1));
                @(posedge axi_tb_ACLK);
            end
        end

        @(posedge axi_tb_ACLK);
        init_write_reg();
        $display("@%0t: READ Burst complete.", $time);

    endtask

    task compare_write_read_data(
        input logic [15:0] addr
    );
        int i;
        logic [DATA_WIDTH-1:0] write_data_cmp;

        $display("@%0t: --- Data Comparison Start ---", $time);

        for (i = 0; i < num_beats; i++) begin
            //write_data_cmp = mem_array_ref[addr >> ADDR_SHIFT];
            convert_hex_addr_to_mem_index_num(addr, index);
            write_data_cmp = mem_array_ref[index];

            if (write_data_cmp !== read_data_storage[i]) begin
                //$display("@%0t: [DEBUG_WRITE_TB] beat = %0d, addr = 0x%h, index = %d, data = 0x%h", $time, i, addr, addr >> ADDR_SHIFT, write_data_cmp);
                $display("@%0t: [DEBUG_WRITE_TB] beat = %0d, addr = 0x%h, index = %d, data = 0x%h", $time, i, addr, index, write_data_cmp);
                $error("@%0t: [COMPARE_FAIL] Beat %0d, Wrote 0x%h, Read 0x%h", $time, i, write_data_cmp, read_data_storage[i]);
            end
            else begin
                //$display("@%0t: [DEBUG_WRITE_TB] beat = %0d, addr = 0x%h, index = %d, data = 0x%h", $time, i, addr, addr >> ADDR_SHIFT, write_data_cmp);
                $display("@%0t: [DEBUG_WRITE_TB] beat = %0d, addr = 0x%h, index = %d, data = 0x%h", $time, i, addr, index, write_data_cmp);
                $display("@%0t: [COMPARE_PASS] Beat %0d, Wrote 0x%h, Read 0x%h", $time, i, write_data_cmp, read_data_storage[i]);
            end
            addr = addr + (1 << SIZE) / num_bytes_addr_store;
        end
    endtask

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpSVA(0, axi_tb_top);
        $fsdbDumpvars(0, axi_tb_top);
    end

endmodule