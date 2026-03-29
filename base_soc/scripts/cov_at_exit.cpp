// Simple atexit hook to write Verilator coverage without relying on plusargs.
#include "verilated.h"
#if VM_COVERAGE
# include "verilated_cov.h"
# include <cstdlib>
# include <string>
static void cov_exit() {
    const char* p = std::getenv("COVERAGE_OUT");
    const char* path = (p && *p) ? p : "coverage.dat";
    VerilatedCov::write(path);
}
static int reg_cov = (std::atexit(cov_exit), 0);
#else
// No coverage compiled in; nothing to do.
#endif

