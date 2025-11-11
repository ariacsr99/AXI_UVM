class axi_read_driver #(
        parameter ADDR_WIDTH = 16,
        parameter DATA_WIDTH = 32,
        parameter LEN_WIDTH = 8,
        parameter SIZE_WIDTH = 3,
        parameter BURST_WIDTH = 2,
        parameter RESP_WIDTH = 2,
        parameter ID_WIDTH = 4,
        parameter STROBE_WIDTH = DATA_WIDTH/8,
        parameter ADDR_BYTE_SIZE = 1
    ) extends uvm_driver #(axi_read_trans #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE))
        );

    `uvm_component_param_utils(axi_read_driver #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
    ))

    virtual axi_if.drv_mp vif;

    uvm_analysis_port #(
        axi_read_trans #(
            .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
            .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
            .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
        )
        ) rd_drv_ap;

    logic [LEN_WIDTH-1:0] num_beats;

    function new(string name = "axi_read_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        rd_drv_ap = new("rd_drv_ap", this);

        if(!uvm_config_db#(virtual axi_if.drv_mp)::get(this, "", "vif", vif)) begin
        `uvm_error(get_type_name(), "Virtual interface (drv_mp) not found in config db")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        axi_read_trans rd_tr;

        forever begin
            seq_item_port.get_next_item(rd_tr);

            init_read(rd_tr);
            send_read(rd_tr);
            init_read(rd_tr);

            seq_item_port.item_done();
        end
    endtask

    virtual task send_read(axi_read_trans rd_tr);

         `uvm_info(get_type_name(), $sformatf("Starting READ Burst from addr = 0x%h", rd_tr.axi_tb_ADDR), UVM_MEDIUM)

        @(posedge vif.axi_tb_ACLK);
        vif.axi_tb_ARVALID <= 1'b1;
        vif.axi_tb_ARADDR <= {{(ADDR_WIDTH - 16){1'b0}}, rd_tr.axi_tb_ADDR};
        vif.axi_tb_ARID <= {{(ID_WIDTH - 4){1'b0}}, rd_tr.axi_tb_ID};
        vif.axi_tb_ARLEN <= {{(LEN_WIDTH - 8){1'b0}}, rd_tr.axi_tb_LEN};
        vif.axi_tb_ARSIZE <= {{(SIZE_WIDTH - 3){1'b0}}, rd_tr.axi_tb_SIZE};
        vif.axi_tb_ARBURST <= {{(BURST_WIDTH - 2){1'b0}}, rd_tr.axi_tb_BURST};
        vif.axi_tb_RREADY <= 1'b1;

        while (vif.axi_tb_ARREADY !== 1'b1) begin
            @(posedge vif.axi_tb_ACLK);
            `uvm_info(get_type_name(), $sformatf("Waiting for ARREADY to be 1..."), UVM_MEDIUM)
        end

        @(posedge vif.axi_tb_ACLK);
        vif.axi_tb_ARVALID <= 1'b0;

        num_beats <= rd_tr.axi_tb_LEN;


        while (vif.axi_tb_RVALID !== 1'b1) begin
            @(posedge vif.axi_tb_ACLK);
            `uvm_info(get_type_name(), $sformatf("Waiting for RVALID to be 1..."), UVM_MEDIUM)
        end

        for (int i = 0; i < num_beats; i++ ) begin
            `uvm_info(get_type_name(), $sformatf("[READ_TB] beat = %0d, addr = 0x%h, data = 0x%h, RLAST = %0b, RRESP = 0x%h", i, vif.axi_tb_ARADDR, vif.axi_tb_RDATA, vif.axi_tb_RLAST, vif.axi_tb_RRESP), UVM_MEDIUM)

            if (i == (num_beats-1)) begin
                repeat (3) @(posedge vif.axi_tb_ACLK) begin
                    if (vif.axi_tb_RVALID && vif.axi_tb_RREADY) begin
                        if (vif.axi_tb_RLAST !== 1'b1 && vif.axi_tb_RRESP !== 2'b00) begin
                            `uvm_error(get_type_name(), $sformatf("ERROR: RLAST fail to assert on last beat (%0d/%0d)",i, num_beats-1))
                            `uvm_error(get_type_name(), $sformatf("ERROR: RRESP !== 2'b00, Received RRESP = 2'b%0b", vif.axi_tb_RRESP))
                        end else begin
                            `uvm_info(get_type_name(), $sformatf("RLAST asserted on last beat (%0d/%0d)",i, num_beats-1), UVM_MEDIUM)
                            `uvm_info(get_type_name(), $sformatf("READ PASS: RRESP === 2'b00"), UVM_MEDIUM)
                            break;
                        end
                    end
                end
            end
            else begin
                `uvm_info(get_type_name(), $sformatf("Waiting RLAST to be asserted on last beat (%0d/%0d)",i, num_beats-1), UVM_MEDIUM)
            end

            @(posedge vif.axi_tb_ACLK);
        end

        vif.axi_tb_RREADY <= 1'b0;
        `uvm_info(get_type_name(), $sformatf("READ Burst complete."), UVM_MEDIUM)

    endtask

    virtual task init_read(axi_read_trans rd_tr);
        @(posedge vif.axi_tb_ACLK);
        vif.axi_tb_ARVALID <= 1'b0;
        vif.axi_tb_ARADDR <= '0;
        vif.axi_tb_ARID <= '0;
        vif.axi_tb_ARLEN <= '0;
        vif.axi_tb_ARSIZE <= '0;
        vif.axi_tb_ARBURST <= '0;
        vif.axi_tb_RREADY <= 1'b1;

        num_beats <= '0;
    endtask

endclass