export CURRENT_DIR = ${PWD}
#export REPO_ROOT = $(realpath $(CURRENT_DIR)/../)

export TOP_MODULE = axi_tb_top

VCS_OPTIONS = -sverilog -full64 -ntb_opts uvm-1.2 -kdb -timescale=1ps/1ps -debug_report -debug_access+all +v2k +vcs+lic+wait +vcs+flush+all
COV_OPTIONS = -cm line+tgl+cond+fsm+branch+assert -assert enable_diag
FILELIST = -f axi_flist.f
ITER = 1
SEED = 0

build_axi:
	vcs ${VCS_OPTIONS} ${COV_OPTIONS} \
	${FILELIST} \
	-top ${TOP_MODULE} \
	-l $@.log

run:
	./simv +UVM_TESTNAME=${TESTNAME} +ITER=${ITER} +ntb_random_seed=${SEED} -l $@.log

clean:
	rm -rf csrc simv* ucli.key *.log *.fsdb DVEfiles vc_hdrs.h debug.report verdi*

#To generate coverage reports and analyze the results
#using Unified Report Generator
urgcov:
	urg -dir simv.vdb

# using Verdi Coverage GUI
verdicov:
	verdi -cov -covdir simv.vdb &

buildrun:
	make clean
	make build_axi
	make run

all:
	make clean
	make build_apb
	make run_sim TESTNAME=apb_base_test ITER=100 SEED=1