module axi_dut #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter LEN_WIDTH = 8,
    parameter SIZE_WIDTH = 3,
    parameter BURST_WIDTH = 2,
    parameter RESP_WIDTH = 2,
    parameter ID_WIDTH = 4,
    parameter STROBE_WIDTH = DATA_WIDTH/8,
    parameter ADDR_BYTE_SIZE = 1
)
(
    //Clock and reset
    input  logic axi_ACLK,
    input  logic axi_ARESETn,

    //Write request channel
    input  logic                    axi_AWVALID,
    output logic                    axi_AWREADY,
    input  logic [ID_WIDTH-1:0]     axi_AWID,
    input  logic [ADDR_WIDTH-1:0]   axi_AWADDR,
    input  logic [LEN_WIDTH-1:0]    axi_AWLEN,
    input  logic [SIZE_WIDTH-1:0]   axi_AWSIZE,
    input  logic [BURST_WIDTH-1:0]  axi_AWBURST,

    //Write data channel
    input  logic                    axi_WVALID,
    output logic                    axi_WREADY,
    input  logic [DATA_WIDTH-1:0]   axi_WDATA,
    input  logic [STROBE_WIDTH-1:0] axi_WSTRB,
    input  logic                    axi_WLAST,

    //Write response channel
    output logic                    axi_BVALID,
    input  logic                    axi_BREADY,
    output logic [ID_WIDTH-1:0]     axi_BID,
    output logic [RESP_WIDTH-1:0]   axi_BRESP,

    //Read request channel
    input  logic                    axi_ARVALID,
    output logic                    axi_ARREADY,
    input  logic [ID_WIDTH-1:0]     axi_ARID,
    input  logic [ADDR_WIDTH-1:0]   axi_ARADDR,
    input  logic [LEN_WIDTH-1:0]    axi_ARLEN,
    input  logic [SIZE_WIDTH-1:0]   axi_ARSIZE,
    input  logic [BURST_WIDTH-1:0]  axi_ARBURST,

    //Read data channel
    output logic                    axi_RVALID,
    input  logic                    axi_RREADY,
    output logic [ID_WIDTH-1:0]     axi_RID,
    output logic [DATA_WIDTH-1:0]   axi_RDATA,
    output logic [RESP_WIDTH-1:0]   axi_RRESP,
    output logic                    axi_RLAST
);

// Internal Memory
//localparam MEM_DEPTH = 256;
localparam MEM_DEPTH = (1 << ADDR_WIDTH) - 1;
reg [DATA_WIDTH-1:0] mem_array [MEM_DEPTH-1:0]; //0x000 to 0x3fc assuming each addr store 8 bit and each mem_arr[index] can store 32 bit

// Calculates the number of LSBs to shift to convert byte-address to word-index.
// Eg: 0x0000 -> 0x0003 = index 0, 0x0004 -> 0x0007 = index 1 assuming each addr store 8 bit and each mem_arr[index] can store 32 bit
// Equivalent to log2(DATA_WIDTH / 8). For 32-bit width, this returns 2.
// function automatic integer get_addr_shift_amount();
//     integer shift = 0;
//     integer word_bytes = DATA_WIDTH / 8;
//     while (word_bytes > 1) begin
//         word_bytes = word_bytes >> 1;
//         shift = shift + 1;
//     end
//     return shift;
// endfunction
// localparam ADDR_SHIFT = get_addr_shift_amount();

//Alternative to convert hex address to mem_array index
real num_bytes_mem_row_store = DATA_WIDTH / 8;
real num_bytes_addr_store = ADDR_BYTE_SIZE;
logic [ADDR_WIDTH-1:0] min_hex_addr = '0;
logic [ADDR_WIDTH-1:0] max_hex_addr = (MEM_DEPTH-1) * num_bytes_mem_row_store / num_bytes_addr_store;
integer index;
integer rd_index;
integer wr_beat_num;
integer next_rd_beat_num;

function int convert_hex_addr_to_mem_index_num(logic [ADDR_WIDTH-1:0] addr);
    return addr * (num_bytes_addr_store / num_bytes_mem_row_store);
endfunction

// Write Registers
reg [ID_WIDTH-1:0]      latched_awid;
reg [LEN_WIDTH-1:0]     latched_awlen;
reg [SIZE_WIDTH-1:0]    latched_awsize;
reg [BURST_WIDTH-1:0]   latched_awburst;

// Read Registers
reg [ID_WIDTH-1:0]      latched_arid;
reg [LEN_WIDTH-1:0]     latched_arlen;
reg [SIZE_WIDTH-1:0]    latched_arsize;
reg [BURST_WIDTH-1:0]   latched_arburst;

reg [ADDR_WIDTH-1:0]    current_aw_addr; // Current write address pointer
reg [ADDR_WIDTH-1:0]    next_ar_addr; // Next read address pointer

reg wr_addr_start;
reg wr_addr_done;
reg wr_data_start;
reg wr_data_done;
reg wr_wait_resp;
reg wr_resp_done;

