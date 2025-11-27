class axi_read_seq #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter LEN_WIDTH = 8,
    parameter SIZE_WIDTH = 3,
    parameter BURST_WIDTH = 2,
    parameter RESP_WIDTH = 2,
    parameter ID_WIDTH = 4,
    parameter STROBE_WIDTH = DATA_WIDTH/8,
    parameter ADDR_BYTE_SIZE = 1
) extends uvm_sequence #(axi_read_trans #(
    .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
    .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
    .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
));

    `uvm_object_param_utils(axi_read_seq #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ))

    axi_read_trans #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ) rd_tr;

    function new(string name = "axi_read_seq");
        super.new(name);
    endfunction

    virtual task body();
        // 1st Read
        `uvm_info(get_type_name(), "Starting Directed Read 1", UVM_MEDIUM)

        // Create new transaction
        rd_tr = axi_read_trans #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                                 .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                                 .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
                                )::type_id::create("rd_tr1");

        // Set directed values
        rd_tr.axi_tb_ADDR = 16'h1000;
        rd_tr.axi_tb_ID   = 4'hF;
        rd_tr.axi_tb_LEN = 8'h0;
        rd_tr.axi_tb_SIZE = 3'b10; //4 bytes
        rd_tr.axi_tb_BURST = 2'b01; //INCR

        // Execute the transaction
        start_item(rd_tr);
        finish_item(rd_tr);

        `uvm_info(get_type_name(), $sformatf("Directed Read 1: %s", rd_tr.convert2string()), UVM_MEDIUM)

        // 2nd Read
        `uvm_info(get_type_name(), "Starting Directed Read 2", UVM_MEDIUM)

        rd_tr = axi_read_trans#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                                 .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                                 .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
                                )::type_id::create("rd_tr2");

        rd_tr.axi_tb_ADDR = 16'h2000;
        rd_tr.axi_tb_ID   = 4'hA;
        rd_tr.axi_tb_LEN = 8'h0;
        rd_tr.axi_tb_SIZE = 3'h2;
        rd_tr.axi_tb_BURST = 2'b01; //INCR

        start_item(rd_tr);
        finish_item(rd_tr);

        `uvm_info(get_type_name(), $sformatf("Directed Read 2: %s", rd_tr.convert2string()), UVM_MEDIUM)

    endtask

endclass