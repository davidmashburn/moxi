/* GTK owns the surface and input service; Mojo owns all view/layout state.
 * This Linux presenter supports the retained workbench leaves and exposes
 * published semantics through GTK's AT-SPI service. */
#include "linux_window.h"
#include "linux_text.h"
#include <gtk/gtk.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

#define SLOT_CAPACITY 1024
#define EVENT_CAPACITY 64
#define DEFERRED_EVENT_CAPACITY 256
#define CUSTOM_CAPACITY 262144
#define COLOR_ARGS(p) float p##_r, float p##_g, float p##_b, float p##_a
#define COLOR(p) ((Color){p##_r, p##_g, p##_b, p##_a})
#define BOX_ARGS float x, float y, float width, float height
#define BOX ((Box){x, y, width, height})

typedef struct { float x, y, width, height; } Box;
typedef struct { float r, g, b, a; } Color;
typedef struct {
    Box box, clip, thumb;
    Color fill, ink;
    float radius, font, value;
    int present, clipped, focused, cursor, start, end, enabled;
    int composition_start, composition_end;
    char *text, *composition;
    uintptr_t paragraph;
} Slot;
typedef struct { int kind, slot; } Order;
typedef struct {
    int kind, key, modifiers, target, action, start, end;
    float x, y, dx, dy;
    char *text;
} Event;
typedef struct {
    int id, parent, role, focused, enabled, selected, checked, expanded, has_range, actions;
    float minimum, maximum, now;
    Box box;
    char *label, *value, *hint;
} Semantic;
typedef struct {
    int id, role, container, seen;
    GtkWidget *widget;
    char *text;
    unsigned int caret, start, end;
} SemanticProxy;
typedef struct {
    int kind;
    Box box;
    Color fill, stroke;
    float radius, stroke_width;
    char *text;
} Custom;

static GtkWidget *window, *canvas, *semantic_root;
static GtkIMContext *im;
static gboolean opened, im_focused, resetting_im, im_has_preedit;
static float window_width, window_height, window_scale = 1, pointer_x, pointer_y;
static int editor_key = -1, next_editor_key = -1, active_editor = -1;
static int queue_head, queue_count, dropped, overflow, order_count, semantic_count;
static int ordered, clipped, custom_clipped;
static Box clip, custom_clip;
static Color surface = {0.05f, 0.07f, 0.10f, 1};
static Slot slots[25][SLOT_CAPACITY];
static Order order[SLOT_CAPACITY + 1];
static Semantic semantics[SLOT_CAPACITY];
static Event queue[EVENT_CAPACITY], current;
static GQueue deferred_events = G_QUEUE_INIT;
static gboolean clipboard_reading;
static gboolean clipboard_overflow;
static GCancellable *clipboard_cancel;
static char *clipboard_snapshot;
static SemanticProxy proxies[SLOT_CAPACITY];
static GArray *custom;
static FILE *trace;
static unsigned frame_number;

static void configure_input_environment(void) {
    /* IBus 1.5.29's GTK4 synchronous default loses hide-preedit responses.
     * Hybrid mode preserves cancellation; respect an explicit caller choice. */
    if (!g_getenv("IBUS_ENABLE_SYNC_MODE"))
        g_setenv("IBUS_ENABLE_SYNC_MODE","2",FALSE);
}

/* Opt-in validation evidence, off in normal runs. These are published Mojo
 * semantics and native event payloads, not claims about physical input. */
static void json_string(const char *text) {
    fputc('"',trace);
    for (const unsigned char *p=(const unsigned char *)(text ? text : ""); *p; ++p) {
        if (*p == '"' || *p == '\\') { fputc('\\',trace); fputc(*p,trace); }
        else if (*p < 32) fprintf(trace,"\\u%04x",*p);
        else fputc(*p,trace);
    }
    fputc('"',trace);
}
static void trace_frame(void) {
    ++frame_number;
    if (!trace) return;
    graphene_point_t origin = GRAPHENE_POINT_INIT(0,0), canvas_origin = origin;
    if (canvas && window && !gtk_widget_compute_point(canvas,window,&origin,&canvas_origin)) canvas_origin = origin;
    fprintf(trace,"{\"type\":\"frame\",\"frame\":%u,\"width\":%g,\"height\":%g,\"canvas_x\":%g,\"canvas_y\":%g,\"nodes\":[",frame_number,window_width,window_height,canvas_origin.x,canvas_origin.y);
    for (int i=0;i<semantic_count;++i) {
        Semantic *node = &semantics[i];
        fprintf(trace,"%s{\"id\":%d,\"role\":%d,\"focused\":%d,\"x\":%g,\"y\":%g,\"width\":%g,\"height\":%g,\"label\":",
            i ? "," : "",node->id,node->role,node->focused,node->box.x,node->box.y,node->box.width,node->box.height);
        json_string(node->label); fputs(",\"value\":",trace); json_string(node->value);
        fputs(",\"composition\":",trace);
        const char *composition = "";
        if (node->role == 3) for (int slot=0;slot<SLOT_CAPACITY;++slot) {
            Slot *editor = &slots[5][slot];
            if (editor->present && editor->box.x == node->box.x && editor->box.y == node->box.y &&
                editor->box.width == node->box.width && editor->box.height == node->box.height) {
                composition = editor->composition; break;
            }
        }
        json_string(composition); fputc('}',trace);
    }
    fprintf(trace,"],\"overflow\":%d,\"dropped\":%d}\n",overflow,dropped); fflush(trace);
}

static char *copy_text(const char *text) {
    return g_strdup(text != NULL && g_utf8_validate(text, -1, NULL) ? text : "");
}
static void clear_slot(Slot *slot) {
    g_free(slot->text);
    g_free(slot->composition);
    if (slot->paragraph) moxi_paragraph_release(slot->paragraph);
    memset(slot, 0, sizeof(*slot));
}
static Slot *put_slot(int kind, int index, const char *text, Box box,
                      Color fill, Color ink, float radius, float font) {
    if (index < 0 || index >= SLOT_CAPACITY || kind < 0 || kind >= 25) {
        ++overflow;
        return NULL;
    }
    Slot *slot = &slots[kind][index];
    clear_slot(slot);
    slot->present = slot->enabled = 1;
    slot->text = copy_text(text);
    slot->box = box;
    slot->fill = fill;
    slot->ink = ink;
    slot->radius = radius;
    slot->font = font > 0 ? font : 14;
    slot->clip = clip;
    slot->clipped = clipped;
    return slot;
}
static void push(Event event) {
    /* A bounded synchronous clipboard read dispatches GTK asynchronously.
     * Preserve excess input until Mojo can consume it, in original order. */
    if (!g_queue_is_empty(&deferred_events) || (clipboard_reading && queue_count == EVENT_CAPACITY)) {
        Event *last = g_queue_peek_tail(&deferred_events);
        if (last && last->kind == event.kind && (event.kind == 6 || event.kind == 4 || event.kind == 11)) {
            if (event.kind == 11) { event.dx += last->dx; event.dy += last->dy; }
            g_free(last->text); *last = event;
        } else {
            if (g_queue_get_length(&deferred_events) == DEFERRED_EVENT_CAPACITY) {
                ++dropped; g_free(event.text);
                if (clipboard_reading) {
                    clipboard_overflow = TRUE;
                    if (clipboard_cancel) g_cancellable_cancel(clipboard_cancel);
                }
                return;
            }
            Event *saved = g_new(Event,1); *saved = event;
            g_queue_push_tail(&deferred_events,saved);
        }
        return;
    }
    /* Motion/resize/scroll floods must not evict a committed text event. */
    if (queue_count > 0 && (event.kind == 6 || event.kind == 4 || event.kind == 11)) {
        Event *last = &queue[(queue_head + queue_count - 1) % EVENT_CAPACITY];
        if (last->kind == event.kind) {
            if (event.kind == 11) { event.dx += last->dx; event.dy += last->dy; }
            g_free(last->text);
            *last = event;
            return;
        }
    }
    if (queue_count == EVENT_CAPACITY) { ++dropped; g_free(event.text); return; }
    queue[(queue_head + queue_count++) % EVENT_CAPACITY] = event;
}
static Event new_event(int kind) {
    return (Event){.kind=kind, .target=-1, .start=-1, .end=-1,
                   .x=pointer_x, .y=pointer_y};
}
static void clear_events(void) {
    while (queue_count) {
        g_free(queue[queue_head].text);
        memset(&queue[queue_head],0,sizeof(queue[queue_head]));
        queue_head = (queue_head+1)%EVENT_CAPACITY; --queue_count;
    }
    queue_head = 0;
    Event *saved;
    while ((saved=g_queue_pop_head(&deferred_events))) { g_free(saved->text); g_free(saved); }
    g_free(current.text); current = new_event(0);
}
/* An empty GTK widget supplies exact published geometry and native text
 * accessibility without duplicating the Cairo presenter. GTK 4.14 is the
 * minimum version providing GtkAccessibleText. */
