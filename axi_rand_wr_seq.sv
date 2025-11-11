class axi_rand_wr_seq #(
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

    `uvm_object_param_utils(axi_rand_wr_seq #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ))

    axi_write_trans #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ) wr_tr;

    rand int burst_num;
    constraint c_burst_num { burst_num inside {[5:15]}; } // Run between 5 and 15 writes

    axi_pkg::axi_wr_struct wr_struct_queue[$]; //queue of axi_wr_struct


    function new (string name = "axi_rand_wr_seq");
        super.new(name);
    endfunction

    virtual task body();
        axi_pkg::axi_wr_struct info;
        wr_struct_queue.delete();

        `uvm_info(get_full_name(), $sformatf("Starting Burst Random Write Sequence (Running %0d read)...", burst_num), UVM_LOW)

        // if (!this.randomize() ) begin
        //     `uvm_fatal(get_full_name(), "Sequence randomization failed for burst_num!")
        // end

        repeat (burst_num) begin
            // Create the transaction object
            wr_tr = axi_write_trans #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                                 .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                                 .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
                                )::type_id::create("wr_tr");

            // Randomize with constraints
            if (!wr_tr.randomize() with {
                wr_tr.axi_tb_BURST == 2'b01;
                wr_tr.axi_tb_LEN   == 8;
                wr_tr.axi_tb_SIZE  == 2;
                wr_tr.axi_tb_WSTRB == 4'b1111;
            }) begin
                `uvm_error(get_full_name(), "Randomization with constraints failed.")
            end
            // assert(wr_tr.randomize() with { axi_tb_BURST == 2'b10; axi_tb_LEN == 8; axi_tb_SIZE == 2; });

            // Send the item to the connected write driver
            start_item(wr_tr);
            finish_item(wr_tr);

            //Capture randomized transaction

            info.addr  = wr_tr.axi_tb_ADDR;
            info.len   = wr_tr.axi_tb_LEN;
            info.size  = wr_tr.axi_tb_SIZE;
            info.id    = wr_tr.axi_tb_ID;
            info.burst = wr_tr.axi_tb_BURST;
            wr_struct_queue.push_back(info);

            // Log the result
            `uvm_info(get_full_name(),
                    $sformatf("Random WRITE transaction completed. AWADDR: 0x%0h, AWID: 0x%0h, AWLEN: 0x%0h, AWSIZE: 0x%0h, AWBURST: 2'b%0b, WSTRB: 4'b%0b, WDATA: 0x%0h",
                                wr_tr.axi_tb_ADDR, wr_tr.axi_tb_ID, wr_tr.axi_tb_LEN, wr_tr.axi_tb_SIZE, wr_tr.axi_tb_BURST, wr_tr.axi_tb_WSTRB, wr_tr.axi_tb_WDATA),
                    UVM_MEDIUM)
        end
    endtask

endclass