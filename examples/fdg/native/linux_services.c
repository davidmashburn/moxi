// Small application services around Moxi's existing GTK host.
#include <gtk/gtk.h>
#include <stdint.h>
#include <string.h>
extern void moxi_window_end_frame(void);
extern void moxi_window_close(void);
void fdg_present_frame(void) { /* renderer.end_frame already queued GTK draw */ }
void fdg_close_window(void) { moxi_window_close(); }

typedef struct { GMainLoop *loop; char *path; } SaveRequest;
static void saved(GObject *source, GAsyncResult *result, gpointer data) {
    SaveRequest *request = data;
    GError *error = NULL;
    GFile *file = gtk_file_dialog_save_finish(GTK_FILE_DIALOG(source), result, &error);
    if (file) { request->path = g_file_get_path(file); g_object_unref(file); }
    // Cancellation is a normal empty result; errors remain explicit.
    else if (error && !g_error_matches(error, GTK_DIALOG_ERROR, GTK_DIALOG_ERROR_DISMISSED))
        request->path = g_strdup("");
    g_clear_error(&error);
    g_main_loop_quit(request->loop);
}
int64_t fdg_choose_export_path(uint8_t *buffer, int64_t capacity) {
    GtkFileDialog *dialog = gtk_file_dialog_new();
    gtk_file_dialog_set_title(dialog, "Export graph (.svg, .png or .pdf)");
    gtk_file_dialog_set_initial_name(dialog, "moxi-fdg.svg");
    SaveRequest request = {g_main_loop_new(NULL, FALSE), NULL};
    gtk_file_dialog_save(dialog, NULL, NULL, saved, &request);
    g_main_loop_run(request.loop);
    g_main_loop_unref(request.loop);
    g_object_unref(dialog);
    if (!request.path) return 0;
    size_t length = strlen(request.path);
    int64_t result = -1;
    if (length && length < (size_t)capacity) {
        memcpy(buffer, request.path, length + 1);
        result = (int64_t)length;
    }
    g_free(request.path);
    return result;
}

// GTK widget snapshot: offscreen-render evidence from the actual running app.
int32_t fdg_capture_frame(const char *path) {
    GListModel *windows = gtk_window_get_toplevels();
    GtkWindow *window = NULL;
    for (guint i = 0; i < g_list_model_get_n_items(windows); ++i) {
        GtkWindow *candidate = g_list_model_get_item(windows, i);
        if (g_strcmp0(gtk_window_get_title(candidate), "Moxi Force Graph") == 0) { window = candidate; break; }
        g_object_unref(candidate);
    }
    if (!window) return -1;
    GtkWidget *child = gtk_window_get_child(window);
    GdkPaintable *paintable = gtk_widget_paintable_new(child);
    GtkSnapshot *snapshot = gtk_snapshot_new();
    gdk_paintable_snapshot(paintable, GDK_SNAPSHOT(snapshot), gtk_widget_get_width(child), gtk_widget_get_height(child));
    GskRenderNode *node = gtk_snapshot_free_to_node(snapshot);
    int result = -1;
    if (node) {
        GskRenderer *renderer = gtk_native_get_renderer(GTK_NATIVE(window));
        GdkTexture *texture = gsk_renderer_render_texture(renderer, node, NULL);
        if (texture) { result = gdk_texture_save_to_png(texture, path) ? 0 : -1; g_object_unref(texture); }
        gsk_render_node_unref(node);
    }
    g_object_unref(paintable);
    g_object_unref(window);
    return result;
}
