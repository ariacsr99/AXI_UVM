interface axi_if #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter LEN_WIDTH = 8,
    parameter SIZE_WIDTH = 3,
    parameter BURST_WIDTH = 2,
    parameter RESP_WIDTH = 2,
    parameter ID_WIDTH = 4,
    parameter STROBE_WIDTH = DATA_WIDTH/8,
    parameter ADDR_BYTE_SIZE = 1
    ) (
        input logic             axi_tb_ACLK
    );

    logic                       axi_tb_ARESETn;

    //Write request channel
    logic                       axi_tb_AWVALID;
    logic                       axi_tb_AWREADY;
    logic [ID_WIDTH-1:0]        axi_tb_AWID; //unique tag to enable out of order transactions
    logic [ADDR_WIDTH-1:0]      axi_tb_AWADDR;
    logic [LEN_WIDTH-1:0]       axi_tb_AWLEN; //burst length, total number of beats
    logic [SIZE_WIDTH-1:0]      axi_tb_AWSIZE; //size in bytes of each individual data transfer (beat) within the burst, 2^AxSIZE
    logic [BURST_WIDTH-1:0]     axi_tb_AWBURST; //Burst type - 2'b00: FIXED, 2'b01: INCR, 2'b10: WRAP, 2'b11: Reserved

    //Write data channel
    logic                       axi_tb_WVALID;
    logic                       axi_tb_WREADY;
    logic [DATA_WIDTH-1:0]      axi_tb_WDATA;
    logic [STROBE_WIDTH-1:0]    axi_tb_WSTRB;
    logic                       axi_tb_WLAST;

    //Write response channel
    logic                       axi_tb_BVALID;
    logic                       axi_tb_BREADY;
    logic [ID_WIDTH-1:0]        axi_tb_BID;
    logic [RESP_WIDTH-1:0]      axi_tb_BRESP;

    //Read request channel
    logic                       axi_tb_ARVALID;
    logic                       axi_tb_ARREADY;
    logic [ID_WIDTH-1:0]        axi_tb_ARID;
    logic [ADDR_WIDTH-1:0]      axi_tb_ARADDR;
    logic [LEN_WIDTH-1:0]       axi_tb_ARLEN;
    logic [SIZE_WIDTH-1:0]      axi_tb_ARSIZE;
    logic [BURST_WIDTH-1:0]     axi_tb_ARBURST;

    //Read data channel
    logic                       axi_tb_RVALID;
    logic                       axi_tb_RREADY;
    logic [ID_WIDTH-1:0]        axi_tb_RID;
    logic [DATA_WIDTH-1:0]      axi_tb_RDATA;
    logic [RESP_WIDTH-1:0]      axi_tb_RRESP;
    logic                       axi_tb_RLAST;

    // Modport for driver
    modport drv_mp (
        output axi_tb_ARESETn, axi_tb_AWVALID, axi_tb_AWID, axi_tb_AWADDR, axi_tb_AWLEN, axi_tb_AWSIZE, axi_tb_AWBURST, axi_tb_WVALID, axi_tb_WDATA, axi_tb_WSTRB, axi_tb_WLAST, axi_tb_BREADY, axi_tb_ARVALID, axi_tb_ARID, axi_tb_ARADDR, axi_tb_ARLEN, axi_tb_ARSIZE, axi_tb_ARBURST, axi_tb_RREADY,
        input axi_tb_AWREADY, axi_tb_WREADY, axi_tb_BVALID, axi_tb_BID, axi_tb_BRESP, axi_tb_ARREADY, axi_tb_RVALID, axi_tb_RID, axi_tb_RDATA, axi_tb_RRESP, axi_tb_RLAST,
        input axi_tb_ACLK
    );

    // Modport for monitor
    modport mon_mp (
        input axi_tb_ARESETn, axi_tb_AWVALID, axi_tb_AWID, axi_tb_AWADDR, axi_tb_AWLEN, axi_tb_AWSIZE, axi_tb_AWBURST, axi_tb_WVALID, axi_tb_WDATA, axi_tb_WSTRB, axi_tb_WLAST, axi_tb_BREADY, axi_tb_ARVALID, axi_tb_ARID, axi_tb_ARADDR, axi_tb_ARLEN, axi_tb_ARSIZE, axi_tb_ARBURST, axi_tb_RREADY, axi_tb_AWREADY, axi_tb_WREADY, axi_tb_BVALID, axi_tb_BID, axi_tb_BRESP, axi_tb_ARREADY, axi_tb_RVALID, axi_tb_RID, axi_tb_RDATA, axi_tb_RRESP, axi_tb_RLAST, axi_tb_ACLK // Monitor only reads
    );

endinterface

interface clk_if();
    logic axi_tb_ACLK;
    real ACLK_FREQ = 200;
    real ACLK_PERIOD_NS = 1/ACLK_FREQ*1000;

    initial begin
        axi_tb_ACLK = 0;
        forever begin
            #(ACLK_PERIOD_NS/2 * 1ns) axi_tb_ACLK = ~axi_tb_ACLK;
        end
    end

endinterface