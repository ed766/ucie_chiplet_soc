#include <cstdlib>
#include <memory>
#include "verilated.h"
#include "verilated_cov.h"
#ifdef RV32M_COVERAGE_UNIT
#include "Vtb_rv32_muldiv.h"
using CoverageTop = Vtb_rv32_muldiv;
#else
#include "Vtb_rv32m_boundaries.h"
using CoverageTop = Vtb_rv32m_boundaries;
#endif

int main(int argc, char** argv) {
    auto context = std::make_unique<VerilatedContext>();
    context->commandArgs(argc, argv);
    auto top = std::make_unique<CoverageTop>(context.get());
    while (!context->gotFinish()) {
        top->eval();
        if (!top->eventsPending()) break;
        context->time(top->nextTimeSlot());
    }
    top->final();
    const char* output = std::getenv("VERILATOR_COVERAGE_FILE");
    if (output) VerilatedCov::write(output);
    return context->gotFinish() ? 0 : 1;
}
