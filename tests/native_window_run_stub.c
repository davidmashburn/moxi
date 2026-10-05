/* Bounded native event source for the standalone Mojo lifecycle runner.
 * Each pump produces input that must be consumed before a subsequent wait or
 * pump can progress. The third pump closes the host without another wait.
 */
static int opened;
static int phase;
static int queued;
static int consumed;
static int waits;
static int failures;
static int open_queries;

void moxi_test_native_run_reset(void) {
    opened = 1;
    phase = queued = consumed = waits = failures = open_queries = 0;
}

int moxi_test_native_run_failures(void) { return failures; }
int moxi_test_native_run_pumps(void) { return phase; }
int moxi_test_native_run_waits(void) { return waits; }
int moxi_test_native_run_consumed(void) { return consumed; }

int moxi_window_is_open(void) {
    if (++open_queries > 64) {
        failures |= 8;
        opened = 0;
    }
    return opened;
}

void moxi_window_pump(void) {
    if (!opened || queued != 0) {
        failures |= 1;
        opened = 0;
        return;
    }
    if (++phase == 3) {
        opened = 0;
        return;
    }
    queued = 2;
}

void moxi_window_wait(float timeout_seconds) {
    ++waits;
    if (queued != 0 || !opened || timeout_seconds != -1.0f) {
        failures |= 2;
        opened = 0;
    }
}

int moxi_window_poll_event(void) {
    if (queued == 0) return 0;
    --queued;
    ++consumed;
    /* Exercise both a key payload and the codepoint text ABI while draining. */
    return queued == 1 ? 2 : 3;
}

int moxi_window_event_key(void) { return 1000; }
int moxi_window_event_modifiers(void) { return 0; }
int moxi_window_event_selection_start(void) { return -1; }
int moxi_window_event_selection_end(void) { return -1; }
int moxi_window_event_target(void) { return -1; }
int moxi_window_event_action(void) { return -1; }
int moxi_window_event_codepoint_at(int index) {
    return index == 0 ? 0x65e5 : -1;
}
float moxi_window_event_x(void) { return 0; }
float moxi_window_event_y(void) { return 0; }
float moxi_window_event_scroll_x(void) { return 0; }
float moxi_window_event_scroll_y(void) { return 0; }
float moxi_window_width(void) { return 320; }
float moxi_window_height(void) { return 160; }
