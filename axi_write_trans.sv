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
    randc logic [DATA_WIDTH-1:0]   axi_tb_WDATA;
    randc logic [STROBE_WIDTH-1:0] axi_tb_WSTRB;
    logic                    axi_tb_WLAST;

    //Write response channel
    logic                    axi_tb_BVALID;
    logic                    axi_tb_BREADY;
    logic [ID_WIDTH-1:0]     axi_tb_BID;
    logic [RESP_WIDTH-1:0]   axi_tb_BRESP;

    function new(string name = "axi_write_trans");
        super.new(name);
    endfunction

    function string convert2string();
        return {super.convert2string(), $sformatf(
        "[axi_write_trans] axi_tb_AWVALID=%0b, axi_tb_AWREADY=%0b, axi_tb_AWID=%h, axi_tb_AWADDR=%h, axi_tb_AWLEN=%h, axi_tb_AWSIZE=%h, axi_tb_AWBURST=%0b, axi_tb_WVALID=%0b, axi_tb_WREADY=%0b, axi_tb_WDATA=%h, axi_tb_WSTRB=%0b, axi_tb_WLAST=%0b, axi_tb_BVALID=%0b, axi_tb_BREADY=%0b, axi_tb_BID=%h, axi_tb_BRESP=%0b",
        axi_tb_AWVALID, axi_tb_AWREADY, axi_tb_ID, axi_tb_ADDR, axi_tb_LEN, axi_tb_SIZE, axi_tb_BURST, axi_tb_WVALID, axi_tb_WREADY, axi_tb_WDATA, axi_tb_WSTRB, axi_tb_WLAST, axi_tb_BVALID, axi_tb_BREADY, axi_tb_BID, axi_tb_BRESP)};
    endfunction

endclass