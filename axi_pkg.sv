package axi_pkg;
    parameter ADDR_WIDTH  = 16;
    parameter LEN_WIDTH   = 8;
    parameter SIZE_WIDTH  = 3;
    parameter BURST_WIDTH = 2;
    parameter ID_WIDTH    = 4;

    typedef struct packed {
        logic [ADDR_WIDTH-1:0] addr;
        logic [LEN_WIDTH-1:0]  len;
        logic [SIZE_WIDTH-1:0] size;
        logic [ID_WIDTH-1:0]   id;
        logic [BURST_WIDTH-1:0] burst;
    } axi_wr_struct;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    `include "tb_macros.svh"

    `include "axi_base_trans.sv"
    `include "axi_write_trans.sv"
    `include "axi_read_trans.sv"

    `include "axi_burst_trans.sv"

    // Declare distinct analysis implementation types for each channel
    `uvm_analysis_imp_decl(_AW)
    `uvm_analysis_imp_decl(_W)
    `uvm_analysis_imp_decl(_B)
    `uvm_analysis_imp_decl(_AR)
    `uvm_analysis_imp_decl(_R)

    // Compilation order matters
    `include "axi_write_seq.sv"
    `include "axi_read_seq.sv"
    `include "axi_rand_wr_seq.sv"
    `include "axi_rand_rd_seq.sv"
    `include "axi_sqr_write.sv"
    `include "axi_sqr_read.sv"
    `include "axi_seq_directed_wr_rd.sv"
    `include "axi_burst_rand_wr_rd_seq.sv"
    `include "axi_write_driver.sv"
    `include "axi_read_driver.sv"
    `include "axi_monitor.sv"
    `include "axi_agt.sv"
    `include "axi_cov.sv"
    `include "axi_scb.sv"
    `include "axi_env.sv"
    `include "axi_base_test.sv"
    //include other tests
endpackage