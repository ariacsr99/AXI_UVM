class axi_burst_trans #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter LEN_WIDTH = 8,
    parameter SIZE_WIDTH = 3,
    parameter BURST_WIDTH = 2,
    parameter RESP_WIDTH = 2,
    parameter ID_WIDTH = 4,
    parameter STROBE_WIDTH = DATA_WIDTH/8
) extends uvm_sequence_item;

    `uvm_object_param_utils(axi_burst_trans #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH)
    ))

    // Control/Address Information (captured during AW/AR handshake)
    logic [ADDR_WIDTH-1:0] addr;
    logic [ID_WIDTH-1:0]   id;
    logic [LEN_WIDTH-1:0]  len;
    logic [SIZE_WIDTH-1:0] size;
    logic [BURST_WIDTH-1:0] burst;

    // Write Data Arrays (Allocated in write_AW, filled in during write_W)
    logic [DATA_WIDTH-1:0] w_data_beats[];
    logic [STROBE_WIDTH-1:0] w_strobe_beats[];
    logic [RESP_WIDTH-1:0] b_resp;

    // Read Data Arrays (Allocated in write_AR, used for comparison during write_R)
    logic [DATA_WIDTH-1:0] r_data_beats[];
    logic [RESP_WIDTH-1:0] r_resp_beats[]; // Array of responses (one per beat)

    int beats_received = 0; // Tracks how many W or R beats have arrived

    bit is_write; // flag for conditional print: 1=Write Burst (AW/W/B), 0=Read Burst (AR/R)

    function new(string name = "axi_burst_trans");
        super.new(name);
    endfunction

    function void do_print(uvm_printer printer);
        super.do_print(printer); // Override the do_print function more debug info
        //printer.print_field("<name>", <value>, <size>, <format_enum, eg:UVM_HEX>);
        //printer.print_field("ADDR", addr, ADDR_WIDTH, $sformatf("%h", addr));
        printer.print_field("ADDR", addr, ADDR_WIDTH, UVM_HEX);
        printer.print_field("ID", id, ID_WIDTH, UVM_HEX);
        printer.print_field("LEN", len, LEN_WIDTH, UVM_DEC);
        printer.print_field("SIZE", size, SIZE_WIDTH, UVM_DEC);
        printer.print_field("BURST", burst, BURST_WIDTH, UVM_BIN);
        printer.print_field("Beats Received", beats_received, 32, UVM_DEC);

        if (is_write) begin
            printer.print_string("Type", "WRITE Burst (AW/W/B)");
            // printer.print_array_header: for array items
            // printer.print_array_header( "<string name>", <int size>, <string type_name>
            printer.print_array_header("WDATA Beats", w_data_beats.size(), $sformatf("%0d-bit data", DATA_WIDTH));
            foreach (w_data_beats[i]) begin
                printer.print_field($sformatf("w_data_beats[%0d]", i), w_data_beats[i], DATA_WIDTH, UVM_HEX);
            end
            printer.print_array_footer(); // Close the array context (mandatory)

            printer.print_array_header("WSTRB Beats", w_strobe_beats.size(), $sformatf("%0d-bit strobe", STROBE_WIDTH));
            foreach (w_strobe_beats[i]) begin
                printer.print_field($sformatf("w_strobe_beats[%0d]", i), w_strobe_beats[i], STROBE_WIDTH, UVM_HEX);
            end
            printer.print_array_footer(); // Close the array context

            printer.print_field("BRESP", b_resp, RESP_WIDTH, UVM_HEX);

        end else begin
            printer.print_string("Type", "READ Burst (AR/R)");
            printer.print_array_header("RDATA Beats", r_data_beats.size(), $sformatf("%0d-bit data", DATA_WIDTH));
            foreach (r_data_beats[i]) begin
                printer.print_field($sformatf("r_data_beats[%0d]", i), r_data_beats[i], DATA_WIDTH, UVM_HEX);
            end
            printer.print_array_footer();

            printer.print_array_header("RRESP Beats", r_resp_beats.size(), $sformatf("%0d-bit response", RESP_WIDTH));
            foreach (r_resp_beats[i]) begin
                printer.print_field($sformatf("r_resp_beats[%0d]", i), r_resp_beats[i], RESP_WIDTH, UVM_HEX);
            end
            printer.print_array_footer();
        end

    endfunction

endclass