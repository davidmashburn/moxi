package org.moxi.host;

import android.app.Activity;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.os.Bundle;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.widget.FrameLayout;

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
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final RectF panel = new RectF();
        private float lastX;
        private float lastY;

        MoxiCanvas(Activity activity) {
            super(activity);
            setFocusable(true);
            setContentDescription("Moxi Android host demo");
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
