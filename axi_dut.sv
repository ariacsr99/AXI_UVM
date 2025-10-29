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
localparam MEM_DEPTH = 256;
reg [DATA_WIDTH-1:0] mem_array [MEM_DEPTH-1:0]; //0x000 to 0x3fc assuming each addr store 8 bit and each mem_arr[index] can store 32 bit

// Calculates the number of LSBs to shift to convert byte-address to word-index.
// Eg: 0x0000 -> 0x0003 = index 0, 0x0004 -> 0x0007 = index 1 assuming each addr store 8 bit and each mem_arr[index] can store 32 bit
// Equivalent to log2(DATA_WIDTH / 8). For 32-bit width, this returns 2.
function automatic integer get_addr_shift_amount();
    integer shift = 0;
    integer word_bytes = DATA_WIDTH / 8;
    while (word_bytes > 1) begin
        word_bytes = word_bytes >> 1;
        shift = shift + 1;
    end
    return shift;
endfunction
localparam ADDR_SHIFT = get_addr_shift_amount();

//Alternative to convert hex address to mem_array index
real num_bytes_mem_row_store = DATA_WIDTH / 8;
real num_bytes_addr_store = ADDR_BYTE_SIZE;
logic [ADDR_WIDTH-1:0] min_hex_addr = '0;
logic [ADDR_WIDTH-1:0] max_hex_addr = (MEM_DEPTH-1) * num_bytes_mem_row_store / num_bytes_addr_store;
integer index;

task automatic convert_hex_addr_to_mem_index_num(
    input logic [ADDR_WIDTH-1:0] addr,
    output int index_num
);
    //addr * num bytes each addr can store = index * num bytes each mem_arr row can store
    index_num = addr * (num_bytes_addr_store / num_bytes_mem_row_store);
endtask


// Write Registers
reg [ID_WIDTH-1:0]      latched_awid;
reg [LEN_WIDTH-1:0]     latched_awlen;
reg [SIZE_WIDTH-1:0]    latched_awsize;
reg [BURST_WIDTH-1:0]   latched_awburst;
reg [ADDR_WIDTH-1:0]    current_aw_addr;  // Current address pointer
reg [LEN_WIDTH-1:0]     w_beat_count;     // Current beat index (0 to LEN)
reg                     w_in_progress;    // Write in progress (transfer beats)
reg                     w_done_pending_b; // Write complete, waiting for B response
reg                     w_failed;

// Read Registers
reg [ID_WIDTH-1:0]      latched_arid;
reg [LEN_WIDTH-1:0]     latched_arlen;
reg [SIZE_WIDTH-1:0]    latched_arsize;
reg [BURST_WIDTH-1:0]   latched_arburst;
reg [ADDR_WIDTH-1:0]    current_ar_addr; // Current address pointer
reg [LEN_WIDTH-1:0]     r_beat_count;    // Current beat index (0 to LEN)
reg                     r_data_valid;   // Data is available and ready to be driven

// Combinational Logic for READY/VALID Handshake
// AWREADY is high when not currently processing a write burst
assign axi_AWREADY = ~w_in_progress;
// ARREADY is high when not currently processing a read burst
assign axi_ARREADY = ~r_data_valid;
// WREADY is high when address is latched and we are in the data phase
assign axi_WREADY  = w_in_progress;

