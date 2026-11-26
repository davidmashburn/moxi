/* Real GTK display, host ABI and GSK render/readback. Build as a standalone test. */
#include "../../native/linux_window.c"
#include <epoxy/gl.h>
#include <assert.h>

int main(void) {
    for (int cycle=0;cycle<3;cycle++) {
        moxi_window_open("Moxi Scene resource probe",80,60,0,0,0,0,1,0);
        GdkDisplay *display = gtk_widget_get_display(canvas);
        GError *error = NULL;
        GdkGLContext *context = gdk_display_create_gl_context(display,&error);
        if (context && gdk_gl_context_realize(context,&error)) {
            gdk_gl_context_make_current(context);
            printf("GL renderer: %s; version: %s\n",glGetString(GL_RENDERER),glGetString(GL_VERSION));
            gdk_gl_context_clear_current();
        }
        g_clear_error(&error);
        g_clear_object(&context);

        moxi_window_begin_custom_paint();
        uint8_t pixel[] = {255,0,0,255};
        assert(!moxi_window_add_custom_bitmap(pixel,3,1,1,0,0,10,10,1));
        assert(moxi_window_add_custom_bitmap(pixel,4,1,1,0,0,10,10,1));
        memset(pixel,0,sizeof pixel); /* Caller immediately reuses its memory. */
        GdkTexture *weak = g_array_index(custom,Custom,0).texture;
        g_object_add_weak_pointer(G_OBJECT(weak),(gpointer *)&weak);
        moxi_window_set_custom_clip(2,2,5,5);
        GtkSnapshot *snapshot = gtk_snapshot_new();
        graphene_rect_t viewport = GRAPHENE_RECT_INIT(0,0,10,10);
        snapshot_custom(snapshot,&viewport);
        GskRenderNode *node = gtk_snapshot_free_to_node(snapshot);
        moxi_window_begin_custom_paint();
        assert(weak && !custom->len); /* Published node retains the texture. */
        GskRenderer *renderer = gtk_native_get_renderer(GTK_NATIVE(window));
        GdkTexture *result = gsk_renderer_render_texture(renderer,node,&viewport);
        unsigned char pixels[400];
        gdk_texture_download(result,pixels,40);
        guint32 center, outside;
        memcpy(&center,pixels+4*(5*10+5),4);
        memcpy(&outside,pixels,4);
        assert(center == 0xffff0000 && outside == 0);
        g_object_unref(result);
        gsk_render_node_unref(node);
        moxi_window_close();
        assert(!weak);
    }
    puts("PASS copied RGBA, rejected length, clip, retained node, release and reopen (3 cycles)");
}
