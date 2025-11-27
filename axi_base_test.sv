class axi_base_test extends uvm_test;
    `uvm_component_utils(axi_base_test)

    axi_env env;
    axi_seq_directed_wr_rd d_seq;
    axi_burst_rand_wr_rd_seq v_seq;
    virtual axi_if.drv_mp vif;

    int num_iters = 1;

    function new(string name = "axi_base_test", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Factory create env (which internally knows the parameters)
        env = axi_env::type_id::create("env", this);

        // Set agent active/passive if needed
        uvm_config_db#(uvm_active_passive_enum)::set(this, "env.agt", "is_active", UVM_ACTIVE);

        // Get number of iterations
        if ($value$plusargs("ITER=%d", num_iters))
            `uvm_info(get_type_name(), $sformatf("User defined iterations = %0d", num_iters), UVM_LOW)
        else
            `uvm_info(get_type_name(), $sformatf("Default iterations = %0d", num_iters), UVM_LOW)
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        `uvm_info(get_type_name(), "Base test running", UVM_LOW)

        // Get virtual interface
        if (!uvm_config_db#(virtual axi_if.drv_mp)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "Virtual interface (drv_mp) not found in config DB")

        `uvm_info(get_type_name(), "Waiting for reset to be de-asserted...", UVM_LOW)
        @(posedge `AXI_CLOCK);
        wait(`AXI_RESET === 1);
        `uvm_info(get_type_name(), "Reset is de-asserted. Starting test...", UVM_LOW)

        //1. Start Directed Sequence
        `uvm_info(get_full_name(), "Starting Directed AXI Read/Write Test Sequence...", UVM_LOW)
        d_seq = axi_seq_directed_wr_rd::type_id::create("d_seq");
        d_seq.start(null);

        //2. Start Randomized Sequence
        for (int i = 0; i < num_iters; i++) begin
            v_seq = axi_burst_rand_wr_rd_seq::type_id::create($sformatf("v_seq_%0d", i));
            v_seq.start(null);

            `uvm_info(get_full_name(), $sformatf("Finished iteration %0d of %0d.", i + 1, num_iters), UVM_LOW)
        end

        phase.drop_objection(this);
    endtask
endclass