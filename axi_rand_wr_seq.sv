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

    // Transaction object declaration (must be the parameterized type)
    axi_write_trans #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ) wr_tr;

    rand int burst_num;
    //constraint c_burst_num { burst_num inside {[5:15]}; } // Run between 5 and 15 writes
    constraint c_burst_num { burst_num == 3; }

    // Queue to hold transaction information to pass to read
    axi_pkg::axi_wr_struct wr_struct_queue[$];
    // Queue to hold all randomized WDATA values
    bit [DATA_WIDTH-1:0] local_data_queue[$];

    function new (string name = "axi_rand_wr_seq");
        super.new(name);
    endfunction

    virtual task body();
        axi_pkg::axi_wr_struct info;
        int num_beats;
        int i;

        wr_struct_queue.delete();
        local_data_queue.delete();

        // Randomize the sequence object itself to get burst_num
        if (!this.randomize() ) begin
            `uvm_fatal(get_full_name(), "Sequence randomization failed for burst_num!")
        end

        `uvm_info(get_full_name(), $sformatf("Starting Burst Random Write Sequence (Running %0d bursts)...", burst_num), UVM_LOW)

        repeat (burst_num) begin
            // Create the transaction object
            wr_tr = axi_write_trans #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
                                     .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
                                     .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
                                     )::type_id::create("wr_tr");

            // Randomize the ADDRESS/CONTROL fields
            if (!wr_tr.randomize() with {
                wr_tr.axi_tb_BURST == 2'b01; // Force INCR burst
                //wr_tr.axi_tb_LEN inside {[0:7]};
                //wr_tr.axi_tb_SIZE inside {[0:2]};
                wr_tr.axi_tb_LEN inside {3};
                wr_tr.axi_tb_SIZE inside {2};
            }) begin
                `uvm_error(get_full_name(), "Randomization of control fields failed.")
                continue;
            end

            num_beats = wr_tr.axi_tb_LEN + 1;

            // Size and randomize WDATA and WSTRB
            // WDATA and WSTRB must be sized before randomization since they are dynamic arrays
            wr_tr.axi_tb_WDATA = new[num_beats];
            wr_tr.axi_tb_WSTRB = new[num_beats];

            // Randomize all data beats and set strobes
            foreach (wr_tr.axi_tb_WDATA[i]) begin
                // Use std::randomize() for simple data types (logic), not the .randomize() method which is for objects.
                if (!std::randomize(wr_tr.axi_tb_WDATA[i])) begin
                    `uvm_error(get_full_name(), $sformatf("WDATA randomization failed for beat %0d.", i))
                end

                //if (!std::randomize(wr_tr.axi_tb_WSTRB[i]) with {wr_tr.axi_tb_WSTRB[i] == ((1 << (1 << wr_tr.axi_tb_SIZE)) - 1);}) begin
                //    `uvm_error(get_full_name(), $sformatf("WSTRB randomization failed for beat %0d.", i))
                //end

                // Set full strobe coverage for simplicity
                wr_tr.axi_tb_WSTRB[i] = {STROBE_WIDTH{1'b1}};
            end

            // Send the item to the connected write driver
            start_item(wr_tr);
            finish_item(wr_tr);

            // EXPLORE: uvm_do(item) - macro that automatically creates item object (uvm_create(req)), start_item(req), wait_for_grant(), randomize seq item fields (req.randomize()), send item to sequencer, which forwards to driver (finish_item(req) -> send_request() -> wait_for_item_done())
            // uvm_do_with(item, constraints) - same as uvm_do, but applies inline constraints during randomization
            // uvm_do_on(item,sequencer) - same as uvm_do but executes on specified sequencer
            // uvm_do_on_with - combines inline constraints & specific sequencer

            // Capture randomized transaction info
            info.addr  = wr_tr.axi_tb_ADDR;
            info.len   = wr_tr.axi_tb_LEN;
            info.size  = wr_tr.axi_tb_SIZE;
            info.id    = wr_tr.axi_tb_ID;
            info.burst = wr_tr.axi_tb_BURST;
            wr_struct_queue.push_back(info);

            // Capture all randomized WDATA values
            foreach (wr_tr.axi_tb_WDATA[i]) begin
                local_data_queue.push_back(wr_tr.axi_tb_WDATA[i]);

                `uvm_info(get_full_name(),
                        $sformatf("Random WRITE burst sent. AWADDR: 0x%0h, AWID: 0x%0h, AWLEN: 0x%0h, AWSIZE: 0x%0h, AWBURST: 2'b%0b, WSTRB[%0d]: 0x%0h, WDATA[%0d]: 0x%0h",
                                  wr_tr.axi_tb_ADDR,
                                  wr_tr.axi_tb_ID,
                                  wr_tr.axi_tb_LEN,
                                  wr_tr.axi_tb_SIZE,
                                  wr_tr.axi_tb_BURST,
                                  i,
                                  wr_tr.axi_tb_WSTRB[i],
                                  i,
                                  wr_tr.axi_tb_WDATA[i]),
                        UVM_MEDIUM)
            end

        end
    endtask

endclass