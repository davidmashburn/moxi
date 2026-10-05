/* GTK desktop services, including the private deferred-event boundary. */
#include "../linux_window.c"
#include <assert.h>

static void drain_events(void) { while (moxi_window_poll_event()) {} }
static gboolean flood_input(gpointer data) {
    int count = data ? GPOINTER_TO_INT(data) : EVENT_CAPACITY+12;
    for (int i=0;i<count;++i) {
        Event event = new_event(3); event.target = i; event.text = copy_text("🙂"); push(event);
    }
    return G_SOURCE_REMOVE;
}
static void check_deferred_input(void) {
    drain_events(); int before = dropped;
    clipboard_reading = TRUE; flood_input(NULL); clipboard_reading = FALSE;
    /* New input joins the deferred tail rather than overtaking older events. */
    Event last = new_event(10); last.target = 1000; push(last);
    assert(moxi_window_event_queue_depth() == EVENT_CAPACITY+13);
    for (int i=0;i<EVENT_CAPACITY+12;++i) {
        assert(moxi_window_poll_event() == 3 && moxi_window_event_target() == i);
        assert(moxi_window_event_codepoint() == 0x1f642);
    }
    assert(moxi_window_poll_event() == 10 && moxi_window_event_target() == 1000);
    assert(!moxi_window_poll_event() && dropped == before);
    puts("Clipboard dispatch retains excess input and subsequent event ordering: pass");
    clipboard_reading = TRUE; clipboard_overflow = FALSE;
    for (int i=0;i<EVENT_CAPACITY+DEFERRED_EVENT_CAPACITY+12;++i) {
        Event event = new_event(3); event.target = i; push(event);
    }
    clipboard_reading = FALSE;
    assert(clipboard_overflow && dropped == before+12);
    assert(moxi_window_event_queue_depth() == EVENT_CAPACITY+DEFERRED_EVENT_CAPACITY);
    for (int i=0;i<EVENT_CAPACITY+DEFERRED_EVENT_CAPACITY;++i)
        assert(moxi_window_poll_event() == 3 && moxi_window_event_target() == i);
    assert(!moxi_window_poll_event());
    puts("Clipboard deferred capacity reports overflow and preserves accepted event order: pass");
}

typedef struct { GdkContentProvider parent; } SlowProvider;
typedef struct { GdkContentProviderClass parent; } SlowProviderClass;
G_DEFINE_TYPE(SlowProvider,slow_provider,GDK_TYPE_CONTENT_PROVIDER)
static GdkContentFormats *slow_formats(GdkContentProvider *provider) {
    (void)provider; const char *mime[] = {"text/plain;charset=utf-8"};
    return gdk_content_formats_new(mime,1);
}
static gboolean slow_complete(gpointer data) {
    GTask *task = data;
    if (!g_task_return_error_if_cancelled(task))
        g_task_return_new_error(task,G_IO_ERROR,G_IO_ERROR_FAILED,"Test provider deliberately stalled");
    g_object_unref(task); return G_SOURCE_REMOVE;
}
static void slow_write(GdkContentProvider *provider, const char *mime, GOutputStream *stream,
    int priority, GCancellable *cancel, GAsyncReadyCallback callback, gpointer data) {
    (void)mime; (void)stream; (void)priority;
    GTask *task = g_task_new(provider,cancel,callback,data);
    g_timeout_add(1500,slow_complete,task);
}
static gboolean slow_finish(GdkContentProvider *provider, GAsyncResult *result, GError **error) {
    (void)provider; return g_task_propagate_boolean(G_TASK(result),error);
}
static void slow_provider_class_init(SlowProviderClass *klass) {
    GdkContentProviderClass *provider = GDK_CONTENT_PROVIDER_CLASS(klass);
    provider->ref_formats = slow_formats; provider->ref_storable_formats = slow_formats;
    provider->write_mime_type_async = slow_write; provider->write_mime_type_finish = slow_finish;
}
static void slow_provider_init(SlowProvider *provider) { (void)provider; }
static void check_clipboard(void) {
    moxi_window_open("Moxi clipboard regression",200,100,0,0,0,0,1,0);
    moxi_clipboard_set("A🙂日");
    assert(moxi_clipboard_read_snapshot() == 3);
    assert(moxi_clipboard_codepoint_at(0) == 'A');
    assert(moxi_clipboard_codepoint_at(1) == 0x1f642);
    assert(moxi_clipboard_codepoint_at(2) == 0x65e5);
    assert(moxi_clipboard_codepoint_at(-1) == -1 && moxi_clipboard_codepoint_at(3) == -1);
    moxi_clipboard_set("changed");
    assert(moxi_clipboard_codepoint_at(1) == 0x1f642); /* Stable until next read. */
    assert(moxi_clipboard_read_snapshot() == 7);
    moxi_clipboard_set(""); assert(moxi_clipboard_read_snapshot() == 0);
    puts("GTK clipboard Unicode, empty content and stable read snapshot: pass");

    GdkContentProvider *provider = g_object_new(slow_provider_get_type(),NULL);
    assert(gdk_clipboard_set_content(native_clipboard(),provider)); g_object_unref(provider);
    drain_events(); int before = dropped;
    g_timeout_add(10,flood_input,NULL);
    gint64 start = g_get_monotonic_time();
    assert(moxi_clipboard_read_snapshot() == -1);
    gint64 elapsed = g_get_monotonic_time()-start;
    assert(elapsed >= 900000 && elapsed < 2500000);
    assert(moxi_window_event_queue_depth() >= EVENT_CAPACITY+12);
    int received = 0;
    while (moxi_window_poll_event()) if (moxi_window_event_target() >= 0) {
        assert(moxi_window_event_target() == received++);
        assert(moxi_window_event_codepoint() == 0x1f642);
    }
    assert(received == EVENT_CAPACITY+12 && dropped == before);
    moxi_window_wait(0.7f); drain_events(); /* Complete the cancelled async callback. */
    provider = g_object_new(slow_provider_get_type(),NULL);
    assert(gdk_clipboard_set_content(native_clipboard(),provider)); g_object_unref(provider);
    before = dropped;
    g_timeout_add(10,flood_input,GINT_TO_POINTER(EVENT_CAPACITY+DEFERRED_EVENT_CAPACITY+12));
    assert(moxi_clipboard_read_snapshot() == -1 && clipboard_overflow);
    assert(dropped >= before+12 && moxi_window_event_queue_depth() <= EVENT_CAPACITY+DEFERRED_EVENT_CAPACITY);
    received = 0;
    while (moxi_window_poll_event()) if (moxi_window_event_target() >= 0)
        assert(moxi_window_event_target() == received++);
    assert(received > 0 && received <= EVENT_CAPACITY+DEFERRED_EVENT_CAPACITY);
    moxi_window_close();
    puts("GTK clipboard deadline returns failure and retains dispatched input: pass");
    puts("GTK clipboard deferred exhaustion aborts the read and reports dropped input: pass");
}

