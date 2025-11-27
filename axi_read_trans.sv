class axi_read_trans #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter LEN_WIDTH = 8,
    parameter SIZE_WIDTH = 3,
    parameter BURST_WIDTH = 2,
    parameter RESP_WIDTH = 2,
    parameter ID_WIDTH = 4,
    parameter STROBE_WIDTH = DATA_WIDTH/8,
    parameter ADDR_BYTE_SIZE = 1
    ) extends axi_base_trans #(
    .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH),
    .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH),
    .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
    .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    );

    `uvm_object_param_utils(axi_read_trans #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ))

    // Read request channel signals (control signals)
    logic axi_tb_ARVALID;
    logic axi_tb_ARREADY;

    // Read data channel
    logic axi_tb_RVALID;
    logic axi_tb_RREADY;
    logic [ID_WIDTH-1:0] axi_tb_RID;

    // Dynamic Arrays for Read Data/Response
    logic [DATA_WIDTH-1:0] axi_tb_RDATA[];
    logic [RESP_WIDTH-1:0] axi_tb_RRESP[];

    logic axi_tb_RLAST;

    function new(string name = "axi_read_trans");
        super.new(name);
    endfunction

    function void post_randomize();
        // Calculate the total number of beats (transfers)
        int beats = axi_tb_LEN + 1;

        // Resize the arrays based on the randomized length
        axi_tb_RDATA = new[beats];
        axi_tb_RRESP = new[beats];

        // Initialize RDATA array elements
        foreach (axi_tb_RDATA[i]) begin
           // Use $urandom to fill each element with random data
           //axi_tb_RDATA[i] = $urandom();
           axi_tb_RDATA[i] = '0;
        end

        // Initialize RRESP array elements
        foreach (axi_tb_RRESP[i]) begin
           axi_tb_RRESP[i] = '0; // Initialize to 0 (AXI OKAY response)
        end

    endfunction

    function string convert2string();
        string s;
        string rdata_str = "";
        string rresp_str = "";

        // Loop through all data beats and format them into a single string
        if (axi_tb_RDATA.size() > 0) begin
            rdata_str = "RDATA: {";
            rresp_str = "RRESP: {";
            for (int i = 0; i < axi_tb_RDATA.size(); i++) begin
                // Append RDATA element (using %h for hex data)
                rdata_str = {rdata_str, $sformatf("0x%h", axi_tb_RDATA[i])};

                // Append RRESP element (using %b for binary strobe)
                rresp_str = {rresp_str, $sformatf("'b%0b", axi_tb_RRESP[i])};

                // Add separator if not the last element
                if (i < axi_tb_RDATA.size() - 1) begin
                    rdata_str = {rdata_str, ", "};
                    rresp_str = {rresp_str, ", "};
                end
            end
            rdata_str = {rdata_str, "}"};
            rresp_str = {rresp_str, "}"};
        end else begin
            rdata_str = "RDATA: []";
            rresp_str = "RRESP: []";
        end

        // Combine all formatted information
        $sformat(s,
            "%s | RDATA Beats=%0d | %s | %s",
            super.convert2string(),
            axi_tb_RDATA.size(),
            rdata_str,
            rresp_str
        );
        return s;
    endfunction

endclass