typedef struct { GtkWidget parent; SemanticProxy *proxy; } MoxiSemanticLeaf;
typedef struct { GtkWidgetClass parent; } MoxiSemanticLeafClass;
static void moxi_semantic_text_init(GtkAccessibleTextInterface *iface);
G_DEFINE_TYPE_WITH_CODE(MoxiSemanticLeaf,moxi_semantic_leaf,GTK_TYPE_WIDGET,
    G_IMPLEMENT_INTERFACE(GTK_TYPE_ACCESSIBLE_TEXT,moxi_semantic_text_init))
static void moxi_semantic_leaf_class_init(MoxiSemanticLeafClass *klass) { (void)klass; }
static void moxi_semantic_leaf_init(MoxiSemanticLeaf *leaf) { leaf->proxy = NULL; }
static const char *accessible_text(GtkAccessibleText *self) {
    SemanticProxy *proxy = ((MoxiSemanticLeaf *)self)->proxy;
    return proxy && proxy->text ? proxy->text : "";
}
static GBytes *accessible_contents(GtkAccessibleText *self, unsigned int start, unsigned int end) {
    const char *text = accessible_text(self);
    unsigned int length = (unsigned int)g_utf8_strlen(text,-1);
    start = MIN(start,length); end = CLAMP(end,start,length);
    const char *first = g_utf8_offset_to_pointer(text,start);
    const char *last = g_utf8_offset_to_pointer(text,end);
    return g_bytes_new(first,(gsize)(last-first));
}
static gboolean text_boundary(const PangoLogAttr *attr, GtkAccessibleTextGranularity granularity) {
    if (granularity == GTK_ACCESSIBLE_TEXT_GRANULARITY_WORD) return attr->is_word_start;
    if (granularity == GTK_ACCESSIBLE_TEXT_GRANULARITY_SENTENCE) return attr->is_sentence_start;
    return attr->is_mandatory_break;
}
static GBytes *accessible_contents_at(GtkAccessibleText *self, unsigned int offset,
    GtkAccessibleTextGranularity granularity, unsigned int *start, unsigned int *end) {
    const char *text = accessible_text(self);
    unsigned int length = (unsigned int)g_utf8_strlen(text,-1);
    *start = MIN(offset,length); *end = MIN(*start+1,length);
    if (granularity != GTK_ACCESSIBLE_TEXT_GRANULARITY_CHARACTER && *start < length) {
        PangoLogAttr *attrs = g_new0(PangoLogAttr,length+1);
        pango_get_log_attrs(text,-1,-1,pango_language_get_default(),attrs,(int)length+1);
        while (*start > 0 && !text_boundary(&attrs[*start],granularity)) --*start;
        while (*end < length && !text_boundary(&attrs[*end],granularity)) ++*end;
        g_free(attrs);
    }
    return accessible_contents(self,*start,*end);
}
static unsigned int accessible_caret(GtkAccessibleText *self) {
    SemanticProxy *proxy = ((MoxiSemanticLeaf *)self)->proxy;
    return proxy ? proxy->caret : 0;
}
static gboolean accessible_selection(GtkAccessibleText *self, gsize *count, GtkAccessibleTextRange **ranges) {
    SemanticProxy *proxy = ((MoxiSemanticLeaf *)self)->proxy;
    *count = 0; if (ranges) *ranges = NULL;
    if (!proxy || proxy->start == proxy->end) return FALSE;
    *count = 1;
    if (ranges) {
        *ranges = g_new(GtkAccessibleTextRange,1);
        **ranges = (GtkAccessibleTextRange){proxy->start,proxy->end-proxy->start};
    }
    return TRUE;
}
static gboolean accessible_attributes(GtkAccessibleText *self, unsigned int offset,
    gsize *count, GtkAccessibleTextRange **ranges, char ***names, char ***values) {
    (void)self; (void)offset;
    *count = 0; if (ranges) *ranges = NULL;
    if (names) *names = g_new0(char *,1);
    if (values) *values = g_new0(char *,1);
    return FALSE;
}
static void accessible_default_attributes(GtkAccessibleText *self, char ***names, char ***values) {
    (void)self;
    if (names) *names = g_new0(char *,1);
    if (values) *values = g_new0(char *,1);
}
static void moxi_semantic_text_init(GtkAccessibleTextInterface *iface) {
    iface->get_contents = accessible_contents; iface->get_contents_at = accessible_contents_at;
    iface->get_caret_position = accessible_caret; iface->get_selection = accessible_selection;
    iface->get_attributes = accessible_attributes; iface->get_default_attributes = accessible_default_attributes;
}
static GtkAccessibleRole accessible_role(int role) {
    switch (role) {
        case 1: return GTK_ACCESSIBLE_ROLE_LABEL;
        case 2: return GTK_ACCESSIBLE_ROLE_BUTTON;
        case 3: case 12: return GTK_ACCESSIBLE_ROLE_TEXT_BOX;
        case 5: return GTK_ACCESSIBLE_ROLE_GROUP;
        case 6: return GTK_ACCESSIBLE_ROLE_CHECKBOX;
        case 7: return GTK_ACCESSIBLE_ROLE_PROGRESS_BAR;
        case 8: return GTK_ACCESSIBLE_ROLE_SLIDER;
        case 9: return GTK_ACCESSIBLE_ROLE_SWITCH;
        case 10: return GTK_ACCESSIBLE_ROLE_RADIO;
        case 11: case 20: return GTK_ACCESSIBLE_ROLE_IMG;
        case 13: return GTK_ACCESSIBLE_ROLE_COMBO_BOX;
        case 14: return GTK_ACCESSIBLE_ROLE_LIST;
        case 15: return GTK_ACCESSIBLE_ROLE_TABLE;
        case 16: return GTK_ACCESSIBLE_ROLE_TREE;
        case 17: return GTK_ACCESSIBLE_ROLE_MENU;
        case 18: return GTK_ACCESSIBLE_ROLE_DIALOG;
        case 19: return GTK_ACCESSIBLE_ROLE_TAB_LIST;
        case 21: return GTK_ACCESSIBLE_ROLE_SEPARATOR;
        default: return GTK_ACCESSIBLE_ROLE_NONE;
    }
}
static void semantic_action(GSimpleAction *action, GVariant *parameter, gpointer data) {
    (void)parameter;
    SemanticProxy *proxy = data;
    Event event = new_event(10);
    event.target = proxy->id;
    event.action = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(action),"moxi-action"));
    push(event);
}
static void clear_proxy(SemanticProxy *proxy) {
    if (!proxy->widget) return;
    if (gtk_widget_get_parent(proxy->widget)) gtk_widget_unparent(proxy->widget);
    g_object_unref(proxy->widget);
    g_free(proxy->text);
    memset(proxy,0,sizeof(*proxy));
}
static void clear_proxies(void) {
    /* Stored references keep descendants alive until their own cleanup. */
    for (int i=0;i<SLOT_CAPACITY;++i) clear_proxy(&proxies[i]);
}
static SemanticProxy *semantic_proxy(const Semantic *node, gboolean container) {
    SemanticProxy *free_proxy = NULL;
    for (int i=0;i<SLOT_CAPACITY;++i) {
        SemanticProxy *proxy = &proxies[i];
        if (proxy->widget && proxy->id == node->id) {
            if (proxy->role == node->role && proxy->container == container) return proxy;
            clear_proxy(proxy);
        }
        if (!proxy->widget && !free_proxy) free_proxy = proxy;
    }
    if (!free_proxy) { ++overflow; return NULL; }
    free_proxy->id = node->id; free_proxy->role = node->role; free_proxy->container = container;
    free_proxy->widget = g_object_new(container ? GTK_TYPE_FIXED : moxi_semantic_leaf_get_type(),
        "accessible-role",accessible_role(node->role),NULL);
    if (!container) ((MoxiSemanticLeaf *)free_proxy->widget)->proxy = free_proxy;
    g_object_ref_sink(free_proxy->widget);
    gtk_widget_set_can_target(free_proxy->widget,FALSE);
    return free_proxy;
}
static void publish_semantics(void) {
    if (!semantic_root) return; /* Headless Cairo tests do not initialize GTK. */
    SemanticProxy *published[SLOT_CAPACITY] = {0};
    for (int i=0;i<SLOT_CAPACITY;++i) {
        SemanticProxy *proxy = &proxies[i];
        gboolean retained = FALSE;
        for (int node=0;node<semantic_count;++node)
            if (semantics[node].id == proxy->id) retained = TRUE;
        if (proxy->widget && !retained) clear_proxy(proxy);
        proxy->seen = 0;
    }
    for (int i=0;i<semantic_count;++i) {
        Semantic *node = &semantics[i];
        gboolean container = FALSE;
        for (int child=0;child<semantic_count;++child)
            if (semantics[child].parent == node->id && child != i) container = TRUE;
        SemanticProxy *proxy = semantic_proxy(node,container);
        if (!proxy) continue;
        published[i] = proxy; proxy->seen = 1;
        GtkWidget *widget = proxy->widget;
        if (!container) {
            const char *text = node->value && *node->value ? node->value :
                (node->role == 3 || node->role == 12 ? "" : node->label);
            if (g_strcmp0(proxy->text,text) != 0) {
                unsigned int old_length = proxy->text ? (unsigned int)g_utf8_strlen(proxy->text,-1) : 0;
                if (old_length) gtk_accessible_text_update_contents(GTK_ACCESSIBLE_TEXT(widget),
                    GTK_ACCESSIBLE_TEXT_CONTENT_CHANGE_REMOVE,0,old_length);
                g_free(proxy->text); proxy->text = copy_text(text);
                unsigned int length = (unsigned int)g_utf8_strlen(proxy->text,-1);
                if (length) gtk_accessible_text_update_contents(GTK_ACCESSIBLE_TEXT(widget),
                    GTK_ACCESSIBLE_TEXT_CONTENT_CHANGE_INSERT,0,length);
            }
            proxy->caret = proxy->start = proxy->end = 0;
            if (node->id == next_editor_key && active_editor >= 0) {
                Slot *editor = &slots[5][active_editor];
                unsigned int length = (unsigned int)g_utf8_strlen(proxy->text,-1);
                proxy->caret = (unsigned int)CLAMP(editor->cursor,0,(int)length);
                proxy->start = (unsigned int)CLAMP(MIN(editor->start,editor->end),0,(int)length);
                proxy->end = (unsigned int)CLAMP(MAX(editor->start,editor->end),0,(int)length);
            }
            gtk_accessible_text_update_caret_position(GTK_ACCESSIBLE_TEXT(widget));
            gtk_accessible_text_update_selection_bound(GTK_ACCESSIBLE_TEXT(widget));
        }
        gtk_widget_set_size_request(widget,MAX(1,(int)ceilf(node->box.width)),MAX(1,(int)ceilf(node->box.height)));
        gtk_widget_set_sensitive(widget,node->enabled != 0);
        gtk_widget_set_focusable(widget,node->actions != 0 || node->role == 3 || node->role == 12);
        gtk_accessible_update_property(GTK_ACCESSIBLE(widget),
            GTK_ACCESSIBLE_PROPERTY_LABEL,node->label,
            GTK_ACCESSIBLE_PROPERTY_DESCRIPTION,node->hint,
            GTK_ACCESSIBLE_PROPERTY_VALUE_TEXT,node->value,-1);
        gtk_accessible_update_state(GTK_ACCESSIBLE(widget),
            GTK_ACCESSIBLE_STATE_DISABLED,!node->enabled,
            GTK_ACCESSIBLE_STATE_SELECTED,node->selected,-1);
        if (node->role == 6 || node->role == 9 || node->role == 10)
            gtk_accessible_update_state(GTK_ACCESSIBLE(widget),GTK_ACCESSIBLE_STATE_CHECKED,
                node->checked ? GTK_ACCESSIBLE_TRISTATE_TRUE : GTK_ACCESSIBLE_TRISTATE_FALSE,-1);
        if (node->actions & (16|32))
            gtk_accessible_update_state(GTK_ACCESSIBLE(widget),GTK_ACCESSIBLE_STATE_EXPANDED,node->expanded,-1);
        if (node->has_range) gtk_accessible_update_property(GTK_ACCESSIBLE(widget),
            GTK_ACCESSIBLE_PROPERTY_VALUE_MIN,(double)node->minimum,
            GTK_ACCESSIBLE_PROPERTY_VALUE_MAX,(double)node->maximum,
            GTK_ACCESSIBLE_PROPERTY_VALUE_NOW,(double)node->now,-1);
        else {
            gtk_accessible_reset_property(GTK_ACCESSIBLE(widget),GTK_ACCESSIBLE_PROPERTY_VALUE_MIN);
            gtk_accessible_reset_property(GTK_ACCESSIBLE(widget),GTK_ACCESSIBLE_PROPERTY_VALUE_MAX);
            gtk_accessible_reset_property(GTK_ACCESSIBLE(widget),GTK_ACCESSIBLE_PROPERTY_VALUE_NOW);
        }
        GSimpleActionGroup *group = g_simple_action_group_new();
        const char *names[] = {"press","increment","decrement","select","expand","collapse"};
        for (int action=0;action<6;++action) if (node->actions & (1<<action)) {
            GSimpleAction *item = g_simple_action_new(names[action],NULL);
            g_object_set_data(G_OBJECT(item),"moxi-action",GINT_TO_POINTER(1<<action));
            g_simple_action_set_enabled(item,node->enabled != 0);
            g_signal_connect(item,"activate",G_CALLBACK(semantic_action),proxy);
            g_action_map_add_action(G_ACTION_MAP(group),G_ACTION(item)); g_object_unref(item);
        }
        gtk_widget_insert_action_group(widget,"moxi",G_ACTION_GROUP(group)); g_object_unref(group);
    }
    for (int i=0;i<semantic_count;++i) if (published[i]) {
        Semantic *node = &semantics[i];
        GtkWidget *parent = semantic_root;
        float x = node->box.x, y = node->box.y;
        for (int p=0;p<semantic_count;++p)
            if (published[p] && published[p]->container && p != i && semantics[p].id == node->parent) {
                parent = published[p]->widget; x -= semantics[p].box.x; y -= semantics[p].box.y; break;
            }
        GtkWidget *widget = published[i]->widget;
        if (gtk_widget_get_parent(widget) != parent) {
            if (gtk_widget_get_parent(widget)) gtk_widget_unparent(widget);
            gtk_fixed_put(GTK_FIXED(parent),widget,x,y);
        } else gtk_fixed_move(GTK_FIXED(parent),widget,x,y);
        gtk_widget_set_visible(widget,TRUE);
    }
    for (int i=0;i<SLOT_CAPACITY;++i) if (proxies[i].widget && !proxies[i].seen) clear_proxy(&proxies[i]);
    gboolean focused = FALSE;
    for (int i=0;i<semantic_count;++i)
        if (published[i] && semantics[i].focused && semantics[i].enabled)
            focused = gtk_widget_grab_focus(published[i]->widget) || focused;
    if (!focused && canvas) gtk_widget_grab_focus(canvas);
}
static int modifiers(GdkModifierType state) {
    return ((state & GDK_SHIFT_MASK) ? 1 : 0) |
           ((state & GDK_SUPER_MASK) ? 2 : 0) |
           ((state & GDK_CONTROL_MASK) ? 4 : 0) |
           ((state & GDK_ALT_MASK) ? 8 : 0);
}
static int key_code(guint key) {
    switch (key) {
        case GDK_KEY_Tab: case GDK_KEY_ISO_Left_Tab: case GDK_KEY_KP_Tab: return 9;
        case GDK_KEY_KP_Space: return 32;
        case GDK_KEY_Return: case GDK_KEY_KP_Enter: return 13;
        case GDK_KEY_Escape: return 27;
        case GDK_KEY_BackSpace: return 8;
        case GDK_KEY_Delete: case GDK_KEY_KP_Delete: return 127;
        case GDK_KEY_Left: case GDK_KEY_KP_Left: return 1000;
        case GDK_KEY_Right: case GDK_KEY_KP_Right: return 1001;
        case GDK_KEY_Up: case GDK_KEY_KP_Up: return 1002;
        case GDK_KEY_Down: case GDK_KEY_KP_Down: return 1003;
        case GDK_KEY_Home: case GDK_KEY_KP_Home: return 1004;
        case GDK_KEY_End: case GDK_KEY_KP_End: return 1005;
        default: return (int)gdk_keyval_to_unicode(gdk_keyval_to_lower(key));
    }
}
static gboolean key_pressed(GtkEventControllerKey *controller, guint key,
                            guint keycode, GdkModifierType state, gpointer data) {
    (void)keycode; (void)data;
    GdkEvent *native = gtk_event_controller_get_current_event(GTK_EVENT_CONTROLLER(controller));
    /* The IM context consumes printable/preedit keys. Tab still reaches the
     * Mojo focus order, and shortcuts/navigation reach its editor state. */
    if (im_focused && key != GDK_KEY_Tab && key != GDK_KEY_ISO_Left_Tab && key != GDK_KEY_KP_Tab &&
        native && gtk_im_context_filter_keypress(im, native)) return TRUE;
    Event event = new_event(2);
    event.key = key_code(key);
    event.modifiers = modifiers(state);
    push(event);
    return TRUE;
}
static void key_released(GtkEventControllerKey *controller, guint key,
                         guint keycode, GdkModifierType state, gpointer data) {
    (void)key; (void)keycode; (void)state; (void)data;
    GdkEvent *native = gtk_event_controller_get_current_event(GTK_EVENT_CONTROLLER(controller));
    if (im_focused && native) gtk_im_context_filter_keypress(im, native);
}
static void pointer_pressed(GtkGestureClick *gesture, int count, double x,
                            double y, gpointer data) {
    (void)count; (void)data;
    pointer_x = (float)x; pointer_y = (float)y;
    gtk_widget_grab_focus(canvas);
    Event event = new_event(1);
    event.modifiers = modifiers(gtk_event_controller_get_current_event_state(GTK_EVENT_CONTROLLER(gesture)));
    push(event);
}
static void pointer_released(GtkGestureClick *gesture, int count, double x,
                             double y, gpointer data) {
    (void)count; (void)data;
    pointer_x = (float)x; pointer_y = (float)y;
    Event event = new_event(5);
    event.modifiers = modifiers(gtk_event_controller_get_current_event_state(GTK_EVENT_CONTROLLER(gesture)));
    push(event);
}
static void pointer_motion(GtkEventControllerMotion *controller, double x,
                           double y, gpointer data) {
    (void)controller; (void)data;
    pointer_x = (float)x; pointer_y = (float)y;
    push(new_event(6));
}
static gboolean scroll_event(GtkEventControllerScroll *controller, double dx,
                              double dy, gpointer data) {
    (void)data;
    Event event = new_event(11);
    /* GTK surface deltas already use increasing content coordinates. Wheel
     * detents are converted to logical pixels; touchpad pixel deltas stay exact. */
    float unit = gtk_event_controller_scroll_get_unit(controller) == GDK_SCROLL_UNIT_WHEEL ? 48 : 1;
    event.dx = (float)dx * unit; event.dy = (float)dy * unit;
    push(event);
    return TRUE;
}
static void commit_text(GtkIMContext *context, const char *text, gpointer data) {
    (void)context; (void)data;
    if (!im_focused || resetting_im) return;
    Event event = new_event(3);
    event.target = editor_key;
    event.text = copy_text(text);
    /* -1 replacement range means use the Mojo editor's current selection. */
    push(event);
}
static void preedit_changed(GtkIMContext *context, gpointer data) {
    (void)data;
    if (!im_focused || resetting_im) return;
    char *text = NULL;
    PangoAttrList *attrs = NULL;
    int cursor = 0;
    gtk_im_context_get_preedit_string(context, &text, &attrs, &cursor);
    im_has_preedit = text && *text;
    Event event = new_event(text && *text ? 8 : 9);
    event.target = editor_key;
    event.start = event.end = cursor;
    event.text = text;
    if (attrs) pango_attr_list_unref(attrs);
    push(event);
}
static gboolean retrieve_surrounding(GtkIMContext *context, gpointer data) {
    (void)data;
    if (active_editor < 0) return FALSE;
    Slot *slot = &slots[5][active_editor];
    int length = (int)g_utf8_strlen(slot->text, -1);
    int cursor = CLAMP(slot->cursor, 0, length);
    int anchor = slot->start == cursor ? slot->end : slot->start;
    gtk_im_context_set_surrounding_with_selection(context, slot->text, -1,
        (int)(g_utf8_offset_to_pointer(slot->text, cursor) - slot->text),
        (int)(g_utf8_offset_to_pointer(slot->text, CLAMP(anchor,0,length)) - slot->text));
    return TRUE;
}
static gboolean delete_surrounding(GtkIMContext *context, int offset,
                                   int count, gpointer data) {
    (void)context; (void)data;
    if (active_editor < 0 || count < 0) return FALSE;
    Slot *slot = &slots[5][active_editor];
    int length = (int)g_utf8_strlen(slot->text, -1);
    Event event = new_event(3);
    event.target = editor_key;
    event.start = CLAMP(slot->cursor + offset,0,length);
    event.end = CLAMP(event.start + count,0,length);
    event.text = g_strdup("");
    push(event);
    return TRUE;
}
static gboolean close_request(GtkWindow *widget, gpointer data) {
    (void)widget; (void)data;
    opened = FALSE;
    return TRUE;
}
static void focus_changed(GObject *object, GParamSpec *property, gpointer data) {
    (void)object; (void)property; (void)data;
    if (im_focused) {
        if (gtk_window_is_active(GTK_WINDOW(window))) gtk_im_context_focus_in(im);
        else gtk_im_context_focus_out(im);
    }
}
static void resized(GtkDrawingArea *area, int width, int height, gpointer data) {
    (void)area; (void)data;
    if (window_width == width && window_height == height) return;
    window_width = (float)width; window_height = (float)height;
    push(new_event(4));
}
static void scale_changed(GObject *object, GParamSpec *property, gpointer data) {
    (void)property; (void)data;
    float scale = (float)gtk_widget_get_scale_factor(GTK_WIDGET(object));
    if (scale == window_scale) return;
    window_scale = scale;
    /* Logical dimensions can stay the same when moving between displays. */
    push(new_event(4));
}
static void set_color(cairo_t *cr, Color color) {
    cairo_set_source_rgba(cr, color.r, color.g, color.b, color.a);
}
static void box_path(cairo_t *cr, Box box, float radius) {
    if (box.width <= 0 || box.height <= 0) { cairo_new_path(cr); return; }
    double r = fmax(0, fmin(radius, fmin(box.width, box.height)/2));
    if (r == 0) { cairo_rectangle(cr,box.x,box.y,box.width,box.height); return; }
    const double pi = G_PI;
    cairo_new_sub_path(cr);
    cairo_arc(cr,box.x+box.width-r,box.y+r,r,-pi/2,0);
    cairo_arc(cr,box.x+box.width-r,box.y+box.height-r,r,0,pi/2);
    cairo_arc(cr,box.x+r,box.y+box.height-r,r,pi/2,pi);
    cairo_arc(cr,box.x+r,box.y+r,r,pi,3*pi/2);
    cairo_close_path(cr);
}
static void fill_box(cairo_t *cr, Box box, Color color, float radius) {
    box_path(cr,box,radius); set_color(cr,color); cairo_fill(cr);
}
static void configure_text_layout(PangoLayout *layout, const char *text, float font, int width) {
    PangoFontDescription *desc = pango_font_description_from_string("Sans");
    pango_font_description_set_absolute_size(desc,font * PANGO_SCALE);
    pango_layout_set_font_description(layout,desc);
    pango_font_description_free(desc);
    pango_layout_set_text(layout,text ? text : "",-1);
    pango_layout_set_width(layout,width);
    pango_layout_set_wrap(layout,PANGO_WRAP_WORD_CHAR);
}
static PangoLayout *text_layout(cairo_t *cr, const char *text, float font, int width) {
    PangoLayout *layout = pango_cairo_create_layout(cr);
    configure_text_layout(layout,text,font,width);
    return layout;
}
static void draw_text(cairo_t *cr, const char *text, Box box, Color color,
                       float font, int wrap, int centered) {
    PangoLayout *layout = text_layout(cr,text,font,wrap ? (int)(fmax(0,box.width)*PANGO_SCALE) : -1);
    PangoRectangle logical;
    pango_layout_get_extents(layout,NULL,&logical);
    float w = (float)logical.width/PANGO_SCALE, h = (float)logical.height/PANGO_SCALE;
    cairo_save(cr);
    cairo_rectangle(cr,box.x,box.y,fmax(0,box.width),fmax(0,box.height)); cairo_clip(cr);
    cairo_move_to(cr,box.x+(centered ? (box.width-w)/2 : 0)-(float)logical.x/PANGO_SCALE,
                  box.y+(centered ? (box.height-h)/2 : 0)-(float)logical.y/PANGO_SCALE);
    set_color(cr,color); pango_cairo_show_layout(cr,layout);
    cairo_restore(cr);
    g_object_unref(layout);
}
typedef struct {
    char *display;
    int caret, marked_start, marked_end, selection_start, selection_end;
    gboolean composing;
} EditorText;
typedef struct { Box inset; float origin, caret_x; } EditorGeometry;
static EditorText editor_text(const Slot *slot) {
    const char *text = slot->text ? slot->text : "";
    int length = (int)g_utf8_strlen(text,-1);
    int cursor = CLAMP(slot->cursor,0,length);
    EditorText result = {.composing=slot->focused && slot->composition && *slot->composition};
    if (result.composing) {
        int start = CLAMP(MIN(slot->start,slot->end),0,length);
        int end = CLAMP(MAX(slot->start,slot->end),0,length);
        const char *before = g_utf8_offset_to_pointer(text,start);
        const char *after = g_utf8_offset_to_pointer(text,end);
        int marked_length = (int)g_utf8_strlen(slot->composition,-1);
        int anchor = CLAMP(slot->composition_start,0,marked_length);
        int marked_cursor = CLAMP(slot->composition_end,0,marked_length);
        result.display = g_strdup_printf("%.*s%s%s",(int)(before-text),text,slot->composition,after);
        result.marked_start = (int)(before-text);
        result.marked_end = result.marked_start + (int)strlen(slot->composition);
        result.caret = result.marked_start + (int)(g_utf8_offset_to_pointer(slot->composition,marked_cursor)-slot->composition);
        result.selection_start = result.marked_start + (int)(g_utf8_offset_to_pointer(slot->composition,MIN(anchor,marked_cursor))-slot->composition);
        result.selection_end = result.marked_start + (int)(g_utf8_offset_to_pointer(slot->composition,MAX(anchor,marked_cursor))-slot->composition);
    } else {
        result.display = g_strdup(text);
        result.caret = (int)(g_utf8_offset_to_pointer(text,cursor)-text);
        result.selection_start = (int)(g_utf8_offset_to_pointer(text,CLAMP(MIN(slot->start,slot->end),0,length))-text);
        result.selection_end = (int)(g_utf8_offset_to_pointer(text,CLAMP(MAX(slot->start,slot->end),0,length))-text);
    }
    return result;
}
static EditorGeometry editor_geometry(const Slot *slot, PangoLayout *layout, const EditorText *text) {
    EditorGeometry geometry = {.inset={slot->box.x+8,slot->box.y+4,
        fmax(0,slot->box.width-16),fmax(0,slot->box.height-8)}};
    PangoRectangle caret;
    pango_layout_get_cursor_pos(layout,text->caret,&caret,NULL);
    geometry.caret_x = (float)caret.x/PANGO_SCALE;
    geometry.origin = geometry.inset.x - fmax(0,geometry.caret_x-geometry.inset.width+2);
    return geometry;
}
static void editor_selection(cairo_t *cr, PangoLayout *layout, EditorGeometry geometry,
                             int start, int end, gboolean underline) {
    if (start == end) return;
    PangoLayoutLine *line = pango_layout_get_line_readonly(layout,0);
    int *ranges = NULL, count = 0;
    pango_layout_line_get_x_ranges(line,start,end,&ranges,&count);
    for (int i=0;i<count;++i) {
        float x = geometry.origin+(float)ranges[2*i]/PANGO_SCALE;
        float width = (float)(ranges[2*i+1]-ranges[2*i])/PANGO_SCALE;
        if (underline) {
            cairo_move_to(cr,x,geometry.inset.y+geometry.inset.height-2);
            cairo_line_to(cr,x+width,geometry.inset.y+geometry.inset.height-2);
        } else fill_box(cr,(Box){x,geometry.inset.y,width,geometry.inset.height},
                        (Color){0.18f,0.40f,0.60f,1},0);
    }
    g_free(ranges);
    if (underline) { cairo_set_line_width(cr,1); cairo_stroke(cr); }
}
static void draw_editor(cairo_t *cr, Slot *slot) {
    EditorText text = editor_text(slot);
    PangoLayout *layout = text_layout(cr,text.display,slot->font,-1);
    EditorGeometry geometry = editor_geometry(slot,layout,&text);
    Box inset = geometry.inset;
    cairo_save(cr);
    cairo_rectangle(cr,inset.x,inset.y,inset.width,inset.height); cairo_clip(cr);
    if (slot->focused) editor_selection(cr,layout,geometry,text.selection_start,text.selection_end,FALSE);
    cairo_move_to(cr,geometry.origin,inset.y); set_color(cr,slot->ink); pango_cairo_show_layout(cr,layout);
    if (slot->focused) {
        if (text.composing) editor_selection(cr,layout,geometry,text.marked_start,text.marked_end,TRUE);
        cairo_move_to(cr,geometry.origin+geometry.caret_x,inset.y+2);
        cairo_line_to(cr,geometry.origin+geometry.caret_x,inset.y+inset.height-2);
        cairo_set_line_width(cr,1); cairo_stroke(cr);
    }
    cairo_restore(cr);
    g_object_unref(layout); g_free(text.display);
}
static void draw_slot(cairo_t *cr, int kind, int index) {
    if (kind < 0 || kind >= 25 || index < 0 || index >= SLOT_CAPACITY) return;
    Slot *slot = &slots[kind][index];
    if (!slot->present) return;
    cairo_save(cr);
    if (slot->clipped) {
        cairo_rectangle(cr,slot->clip.x,slot->clip.y,fmax(0,slot->clip.width),fmax(0,slot->clip.height));
        cairo_clip(cr);
    }
    if (kind == 1) {
        if (slot->paragraph) moxi_linux_paragraph_draw(cr,slot->paragraph,slot->box.x,slot->box.y,
            slot->box.width,slot->box.height,slot->ink.r,slot->ink.g,slot->ink.b,slot->ink.a);
        else draw_text(cr,slot->text,slot->box,slot->ink,slot->font,slot->value != 0,0);
    } else {
        fill_box(cr,slot->box,slot->fill,slot->radius);
        if (kind == 24) fill_box(cr,slot->thumb,slot->ink,slot->radius);
        else if (kind == 5) draw_editor(cr,slot);
        else if (kind != 3) draw_text(cr,slot->text,slot->box,slot->ink,slot->font,0,1);
        if (slot->focused) {
            box_path(cr,slot->box,slot->radius);
            set_color(cr,(Color){0.35f,0.85f,0.75f,1}); cairo_set_line_width(cr,2); cairo_stroke(cr);
        }
    }
    cairo_restore(cr);
}
static void draw_custom(cairo_t *cr) {
    if (!custom) return;
    cairo_save(cr);
    if (custom_clipped) {
        cairo_rectangle(cr,custom_clip.x,custom_clip.y,fmax(0,custom_clip.width),fmax(0,custom_clip.height)); cairo_clip(cr);
    }
    for (guint i=0;i<custom->len;++i) {
        Custom *item = &g_array_index(custom,Custom,i);
        if (item->kind == 4) { draw_text(cr,item->text,item->box,item->fill,item->radius,1,0); continue; }
        if (item->kind == 2) {
            cairo_move_to(cr,item->box.x,item->box.y); cairo_line_to(cr,item->box.width,item->box.height);
        } else if (item->kind == 3) {
            cairo_new_sub_path(cr); cairo_arc(cr,item->box.x,item->box.y,item->radius,0,2*G_PI);
        } else box_path(cr,item->box,item->radius);
        if (item->kind != 2) { set_color(cr,item->fill); cairo_fill_preserve(cr); }
        if (item->stroke_width > 0) { set_color(cr,item->stroke); cairo_set_line_width(cr,item->stroke_width); cairo_stroke(cr); }
        else cairo_new_path(cr);
    }
    cairo_restore(cr);
}
static void draw(GtkDrawingArea *area, cairo_t *cr, int width, int height, gpointer data) {
    (void)area; (void)width; (void)height; (void)data;
    set_color(cr,surface); cairo_paint(cr);
    if (ordered) {
        for (int i=0;i<order_count;++i) {
            if (order[i].kind == 100) draw_custom(cr);
            else draw_slot(cr,order[i].kind,order[i].slot);
        }
    } else {
        for (int kind=1;kind<25;++kind) for (int i=0;i<SLOT_CAPACITY;++i) draw_slot(cr,kind,i);
        draw_custom(cr);
    }
    if (trace) { fprintf(trace,"{\"type\":\"draw\",\"frame\":%u}\n",frame_number); fflush(trace); }
}