static void publish_fixture(int focus) {
    moxi_window_begin_frame();
    moxi_window_text_editor_key(13);
    moxi_window_set_text_input_at(0,"A🙂日",40,140,180,36,
        0.1f,0.1f,0.1f,1,1,1,1,1,0,16,0,focus==13,2,1,2,"",0,0);
    moxi_window_begin_accessibility();
    moxi_window_set_accessibility_at(0,100,-1,5,"Service group","","group hint",20,20,300,220,
        1,0,0,0,0,0,0,0,0,0);
    moxi_window_set_accessibility_at(1,41,100,2,"Invoke service","","action hint",40,40,120,32,
        1,focus==41,0,0,0,0,0,0,0,1);
    moxi_window_set_accessibility_at(2,42,100,2,"Disabled service","","",40,80,120,32,
        0,0,0,0,0,0,0,0,0,1);
    moxi_window_set_accessibility_at(3,43,100,6,"Checked service","on","",180,40,100,32,
        1,0,1,1,0,0,0,0,0,1);
    moxi_window_set_accessibility_at(4,13,100,3,"Service editor","A🙂日","editor hint",40,140,180,36,
        1,focus==13,0,0,0,0,0,0,0,0);
    moxi_window_end_accessibility(); moxi_window_end_frame();
}
static void run_fixture(void) {
    g_set_prgname("moxi-native-services-fixture");
    moxi_window_open("Moxi desktop service fixture",360,280,0,0,0,0,1,0);
    publish_fixture(13);
    printf("READY\n"); fflush(stdout);
    gint64 deadline = g_get_monotonic_time()+45000000;
    int activated = 0;
    while (opened && g_get_monotonic_time() < deadline) {
        moxi_window_wait(0.25f);
        int kind;
        while ((kind=moxi_window_poll_event())) {
            if (kind == 2) {
                printf("KEY key=%d\n",moxi_window_event_key()); fflush(stdout);
            }
            if (kind != 10) continue;
            assert(moxi_window_event_target() == 41 && moxi_window_event_action() == 1);
            assert(moxi_clipboard_read_snapshot() == 9);
            assert(strcmp(clipboard_snapshot,"outside🙂日") == 0);
            moxi_clipboard_set("Moxi🙂日");
            assert(strcmp(clipboard_snapshot,"outside🙂日") == 0);
            publish_fixture(41); ++activated;
            printf("ACTION target=41 action=1; external clipboard read and stable snapshot: pass\n"); fflush(stdout);
        }
        if (activated && g_getenv("MOXI_SERVICES_FINISH_FILE") &&
            g_file_test(g_getenv("MOXI_SERVICES_FINISH_FILE"),G_FILE_TEST_EXISTS)) break;
    }
    assert(activated == 1); moxi_window_close();
}
int main(int argc, char **argv) {
    if (argc == 2 && strcmp(argv[1],"--fixture") == 0) { run_fixture(); return 0; }
    check_deferred_input();
    if (argc == 2 && strcmp(argv[1],"--display") == 0) { check_clipboard(); return 0; }
    assert(argc == 1); return 0;
}
