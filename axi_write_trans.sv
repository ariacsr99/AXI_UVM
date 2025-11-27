class axi_write_trans #(
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

    `uvm_object_param_utils(axi_write_trans #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ))

    //Write request channel
    logic                    axi_tb_AWVALID;
    logic                    axi_tb_AWREADY;
    // randc logic [ID_WIDTH-1:0]     axi_tb_ID;
    // randc logic [ADDR_WIDTH-1:0]   axi_tb_AWADDR;
    // randc logic [LEN_WIDTH-1:0]    axi_tb_AWLEN;
    // randc logic [SIZE_WIDTH-1:0]   axi_tb_AWSIZE;
    // randc logic [BURST_WIDTH-1:0]  axi_tb_AWBURST;

    //Write data channel
    logic                    axi_tb_WVALID;
    logic                    axi_tb_WREADY;
    randc logic [DATA_WIDTH-1:0]   axi_tb_WDATA[]; //dynamic arrays to do burst transfer
    randc logic [STROBE_WIDTH-1:0] axi_tb_WSTRB[];
    logic                    axi_tb_WLAST;

    //Write response channel
    logic                    axi_tb_BVALID;
    logic                    axi_tb_BREADY;
    logic [ID_WIDTH-1:0]     axi_tb_BID;
    logic [RESP_WIDTH-1:0]   axi_tb_BRESP;

    constraint wdata_array_size {
        axi_tb_WDATA.size() == axi_tb_LEN + 1;
        axi_tb_WSTRB.size() == axi_tb_LEN + 1;
    }

    // forces the WSTRB value to equal max mask (eg: 4'b1111 if SIZE=2)
    constraint wstrb_value {
        foreach (axi_tb_WSTRB[i]) {
            // (1 << (1 << axi_tb_SIZE)) calculates the boundary value.
            axi_tb_WSTRB[i] == ((1 << (1 << axi_tb_SIZE)) - 1);
        }
    }

    function new(string name = "axi_write_trans");
        super.new(name);
    endfunction

    function string convert2string();
        string s;
        string wdata_str = "";
        string wstrb_str = "";

        // Loop through all data beats and format them into a single string
        if (axi_tb_WDATA.size() > 0) begin
            wdata_str = "WDATA: {";
            wstrb_str = "WSTRB: {";
            for (int i = 0; i < axi_tb_WDATA.size(); i++) begin
                // Append WDATA element (using %h for hex data)
                wdata_str = {wdata_str, $sformatf("0x%h", axi_tb_WDATA[i])};

                // Append WSTRB element (using %b for binary strobe)
                wstrb_str = {wstrb_str, $sformatf("'b%0b", axi_tb_WSTRB[i])};

                // Add separator if not the last element
                if (i < axi_tb_WDATA.size() - 1) begin
                    wdata_str = {wdata_str, ", "};
                    wstrb_str = {wstrb_str, ", "};
                end
            end
            wdata_str = {wdata_str, "}"};
            wstrb_str = {wstrb_str, "}"};
        end else begin
            wdata_str = "WDATA: []";
            wstrb_str = "WSTRB: []";
        end

        // Combine all formatted information
        $sformat(s,
            "%s | WDATA Beats=%0d | %s | %s",
            super.convert2string(),
            axi_tb_WDATA.size(),
            wdata_str,
            wstrb_str
        );
        return s;
    endfunction
endclass