void moxi_window_open(const char *title, float width, float height,
                      float min_width, float min_height, float max_width,
                      float max_height, int resizable, int fullscreen) {
    (void)max_width; (void)max_height; /* GTK4 has no portable maximum-size hint. */
    if (opened) return;
    if (window) moxi_window_pump(); /* Finish a prior close before replacing it. */
    /* A newly opened surface has a new input lifetime. Old pointer/text/action
     * events must never address reused Mojo IDs in the new view tree. */
    clear_events();
    resetting_im = im_has_preedit = im_focused = FALSE;
    editor_key = next_editor_key = active_editor = -1;
    configure_input_environment();
    if (!gtk_init_check()) g_error("Moxi Linux requires a working GTK display (X11 or Wayland)");
    const char *trace_path = g_getenv("MOXI_LINUX_TRACE_FILE");
    if (trace_path && *trace_path) trace = fopen(trace_path,"w");
    window_width = width; window_height = height;
    window = gtk_window_new();
    gtk_window_set_title(GTK_WINDOW(window),title ? title : "Moxi");
    gtk_window_set_default_size(GTK_WINDOW(window),(int)width,(int)height);
    gtk_window_set_resizable(GTK_WINDOW(window),resizable != 0);
    canvas = g_object_new(GTK_TYPE_DRAWING_AREA,"accessible-role",GTK_ACCESSIBLE_ROLE_PRESENTATION,NULL);
    window_scale = (float)gtk_widget_get_scale_factor(canvas);
    gtk_widget_set_focusable(canvas,TRUE);
    gtk_widget_set_size_request(canvas,(int)min_width,(int)min_height);
    GtkWidget *overlay = gtk_overlay_new();
    gtk_overlay_set_child(GTK_OVERLAY(overlay),canvas);
    semantic_root = gtk_fixed_new();
    gtk_widget_set_can_target(semantic_root,FALSE);
    gtk_overlay_add_overlay(GTK_OVERLAY(overlay),semantic_root);
    gtk_overlay_set_measure_overlay(GTK_OVERLAY(overlay),semantic_root,FALSE);
    gtk_window_set_child(GTK_WINDOW(window),overlay);
    gtk_drawing_area_set_draw_func(GTK_DRAWING_AREA(canvas),draw,NULL,NULL);
    g_signal_connect(canvas,"resize",G_CALLBACK(resized),NULL);
    g_signal_connect(canvas,"notify::scale-factor",G_CALLBACK(scale_changed),NULL);
    g_signal_connect(window,"close-request",G_CALLBACK(close_request),NULL);
    g_signal_connect(window,"notify::is-active",G_CALLBACK(focus_changed),NULL);
    im = gtk_im_multicontext_new();
    gtk_im_context_set_client_widget(im,canvas);
    g_signal_connect(im,"commit",G_CALLBACK(commit_text),NULL);
    g_signal_connect(im,"preedit-changed",G_CALLBACK(preedit_changed),NULL);
    g_signal_connect(im,"retrieve-surrounding",G_CALLBACK(retrieve_surrounding),NULL);
    g_signal_connect(im,"delete-surrounding",G_CALLBACK(delete_surrounding),NULL);
    GtkEventController *keys = gtk_event_controller_key_new();
    g_signal_connect(keys,"key-pressed",G_CALLBACK(key_pressed),NULL);
    g_signal_connect(keys,"key-released",G_CALLBACK(key_released),NULL);
    gtk_event_controller_set_propagation_phase(keys,GTK_PHASE_CAPTURE);
    gtk_widget_add_controller(window,keys);
    GtkGesture *click = gtk_gesture_click_new();
    gtk_gesture_single_set_button(GTK_GESTURE_SINGLE(click),GDK_BUTTON_PRIMARY);
    g_signal_connect(click,"pressed",G_CALLBACK(pointer_pressed),NULL);
    g_signal_connect(click,"released",G_CALLBACK(pointer_released),NULL);
    gtk_widget_add_controller(canvas,GTK_EVENT_CONTROLLER(click));
    GtkEventController *motion = gtk_event_controller_motion_new();
    g_signal_connect(motion,"motion",G_CALLBACK(pointer_motion),NULL);
    gtk_widget_add_controller(canvas,motion);
    GtkEventController *scroll = gtk_event_controller_scroll_new(GTK_EVENT_CONTROLLER_SCROLL_BOTH_AXES);
    g_signal_connect(scroll,"scroll",G_CALLBACK(scroll_event),NULL);
    gtk_widget_add_controller(canvas,scroll);
    opened = TRUE;
    gtk_window_present(GTK_WINDOW(window));
    if (fullscreen) gtk_window_fullscreen(GTK_WINDOW(window));
    gtk_widget_grab_focus(canvas);
}
void moxi_window_begin_frame(void) {
    for (int kind=0;kind<25;++kind) for (int i=0;i<SLOT_CAPACITY;++i) clear_slot(&slots[kind][i]);
    overflow = order_count = ordered = 0;
    active_editor = -1; next_editor_key = -1;
}
void moxi_window_ordered_paint_begin(void) { ordered = 1; order_count = 0; }
void moxi_window_ordered_paint(int kind, int index) {
    if ((kind != 1 && kind != 2 && kind != 3 && kind != 5 && kind != 22 && kind != 100) ||
        index < 0 || index >= SLOT_CAPACITY || order_count >= SLOT_CAPACITY+1) { ++overflow; return; }
    order[order_count++] = (Order){kind,index};
}
void moxi_window_set_clip(int enabled, BOX_ARGS) { clipped = enabled != 0; clip = BOX; }
void moxi_window_set_surface(COLOR_ARGS(fill)) { surface = COLOR(fill); }
void moxi_window_set_panel_at(int index, BOX_ARGS, COLOR_ARGS(fill), float radius,
                              int enabled, float cx, float cy, float cw, float ch) {
    Slot *slot = put_slot(3,index,"",BOX,COLOR(fill),(Color){0},radius,14);
    if (slot) { slot->clipped = enabled; slot->clip = (Box){cx,cy,cw,ch}; }
}
void moxi_window_set_panel(BOX_ARGS, COLOR_ARGS(fill), float radius) {
    moxi_window_set_panel_at(0,x,y,width,height,fill_r,fill_g,fill_b,fill_a,radius,
                            clipped,clip.x,clip.y,clip.width,clip.height);
}
void moxi_window_set_label_at(int index, const char *text, BOX_ARGS, COLOR_ARGS(ink),
                              float font, int wrap) {
    Slot *slot = put_slot(1,index,text,BOX,(Color){0},COLOR(ink),0,font);
    if (slot) slot->value = wrap;
}
void moxi_window_set_label(const char *text, BOX_ARGS) {
    moxi_window_set_label_at(0,text,x,y,width,height,1,1,1,1,24,0);
}
void moxi_window_set_paragraph_at(int index, uintptr_t handle) {
    if (index < 0 || index >= SLOT_CAPACITY || !slots[1][index].present) return;
    Slot *slot = &slots[1][index];
    if (handle) moxi_paragraph_retain(handle);
    if (slot->paragraph) moxi_paragraph_release(slot->paragraph);
    slot->paragraph = handle;
}
void moxi_window_set_button_at(int index, const char *text, BOX_ARGS,
    COLOR_ARGS(fill), COLOR_ARGS(ink), float radius, float font, int wrap,
    int focused, int hovered, int pressed, int enabled) {
    (void)wrap; (void)hovered; (void)pressed;
    Slot *slot = put_slot(2,index,text,BOX,COLOR(fill),COLOR(ink),radius,font);
    if (slot) { slot->focused = focused; slot->enabled = enabled; }
}
void moxi_window_set_button(const char *text, BOX_ARGS) {
    moxi_window_set_button_at(0,text,x,y,width,height,0.15f,0.25f,0.35f,1,
                              1,1,1,1,6,14,0,0,0,0,1);
}
void moxi_window_text_editor_key(int key) { next_editor_key = key; }
void moxi_window_set_text_input_at(int index, const char *text, BOX_ARGS,
    COLOR_ARGS(fill), COLOR_ARGS(ink), float radius, float font, int wrap,
    int focused, int cursor, int start, int end, const char *composition,
    int composition_start, int composition_end) {
    (void)wrap;
    Slot *slot = put_slot(5,index,text,BOX,COLOR(fill),COLOR(ink),radius,font);
    if (!slot) return;
    slot->focused = focused; slot->cursor = cursor; slot->start = start; slot->end = end;
    slot->composition = copy_text(composition);
    slot->composition_start = composition_start; slot->composition_end = composition_end;
    if (focused) active_editor = index;
}
void moxi_window_begin_accessibility(void) {
    for (int i=0;i<semantic_count;++i) {
        g_free(semantics[i].label); g_free(semantics[i].value); g_free(semantics[i].hint);
        memset(&semantics[i],0,sizeof(semantics[i]));
    }
    semantic_count = 0;
}
void moxi_window_set_accessibility_at(int index, int id, int parent, int role,
    const char *label, const char *value, const char *hint, BOX_ARGS,
    int enabled, int focused, int selected, int checked, int expanded, int has_range,
    float minimum, float maximum, float now, int actions) {
    if (index < 0 || index >= SLOT_CAPACITY) { ++overflow; return; }
    g_free(semantics[index].label); g_free(semantics[index].value); g_free(semantics[index].hint);
    semantics[index] = (Semantic){.id=id,.parent=parent,.role=role,.focused=focused,
        .enabled=enabled,.selected=selected,.checked=checked,.expanded=expanded,
        .has_range=has_range,.actions=actions,.minimum=minimum,.maximum=maximum,.now=now,
        .box=BOX,.label=copy_text(label),.value=copy_text(value),.hint=copy_text(hint)};
    semantic_count = MAX(semantic_count,index+1);
}
static void synchronize_editor(void) {
    gboolean allowed = FALSE;
    for (int i=0;i<semantic_count;++i)
        if (semantics[i].id == next_editor_key && semantics[i].role == 3 &&
            semantics[i].focused && semantics[i].enabled) allowed = TRUE;
    if (!allowed || active_editor < 0) next_editor_key = -1;
    if (editor_key != next_editor_key || (im_focused && next_editor_key < 0)) {
        /* Reset cancels GTK preedit. Address its cleanup to the old Mojo editor
         * even when the new publication has moved focus into a modal. */
        if (editor_key >= 0 && im_has_preedit) {
            Event end = new_event(9);
            end.target = editor_key;
            push(end);
        }
        im_has_preedit = FALSE;
        if (im) {
            resetting_im = TRUE;
            gtk_im_context_reset(im);
            gtk_im_context_focus_out(im);
            resetting_im = FALSE;
        }
        im_focused = FALSE;
        editor_key = next_editor_key;
    }
    if (editor_key >= 0 && im) {
        if (!im_focused) { gtk_im_context_focus_in(im); im_focused = TRUE; }
        Slot *slot = &slots[5][active_editor];
        EditorText text = editor_text(slot);
        PangoLayout *layout = pango_layout_new(gtk_widget_get_pango_context(canvas));
        configure_text_layout(layout,text.display,slot->font,-1);
        EditorGeometry geometry = editor_geometry(slot,layout,&text);
        GdkRectangle rect = {(int)(geometry.origin+geometry.caret_x),(int)geometry.inset.y,
                             1,MAX(1,(int)geometry.inset.height)};
        gtk_im_context_set_cursor_location(im,&rect);
        g_object_unref(layout); g_free(text.display);
        retrieve_surrounding(im,NULL);
    }
}
void moxi_window_end_accessibility(void) { publish_semantics(); synchronize_editor(); }
void moxi_window_end_frame(void) {
    synchronize_editor();
    if (canvas) gtk_widget_queue_draw(canvas);
    trace_frame();
}
static void clear_custom(void) {
    if (!custom) return;
    for (guint i=0;i<custom->len;++i) g_free(g_array_index(custom,Custom,i).text);
    g_array_set_size(custom,0);
}
void moxi_window_begin_custom_paint(void) {
    if (!custom) custom = g_array_new(FALSE,FALSE,sizeof(Custom));
    clear_custom(); custom_clipped = 0;
}
void moxi_window_set_custom_clip(BOX_ARGS) { custom_clip = BOX; custom_clipped = 1; }
static void add_custom(Custom item) {
    if (!custom) custom = g_array_new(FALSE,FALSE,sizeof(Custom));
    if (custom->len >= CUSTOM_CAPACITY) { ++overflow; g_free(item.text); return; }
    g_array_append_val(custom,item);
}
void moxi_window_add_custom_rect(BOX_ARGS, COLOR_ARGS(fill), COLOR_ARGS(stroke), float stroke_width) {
    add_custom((Custom){.box=BOX,.fill=COLOR(fill),.stroke=COLOR(stroke),.stroke_width=stroke_width});
}
void moxi_window_add_custom_rounded_rect(BOX_ARGS, COLOR_ARGS(fill), COLOR_ARGS(stroke),
                                        float stroke_width, float radius) {
    add_custom((Custom){.box=BOX,.fill=COLOR(fill),.stroke=COLOR(stroke),.stroke_width=stroke_width,.radius=radius});
}
void moxi_window_add_custom_line(float x, float y, float ex, float ey, COLOR_ARGS(ink), float width) {
    add_custom((Custom){.kind=2,.box={x,y,ex,ey},.stroke=COLOR(ink),.stroke_width=width});
}
void moxi_window_add_custom_circle(float x, float y, float radius, COLOR_ARGS(fill),
                                  COLOR_ARGS(stroke), float stroke_width) {
    add_custom((Custom){.kind=3,.box={x,y,0,0},.fill=COLOR(fill),.stroke=COLOR(stroke),.stroke_width=stroke_width,.radius=radius});
}
void moxi_window_add_custom_text(const char *text, BOX_ARGS, COLOR_ARGS(ink), float font) {
    add_custom((Custom){.kind=4,.box=BOX,.fill=COLOR(ink),.radius=font,.text=copy_text(text)});
}
void moxi_window_set_custom_paint_cache_enabled(int enabled) { (void)enabled; }
void moxi_window_pump(void) {
    /* Mojo publishes focus/selection after each event, before GTK filters the
     * next key. Waiting for new work is a separate, blocking host operation. */
    while (opened && !moxi_window_event_queue_depth() && g_main_context_pending(NULL))
        g_main_context_iteration(NULL,FALSE);
    if (!opened && window) {
        resetting_im = TRUE;
        gtk_im_context_focus_out(im); gtk_im_context_set_client_widget(im,NULL);
        g_clear_object(&im); im_focused = FALSE;
        editor_key = next_editor_key = active_editor = -1;
        im_has_preedit = resetting_im = FALSE;
        clear_proxies();
        gtk_window_destroy(GTK_WINDOW(window)); window = canvas = semantic_root = NULL;
        moxi_window_begin_frame(); clear_custom();
        moxi_window_begin_accessibility();
        if (trace) { fclose(trace); trace = NULL; }
    }
}
static gboolean wait_deadline(gpointer data) {
    *(gboolean *)data = TRUE;
    return G_SOURCE_REMOVE;
}
typedef struct {
    int references;
    gboolean done, succeeded;
    GCancellable *cancel;
    char *text;
} ClipboardRead;
static void clipboard_read_release(ClipboardRead *read) {
    if (--read->references) return;
    g_object_unref(read->cancel); g_free(read->text); g_free(read);
}
static void clipboard_ready(GObject *source, GAsyncResult *result, gpointer data) {
    ClipboardRead *read = data;
    GError *error = NULL;
    read->text = gdk_clipboard_read_text_finish(GDK_CLIPBOARD(source),result,&error);
    read->succeeded = !error && read->text && g_utf8_validate(read->text,-1,NULL);
    read->done = TRUE;
    g_clear_error(&error);
    clipboard_read_release(read);
}
static GdkClipboard *native_clipboard(void) {
    configure_input_environment();
    if (!gdk_display_get_default() && !gtk_init_check()) return NULL;
    GdkDisplay *display = gdk_display_get_default();
    return display ? gdk_display_get_clipboard(display) : NULL;
}
void moxi_clipboard_set(const char *text) {
    GdkClipboard *clipboard = native_clipboard();
    if (!clipboard) return;
    char *valid = copy_text(text);
    gdk_clipboard_set_text(clipboard,valid); g_free(valid);
}
int moxi_clipboard_read_snapshot(void) {
    GdkClipboard *clipboard = native_clipboard();
    if (!clipboard || clipboard_reading) return -1;
    g_clear_pointer(&clipboard_snapshot,g_free);
    gsize mime_count = 0;
    gdk_content_formats_get_mime_types(gdk_clipboard_get_formats(clipboard),&mime_count);
    if (!mime_count) { clipboard_snapshot = g_strdup(""); return 0; }
    ClipboardRead *read = g_new0(ClipboardRead,1);
    read->references = 2; read->cancel = g_cancellable_new();
    gboolean expired = FALSE;
    GSource *deadline = g_timeout_source_new(1000);
    g_source_set_callback(deadline,wait_deadline,&expired,NULL);
    g_source_attach(deadline,NULL);
    clipboard_reading = TRUE; clipboard_overflow = FALSE; clipboard_cancel = read->cancel;
    gdk_clipboard_read_text_async(clipboard,read->cancel,clipboard_ready,read);
    while (!read->done && !expired && !clipboard_overflow) g_main_context_iteration(NULL,TRUE);
    g_source_destroy(deadline); g_source_unref(deadline);
    clipboard_reading = FALSE; clipboard_cancel = NULL;
    int count = -1;
    if (read->done && read->succeeded && !clipboard_overflow) {
        glong length = g_utf8_strlen(read->text,-1);
        if (length <= G_MAXINT) {
            clipboard_snapshot = g_steal_pointer(&read->text);
            count = (int)length;
        }
    } else g_cancellable_cancel(read->cancel);
    /* Cancellation may complete later. Its callback owns the remaining
     * reference, so no request state points into this stack frame. */
    clipboard_read_release(read);
    return count;
}
int moxi_clipboard_codepoint_at(int index) {
    if (!clipboard_snapshot || index < 0 || index >= g_utf8_strlen(clipboard_snapshot,-1)) return -1;
    return (int)g_utf8_get_char(g_utf8_offset_to_pointer(clipboard_snapshot,index));
}
void moxi_window_wait(float timeout_seconds) {
    moxi_window_pump();
    if (!opened || moxi_window_event_queue_depth() || timeout_seconds == 0 || isnan(timeout_seconds)) return;
    gboolean expired = FALSE;
    GSource *deadline = NULL;
    if (timeout_seconds > 0) {
        double milliseconds = ceil((double)timeout_seconds*1000);
        guint interval = (guint)fmin(milliseconds,G_MAXUINT);
        deadline = g_timeout_source_new(MAX(1u,interval));
        g_source_set_callback(deadline,wait_deadline,&expired,NULL);
        g_source_attach(deadline,NULL);
    }
    while (opened && !moxi_window_event_queue_depth() && !expired) g_main_context_iteration(NULL,TRUE);
    if (deadline) { g_source_destroy(deadline); g_source_unref(deadline); }
    moxi_window_pump();
}
void moxi_window_close(void) {
    opened = FALSE;
    moxi_window_pump();
}
int moxi_window_is_open(void) { return opened; }
int moxi_window_poll_event(void) {
    g_free(current.text); memset(&current,0,sizeof(current));
    if (queue_count) {
        current = queue[queue_head]; queue_head = (queue_head+1)%EVENT_CAPACITY; --queue_count;
    } else {
        Event *saved = g_queue_pop_head(&deferred_events);
        if (!saved) return 0;
        current = *saved; g_free(saved);
    }
    if (trace) {
        fprintf(trace,"{\"type\":\"event\",\"kind\":%d,\"target\":%d,\"dx\":%g,\"dy\":%g,\"text\":",current.kind,current.target,current.dx,current.dy);
        json_string(current.text); fputs("}\n",trace); fflush(trace);
    }
    return current.kind;
}
int moxi_window_poll_click(void) { return 0; } /* Retained loop consumes pointer events. */
float moxi_window_click_x(void) { return current.x; }
float moxi_window_click_y(void) { return current.y; }
int moxi_window_event_queue_depth(void) {
    return queue_count + (int)MIN(g_queue_get_length(&deferred_events),(guint)(G_MAXINT-EVENT_CAPACITY));
}
int moxi_window_event_dropped_count(void) { return dropped; }
int moxi_window_command_overflow_count(void) { return overflow; }
int moxi_window_event_key(void) { return current.key; }
int moxi_window_event_modifiers(void) { return current.modifiers; }
int moxi_window_event_codepoint_at(int index) {
    if (!current.text || index < 0 || index >= g_utf8_strlen(current.text,-1)) return -1;
    return (int)g_utf8_get_char(g_utf8_offset_to_pointer(current.text,index));
}
int moxi_window_event_codepoint(void) { return moxi_window_event_codepoint_at(0); }
int moxi_window_event_selection_start(void) { return current.start; }
int moxi_window_event_selection_end(void) { return current.end; }
float moxi_window_event_x(void) { return current.x; }
float moxi_window_event_y(void) { return current.y; }
float moxi_window_event_scroll_x(void) { return current.dx; }
float moxi_window_event_scroll_y(void) { return current.dy; }
int moxi_window_event_target(void) { return current.target; }
int moxi_window_event_action(void) { return current.action; }
float moxi_window_width(void) { return window_width; }
float moxi_window_height(void) { return window_height; }
float moxi_window_scale_factor(void) {
    return canvas ? (float)gtk_widget_get_scale_factor(canvas) : 1;
}