reg rd_addr_start;
reg rd_addr_done;
reg rd_data_start;
reg rd_data_done;

assign index = convert_hex_addr_to_mem_index_num(current_aw_addr);
assign rd_index = convert_hex_addr_to_mem_index_num(next_ar_addr);

always_comb begin
    if (axi_AWVALID && axi_AWREADY)
        wr_addr_start = 1;
    else
        wr_addr_start = 0;

    if (axi_WVALID && axi_WREADY)
        wr_data_start = 1;
    else
        wr_data_start = 0;

    if (wr_addr_done && wr_data_done)
        wr_wait_resp = 1;
    else
        wr_wait_resp = 0;


    if(axi_ARVALID && axi_ARREADY)
        rd_addr_start = 1;
    else
        rd_addr_start = 0;

    if (axi_RREADY && axi_RVALID)
        rd_data_start = 1;
    else
        rd_data_start = 0;
end

always @(posedge axi_ACLK or negedge axi_ARESETn) begin
    if (!axi_ARESETn) begin
        // Reset all internal states and outputs
        wr_addr_done <= 1'b0;
        wr_data_done <= 1'b0;
        wr_resp_done <= 1'b0;
        rd_addr_done <= 1'b0;
        rd_data_done <= 1'b0;
        current_aw_addr <= '0;
        next_ar_addr <= '0;

        latched_awid <= '0;
        latched_awburst <= '0;
        latched_awlen <= '0;
        latched_awsize <= '0;

        axi_AWREADY <= 1'b1;
        axi_WREADY <= 1'b1;
        axi_BVALID <= 1'b0;
        axi_BID <= '0;
        axi_BRESP <= '0;

        latched_arid <= '0;
        latched_arburst <= '0;
        latched_arlen <= '0;
        latched_arsize <= '0;

        axi_ARREADY <= 1'b1;
        axi_RVALID <= 1'b0;
        axi_RID <= '0;
        axi_RDATA <= '0;
        axi_RRESP <= '0;
        axi_RLAST <= '0;

    end else begin
        // WRITE ADDRESS CHANNEL (AW)
        if (wr_addr_start) begin
            if ((axi_AWADDR < min_hex_addr) || (axi_AWADDR > max_hex_addr)) begin
                //convert_hex_addr_to_mem_index_num(axi_AWADDR, index);
                $fatal("@%0t: ERROR: [WRITE_INVALID_ADDR] addr = 0x%h, max_addr = 0x%h, max_index = %d", $time, axi_AWADDR, max_hex_addr, MEM_DEPTH-1);
                //$fatal("@%0t: ERROR: [WRITE_INVALID_ADDR] addr = 0x%h, index = %d, max_addr = 0x%h, max_index = %d", $time, axi_AWADDR, index, max_hex_addr, MEM_DEPTH-1);
            end
            else begin
                latched_awid      <= axi_AWID;
                latched_awlen     <= axi_AWLEN + 1;
                latched_awsize    <= axi_AWSIZE;
                latched_awburst   <= axi_AWBURST;
                current_aw_addr   <= axi_AWADDR;

                wr_addr_done      <= 1'b1;
                axi_AWREADY       <= 1'b0;
                wr_beat_num       <= 0;
            end
        end

        // WRITE DATA CHANNEL (W)
        if (wr_addr_done && wr_data_start) begin

            if ((current_aw_addr < min_hex_addr) || (current_aw_addr > max_hex_addr)) begin
                //convert_hex_addr_to_mem_index_num(current_aw_addr, index);

                $fatal("@%0t: ERROR: [WRITE_INVALID_ADDR] addr = 0x%h, index = %d, max_addr = 0x%h, max_index = %d", $time, axi_AWADDR, index, max_hex_addr, MEM_DEPTH-1);
            end
            else begin
                if (wr_beat_num < latched_awlen) begin
                    // Write Data to memory
                    for (integer i = 0; i < STROBE_WIDTH; i++) begin
                        if (axi_WSTRB[i])
                            // Correctly access index memory array using ADDR_SHIFT
                            //mem_array[current_aw_addr >> ADDR_SHIFT][i*8 +: 8] <= axi_WDATA[i*8 +: 8];

                            //convert_hex_addr_to_mem_index_num(current_aw_addr, index);
                            //index = convert_hex_addr_to_mem_index_num(current_aw_addr);
                            mem_array[index][i*8 +: 8] <= axi_WDATA[i*8 +: 8];
                    end
                    //$display("@%0t: [WRITE_DUT, BEAT %0d] addr=0x%h, index %d, data = 0x%h", $time, wr_beat_num, current_aw_addr, current_aw_addr >> ADDR_SHIFT,  axi_WDATA);
                    $display("@%0t: [WRITE_DUT, BEAT %0d] addr = 0x%h, index = %0d, data = 0x%h", $time, wr_beat_num, current_aw_addr, index,  axi_WDATA);

                    // Update state for next beat
                    if (axi_WLAST && (wr_beat_num == (latched_awlen-1))) begin
                        wr_data_done <= 1;
                        axi_WREADY <= 1'b0;
                    end
                    else if (latched_awburst === 2'b01) begin // INCR burst
                        // Calculate next address
                        //current_aw_addr <= current_aw_addr + (1 << latched_awsize); //address increases per beat size (2^awsize)
                        current_aw_addr <= current_aw_addr + (1 << latched_awsize) / num_bytes_addr_store;
                        wr_beat_num <= wr_beat_num + 1;

                        //current_aw_addr <= current_aw_addr + ((latched_awlen * (1 << latched_awsize))/ DATA_WIDTH/8); //not supposed to increment by total burst size
                    end
                end
            end
        end

        // WRITE RESPONSE CHANNEL (B)
        if (wr_wait_resp) begin
            axi_BID    <= latched_awid;
            axi_BRESP  <= 2'b00; // OKAY response
            axi_BVALID <= 1'b1;
        end

        if (axi_BVALID && axi_BREADY) begin
            latched_awid <= '0;
            latched_awburst <= '0;
            latched_awlen <= '0;
            latched_awsize <= '0;

            wr_resp_done <= 1'b1;
            axi_BVALID <= 1'b0;
            axi_BID <= '0;
            axi_BRESP <= '0;
            axi_AWREADY <= 1'b1;
            axi_WREADY <= 1'b1;

            wr_addr_done <= 1'b0;
            wr_data_done <= 1'b0;
            @(posedge axi_ACLK);
            wr_resp_done <= 1'b0;
        end

        // READ ADDRESS CHANNEL (AR)
        if (rd_addr_start) begin
            if ((axi_ARADDR < min_hex_addr) || (axi_ARADDR > max_hex_addr)) begin
                //convert_hex_addr_to_mem_index_num(axi_ARADDR, index);
                $fatal("@%0t: ERROR: [READ_INVALID_ADDR] addr = 0x%h, max_addr = 0x%h, max_index = %d", $time, axi_ARADDR, max_hex_addr, MEM_DEPTH-1);
                //$fatal("@%0t: ERROR: [READ_INVALID_ADDR] addr = 0x%h, index = %d, max_addr = 0x%h, max_index = %d", $time, axi_ARADDR, index, max_hex_addr, MEM_DEPTH-1);
            end
            else begin
                latched_arid      <= axi_ARID;
                latched_arlen     <= axi_ARLEN + 1;
                latched_arsize    <= axi_ARSIZE;
                latched_arburst   <= axi_ARBURST;

                next_ar_addr   <= axi_ARADDR;
                rd_addr_done    <= 1'b1;
                axi_ARREADY     <= 1'b0;

                next_rd_beat_num <= 0;
            end
        end

        // READ DATA CHANNEL (R)
        if (rd_addr_done) begin
            axi_RVALID <= 1'b1;
            // Data driven every cycle until RLAST is handshaked
            if ((next_ar_addr < min_hex_addr) || (next_ar_addr > max_hex_addr)) begin
                //convert_hex_addr_to_mem_index_num(next_ar_addr, index);
                $fatal("@%0t: ERROR: [READ_INVALID_ADDR] addr = 0x%h, index = %d, max_addr = 0x%h, max_index = %d", $time, next_ar_addr, rd_index, max_hex_addr, MEM_DEPTH-1);
            end
            else begin
                // Load data for the next beat
                //axi_RDATA  <= mem_array[next_ar_addr >> ADDR_SHIFT]; //convert addr to index num of mem_array
                //convert_hex_addr_to_mem_index_num(next_ar_addr, index);
                axi_RDATA  <= mem_array[rd_index];
                axi_RID    <= latched_arid;
                axi_RRESP  <= 2'b00; // OKAY

                // Determine RLAST
                if (next_rd_beat_num == (latched_arlen-1)) begin
                    axi_RLAST <= 1'b1; // This is for the final beat
                    rd_data_done <= 1'b1;
                end
                if (latched_arburst === 2'b01) begin // INCR burst
                    // Calculate next address

                    //next_ar_addr <= next_ar_addr + (1 << latched_arsize); //calculate addr + 2^arsize
                    next_ar_addr <= next_ar_addr + (1 << latched_arsize) / num_bytes_addr_store;

                end
                next_rd_beat_num <= next_rd_beat_num + 1;
            end
        end

        if (rd_data_done) begin
            next_ar_addr   <= '0;
            rd_addr_done    <= 1'b0;

            latched_arid <= '0;
            latched_arburst <= '0;
            latched_arlen <= '0;
            latched_arsize <= '0;

            axi_ARREADY <= 1'b1;
            axi_RVALID <= 1'b0;
            axi_RID <= '0;
            axi_RDATA <= '0;
            axi_RRESP <= '0;
            axi_RLAST <= '0;

            rd_data_done <= 1'b0;
        end
    end
end
endmodule