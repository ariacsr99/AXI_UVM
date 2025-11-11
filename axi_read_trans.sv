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

    //Read request channel
    logic                    axi_tb_ARVALID;
    logic                    axi_tb_ARREADY;
    // logic [ID_WIDTH-1:0]     axi_tb_ARID;
    // logic [ADDR_WIDTH-1:0]   axi_tb_ARADDR;
    // logic [LEN_WIDTH-1:0]    axi_tb_ARLEN;
    // logic [SIZE_WIDTH-1:0]   axi_tb_ARSIZE;
    // logic [BURST_WIDTH-1:0]  axi_tb_ARBURST;

    //Read data channel
    logic                    axi_tb_RVALID;
    logic                    axi_tb_RREADY;
    logic [ID_WIDTH-1:0]     axi_tb_RID;
    logic [DATA_WIDTH-1:0]   axi_tb_RDATA;
    logic [RESP_WIDTH-1:0]   axi_tb_RRESP;
    logic                    axi_tb_RLAST;


    function new(string name = "axi_read_trans");
        super.new(name);
    endfunction

    function string convert2string();
        return {super.convert2string(), $sformatf(
        "[axi_read_trans] axi_tb_ARVALID=%0b, axi_tb_ARREADY=%0b, axi_tb_ARID=%h, axi_tb_ARADDR=%h, axi_tb_ARLEN=%h, axi_tb_ARSIZE=%h, axi_tb_ARBURST=%0b, axi_tb_RVALID=%0b, axi_tb_RREADY=%0b, axi_tb_RID=%h, axi_tb_RDATA=%h, axi_tb_RRESP=%0b, axi_tb_RLAST=%0b",
        axi_tb_ARVALID, axi_tb_ARREADY, axi_tb_ID, axi_tb_ADDR, axi_tb_LEN, axi_tb_SIZE, axi_tb_BURST, axi_tb_RVALID, axi_tb_RREADY, axi_tb_RID, axi_tb_RDATA, axi_tb_RRESP, axi_tb_RLAST)};
    endfunction

endclass