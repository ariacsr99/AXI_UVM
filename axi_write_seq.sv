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

    // Override the base class body to implement the directed traffic
    virtual task body();

        //1st Write
        `uvm_info(get_type_name(), "Starting Directed Write 1", UVM_MEDIUM)

        // Create new transaction using the base class handle (wr_tr)
        wr_tr = axi_write_trans #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                                 .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                                 .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
                                )::type_id::create("wr_tr1");


        // Set directed values BEFORE calling super.body()
        wr_tr.axi_tb_ADDR = 16'h1000;
        wr_tr.axi_tb_ID   = 4'hF;
        wr_tr.axi_tb_LEN = 8'h1;
        wr_tr.axi_tb_SIZE = 3'b10; //4 bytes
        wr_tr.axi_tb_BURST = 2'b01; //INCR
        wr_tr.axi_tb_WDATA  = 32'hDEAD_BEEF;
        wr_tr.axi_tb_WSTRB = 4'b1111;

        start_item(wr_tr);
        finish_item(wr_tr);

        `uvm_info(get_type_name(), $sformatf("Directed Write 1: Addr = 0x%0h, AWID = 0x%0h, Data = 0x%0h", wr_tr.axi_tb_ADDR, wr_tr.axi_tb_ID, wr_tr.axi_tb_WDATA), UVM_MEDIUM)


        // 2nd Write
        `uvm_info(get_type_name(), "Starting Directed Write 2", UVM_MEDIUM)

        wr_tr = axi_write_trans#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                                 .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                                 .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
                                )::type_id::create("wr_tr2");

        wr_tr.axi_tb_ADDR = 16'h2000;
        wr_tr.axi_tb_ID   = 4'hA;
        wr_tr.axi_tb_LEN = 8'h1;
        wr_tr.axi_tb_SIZE = 3'h2;
        wr_tr.axi_tb_BURST = 2'b01; //INCR
        wr_tr.axi_tb_WDATA  = 32'h1234_ABCD;
        wr_tr.axi_tb_WSTRB = 4'b1111;

        start_item(wr_tr);
        finish_item(wr_tr);
        `uvm_info(get_type_name(), $sformatf("Directed Write 2: Addr = 0x%0h, AWID = 0x%0h, Data = 0x%0h", wr_tr.axi_tb_ADDR, wr_tr.axi_tb_ID, wr_tr.axi_tb_WDATA), UVM_MEDIUM)

    endtask

endclass