// Sequential Logic (Memory & State Machine)
always @(posedge axi_ACLK or negedge axi_ARESETn) begin
    if (!axi_ARESETn) begin
        // Reset all internal states and outputs
        w_in_progress  <= 1'b0;
        w_done_pending_b <= 1'b0;
        r_data_valid   <= 1'b0;
        w_beat_count <= '0;
        r_beat_count <= '0;
        axi_BVALID <= 1'b0;
        axi_RVALID <= 1'b0;
        axi_RLAST  <= 1'b0;

    end else begin
        // WRITE ADDRESS CHANNEL (AW)
        if (axi_AWVALID && axi_AWREADY) begin
            if ((axi_AWADDR < min_hex_addr) || (axi_AWADDR > max_hex_addr)) begin
                convert_hex_addr_to_mem_index_num(axi_AWADDR, index);
                $error("@%0t: ERROR: [WRITE_INVALID_ADDR] addr = 0x%h, index = %d, max_addr = 0x%h, max_index = %d", $time, axi_AWADDR, index, max_hex_addr, MEM_DEPTH-1);
                w_in_progress     <= 1'b1;
            end
            else begin
                // Latch burst parameters
                latched_awid      <= axi_AWID;
                latched_awlen     <= axi_AWLEN;
                latched_awsize    <= axi_AWSIZE;
                latched_awburst   <= axi_AWBURST;

                // Initialize current address and beat counter
                current_aw_addr   <= axi_AWADDR;
                w_beat_count      <= '0;

                // Move to data phase
                w_in_progress     <= 1'b1;
            end
        end

        // WRITE DATA CHANNEL (W)
        if (w_in_progress && axi_WVALID && axi_WREADY) begin
            if ((current_aw_addr < min_hex_addr) || (current_aw_addr > max_hex_addr)) begin
                convert_hex_addr_to_mem_index_num(current_aw_addr, index);
                $error("@%0t: ERROR: [WRITE_INVALID_ADDR] addr = 0x%h, index = %d, max_addr = 0x%h, max_index = %d", $time, current_aw_addr, index, max_hex_addr, MEM_DEPTH-1);
                w_failed           <= 1'b1;
            end

            else begin
                // 1. Write Data to memory
                for (integer i = 0; i < STROBE_WIDTH; i++) begin
                    if (axi_WSTRB[i])
                        // Correctly access index memory array using ADDR_SHIFT
                        //mem_array[current_aw_addr >> ADDR_SHIFT][i*8 +: 8] <= axi_WDATA[i*8 +: 8];

                        convert_hex_addr_to_mem_index_num(current_aw_addr, index);
                        mem_array[index][i*8 +: 8] <= axi_WDATA[i*8 +: 8];
                end
                //$display("@%0t: [WRITE_DUT, BEAT %0d] addr=0x%h, index %d, data = 0x%h", $time, w_beat_count, current_aw_addr, current_aw_addr >> ADDR_SHIFT,  axi_WDATA);
                $display("@%0t: [WRITE_DUT, BEAT %0d] addr = 0x%h, index = %0d, data = 0x%h", $time, w_beat_count, current_aw_addr, index,  axi_WDATA);
            end

            // 2. Update state for next beat
            if (axi_WLAST && (w_beat_count == latched_awlen)) begin
                w_in_progress      <= 1'b0; // Data phase complete
                w_done_pending_b   <= 1'b1; // Start B response process
            end else if (latched_awburst == 2'b01) begin // INCR burst
                // Calculate next address
                //current_aw_addr <= current_aw_addr + (1 << latched_awsize); //address increases per beat size (2^awsize)
                current_aw_addr <= current_aw_addr + (1 << latched_awsize) / num_bytes_addr_store;

                //current_aw_addr <= current_aw_addr + ((latched_awlen * (1 << latched_awsize))/ DATA_WIDTH/8); //not supposed to increment by total burst size
                w_beat_count    <= w_beat_count + 1;
            end

        end

        // WRITE RESPONSE CHANNEL (B)
        // Assert BVALID when data is written and B response is pending
        if (w_failed) begin
            axi_BVALID <= 1'b1;
            axi_BRESP  <= 2'b11; // DECERR response
        end
        else if (w_done_pending_b) begin
            axi_BVALID <= 1'b1;
            axi_BID    <= latched_awid;
            axi_BRESP  <= 2'b00; // OKAY response
        end

        // Deassert BVALID when BREADY is high
        if (axi_BVALID && axi_BREADY) begin
            axi_BVALID         <= 1'b0;
            w_done_pending_b   <= 1'b0; // Write transaction complete
            w_failed           <= 1'b0;
        end


        // READ ADDRESS CHANNEL (AR)
        if (axi_ARVALID && axi_ARREADY) begin
            if ((axi_ARADDR < min_hex_addr) || (axi_ARADDR > max_hex_addr)) begin
                convert_hex_addr_to_mem_index_num(axi_ARADDR, index);
                $error("@%0t: ERROR: [READ_INVALID_ADDR] addr = 0x%h, index = %d, max_addr = 0x%h, max_index = %d", $time, axi_ARADDR, index, max_hex_addr, MEM_DEPTH-1);
                r_data_valid    <= 1'b1;
            end
            else begin
                // Latch burst parameters
                latched_arid      <= axi_ARID;
                latched_arlen     <= axi_ARLEN;
                latched_arsize    <= axi_ARSIZE;
                latched_arburst   <= axi_ARBURST;

                // Initialize current address and beat counter
                current_ar_addr   <= axi_ARADDR;
                r_beat_count      <= '0;

                // Transition to data valid state in the next cycle (modeling latency)
                r_data_valid    <= 1'b1;
            end
        end

        // READ DATA CHANNEL (R)
        if (r_data_valid) begin

            // Data driven every cycle until RLAST is handshaked
            if (axi_RVALID && axi_RREADY) begin
                if ((current_ar_addr < min_hex_addr) || (current_ar_addr > max_hex_addr)) begin
                    convert_hex_addr_to_mem_index_num(current_ar_addr, index);
                    $error("@%0t: ERROR: [READ_INVALID_ADDR] addr = 0x%h, index = %d, max_addr = 0x%h, max_index = %d", $time, current_ar_addr, index, max_hex_addr, MEM_DEPTH-1);
                    axi_RRESP  <= 2'b11; // DECERR
                    axi_RVALID <= 1'b0;
                    r_data_valid <= 1'b0;
                end
                else begin
                    // Load data for the current beat
                    //axi_RDATA  <= mem_array[current_ar_addr >> ADDR_SHIFT]; //convert addr to index num of mem_array
                    convert_hex_addr_to_mem_index_num(current_ar_addr, index);
                    axi_RDATA  <= mem_array[index];
                    axi_RID    <= latched_arid;
                    axi_RRESP  <= 2'b00; // OKAY
                end

                // Increment address for INCR burst
                if (latched_arburst == 2'b01) begin
                    //current_ar_addr <= current_ar_addr + (1 << latched_arsize); //calculate addr + 2^arsize
                    current_ar_addr <= current_ar_addr + (1 << latched_arsize) / num_bytes_addr_store;
                end
                // process next beat
                r_beat_count <= r_beat_count + 1;

            end

            // Determine RLAST
            if (r_beat_count == latched_arlen) begin
                axi_RLAST <= 1'b1; // This is the final beat
                if (axi_RREADY) begin // If master accepts the last beat
                    axi_RVALID <= 1'b0;
                    r_data_valid <= 1'b0;
                end
            end else begin
                axi_RLAST <= 1'b0;
                axi_RVALID <= 1'b1; // Keep RVALID high while RLAST is not handshaked
            end
        end

    end
end
endmodule