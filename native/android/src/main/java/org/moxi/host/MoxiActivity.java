package org.moxi.host;

import android.app.Activity;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;
import android.os.Bundle;
import android.os.Build;
import android.util.SparseArray;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.accessibility.AccessibilityNodeProvider;
import android.widget.FrameLayout;

import java.util.ArrayList;
import java.util.List;

public final class MoxiActivity extends Activity {
    static {
        System.loadLibrary("moxi_host");
    }

    private long nativeHost;
    private MoxiSurface surface;
    private MoxiCanvas canvas;

    private native long nativeCreate(int width, int height, float scale);
    private native void nativeDestroy(long handle);
    private native void nativeSurface(long handle, Object surface);
    private native void nativeSize(long handle, int width, int height, float scale);
    private native void nativeTouch(
        long handle,
        int kind,
        int pointerId,
        float x,
        float y,
        int buttons,
        int modifiers
    );
    private native void nativeKey(long handle, int key, int modifiers);
    private native void nativeText(long handle, String text, int start, int end);
    private native void nativeAction(long handle, int target, int action);
    private native void nativeFrame(long handle);

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        float scale = getResources().getDisplayMetrics().density;
        nativeHost = nativeCreate(1, 1, scale);

        FrameLayout root = new FrameLayout(this);
        surface = new MoxiSurface(this);
        canvas = new MoxiCanvas(this);
        root.addView(surface, new FrameLayout.LayoutParams(-1, -1));
        root.addView(canvas, new FrameLayout.LayoutParams(-1, -1));
        setContentView(root);
    }

    @Override
    protected void onDestroy() {
        if (nativeHost != 0) {
            nativeDestroy(nativeHost);
            nativeHost = 0;
        }
        super.onDestroy();
    }

    private final class MoxiSurface extends SurfaceView implements SurfaceHolder.Callback {
        MoxiSurface(Activity activity) {
            super(activity);
            getHolder().addCallback(this);
            setFocusable(true);
        }

        @Override
        public void surfaceCreated(SurfaceHolder holder) {
            nativeSurface(nativeHost, holder.getSurface());
        }

        @Override
        public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
            float scale = getResources().getDisplayMetrics().density;
            nativeSize(nativeHost, width, height, scale);
        }

        @Override
        public void surfaceDestroyed(SurfaceHolder holder) {
            nativeSurface(nativeHost, null);
        }
    }

    private final class MoxiCanvas extends View {
        private static final int HOST_VIEW_ID = -1;
        private static final int ROLE_BUTTON = 2;
        private static final int ROLE_TEXT_INPUT = 3;
        private static final int ROLE_CHECKBOX = 6;
        private static final int ROLE_PROGRESS = 7;
        private static final int ROLE_SLIDER = 8;
        private static final int ROLE_SWITCH = 9;
        private static final int ROLE_RADIO = 10;
        private static final int ROLE_IMAGE = 11;
        private static final int ROLE_TEXT_AREA = 12;
        private static final int ROLE_COMBO_BOX = 13;
        private static final int ROLE_LIST = 14;
        private static final int ROLE_TABLE = 15;
        private static final int ROLE_TREE = 16;
        private static final int ROLE_MENU = 17;
        private static final int ROLE_DIALOG = 18;
        private static final int ROLE_TAB_GROUP = 19;
        private static final int ROLE_CANVAS = 20;

        private static final int MOXI_ACTION_PRESS = 1;
        private static final int MOXI_ACTION_INCREMENT = 2;
        private static final int MOXI_ACTION_DECREMENT = 4;
        private static final int MOXI_ACTION_SELECT = 8;
        private static final int MOXI_ACTION_EXPAND = 16;
        private static final int MOXI_ACTION_COLLAPSE = 32;

        private final SparseArray<MoxiAccessibilityNode> accessibilityNodes = new SparseArray<>();
        private final MoxiAccessibilityProvider accessibilityProvider =
            new MoxiAccessibilityProvider();
        private int hoveredAccessibilityId = HOST_VIEW_ID;
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final RectF panel = new RectF();
        private float lastX;
        private float lastY;

        private final class MoxiAccessibilityNode {
            int id;
            int parentId;
            int role;
            String label;
            String value;
            String hint;
            Rect bounds;
            boolean enabled;
            boolean focused;
            boolean accessibilityFocused;
            boolean selected;
            boolean checked;
            boolean expanded;
            boolean hasValueRange;
            float valueMin;
            float valueMax;
            float valueNow;
            int actions;

            MoxiAccessibilityNode(
                int id,
                int parentId,
                int role,
                String label,
                String value,
                String hint,
                Rect bounds,
                int actions
            ) {
                this.id = id;
                this.parentId = parentId;
                this.role = role;
                this.label = label == null ? "" : label;
                this.value = value == null ? "" : value;
                this.hint = hint == null ? "" : hint;
                this.bounds = new Rect(bounds);
                this.enabled = true;
                this.actions = actions;
            }
        }

        private String roleClassName(int role) {
            switch (role) {
                case ROLE_BUTTON:
                case ROLE_CHECKBOX:
                case ROLE_RADIO:
                    return "android.widget.Button";
                case ROLE_TEXT_INPUT:
                case ROLE_TEXT_AREA:
                    return "android.widget.EditText";
                case ROLE_PROGRESS:
                    return "android.widget.ProgressBar";
                case ROLE_SLIDER:
                    return "android.widget.SeekBar";
                case ROLE_SWITCH:
                    return "android.widget.Switch";
                case ROLE_COMBO_BOX:
                    return "android.widget.Spinner";
                case ROLE_IMAGE:
                    return "android.widget.ImageView";
                case ROLE_LIST:
                    return "android.widget.ListView";
                case ROLE_TABLE:
                    return "android.widget.TableLayout";
                case ROLE_DIALOG:
                    return "android.app.Dialog";
                default:
                    return "android.view.View";
            }
        }

        private boolean isInteractive(MoxiAccessibilityNode node) {
            return node.role == ROLE_BUTTON || node.role == ROLE_TEXT_INPUT ||
                node.role == ROLE_TEXT_AREA || node.role == ROLE_CHECKBOX ||
                node.role == ROLE_SLIDER || node.role == ROLE_SWITCH ||
                node.role == ROLE_RADIO || node.role == ROLE_COMBO_BOX ||
                node.role == ROLE_LIST || node.role == ROLE_TABLE ||
                node.role == ROLE_TREE || node.role == ROLE_MENU ||
                node.role == ROLE_DIALOG || node.role == ROLE_TAB_GROUP ||
                node.role == ROLE_CANVAS;
        }

        private void addDemoAccessibilityNodes() {
            accessibilityNodes.clear();
            accessibilityNodes.put(100, new MoxiAccessibilityNode(
                100,
                -1,
                5,
                "Moxi Android host",
                "",
                "",
                new Rect(0, 0, getWidth(), getHeight()),
                0
            ));
            accessibilityNodes.put(101, new MoxiAccessibilityNode(
                101,
                100,
                ROLE_BUTTON,
                "Activate demo",
                "",
                "Activates the Android host demo",
                new Rect(32, 96, 220, 152),
                MOXI_ACTION_PRESS
            ));
        }

        @Override
        protected void onSizeChanged(int width, int height, int oldWidth, int oldHeight) {
            super.onSizeChanged(width, height, oldWidth, oldHeight);
            MoxiAccessibilityNode root = accessibilityNodes.get(100);
            if (root != null) root.bounds.set(0, 0, width, height);
        }

        private final class MoxiAccessibilityProvider extends AccessibilityNodeProvider {
            private void addChildren(AccessibilityNodeInfo info, int parentId) {
                for (int index = 0; index < accessibilityNodes.size(); index++) {
                    MoxiAccessibilityNode node = accessibilityNodes.valueAt(index);
                    if (node.parentId == parentId) info.addChild(MoxiCanvas.this, node.id);
                }
            }

            @Override
            public AccessibilityNodeInfo createAccessibilityNodeInfo(int virtualViewId) {
                if (virtualViewId == HOST_VIEW_ID) {
                    AccessibilityNodeInfo info = AccessibilityNodeInfo.obtain(MoxiCanvas.this);
                    info.setSource(MoxiCanvas.this);
                    info.setPackageName(getContext().getPackageName());
                    info.setClassName("android.view.View");
                    info.setContentDescription("Moxi Android host");
                    info.setBoundsInParent(new Rect(0, 0, getWidth(), getHeight()));
                    info.setVisibleToUser(isShown());
                    addChildren(info, -1);
                    return info;
                }
                MoxiAccessibilityNode node = accessibilityNodes.get(virtualViewId);
                if (node == null) return null;
                AccessibilityNodeInfo info = AccessibilityNodeInfo.obtain();
                info.setSource(MoxiCanvas.this, node.id);
                if (node.parentId < 0) info.setParent(MoxiCanvas.this);
                else info.setParent(MoxiCanvas.this, node.parentId);
                info.setPackageName(getContext().getPackageName());
                info.setClassName(roleClassName(node.role));
                info.setText(node.label);
                info.setContentDescription(node.label);
                if (!node.hint.isEmpty() && Build.VERSION.SDK_INT >= 26) {
                    info.setHintText(node.hint);
                }
                if (!node.value.isEmpty() && Build.VERSION.SDK_INT >= 30) {
                    info.setStateDescription(node.value);
                }
                info.setBoundsInParent(node.bounds);
                Rect screenBounds = new Rect(node.bounds);
                int[] location = new int[2];
                getLocationOnScreen(location);
                screenBounds.offset(location[0], location[1]);
                info.setBoundsInScreen(screenBounds);
                info.setEnabled(node.enabled);
                info.setVisibleToUser(isShown() && node.enabled);
                info.setFocusable(isInteractive(node));
                info.setFocused(node.focused);
                info.setAccessibilityFocused(node.accessibilityFocused);
                info.setSelected(node.selected);
                if (node.role == ROLE_CHECKBOX || node.role == ROLE_SWITCH ||
                    node.role == ROLE_RADIO) {
                    info.setCheckable(true);
                    info.setChecked(node.checked);
                }
                if ((node.actions & MOXI_ACTION_PRESS) != 0) {
                    info.addAction(AccessibilityNodeInfo.ACTION_CLICK);
                }
                if ((node.actions & MOXI_ACTION_INCREMENT) != 0) {
                    info.addAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD);
                }
                if ((node.actions & MOXI_ACTION_DECREMENT) != 0) {
                    info.addAction(AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD);
                }
                if (node.role == ROLE_TEXT_INPUT || node.role == ROLE_TEXT_AREA) {
                    info.addAction(AccessibilityNodeInfo.ACTION_SET_TEXT);
                }
                if (isInteractive(node)) info.addAction(AccessibilityNodeInfo.ACTION_FOCUS);
                addChildren(info, node.id);
                return info;
            }

            @Override
            public List<AccessibilityNodeInfo> findAccessibilityNodeInfosByText(
                String text,
                int virtualViewId
            ) {
                ArrayList<AccessibilityNodeInfo> matches = new ArrayList<>();
                if (text == null) return matches;
                String query = text.toLowerCase();
                for (int index = 0; index < accessibilityNodes.size(); index++) {
                    MoxiAccessibilityNode node = accessibilityNodes.valueAt(index);
                    if (node.label.toLowerCase().contains(query) ||
                        node.value.toLowerCase().contains(query)) {
                        AccessibilityNodeInfo info = createAccessibilityNodeInfo(node.id);
                        if (info != null) matches.add(info);
                    }
                }
                return matches;
            }

            @Override
            public boolean performAction(int virtualViewId, int action, Bundle arguments) {
                MoxiAccessibilityNode node = accessibilityNodes.get(virtualViewId);
                if (node == null) return virtualViewId == HOST_VIEW_ID &&
                    action == AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS;
                if (action == AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS) {
                    node.accessibilityFocused = true;
                    sendAccessibilityEventForVirtualView(node.id, AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUSED);
                    invalidate();
                    return true;
                }
                if (action == AccessibilityNodeInfo.ACTION_CLEAR_ACCESSIBILITY_FOCUS) {
                    node.accessibilityFocused = false;
                    invalidate();
                    return true;
                }
                if (action == AccessibilityNodeInfo.ACTION_FOCUS) {
                    node.focused = true;
                    invalidate();
                    return true;
                }
                if (action == AccessibilityNodeInfo.ACTION_SET_TEXT && arguments != null) {
                    CharSequence value = arguments.getCharSequence(
                        AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE
                    );
                    if (value == null) return false;
                    nativeText(nativeHost, value.toString(), -1, -1);
                    return true;
                }
                int moxiAction = 0;
                if (action == AccessibilityNodeInfo.ACTION_CLICK) {
                    moxiAction = MOXI_ACTION_PRESS;
                } else if (action == AccessibilityNodeInfo.ACTION_SCROLL_FORWARD) {
                    moxiAction = MOXI_ACTION_INCREMENT;
                } else if (action == AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD) {
                    moxiAction = MOXI_ACTION_DECREMENT;
                }
                if (moxiAction == 0 || (node.actions & moxiAction) == 0 || !node.enabled) {
                    return false;
                }
                nativeAction(nativeHost, node.id, moxiAction);
                sendAccessibilityEventForVirtualView(node.id, AccessibilityEvent.TYPE_VIEW_CLICKED);
                return true;
            }

            int virtualViewAt(float x, float y) {
                for (int index = accessibilityNodes.size() - 1; index >= 0; index--) {
                    MoxiAccessibilityNode node = accessibilityNodes.valueAt(index);
                    if (node.enabled && node.bounds.contains((int)x, (int)y)) return node.id;
                }
                return HOST_VIEW_ID;
            }
        }

        private void sendAccessibilityEventForVirtualView(int id, int type) {
            AccessibilityEvent event = AccessibilityEvent.obtain(type);
            event.setPackageName(getContext().getPackageName());
            event.setSource(this, id);
            MoxiAccessibilityNode node = accessibilityNodes.get(id);
            if (node != null) event.getText().add(node.label);
            sendAccessibilityEventUnchecked(event);
            event.recycle();
        }

        MoxiCanvas(Activity activity) {
            super(activity);
            setFocusable(true);
            setContentDescription("Moxi Android host demo");
            addDemoAccessibilityNodes();
        }

        @Override
        public AccessibilityNodeProvider getAccessibilityNodeProvider() {
            return accessibilityProvider;
        }

        @Override
        public boolean dispatchHoverEvent(MotionEvent event) {
            int action = event.getActionMasked();
            if (action != MotionEvent.ACTION_HOVER_ENTER &&
                action != MotionEvent.ACTION_HOVER_MOVE &&
                action != MotionEvent.ACTION_HOVER_EXIT) {
                return super.dispatchHoverEvent(event);
            }
            int next = action == MotionEvent.ACTION_HOVER_EXIT
                ? HOST_VIEW_ID
                : accessibilityProvider.virtualViewAt(event.getX(), event.getY());
            if (next != hoveredAccessibilityId) {
                if (hoveredAccessibilityId != HOST_VIEW_ID) {
                    sendAccessibilityEventForVirtualView(
                        hoveredAccessibilityId,
                        AccessibilityEvent.TYPE_VIEW_HOVER_EXIT
                    );
                }
                hoveredAccessibilityId = next;
                if (next != HOST_VIEW_ID) {
                    sendAccessibilityEventForVirtualView(
                        next,
                        AccessibilityEvent.TYPE_VIEW_HOVER_ENTER
                    );
                }
            }
            return true;
        }

        @Override
        protected void onDraw(Canvas graphics) {
            super.onDraw(graphics);
            float density = getResources().getDisplayMetrics().density;
            float inset = 24.0f * density;
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.rgb(14, 17, 26));
            graphics.drawColor(paint.getColor());
            panel.set(inset, inset * 2.0f, getWidth() - inset, getHeight() - inset * 2.0f);
            paint.setColor(Color.rgb(38, 48, 72));
            graphics.drawRoundRect(panel, 22.0f * density, 22.0f * density, paint);
            paint.setColor(Color.rgb(111, 214, 180));
            graphics.drawRoundRect(
                inset * 1.75f,
                inset * 3.0f,
                inset * 2.25f,
                inset * 3.5f,
                6.0f * density,
                6.0f * density,
                paint
            );
            paint.setColor(Color.WHITE);
            paint.setTextSize(18.0f * density);
            graphics.drawText("Moxi Android host", inset * 1.75f, inset * 5.0f, paint);
            paint.setTextSize(13.0f * density);
            paint.setColor(Color.rgb(191, 201, 222));
            graphics.drawText("NDK surface + touch + frame callbacks", inset * 1.75f, inset * 6.25f, paint);
            if (lastX != 0.0f || lastY != 0.0f) {
                graphics.drawText(
                    String.format("touch %.0f, %.0f", lastX, lastY),
                    inset * 1.75f,
                    inset * 8.0f,
                    paint
                );
            }
            nativeFrame(nativeHost);
            postInvalidateOnAnimation();
        }

        @Override
        public boolean onTouchEvent(MotionEvent event) {
            int action = event.getActionMasked();
            int kind;
            if (action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_POINTER_DOWN) {
                kind = 16;
            } else if (action == MotionEvent.ACTION_MOVE) {
                kind = 17;
            } else if (action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_POINTER_UP) {
                kind = 18;
            } else if (action == MotionEvent.ACTION_CANCEL) {
                kind = 19;
            } else {
                return true;
            }
            int index = event.getActionIndex();
            lastX = event.getX(index);
            lastY = event.getY(index);
            nativeTouch(
                nativeHost,
                kind,
                event.getPointerId(index),
                lastX,
                lastY,
                event.getButtonState(),
                0
            );
            invalidate();
            return true;
        }

        @Override
        public boolean onKeyDown(int keyCode, android.view.KeyEvent event) {
            nativeKey(nativeHost, keyCode, event.getMetaState());
            return super.onKeyDown(keyCode, event);
        }
    }
}