/* The retained leaf adapter rejects these legacy kinds before publication.
 * Keep their shared ABI linkable, but fail explicitly if a caller bypasses it. */
static void unsupported(const char *name) { g_error("Linux retained presenter does not support %s",name); }

#ifdef MOXI_LINUX_TEST
void moxi_linux_test_draw(cairo_t *cr, int width, int height) { draw(NULL,cr,width,height,NULL); }
void moxi_linux_test_push_event(int kind, int target, const char *text, float dx, float dy) {
    Event event = new_event(kind);
    event.target = target; event.dx = dx; event.dy = dy;
    event.text = text ? copy_text(text) : NULL;
    push(event);
}
#endif

void moxi_window_set_native_widget_at(
    int index,
    int kind,
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float text_red,
    float text_green,
    float text_blue,
    float text_alpha,
    float radius,
    float font_size,
    int focused,
    int enabled,
    int selected,
    int expanded
) {
    (void)index; (void)kind; (void)text; (void)x; (void)y; (void)width; (void)height; (void)fill_red; (void)fill_green; (void)fill_blue; (void)fill_alpha; (void)text_red; (void)text_green; (void)text_blue; (void)text_alpha; (void)radius; (void)font_size; (void)focused; (void)enabled; (void)selected; (void)expanded; unsupported("set_native_widget_at");
}

