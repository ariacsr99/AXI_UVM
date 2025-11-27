class axi_write_seq #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter LEN_WIDTH = 8,
    parameter SIZE_WIDTH = 3,
    parameter BURST_WIDTH = 2,
    parameter RESP_WIDTH = 2,
    parameter ID_WIDTH = 4,
    parameter STROBE_WIDTH = DATA_WIDTH/8,
    parameter ADDR_BYTE_SIZE = 1
) extends uvm_sequence #(axi_write_trans #(
    .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
    .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
    .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
));

    `uvm_object_param_utils(axi_write_seq #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ))

    axi_write_trans #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ) wr_tr;

    function new(string name = "axi_write_seq");
        super.new(name);
    endfunction

    virtual task body();

        int num_beats;

        // 1st Write (Single Beat, LEN=0)
        `uvm_info(get_type_name(), "Starting Directed Write 1 (Single Beat, LEN=0)", UVM_MEDIUM)

        wr_tr = axi_write_trans #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                                 .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                                 .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
                                 )::type_id::create("wr_tr1");


        // Set directed values (AW Channel)
        wr_tr.axi_tb_ADDR = 16'h1000;
        wr_tr.axi_tb_ID   = 4'hF;
        wr_tr.axi_tb_LEN = 8'h0;    // LEN=0 means 1 beat total
        wr_tr.axi_tb_SIZE = 3'b10;  // 4 bytes
        wr_tr.axi_tb_BURST = 2'b01; // INCR

        // Calculate the number of beats (0 + 1 = 1)
        num_beats = wr_tr.axi_tb_LEN + 1;

        // Allocate the dynamic arrays to hold exactly 1 beat
        wr_tr.axi_tb_WDATA = new[num_beats];
        wr_tr.axi_tb_WSTRB = new[num_beats];

        // Populate the single beat at index 0
        wr_tr.axi_tb_WDATA[0] = 32'hDEAD_BEEF;
        wr_tr.axi_tb_WSTRB[0] = 4'b1111;

        start_item(wr_tr);
        finish_item(wr_tr);

        `uvm_info(get_type_name(), $sformatf("Directed Write 1: %s", wr_tr.convert2string()), UVM_MEDIUM)


        // 2nd Write (Single Beat, LEN=0)
        `uvm_info(get_type_name(), "Starting Directed Write 2 (Single Beat, LEN=0)", UVM_MEDIUM)

        wr_tr = axi_write_trans#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                                 .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                                 .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
                                 )::type_id::create("wr_tr2");

        // Set directed values (AW Channel)
        wr_tr.axi_tb_ADDR = 16'h2000;
        wr_tr.axi_tb_ID   = 4'hA;
        wr_tr.axi_tb_LEN = 8'h0; // LEN=0 means 1 beat total
        wr_tr.axi_tb_SIZE = 3'h2;
        wr_tr.axi_tb_BURST = 2'b01;

        // Calculate the number of beats (0 + 1 = 1)
        num_beats = wr_tr.axi_tb_LEN + 1;

        // Allocate the dynamic arrays to hold exactly 1 beat
        wr_tr.axi_tb_WDATA = new[num_beats];
        wr_tr.axi_tb_WSTRB = new[num_beats];

        // Populate the single beat at index 0
        wr_tr.axi_tb_WDATA[0] = 32'h1234_ABCD;
        wr_tr.axi_tb_WSTRB[0] = 4'b1111;

        start_item(wr_tr);
        finish_item(wr_tr);

        `uvm_info(get_type_name(), $sformatf("Directed Write 2: %s", wr_tr.convert2string()), UVM_MEDIUM)

    endtask

endclass