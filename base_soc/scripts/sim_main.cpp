// Generic Verilator runner that advances time deterministically.
// Uses macros to select the TB top class and header at compile time.
// Define:
//  -DVTB_HEADER="V<tb>.h"
//  -DVTB_CLASS=V<tb>
// Optional env:
//  MAX_SIM_TIME: absolute max timesteps to run (default: 5e10)
//  TICK_PS: time increment per loop in ps (default: 1 time unit via timeInc(1))

#include "verilated.h"
#include <cstdlib>
#include <cstdint>
#include <chrono>

#ifndef VTB_HEADER
#error "VTB_HEADER must be defined, e.g. -DVTB_HEADER=\"Vtb_iso_cell.h\""
#endif
#ifndef VTB_CLASS
#error "VTB_CLASS must be defined, e.g. -DVTB_CLASS=Vtb_iso_cell"
#endif

#include VTB_HEADER

static uint64_t getenv_u64(const char* name, uint64_t defv) {
    if (const char* p = std::getenv(name)) {
        if (*p) return strtoull(p, nullptr, 0);
    }
    return defv;
}

static uint64_t getenv_u64_clamped(const char* name, uint64_t defv, uint64_t minv, uint64_t maxv) {
    uint64_t v = getenv_u64(name, defv);
    if (v < minv) v = minv;
    if (v > maxv) v = maxv;
    return v;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    // Default to a generous internal limit so testbenches with #delays/clocks
    // don't terminate prematurely. Makefile sets MAX_SIM_TIME based on TIMEOUT_SECS.
    const uint64_t max_time = getenv_u64("MAX_SIM_TIME", 50'000'000'000ULL);

    // Create a context and the top module
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->traceEverOn(true);

    const std::unique_ptr<VTB_CLASS> top{new VTB_CLASS{contextp.get()}};

    // Optional heartbeats to aid debugging timeouts
    // HB_WALL_SECS: emit heartbeat every N seconds of wall time (0=disabled)
    // HB_SIM_DELTA: emit when simulated time advanced by this delta (0=disabled)
    const uint64_t hb_wall_secs = getenv_u64_clamped("HB_WALL_SECS", 0, 0, 3600);
    const uint64_t hb_sim_delta = getenv_u64("HB_SIM_DELTA", 0);
    auto hb_wall_last = std::chrono::steady_clock::now();
    vluint64_t hb_sim_last = 0;

    // Run loop: if there are scheduled timed events, jump to them; otherwise tick by 1
    while (!contextp->gotFinish()) {
        top->eval();
        if (top->eventsPending()) {
            vluint64_t tnext = top->nextTimeSlot();
            // Guard: never go backwards; if stalled, advance by 1
            if (tnext <= contextp->time()) {
                contextp->timeInc(1);
            } else {
                contextp->time(tnext);
            }
        } else {
            // No pending events, advance time by 1 to drive clocks with #delays
            contextp->timeInc(1);
        }

        // Heartbeats (stdout) to show progress
        if (hb_sim_delta) {
            if (contextp->time() - hb_sim_last >= hb_sim_delta) {
                hb_sim_last = contextp->time();
                VL_PRINTF("[hb] sim_time=%llu\n", (unsigned long long)hb_sim_last);
            }
        }
        if (hb_wall_secs) {
            auto now = std::chrono::steady_clock::now();
            auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - hb_wall_last).count();
            if (elapsed >= (long long)hb_wall_secs) {
                hb_wall_last = now;
                VL_PRINTF("[hb] wall=%llus sim_time=%llu\n",
                          (unsigned long long)elapsed,
                          (unsigned long long)contextp->time());
            }
        }
        if (VL_UNLIKELY(contextp->time() > max_time)) {
            // Hard stop to avoid hangs; return non-zero so harness treats as failure
            VL_PRINTF("[sim_main] Reached MAX_SIM_TIME=%llu, exiting\n",
                      (unsigned long long)max_time);
            top->final();
            return 2;
        }
    }

    top->final();
    return 0;
}