void moxi_window_set_scrollbar_at(
    int index,
    float track_x,
    float track_y,
    float track_width,
    float track_height,
    float thumb_x,
    float thumb_y,
    float thumb_width,
    float thumb_height,
    float track_red,
    float track_green,
    float track_blue,
    float track_alpha,
    float thumb_red,
    float thumb_green,
    float thumb_blue,
    float thumb_alpha,
    float radius,
    int visible
) {
    (void)index; (void)track_x; (void)track_y; (void)track_width; (void)track_height; (void)thumb_x; (void)thumb_y; (void)thumb_width; (void)thumb_height; (void)track_red; (void)track_green; (void)track_blue; (void)track_alpha; (void)thumb_red; (void)thumb_green; (void)thumb_blue; (void)thumb_alpha; (void)radius; (void)visible; unsupported("set_scrollbar_at");
}

void moxi_window_register_image(int resource_id, const char *source) {
    (void)resource_id; (void)source; unsupported("register_image");
}

void moxi_window_set_image_at(
    int index,
    int resource_id,
    const char *alt_text,
    float x,
    float y,
    float width,
    float height,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float text_red,
    float text_green,
    float text_blue,
    float text_alpha,
    float radius
) {
    (void)index; (void)resource_id; (void)alt_text; (void)x; (void)y; (void)width; (void)height; (void)fill_red; (void)fill_green; (void)fill_blue; (void)fill_alpha; (void)text_red; (void)text_green; (void)text_blue; (void)text_alpha; (void)radius; unsupported("set_image_at");
}

