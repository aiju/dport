if [ z"$1" = z--trace ]; then
        a="--trace"
else
        a=""
fi
verilator $a --cc -Wno-REALCVT -Wno-CASEINCOMPLETE -I.. val.v --exe valc.cpp && (cd obj_dir; make -f Vval.mk Vval) && ./obj_dir/Vval || exit 0
/gtkwave/bin/vcd2fst obj_dir/sim.vcd obj_dir/sim.fst
