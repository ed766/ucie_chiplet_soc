`ifndef CHIPLET_PROTOCOL_ASSERTIONS_SVH
`define CHIPLET_PROTOCOL_ASSERTIONS_SVH

// Reusable protocol/control assertions used by both bounded harnesses and
// simulation-facing checkers where the required observation signals exist.

`define CHIPLET_ASSERT_CREDIT_BOUNDED(NAME, CLK, RST_N, CREDIT, MAX_CREDITS) \
    property NAME; \
        @(posedge CLK) (RST_N) |-> ((CREDIT) <= (MAX_CREDITS)); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_DMA_QUEUE_COUNTS_BOUNDED(NAME, CLK, RST_N, SUBMIT_COUNT, SUBMIT_DEPTH, COMP_COUNT, COMP_DEPTH) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            ((SUBMIT_COUNT) <= (SUBMIT_DEPTH)) && ((COMP_COUNT) <= (COMP_DEPTH)); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_DMA_COMPLETION_HAS_ACCEPT(NAME, CLK, RST_N, COMP_PUSH, IS_ACCEPTED_COMP, ACCEPTED_COUNT, COMPLETION_COUNT) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            (COMP_PUSH) && (IS_ACCEPTED_COMP) |-> ((ACCEPTED_COUNT) > (COMPLETION_COUNT)); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_DMA_COMPLETION_COUNT_NOT_AHEAD(NAME, CLK, RST_N, ACCEPTED_COUNT, COMPLETION_COUNT) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            ((COMPLETION_COUNT) <= (ACCEPTED_COUNT)); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_DMA_ACCEPTED_ACCOUNTING(NAME, CLK, RST_N, ACCEPTED_COUNT, COMPLETION_COUNT, ACTIVE_COUNT, QUEUED_COUNT) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            ((ACCEPTED_COUNT) == ((COMPLETION_COUNT) + (ACTIVE_COUNT) + (QUEUED_COUNT))); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_DMA_RETIRE_STABLE_WHILE_STALLED(NAME, CLK, RST_N, STALL, TAG, STATUS, ERR, WORDS) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            (STALL) |=> ((STALL) || ($stable(TAG) && $stable(STATUS) && $stable(ERR) && $stable(WORDS))); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_DMA_FRONT_STABLE_UNTIL_POP(NAME, CLK, RST_N, NONEMPTY, POP, TAG, STATUS, WORDS) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            ((NONEMPTY) && !(POP)) |=> (!(NONEMPTY) || (POP) || ($stable(TAG) && $stable(STATUS) && $stable(WORDS))); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_DMA_SUBMIT_REJECT_ZERO_WORDS(NAME, CLK, RST_N, PUSH, STATUS, WORDS, REJECT_STATUS) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            ((PUSH) && ((STATUS) == (REJECT_STATUS))) |-> ((WORDS) == 0); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_DMA_RUNTIME_WORDS_BOUNDED(NAME, CLK, RST_N, PUSH, STATUS, WORDS, LEN, RUNTIME_STATUS) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            ((PUSH) && ((STATUS) == (RUNTIME_STATUS))) |-> ((WORDS) <= (LEN)); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_IRQ_LEVEL_WHILE_PENDING(NAME, CLK, RST_N, PENDING_EXPR, IRQ_EXPR) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            (PENDING_EXPR) |-> (IRQ_EXPR); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_MEM_PARITY_STATUS(NAME, CLK, RST_N, PARITY_EVENT, ERR_KIND_EXPR, EXPECTED_KIND) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            (PARITY_EVENT) |=> ((ERR_KIND_EXPR) == (EXPECTED_KIND)); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_MEM_INVALID_DMA_ABORT(NAME, CLK, RST_N, ERROR_COMP_EVENT, ERR_CODE_EXPR, EXPECTED_CODE) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            (ERROR_COMP_EVENT) |-> ((ERR_CODE_EXPR) == (EXPECTED_CODE)); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_MEM_PARITY_DMA_CODE(NAME, CLK, RST_N, PARITY_DMA_EVENT, ERR_CODE_EXPR, EXPECTED_CODE) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            (PARITY_DMA_EVENT) |-> ((ERR_CODE_EXPR) == (EXPECTED_CODE)); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_MEM_FAULT_NO_DEST_COMMIT(NAME, CLK, RST_N, FAULT_ACTIVE, DEST_WRITE_EVENT) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            (FAULT_ACTIVE) |-> !(DEST_WRITE_EVENT); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_MEM_INVALID_CLEAR_TARGET_ONLY(NAME, CLK, RST_N, WRITE_EVENT, PRE_MASK, POST_MASK, TARGET_BANK) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            (WRITE_EVENT) |-> (((POST_MASK) & ~(2'b01 << (TARGET_BANK))) == ((PRE_MASK) & ~(2'b01 << (TARGET_BANK)))); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_RETRY_REPLAYS_LAST(NAME, CLK, RST_N, RESEND_EVENT, REPLAY_FLIT, LAST_FLIT) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            (RESEND_EVENT) |-> ((REPLAY_FLIT) == (LAST_FLIT)); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_RETRY_BLOCKS_NEW_RETIRE(NAME, CLK, RST_N, RETRY_PENDING, NEW_RETIRE_EVENT) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            (RETRY_PENDING) |-> !(NEW_RETIRE_EVENT); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_STABLE_WHILE_BACKPRESSURED(NAME, CLK, RST_N, VALID, READY, DATA) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            ((VALID) && !(READY)) |=> ((VALID) && $stable(DATA)); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_ISO_TRACKS_SWITCH(NAME, CLK, RST_N, ISO_N, SWITCH_ON) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            ((ISO_N) == (SWITCH_ON)); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_RESTORE_AFTER_SLEEP(NAME, CLK, RST_N, RESTORE, POWER_STATE, SLEEP_STATE, RUN_STATE) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            (RESTORE) |-> ($past(POWER_STATE) == (SLEEP_STATE) && (POWER_STATE) == (RUN_STATE)); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_EVENT_AFTER_RESTORE(NAME, CLK, RST_N, EVENT, RESTORE_SEEN) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            (EVENT) |-> (RESTORE_SEEN); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_DEEP_SLEEP_CLEARS_CONTEXT(NAME, CLK, RST_N, DEEP_TO_RUN_EVENT, SUBMIT_COUNT, COMP_COUNT, ACTIVE_VALID) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            (DEEP_TO_RUN_EVENT) |=> (((SUBMIT_COUNT) == 0) && ((COMP_COUNT) == 0) && !(ACTIVE_VALID)); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_NO_PROGRESS_WHILE_OFF(NAME, CLK, RST_N, DOMAIN_OFF, PROGRESS_EVENT) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            (DOMAIN_OFF) |-> !(PROGRESS_EVENT); \
    endproperty \
    assert property (NAME);

`define CHIPLET_ASSERT_VALID_PST_COMBO(NAME, CLK, RST_N, VALID_EXPR) \
    property NAME; \
        @(posedge CLK) disable iff (!(RST_N)) \
            (VALID_EXPR); \
    endproperty \
    assert property (NAME);

`endif
