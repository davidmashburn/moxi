/* Included by linux_window.c after the retained paint routines. */
typedef struct { GtkDrawingArea parent; } MoxiSceneArea;
typedef struct { GtkDrawingAreaClass parent; } MoxiSceneAreaClass;
G_DEFINE_TYPE(MoxiSceneArea, moxi_scene_area, GTK_TYPE_DRAWING_AREA)

static graphene_rect_t scene_rect(Box box) {
    return GRAPHENE_RECT_INIT(box.x,box.y,box.width,box.height);
}

static GdkRGBA scene_color(Color color) {
    return (GdkRGBA){color.r,color.g,color.b,color.a};
}

static void snapshot_custom(GtkSnapshot *snapshot, const graphene_rect_t *viewport) {
    if (!custom) return;
    if (custom_clipped) {
        graphene_rect_t bounds = scene_rect(custom_clip);
        gtk_snapshot_push_clip(snapshot,&bounds);
    }
    for (guint i=0;i<custom->len;++i) {
        Custom *item = &g_array_index(custom,Custom,i);
        graphene_rect_t bounds = scene_rect(item->box);
        if (item->kind == CUSTOM_RECT && !item->radius && !item->stroke_width) {
            GdkRGBA color = scene_color(item->fill);
            gtk_snapshot_append_color(snapshot,&color,&bounds);
        } else if (item->kind == CUSTOM_LINE) {
            /* Butt-ended segment as a transformed solid quad. This avoids a
             * per-segment path raster/texture upload in GTK 4.14. */
            float dx = item->box.width-item->box.x, dy = item->box.height-item->box.y;
            float length = hypotf(dx,dy);
            if (length <= 0 || item->stroke_width <= 0) continue;
            graphene_point_t start = GRAPHENE_POINT_INIT(item->box.x,item->box.y);
            graphene_rect_t quad = GRAPHENE_RECT_INIT(0,-item->stroke_width/2,
                                                      length,item->stroke_width);
            GdkRGBA ink = scene_color(item->stroke);
            gtk_snapshot_save(snapshot);
            gtk_snapshot_translate(snapshot,&start);
            gtk_snapshot_rotate(snapshot,(float)(atan2f(dy,dx)*180/G_PI));
            gtk_snapshot_append_color(snapshot,&ink,&quad);
            gtk_snapshot_restore(snapshot);
        } else if (item->kind == CUSTOM_BITMAP) {
            gtk_snapshot_push_opacity(snapshot,item->opacity);
            gtk_snapshot_append_texture(snapshot,item->texture,&bounds);
            gtk_snapshot_pop(snapshot);
        } else {
            cairo_t *cr = gtk_snapshot_append_cairo(snapshot,viewport);
            draw_custom_item(cr,item);
            cairo_destroy(cr);
        }
    }
    if (custom_clipped) gtk_snapshot_pop(snapshot);
}

static void moxi_scene_snapshot(GtkWidget *widget, GtkSnapshot *snapshot) {
    graphene_rect_t viewport = GRAPHENE_RECT_INIT(0,0,gtk_widget_get_width(widget),
                                                   gtk_widget_get_height(widget));
    GdkRGBA background = scene_color(surface);
    gtk_snapshot_append_color(snapshot,&background,&viewport);
    cairo_t *cr = gtk_snapshot_append_cairo(snapshot,&viewport);
    if (ordered) {
        for (int i=0;i<order_count;++i) {
            if (order[i].kind == 100) {
                cairo_destroy(cr);
                snapshot_custom(snapshot,&viewport);
                cr = gtk_snapshot_append_cairo(snapshot,&viewport);
            } else draw_slot(cr,order[i].kind,order[i].slot);
        }
    } else {
        for (int kind=1;kind<25;++kind)
            for (int i=0;i<SLOT_CAPACITY;++i) draw_slot(cr,kind,i);
    }
    cairo_destroy(cr);
    if (!ordered) snapshot_custom(snapshot,&viewport);
    if (trace) {
        GskRenderer *renderer = gtk_native_get_renderer(gtk_widget_get_native(widget));
        fprintf(trace,"{\"type\":\"draw\",\"frame\":%u,\"renderer\":\"%s\",\"custom\":%u}\n",
                frame_number,G_OBJECT_TYPE_NAME(renderer),custom ? custom->len : 0);
        fflush(trace);
    }
}

static void moxi_scene_area_class_init(MoxiSceneAreaClass *klass) {
    GTK_WIDGET_CLASS(klass)->snapshot = moxi_scene_snapshot;
}
static void moxi_scene_area_init(MoxiSceneArea *self) { (void)self; }
