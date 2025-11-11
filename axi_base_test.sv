// class axi_init_test #(
//     parameter ADDR_WIDTH = 16,
//     parameter DATA_WIDTH = 32,
//     parameter LEN_WIDTH = 8,
//     parameter SIZE_WIDTH = 3,
//     parameter BURST_WIDTH = 2,
//     parameter RESP_WIDTH = 2,
//     parameter ID_WIDTH = 4,
//     parameter STROBE_WIDTH = DATA_WIDTH/8,
//     parameter ADDR_BYTE_SIZE = 1
// ) extends uvm_test;

//     `uvm_component_param_utils(axi_init_test #(
//         .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
//         .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
//         .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
//     ))

//     typedef axi_sqr_write #(
//         .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
//         .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
//         .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
//     ) wr_sqr_t;

//     typedef axi_sqr_read #(
//         .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
//         .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
//         .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
//     ) rd_sqr_t;

//     axi_env #(ADDR_WIDTH, DATA_WIDTH, LEN_WIDTH, SIZE_WIDTH, BURST_WIDTH, RESP_WIDTH, ID_WIDTH, STROBE_WIDTH, ADDR_BYTE_SIZE) env;
//     // virtual sequence that coordinates random read/write
//     axi_burst_rand_wr_rd_seq #(ADDR_WIDTH, DATA_WIDTH, LEN_WIDTH, SIZE_WIDTH, BURST_WIDTH, RESP_WIDTH, ID_WIDTH, STROBE_WIDTH, ADDR_BYTE_SIZE) v_seq;
//     // virtual sequence that coordinates directed read/write
//     axi_seq_directed_wr_rd #(ADDR_WIDTH, DATA_WIDTH, LEN_WIDTH, SIZE_WIDTH, BURST_WIDTH, RESP_WIDTH, ID_WIDTH, STROBE_WIDTH, ADDR_BYTE_SIZE) d_seq;
//     virtual axi_if.drv_mp vif;

//     int num_iters = 1; // default number of iterations

//     function new(string name = "axi_init_test", uvm_component parent=null);
//         super.new(name, parent);
//     endfunction

//     virtual function void build_phase(uvm_phase phase);
//         super.build_phase(phase);

//         env = axi_env#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
//                        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
//                        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
//                       )::type_id::create("env", this);

//         uvm_config_db#(uvm_active_passive_enum)::set(this,
//                                                      "env.agt",       // Context path for the agent
//                                                      "is_active",     // Field name
//                                                      UVM_ACTIVE       // Value
//                                                     );

//         // Read user-defined iterations from command line (+ITER=N)
//         if ($value$plusargs("ITER=%d", num_iters)) begin
//             `uvm_info(get_type_name(), $sformatf("User defined iterations = %0d", num_iters), UVM_LOW)
//         end
//         else begin
//             `uvm_info(get_type_name(), $sformatf("Using default iterations = %0d", num_iters), UVM_LOW)
//         end

//     endfunction

//     virtual task run_phase(uvm_phase phase);
//         phase.raise_objection(this);

//         `uvm_info(get_type_name(), "Base test running", UVM_LOW)

//         // Get virtual interface
//         if (!uvm_config_db#(virtual axi_if.drv_mp)::get(this, "", "vif", vif))
//             `uvm_fatal(get_type_name(), "Virtual interface (drv_mp) not found in config DB")

//         `uvm_info("apb_base_test", "Waiting for reset to be de-asserted...", UVM_LOW)
//         @(posedge `AXI_CLOCK);
//         wait(`AXI_RESET === 1);
//         `uvm_info("apb_base_test", "Reset is de-asserted. Starting test...", UVM_LOW)

//         //1. Directed Sequence
//         `uvm_info(get_full_name(), "Starting Directed AXI Read/Write Test Sequence...", UVM_LOW)
//         d_seq = axi_seq_directed_wr_rd#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
//                                        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
//                                        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
//                                       )::type_id::create("d_seq");

//         // This task will block until the sequence completes
//         d_seq.start(null);

//         //2. Randomized Sequence
//         `uvm_info(get_full_name(), "Starting Randomized AXI Read/Write Test Sequence...", UVM_LOW)

//         for (int i = 0; i < num_iters; i++) begin

//             v_seq = axi_burst_rand_wr_rd_seq#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .LEN_WIDTH(LEN_WIDTH),
//                                        .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .RESP_WIDTH(RESP_WIDTH),
//                                        .ID_WIDTH(ID_WIDTH), .STROBE_WIDTH(STROBE_WIDTH), .ADDR_BYTE_SIZE(ADDR_BYTE_SIZE)
//                                       )::type_id::create($sformatf("v_seq_%0d", i));

//             // This task will block until the sequence completes
//             v_seq.start(null);

//             `uvm_info(get_full_name(), $sformatf("Finished iteration %0d of %0d.", i + 1, num_iters), UVM_LOW)
//         end

//         phase.drop_objection(this);
//     endtask

// endclass

// class axi_base_test extends axi_init_test #(
//     // Lock in the exact parameters used in the top_tb:
//     .ADDR_WIDTH(16),
//     .DATA_WIDTH(32),
//     .LEN_WIDTH(8),
//     .SIZE_WIDTH(3),
//     .BURST_WIDTH(2),
//     .RESP_WIDTH(2),
//     .ID_WIDTH(4),
//     .STROBE_WIDTH(32/8), // DATA_WIDTH/8
//     .ADDR_BYTE_SIZE(1)
// );
//     // CRITICAL: Register the non-parameterized class name with the factory!
//     // This gives the factory the simple string "axi_base_test" to look up.
//     `uvm_component_utils(axi_base_test)

//     function new(string name = "axi_base_test", uvm_component parent=null);
//         super.new(name, parent);
//     endfunction

// endclass

// Non-parametized base test
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

        //1. Directed Sequence
        `uvm_info(get_full_name(), "Starting Directed AXI Read/Write Test Sequence...", UVM_LOW)
        d_seq = axi_seq_directed_wr_rd::type_id::create("d_seq");
        d_seq.start(null);

        //2. Randomized Sequence
        for (int i = 0; i < num_iters; i++) begin
            v_seq = axi_burst_rand_wr_rd_seq::type_id::create($sformatf("v_seq_%0d", i));
            v_seq.start(null);

            `uvm_info(get_full_name(), $sformatf("Finished iteration %0d of %0d.", i + 1, num_iters), UVM_LOW)
        end

        phase.drop_objection(this);
    endtask
endclass