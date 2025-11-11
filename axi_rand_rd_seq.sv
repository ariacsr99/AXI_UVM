class axi_rand_rd_seq #(
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

    `uvm_object_param_utils(axi_rand_rd_seq #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ))

    axi_read_trans #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ) rd_tr;

    // Received from the write sequence
    axi_pkg::axi_wr_struct wr_struct_queue[$];

    function new (string name = "axi_rand_rd_seq");
        super.new(name);
    endfunction

    virtual task body();
        if (wr_struct_queue.size() == 0)
                `uvm_fatal(get_full_name(), "No write info received from write sequence!")

        foreach (wr_struct_queue[i]) begin
            // 1. Create the transaction object
            rd_tr = axi_read_trans #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                                 .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                                 .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
                                )::type_id::create($sformatf("rd_tr_%0d", i));

            // Randomize with constraints
            if (!rd_tr.randomize() with {
                axi_tb_ADDR == wr_struct_queue[i].addr;
                axi_tb_LEN   == wr_struct_queue[i].len;
                axi_tb_SIZE  == wr_struct_queue[i].size;
                axi_tb_ID    == wr_struct_queue[i].id;
                axi_tb_BURST == wr_struct_queue[i].burst;
                }) begin
                `uvm_error(get_full_name(), "Randomization with constraints failed.")
            end
            // assert(rd_tr.randomize() with { axi_tb_BURST == 2'b10; axi_tb_LEN == 8; axi_tb_SIZE == 2; });

            //Send the item to the connected read driver
            start_item(rd_tr);
            finish_item(rd_tr);

            // Log the result
            `uvm_info(get_full_name(),
                    $sformatf("Random READ transaction completed. ARADDR: 0x%0h, ARID: 0x%0h, ARLEN: 0x%0h, ARSIZE: 0x%0h, ARBURST: 2'b%0b, RDATA: 0x%0h",
                                rd_tr.axi_tb_ADDR, rd_tr.axi_tb_ID, rd_tr.axi_tb_LEN, rd_tr.axi_tb_SIZE, rd_tr.axi_tb_BURST, rd_tr.axi_tb_RDATA),
                    UVM_MEDIUM)
        end
    endtask

endclass