void moxi_window_set_checkbox_at(
    int index,
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float text_red,
    float text_green,
    float text_blue,
    float text_alpha,
    float radius,
    float font_size,
    int focused,
    int hovered,
    int pressed,
    int enabled,
    int checked
) {
    (void)index; (void)text; (void)x; (void)y; (void)width; (void)height; (void)fill_red; (void)fill_green; (void)fill_blue; (void)fill_alpha; (void)text_red; (void)text_green; (void)text_blue; (void)text_alpha; (void)radius; (void)font_size; (void)focused; (void)hovered; (void)pressed; (void)enabled; (void)checked; unsupported("set_checkbox_at");
}

void moxi_window_set_progress_at(
    int index,
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float text_red,
    float text_green,
    float text_blue,
    float text_alpha,
    float radius,
    float font_size,
    float progress
) {
    (void)index; (void)text; (void)x; (void)y; (void)width; (void)height; (void)fill_red; (void)fill_green; (void)fill_blue; (void)fill_alpha; (void)text_red; (void)text_green; (void)text_blue; (void)text_alpha; (void)radius; (void)font_size; (void)progress; unsupported("set_progress_at");
}

void moxi_window_set_slider_at(
    int index,
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float text_red,
    float text_green,
    float text_blue,
    float text_alpha,
    float radius,
    float font_size,
    float value,
    int focused,
    int hovered,
    int pressed,
    int enabled
) {
    (void)index; (void)text; (void)x; (void)y; (void)width; (void)height; (void)fill_red; (void)fill_green; (void)fill_blue; (void)fill_alpha; (void)text_red; (void)text_green; (void)text_blue; (void)text_alpha; (void)radius; (void)font_size; (void)value; (void)focused; (void)hovered; (void)pressed; (void)enabled; unsupported("set_slider_at");
}

void moxi_window_set_toggle_at(
    int index,
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float text_red,
    float text_green,
    float text_blue,
    float text_alpha,
    float radius,
    float font_size,
    int focused,
    int hovered,
    int pressed,
    int enabled,
    int checked,
    int radio
) {
    (void)index; (void)text; (void)x; (void)y; (void)width; (void)height; (void)fill_red; (void)fill_green; (void)fill_blue; (void)fill_alpha; (void)text_red; (void)text_green; (void)text_blue; (void)text_alpha; (void)radius; (void)font_size; (void)focused; (void)hovered; (void)pressed; (void)enabled; (void)checked; (void)radio; unsupported("set_toggle_at");
}
