class axi_burst_rand_wr_rd_seq #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter LEN_WIDTH = 8,
    parameter SIZE_WIDTH = 3,
    parameter BURST_WIDTH = 2,
    parameter RESP_WIDTH = 2,
    parameter ID_WIDTH = 4,
    parameter STROBE_WIDTH = DATA_WIDTH/8,
    parameter ADDR_BYTE_SIZE = 1
) extends uvm_sequence #();

    `uvm_object_param_utils(axi_burst_rand_wr_rd_seq #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ))

    typedef axi_sqr_write #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH), .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)) wr_sqr_t;
    typedef axi_sqr_read  #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH), .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)) rd_sqr_t;
    wr_sqr_t p_wr_sqr;
    rd_sqr_t p_rd_sqr;

    function new (string name = "axi_burst_rand_wr_rd_seq");
        super.new(name);
    endfunction

    virtual task body();
        axi_rand_wr_seq #(ADDR_WIDTH, DATA_WIDTH, LEN_WIDTH, SIZE_WIDTH, BURST_WIDTH, RESP_WIDTH, ID_WIDTH, STROBE_WIDTH, ADDR_BYTE_SIZE) rand_wr_seq;
        axi_rand_rd_seq  #(ADDR_WIDTH, DATA_WIDTH, LEN_WIDTH, SIZE_WIDTH, BURST_WIDTH, RESP_WIDTH, ID_WIDTH, STROBE_WIDTH, ADDR_BYTE_SIZE) rand_rd_seq;

        // Retrieve the sequencer handles from config DB
        if (!uvm_config_db#(wr_sqr_t)::get(null, "uvm_test_top.env.agt", "p_wr_sqr", p_wr_sqr))
            `uvm_fatal(get_full_name(), "Failed to get p_wr_sqr from config DB!")

        if (!uvm_config_db#(rd_sqr_t)::get(null, "uvm_test_top.env.agt", "p_rd_sqr", p_rd_sqr))
            `uvm_fatal(get_full_name(), "Failed to get p_rd_sqr from config DB!")

        if (p_wr_sqr == null || p_rd_sqr == null) begin
             `uvm_fatal(get_full_name(), "Sequencer handles p_wr_sqr or p_rd_sqr are null. They must be set by the test class.")
        end

        // 1. Random Burst Writes
        `uvm_info(get_full_name(), "Starting random AXI write sequence...", UVM_LOW)
        rand_wr_seq = axi_rand_wr_seq #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH), .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE))::type_id::create("rand_wr_seq");

        // Start the writes
        rand_wr_seq.start(p_wr_sqr);

        // 2. Random Burst Reads (Run after writes are complete)
        `uvm_info(get_full_name(), "Starting coordinated random AXI read sequence...", UVM_LOW)
        rand_rd_seq = axi_rand_rd_seq #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH), .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE))::type_id::create("rand_rd_seq");

        // Pass write's wr_struct_queue content to read sequence
        rand_rd_seq.wr_struct_queue = rand_wr_seq.wr_struct_queue;

        // Start the reads
        rand_rd_seq.start(p_rd_sqr);

        `uvm_info(get_full_name(), "Random AXI Write Read sequence finished.", UVM_LOW)
    endtask

endclass