MAKEFLAGS += --silent

ifndef test
	test=axi_base_test
endif

ifndef seed
	seed := 1
endif

ifndef builddir
	builddir = builddir
endif

ifdef buildsubdir
	builddir_final = $(realpath .)/$(builddir)/$(buildsubdir)
else
	builddir_final = $(realpath .)/$(builddir)
endif

builddir_logs = $(builddir_final)/logs

ifndef testdir
	testdir=$(builddir_final)/$(test)/seed_$(seed)
endif

export CURRENT_DIR = $(PWD)
#export REPO_ROOT = $(realpath $(CURRENT_DIR)/../)
export UVM_HOME = /release/uvm/uvm-1.2/src

export COMPILE_LIB	= $(builddir_final)/compile_lib
export LOCAL_VCSLIB_APPEND = "\
							uvm_lib		: $(COMPILE_LIB)/uvm_lib \\n\
							axi_dut_lib	: $(COMPILE_LIB)/axi_dut_lib \\n\
							axi_tb_lib	: $(COMPILE_LIB)/axi_tb_lib"

VLOGAN_OPTIONS = -sverilog -full64 -kdb -timescale=1ps/1ps +v2k +define+UVM_NO_DEPRECATED+UVM_OBJECT_DO_NOT_NEED_CONSTRUCTOR
VCS_OPTIONS = -debug_report -debug_access+all +vcs+lic+wait +vcs+flush+all
COV_OPTIONS = -cm line+tgl+cond+fsm+branch+assert -assert enable_diag
RUN_OPTIONS = +fsdb+force +fsdb+parameter +fsdb+sva_success +fsdb+sva_status

ifeq ($(UVM_TB),1)
	VERIF_FILELIST = -f $(CURRENT_DIR)/axi_uvm_flist.f
	TOP_MODULE = axi_uvm_tb
else
	VERIF_FILELIST = -f $(CURRENT_DIR)/axi_flist.f
	TOP_MODULE = axi_tb_top
endif

ITER = 1
SEED = 0

pre_build:
	mkdir -p $(builddir_logs)
	mkdir -p $(builddir_final)/compile_lib
	echo -e "WORK > DEFAULT \\nDEFAULT:	             ./work \\nwork:                  ./work \\n$(LOCAL_VCSLIB_APPEND)" > $(builddir_final)/synopsys_sim.setup

create_ucli_do:
	echo -e "fsdbDumpvars 0 $(TOP_MODULE) +all +fsdbfile+dump.fsdb \\nfsdbDumpSVA 0 $(TOP_MODULE) \\nrun" > $(testdir)/ucli.do

############################################
######### 3 STEP VLOGAN & VCS FLOW #########
############################################

compile_%:
	make pre_build
	cd $(builddir_final) && \
	if [ "$*" = "uvm" ]; then \
		FLIST_CMD=" \
			-ntb_opts uvm-1.2" ;\
	elif [ "$*" = "axi_dut" ]; then \
		FLIST_CMD=" \
			$(CURRENT_DIR)/axi_dut.sv" ;\
	elif [ "$*" = "axi_tb" ]; then \
		FLIST_CMD=" \
			+incdir+$(UVM_HOME) \
			+incdir+$(CURRENT_DIR) \
			$(VERIF_FILELIST)" ;\
	fi ;\
	vlogan $(VLOGAN_OPTIONS) -work $*_lib -l $(builddir_logs)/$@.log $${FLIST_CMD}

elab:
	cd $(builddir_final) && \
	vcs \
		$(TOP_MODULE) \
		$(VCS_OPTIONS) $(COV_OPTIONS) \
		-l $(builddir_logs)/$@.log \
		-partcomp -fastpartcomp=j80 \
		-cm_dir $(builddir_final)/simv.vdb \
		-o $(builddir_final)/simv

run:
	mkdir -p $(testdir)/logs
	cp -rf $(builddir_final)/simv* $(testdir)/
	make create_ucli_do
	cd $(testdir) ;\
	simv \
	$(RUN_OPTIONS) \
	-cm_dir cov.vdb \
	-ucli -do ucli.do \
	+UVM_TESTNAME=$(test) +ntb_random_seed=$(seed) \
	-l logs/run.log


# Quick buildrun commands
buildrun_3step_direct_tb:
	make clean
	make compile_axi_dut
	make compile_axi_tb
	make elab
	make run

buildrun_3step_uvm_tb:
	make clean
	make compile_uvm
	make compile_axi_dut
	make compile_axi_tb UVM_TB=1
	make elab UVM_TB=1
	make run


#####################################
########## 2 STEP VCS FLOW ##########
#####################################

build:
	vcs $(VLOGAN_OPTIONS) $(VCS_OPTIONS) -ntb_opts uvm-1.2 $(COV_OPTIONS) \
	$(CURRENT_DIR)/axi_dut.sv \
	$(VERIF_FILELIST) \
	-top $(TOP_MODULE) \
	-l $@_$(TOP_MODULE).log

run_sim:
	./simv +UVM_TESTNAME=$(TESTNAME) +ITER=$(ITER) +ntb_random_seed=$(SEED) -l $@_$(TOP_MODULE).log

# Quick buildrun commands
buildrun_2step_direct_tb:
	make clean
	make build
	make run_sim

buildrun_2step_uvm_tb:
	make clean
	make build UVM_TB=1
	make run_sim TESTNAME=axi_base_test ITER=10 SEED=1 UVM_TB=1

clean:
	rm -rf csrc simv* ucli.key *.log *.fsdb DVEfiles vc_hdrs.h debug.report verdi*

#To generate coverage reports and analyze the results
#using Unified Report Generator
urgcov:
	urg -dir simv.vdb

# using Verdi Coverage GUI
verdicov:
	verdi -cov -covdir simv.vdb &