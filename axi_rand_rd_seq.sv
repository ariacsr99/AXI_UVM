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
            string tr_name = $sformatf("rd_tr_%0d", i);

            // Create the transaction object
            rd_tr = axi_read_trans #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                                     .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                                     .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
                                    )::type_id::create(tr_name);

            // Randomize with constraints based on the write transaction
            if (!rd_tr.randomize() with {
                axi_tb_ADDR == wr_struct_queue[i].addr;
                axi_tb_LEN  == wr_struct_queue[i].len;
                axi_tb_SIZE == wr_struct_queue[i].size;
                axi_tb_ID   == wr_struct_queue[i].id;
                axi_tb_BURST == wr_struct_queue[i].burst;
                }) begin
                `uvm_error(get_full_name(), "Randomization with constraints failed.")
            end

            // Send the item to the connected read driver
            `uvm_info(get_full_name(), $sformatf("Starting READ Request: ARADDR=0x%0h, ARLEN=%0d, ARSIZE=%0d, ARID=0x%0h, ARBURST=0x%0h", rd_tr.axi_tb_ADDR, rd_tr.axi_tb_LEN, rd_tr.axi_tb_SIZE, rd_tr.axi_tb_ID, rd_tr.axi_tb_BURST), UVM_MEDIUM)
            start_item(rd_tr);
            finish_item(rd_tr);

            `uvm_info(get_full_name(),
                      $sformatf("Random READ transaction completed. ARADDR=0x%0h, ARLEN=%0d, ARSIZE=%0d, ARID=0x%0h, ARBURST=0x%0h, Total Beats: %0d",
                                rd_tr.axi_tb_ADDR, rd_tr.axi_tb_LEN, rd_tr.axi_tb_SIZE, rd_tr.axi_tb_ID, rd_tr.axi_tb_BURST, rd_tr.axi_tb_RDATA.size()),
                      UVM_MEDIUM)

            foreach (rd_tr.axi_tb_RDATA[k]) begin
                 `uvm_info(get_full_name(), $sformatf("  --> Beat %0d Data=0x%0h, Resp=0x%0h", k, rd_tr.axi_tb_RDATA[k], rd_tr.axi_tb_RRESP[k]), UVM_FULL)
            end

        end
    endtask

endclass