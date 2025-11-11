module axi_uvm_tb;
    import uvm_pkg::*;
    import axi_pkg::*;
    `include "uvm_macros.svh"

    // $time is a built-in system function
    initial $display(">>>>>>>> SIM TIME START: %0t", $time);
    final   $display(">>>>>>>> SIM TIME END  : %0t", $time);

    localparam ADDR_WIDTH = 16;
    localparam DATA_WIDTH = 32;
    localparam LEN_WIDTH = 8;
    localparam SIZE_WIDTH = 3;
    localparam BURST_WIDTH = 2;
    localparam RESP_WIDTH = 2; //2-bit for OKAY, EXOKAY, SLVERR, DECERR
    localparam ID_WIDTH = 4;
    localparam STROBE_WIDTH = DATA_WIDTH/8;
    localparam ADDR_BYTE_SIZE = 1; //num of bytes each addr can store

    clk_if m_clk_if();
    axi_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH),
        .BURST_WIDTH(BURST_WIDTH),
        .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .STROBE_WIDTH(STROBE_WIDTH),
        .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ) m_axi_if (m_clk_if.axi_tb_ACLK);

    axi_dut #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH),
        .BURST_WIDTH(BURST_WIDTH),
        .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .STROBE_WIDTH(STROBE_WIDTH),
        .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ) dut (
        .axi_ACLK(m_clk_if.axi_tb_ACLK),
        .axi_ARESETn(m_axi_if.axi_tb_ARESETn),
        .axi_AWVALID(m_axi_if.axi_tb_AWVALID),
        .axi_AWREADY(m_axi_if.axi_tb_AWREADY),
        .axi_AWID(m_axi_if.axi_tb_AWID),
        .axi_AWADDR(m_axi_if.axi_tb_AWADDR),
        .axi_AWLEN(m_axi_if.axi_tb_AWLEN),
        .axi_AWSIZE(m_axi_if.axi_tb_AWSIZE),
        .axi_AWBURST(m_axi_if.axi_tb_AWBURST),
        .axi_WVALID(m_axi_if.axi_tb_WVALID),
        .axi_WREADY(m_axi_if.axi_tb_WREADY),
        .axi_WDATA(m_axi_if.axi_tb_WDATA),
        .axi_WSTRB(m_axi_if.axi_tb_WSTRB),
        .axi_WLAST(m_axi_if.axi_tb_WLAST),
        .axi_BVALID(m_axi_if.axi_tb_BVALID),
        .axi_BREADY(m_axi_if.axi_tb_BREADY),
        .axi_BID(m_axi_if.axi_tb_BID),
        .axi_BRESP(m_axi_if.axi_tb_BRESP),
        .axi_ARVALID(m_axi_if.axi_tb_ARVALID),
        .axi_ARREADY(m_axi_if.axi_tb_ARREADY),
        .axi_ARID(m_axi_if.axi_tb_ARID),
        .axi_ARADDR(m_axi_if.axi_tb_ARADDR),
        .axi_ARLEN(m_axi_if.axi_tb_ARLEN),
        .axi_ARSIZE(m_axi_if.axi_tb_ARSIZE),
        .axi_ARBURST(m_axi_if.axi_tb_ARBURST),
        .axi_RVALID(m_axi_if.axi_tb_RVALID),
        .axi_RREADY(m_axi_if.axi_tb_RREADY),
        .axi_RID(m_axi_if.axi_tb_RID),
        .axi_RDATA(m_axi_if.axi_tb_RDATA),
        .axi_RRESP(m_axi_if.axi_tb_RRESP),
        .axi_RLAST(m_axi_if.axi_tb_RLAST)
    );

    // bind axi_dut axi_assertions #(
    //     .ADDR_WIDTH(ADDR_WIDTH),
    //     .DATA_WIDTH(DATA_WIDTH),
    //     .LEN_WIDTH(LEN_WIDTH),
    //     .SIZE_WIDTH(SIZE_WIDTH),
    //     .BURST_WIDTH(BURST_WIDTH),
    //     .RESP_WIDTH(RESP_WIDTH),
    //     .ID_WIDTH(ID_WIDTH),
    //     .STROBE_WIDTH(STROBE_WIDTH),
    //     .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    // ) assertion_chk (
    //     .*
    // );

    initial begin
        m_axi_if.axi_tb_AWVALID = '0;
        m_axi_if.axi_tb_AWID = '0;
        m_axi_if.axi_tb_AWADDR = '0;
        m_axi_if.axi_tb_AWLEN = '0;
        m_axi_if.axi_tb_AWSIZE = '0;
        m_axi_if.axi_tb_AWBURST = '0;
        m_axi_if.axi_tb_WVALID = '0;
        m_axi_if.axi_tb_WDATA = '0;
        m_axi_if.axi_tb_WSTRB = '0;
        m_axi_if.axi_tb_WLAST = '0;
        m_axi_if.axi_tb_BREADY = '0;
        m_axi_if.axi_tb_ARVALID = '0;
        m_axi_if.axi_tb_ARID = '0;
        m_axi_if.axi_tb_ARADDR = '0;
        m_axi_if.axi_tb_ARLEN = '0;
        m_axi_if.axi_tb_ARSIZE = '0;
        m_axi_if.axi_tb_ARBURST = '0;
        m_axi_if.axi_tb_RREADY = '0;

        start_reset_seq();

    end

    initial begin
        // uvm_config_db#(virtual axi_if#(ADDR_WIDTH, DATA_WIDTH, LEN_WIDTH, SIZE_WIDTH, BURST_WIDTH, RESP_WIDTH, ID_WIDTH, STROBE_WIDTH, ADDR_BYTE_SIZE).drv_mp)::set(null, "*drv*", "vif", m_axi_if.drv_mp); //store m_axi_if.drv_mp under the name "vif" which is accessible by *drv* hierarchy

        // Make the driver's virtual interface available everywhere (store m_axi_if.drv_mp under the name "vif" which is accessible by * hierarchy)
        //uvm_config_db#(virtual axi_if#(ADDR_WIDTH, DATA_WIDTH, LEN_WIDTH, SIZE_WIDTH, BURST_WIDTH, RESP_WIDTH, ID_WIDTH, STROBE_WIDTH, ADDR_BYTE_SIZE).drv_mp)::set(null,"*", "vif", m_axi_if.drv_mp);

        //uvm_config_db#(virtual axi_if #(ADDR_WIDTH, DATA_WIDTH, LEN_WIDTH, SIZE_WIDTH, BURST_WIDTH, RESP_WIDTH, ID_WIDTH, STROBE_WIDTH, ADDR_BYTE_SIZE).mon_mp)::set(null, "*", "vif", m_axi_if.mon_mp);

        //Reduce scope - only allow env access to axi_if (Each layer only manages its children)
        uvm_config_db#(virtual axi_if)::set(null, "uvm_test_top.env", "vif", m_axi_if);
        uvm_config_db#(virtual axi_if.drv_mp)::set(null, "uvm_test_top", "vif", m_axi_if.drv_mp);

        fork
        begin
            //run_test("axi_base_test");
            run_test();// test will be chosen via UVM_TESTNAME
        end

        begin
            #1000000ns; // set timeout duration
            `uvm_fatal("TIMEOUT", $sformatf("Test timed out after %0t",$time))
        end
        join_any
        disable fork; // stop whichever thread is still running
    end

    task start_reset_seq();
        $display("@%0t: Starting reset sequence...", $time);
        m_axi_if.axi_tb_ARESETn <= 1'b0;
        repeat(10) @(posedge m_clk_if.axi_tb_ACLK);
        m_axi_if.axi_tb_ARESETn <= 1'b1;
        $display("@%0t: Reset released.", $time);
    endtask

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpSVA(0,axi_uvm_tb);
        $fsdbDumpvars(0, axi_uvm_tb);
    end

endmodule