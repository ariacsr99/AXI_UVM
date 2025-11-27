module axi_assertions #(
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
    //Clock and reset
    input  logic axi_ACLK,
    input  logic axi_ARESETn,

    //Write request channel
    input  logic                    axi_AWVALID,
    input  logic                    axi_AWREADY,
    input  logic [ID_WIDTH-1:0]     axi_AWID,
    input  logic [ADDR_WIDTH-1:0]   axi_AWADDR,
    input  logic [LEN_WIDTH-1:0]    axi_AWLEN,
    input  logic [SIZE_WIDTH-1:0]   axi_AWSIZE,
    input  logic [BURST_WIDTH-1:0]  axi_AWBURST,

    //Write data channel
    input  logic                    axi_WVALID,
    input  logic                    axi_WREADY,
    input  logic [DATA_WIDTH-1:0]   axi_WDATA,
    input  logic [STROBE_WIDTH-1:0] axi_WSTRB,
    input  logic                    axi_WLAST,

    //Write response channel
    input logic                     axi_BVALID,
    input logic                     axi_BREADY,
    input logic [ID_WIDTH-1:0]      axi_BID,
    input logic [RESP_WIDTH-1:0]    axi_BRESP,

    //Read request channel
    input  logic                    axi_ARVALID,
    input  logic                    axi_ARREADY,
    input  logic [ID_WIDTH-1:0]     axi_ARID,
    input  logic [ADDR_WIDTH-1:0]   axi_ARADDR,
    input  logic [LEN_WIDTH-1:0]    axi_ARLEN,
    input  logic [SIZE_WIDTH-1:0]   axi_ARSIZE,
    input  logic [BURST_WIDTH-1:0]  axi_ARBURST,

    //Read data channel
    input logic                     axi_RVALID,
    input logic                     axi_RREADY,
    input logic [ID_WIDTH-1:0]      axi_RID,
    input logic [DATA_WIDTH-1:0]    axi_RDATA,
    input logic [RESP_WIDTH-1:0]    axi_RRESP,
    input logic                     axi_RLAST,

    input integer wr_beat_num,
    input integer next_rd_beat_num,
    input logic [LEN_WIDTH-1:0]     latched_awlen,
    input logic [LEN_WIDTH-1:0]     latched_arlen
);

    // Assertions for AW, W & B channel

    property aw_handshake;
        @(posedge axi_ACLK) disable iff (!axi_ARESETn)
        axi_AWVALID |-> axi_AWREADY;
    endproperty
    ast_aw_handshake: assert property (aw_handshake)
        else $error("Failed assertion: aw_handshake");

    property aw_signals_valid;
        @(posedge axi_ACLK) disable iff (!axi_ARESETn)
        (axi_AWVALID && axi_AWREADY) |-> !$isunknown({axi_AWID, axi_AWADDR, axi_AWLEN, axi_AWSIZE, axi_AWBURST});
    endproperty
    ast_aw_signals_valid: assert property (aw_signals_valid)
        else $error("Failed assertion: aw_signals_valid");

    //check if wvalid is asserted within 2 clock cycles after aw handshake
    property aw_to_wvalid;
        @(posedge axi_ACLK) disable iff (!axi_ARESETn)
        (axi_AWVALID && axi_AWREADY) |-> ##[0:2] (axi_WVALID);
    endproperty
    ast_aw_to_wvalid: assert property (aw_to_wvalid)
        else $error("Failed assertion: aw_to_wvalid");

    property w_handshake;
        @(posedge axi_ACLK) disable iff (!axi_ARESETn)
        axi_WVALID |-> axi_WREADY;
    endproperty
    ast_w_handshake: assert property (w_handshake)
        else $error("Failed assertion: w_handshake");

    property w_signals_valid;
        @(posedge axi_ACLK) disable iff (!axi_ARESETn)
        (axi_WVALID && axi_WREADY) |-> !$isunknown({axi_WDATA, axi_WSTRB});
    endproperty
    ast_w_signals_valid: assert property (w_signals_valid)
        else $error("Failed assertion: w_signals_valid");

    property check_wlast;
        @(posedge axi_ACLK) disable iff (!axi_ARESETn)
        (axi_WVALID && axi_WREADY) && (wr_beat_num == (latched_awlen-1)) |-> axi_WLAST;
    endproperty
    ast_check_wlast: assert property (check_wlast)
        else $error("Failed assertion: check_wlast");

    //check if bvalid is asserted within 2 clock cycles after w handshake
    property w_to_bvalid;
        @(posedge axi_ACLK) disable iff (!axi_ARESETn)
        (axi_WVALID && axi_WREADY) |=> !(axi_WVALID && axi_WREADY) |-> ##[0:2](axi_BVALID);
    endproperty
    ast_w_to_bvalid: assert property (w_to_bvalid)
        else $error("Failed assertion: w_to_bvalid");

    property b_handshake;
        @(posedge axi_ACLK) disable iff (!axi_ARESETn)
        axi_BVALID |-> axi_BREADY;
    endproperty
    ast_b_handshake: assert property (b_handshake)
        else $error("Failed assertion: b_handshake");

    property b_signal_valid;
        @(posedge axi_ACLK) disable iff (!axi_ARESETn)
        (axi_BVALID && axi_BREADY) |-> !$isunknown(axi_BID) && (axi_BRESP === 2'b00);
    endproperty
    ast_b_signal_valid: assert property (b_signal_valid)
        else $error("Failed assertion: b_signal_valid");





    // Assertions for AR & R channel
    property ar_handshake;
        @(posedge axi_ACLK) disable iff (!axi_ARESETn)
        axi_ARVALID |-> axi_ARREADY;
    endproperty
    ast_ar_handshake: assert property (ar_handshake)
        else $error("Failed assertion: ar_handshake");

    property ar_signals_valid;
        @(posedge axi_ACLK) disable iff (!axi_ARESETn)
        (axi_ARVALID && axi_ARREADY) |-> !$isunknown({axi_ARID, axi_ARADDR, axi_ARLEN, axi_ARSIZE, axi_ARBURST});
    endproperty
    ast_ar_signals_valid: assert property (ar_signals_valid)
        else $error("Failed assertion: ar_signals_valid");

    //check if rvalid is asserted within 2 clock cycles after ar handshake
    property ar_to_rvalid;
        @(posedge axi_ACLK) disable iff (!axi_ARESETn)
        (axi_ARVALID && axi_ARREADY) |-> ##[0:2](axi_RVALID);
    endproperty
    ast_ar_to_rvalid: assert property (ar_to_rvalid)
        else $error("Failed assertion: ar_to_rvalid");

    property r_handshake;
        @(posedge axi_ACLK) disable iff (!axi_ARESETn)
        axi_RVALID |-> axi_RREADY;
    endproperty
    ast_r_handshake: assert property (r_handshake)
        else $error("Failed assertion: r_handshake");

    property r_signals_valid;
        @(posedge axi_ACLK) disable iff (!axi_ARESETn)
        (axi_RVALID && axi_RREADY) |-> !$isunknown({axi_RDATA, axi_RID}) && (axi_RRESP === 2'b00);
    endproperty
    ast_r_signals_valid: assert property (r_signals_valid)
        else $error("Failed assertion: r_signals_valid");

    property check_rlast;
        @(posedge axi_ACLK) disable iff (!axi_ARESETn)
        (axi_RVALID && axi_RREADY) && (next_rd_beat_num == (latched_arlen-1)) |=> axi_RLAST;
    endproperty
    ast_check_rlast: assert property (check_rlast)
        else $error("Failed assertion: check_rlast");

endmodule