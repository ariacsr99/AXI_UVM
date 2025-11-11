class axi_base_trans #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter LEN_WIDTH = 8,
    parameter SIZE_WIDTH = 3,
    parameter BURST_WIDTH = 2,
    parameter RESP_WIDTH = 2,
    parameter ID_WIDTH = 4,
    parameter STROBE_WIDTH = DATA_WIDTH/8,
    parameter ADDR_BYTE_SIZE = 1
    ) extends uvm_sequence_item;

    `uvm_object_param_utils(axi_base_trans #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ))

    //Common AXI signals
    randc logic [ID_WIDTH-1:0]     axi_tb_ID;
    randc logic [ADDR_WIDTH-1:0]   axi_tb_ADDR;
    randc logic [LEN_WIDTH-1:0]    axi_tb_LEN;
    randc logic [SIZE_WIDTH-1:0]   axi_tb_SIZE;
    randc logic [BURST_WIDTH-1:0]  axi_tb_BURST;

    // Burst type constraint
    constraint axi_burst_type {
        // 2'b01 = INCR, 2'b10 = WRAP, 2'b00 = FIXED
        axi_tb_BURST inside {2'b01, 2'b10, 2'b00}; // Default: INCR bursts only
    }

    // Burst length constraint
    constraint axi_len_range {
        axi_tb_LEN inside {[0:15]}; // limit burst length to 16 beats max
    }

    constraint axi_size_valid {
        axi_tb_SIZE inside {3'd0, 3'd1, 3'd2}; // 1B(8 bits), 2B(16 bits), 4B(32 bits) transfers
    }

    // Address alignment constraint, enforce alignment to data width (byte addressing)
    constraint axi_addr_align {
        // Ensures the address is a multiple of the number of bytes per transfer.
        (axi_tb_ADDR % (1 << axi_tb_SIZE)) == 0;
    }
    //Eg: axi_size = 2, 2 ** 2 = 4 bytes per transfer, address: 0x0000, 0x0004, 0x0008

    function new(string name = "axi_base_trans");
        super.new(name);
    endfunction

    function string convert2string();
        return {super.convert2string(), $sformatf(
        "[axi_base_trans] axi_tb_ID=%h, axi_tb_ADDR=%h, axi_tb_LEN=%h, axi_tb_SIZE=%h, axi_tb_BURST=%0b", axi_tb_ID, axi_tb_ADDR, axi_tb_LEN, axi_tb_SIZE, axi_tb_BURST)};
    endfunction

endclass