package com.limenarc.balloonpop;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.SurfaceView;

import com.limenarc.balloonpop.model.DartLauncher;
import com.limenarc.balloonpop.model.LauncherType;

/**
 * Renders the game and routes touch input. Everything is drawn in a fixed
 * 420-unit-wide virtual space that is scaled to the physical screen, so the
 * layout looks consistent across phone resolutions.
 */
public class GameView extends SurfaceView implements SurfaceHolder.Callback, Runnable {

    private static final float VW = 420f;

    private final Game game = new Game();
    private Thread thread;
    private volatile boolean running;

    private float scale = 1f;
    private int vw = (int) VW;
    private int vh = 800;

    private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);

    // UI state
    private DartLauncher selectedTower;
    private int shopSelection = -1;
    private float previewX = -1f, previewY = -1f;

    // UI rects (virtual coords)
    private final RectF startBtn = new RectF();
    private final RectF[] shopSlots = new RectF[Game.SHOP.length];
    private final RectF upgradeBtn = new RectF();
    private final RectF sellBtn = new RectF();
    private final RectF closeBtn = new RectF();

    public GameView(Context context) {
        super(context);
        getHolder().addCallback(this);
        for (int i = 0; i < shopSlots.length; i++) shopSlots[i] = new RectF();
        setFocusable(true);
    }

    // --------------------------------------------------------- surface / loop

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        running = true;
        thread = new Thread(this, "game-loop");
        thread.start();
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        scale = width / VW;
        vw = (int) VW;
        vh = Math.round(height / scale);
        game.layout(vw, vh);
        computeRects();
        if (game.wave == 0 && game.bannerTimer <= 0f) {
            game.reset();
        }
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        running = false;
        boolean joined = false;
        while (!joined) {
            try {
                if (thread != null) thread.join();
                joined = true;
            } catch (InterruptedException ignored) {
                // retry until the loop thread exits
            }
        }
    }

    @Override
    public void run() {
        long last = System.nanoTime();
        while (running) {
            long now = System.nanoTime();
            float dt = (now - last) / 1_000_000_000f;
            last = now;
            if (dt > 0.05f) dt = 0.05f; // clamp after stalls

            if (game.isLaidOut()) {
                game.update(dt);
            }

            SurfaceHolder holder = getHolder();
            Canvas c = holder.lockCanvas();
            if (c != null) {
                try {
                    render(c);
                } finally {
                    holder.unlockCanvasAndPost(c);
                }
            }

            long frameMs = (System.nanoTime() - now) / 1_000_000L;
            long sleep = 16 - frameMs;
            if (sleep > 0) {
                try {
                    Thread.sleep(sleep);
                } catch (InterruptedException ignored) {
                }
            }
        }
    }

    // ------------------------------------------------------------------ rects

    private void computeRects() {
        float topH = game.topBarH;
        startBtn.set(vw * 0.64f, topH * 0.16f, vw - 8f, topH * 0.84f);

        float pad = 5f;
        float barTop = vh - game.shopBarH;
        float slotTop = barTop + 6f;
        float slotBot = vh - 6f;
        float slotW = (vw - pad * (shopSlots.length + 1)) / shopSlots.length;
        for (int i = 0; i < shopSlots.length; i++) {
            float left = pad + i * (slotW + pad);
            shopSlots[i].set(left, slotTop, left + slotW, slotBot);
        }

        closeBtn.set(vw - 44f, barTop + 6f, vw - 8f, barTop + 38f);
        float btnTop = vh - 6f - 46f;
        upgradeBtn.set(10f, btnTop, vw * 0.5f - 5f, vh - 8f);
        sellBtn.set(vw * 0.5f + 5f, btnTop, vw - 10f, vh - 8f);
    }

    // ------------------------------------------------------------------ input

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        float x = event.getX() / scale;
        float y = event.getY() / scale;
        int action = event.getActionMasked();

        if (action == MotionEvent.ACTION_DOWN) {
            handleDown(x, y);
            performClick();
        } else if (action == MotionEvent.ACTION_MOVE) {
            if (shopSelection >= 0 && inField(y)) {
                previewX = x;
                previewY = y;
            }
        } else if (action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL) {
            previewX = previewY = -1f;
        }
        return true;
    }

    @Override
    public boolean performClick() {
        return super.performClick();
    }

    private boolean inField(float y) {
        return y > game.topBarH && y < vh - game.shopBarH;
    }

    private void handleDown(float x, float y) {
        // End screens: tap to restart.
        if (game.state == Game.State.GAME_OVER || game.state == Game.State.WIN) {
            game.reset();
            selectedTower = null;
            shopSelection = -1;
            return;
        }

        // Start wave button.
        if (startBtn.contains(x, y) && game.canStartWave()) {
            game.startWave();
            return;
        }

        // Upgrade panel (only when a tower is selected).
        if (selectedTower != null) {
            if (closeBtn.contains(x, y)) {
                selectedTower = null;
                return;
            }
            if (upgradeBtn.contains(x, y)) {
                game.upgradeTower(selectedTower);
                return;
            }
            if (sellBtn.contains(x, y)) {
                game.sellTower(selectedTower);
                selectedTower = null;
                return;
            }
        } else {
            // Shop slots.
            for (int i = 0; i < shopSlots.length; i++) {
                if (shopSlots[i].contains(x, y)) {
                    shopSelection = (shopSelection == i) ? -1 : i;
                    return;
                }
            }
        }

        // Field interactions.
        if (inField(y)) {
            DartLauncher hit = game.towerAt(x, y);
            if (hit != null) {
                selectedTower = hit;
                shopSelection = -1;
                return;
            }
            if (selectedTower != null) {
                selectedTower = null;
                return;
            }
            if (shopSelection >= 0) {
                game.tryPlaceTower(Game.SHOP[shopSelection], x, y);
                return;
            }
        }
    }

    // --------------------------------------------------------------- drawing

    private void render(Canvas c) {
        c.save();
        c.scale(scale, scale);

        game.draw(c);
        drawSelectionOverlay(c);
        drawTopBar(c);
        if (selectedTower != null) {
            drawUpgradePanel(c);
        } else {
            drawShop(c);
        }
        drawBanner(c);
        drawEndScreens(c);

        c.restore();
    }

    private void drawSelectionOverlay(Canvas c) {
        if (selectedTower != null) {
            p.setStyle(Paint.Style.STROKE);
            p.setStrokeWidth(2f);
            p.setColor(0x88FFFFFF);
            c.drawCircle(selectedTower.x, selectedTower.y, selectedTower.range(), p);
            p.setStyle(Paint.Style.FILL);
        }
        if (shopSelection >= 0 && previewX >= 0f) {
            LauncherType t = Game.SHOP[shopSelection];
            boolean ok = game.isValidPlacement(previewX, previewY);
            p.setStyle(Paint.Style.STROKE);
            p.setStrokeWidth(2f);
            p.setColor(ok ? 0x8800E676 : 0x88FF1744);
            c.drawCircle(previewX, previewY, t.range, p);
            p.setStyle(Paint.Style.FILL);
            p.setColor((ok ? 0x99000000 : 0x99770000) | (t.color & 0xFFFFFF));
            c.drawCircle(previewX, previewY, Game.TOWER_RADIUS, p);
        }
    }

    private void drawTopBar(Canvas c) {
        p.setStyle(Paint.Style.FILL);
        p.setColor(0xE6102027);
        c.drawRect(0, 0, vw, game.topBarH, p);

        p.setFakeBoldText(true);
        float ts = game.topBarH * 0.30f;
        p.setTextSize(ts);
        float cy = game.topBarH * 0.62f;
        p.setTextAlign(Paint.Align.LEFT);
        p.setColor(0xFFFFD54F);
        c.drawText("$" + game.cash, 8f, cy, p);
        p.setColor(0xFFFF8A80);
        c.drawText("♥ " + game.lives, vw * 0.24f, cy, p);
        p.setTextAlign(Paint.Align.RIGHT);
        p.setColor(0xFF80D8FF);
        c.drawText("WAVE " + game.wave + "/" + Game.TOTAL_WAVES, startBtn.left - 6f, cy, p);
        p.setTextAlign(Paint.Align.LEFT);
        p.setFakeBoldText(false);

        // Start button
        boolean can = game.canStartWave();
        String label = game.state == Game.State.RUNNING ? "FIGHT!" :
                (game.wave >= Game.TOTAL_WAVES ? "DONE" : "START WAVE ▶");
        drawButton(c, startBtn, label, null, can, can ? 0xFF2E7D32 : 0xFF555555);
    }

    private void drawShop(Canvas c) {
        float barTop = vh - game.shopBarH;
        p.setStyle(Paint.Style.FILL);
        p.setColor(0xE6102027);
        c.drawRect(0, barTop, vw, vh, p);

        for (int i = 0; i < shopSlots.length; i++) {
            LauncherType t = Game.SHOP[i];
            RectF r = shopSlots[i];
            boolean affordable = game.cash >= t.cost;
            boolean sel = shopSelection == i;

            p.setColor(affordable ? t.color : dim(t.color));
            c.drawRoundRect(r, 6f, 6f, p);

            if (sel) {
                p.setStyle(Paint.Style.STROKE);
                p.setStrokeWidth(3f);
                p.setColor(0xFFFFFFFF);
                c.drawRoundRect(r, 6f, 6f, p);
                p.setStyle(Paint.Style.FILL);
            }

            p.setColor(0xFFFFFFFF);
            p.setTextAlign(Paint.Align.CENTER);
            p.setFakeBoldText(true);
            p.setTextSize(13f);
            c.drawText(t.shortName, r.centerX(), r.top + 18f, p);
            p.setFakeBoldText(false);
            p.setTextSize(11f);
            p.setColor(affordable ? 0xFFFFE082 : 0xFFBDBDBD);
            c.drawText("$" + t.cost, r.centerX(), r.bottom - 8f, p);
        }
    }

    private void drawUpgradePanel(Canvas c) {
        float barTop = vh - game.shopBarH;
        DartLauncher t = selectedTower;
        p.setStyle(Paint.Style.FILL);
        p.setColor(0xF2141E26);
        c.drawRect(0, barTop, vw, vh, p);

        // Title + stats
        p.setColor(t.type.color);
        c.drawRect(10f, barTop + 8f, 22f, barTop + 34f, p);
        p.setColor(0xFFFFFFFF);
        p.setTextAlign(Paint.Align.LEFT);
        p.setFakeBoldText(true);
        p.setTextSize(15f);
        c.drawText(t.type.displayName + "  (Lv " + t.level + "/" + DartLauncher.MAX_LEVEL + ")",
                30f, barTop + 27f, p);
        p.setFakeBoldText(false);
        p.setTextSize(11f);
        p.setColor(0xFFCFD8DC);
        c.drawText("DMG " + t.damage() + "   RNG " + Math.round(t.range())
                + "   RATE " + String.format(java.util.Locale.US, "%.1f", 1f / t.fireCooldown()) + "/s",
                12f, barTop + 46f, p);
        // wrap description
        drawWrapped(c, t.type.description, 12f, barTop + 62f, vw - 24f, 12f, 0xFF90A4AE);

        // Buttons
        boolean canUp = t.canUpgrade() && game.cash >= t.upgradeCost();
        String upLabel = t.canUpgrade() ? "UPGRADE" : "MAX LEVEL";
        String upSub = t.canUpgrade() ? "$" + t.upgradeCost() : null;
        drawButton(c, upgradeBtn, upLabel, upSub, canUp, canUp ? 0xFF1565C0 : 0xFF555555);
        drawButton(c, sellBtn, "SELL", "$" + t.sellValue(), true, 0xFFB71C1C);

        // Close
        drawButton(c, closeBtn, "✕", null, true, 0xFF37474F);
    }

    private void drawBanner(Canvas c) {
        if (game.bannerTimer <= 0f || game.banner == null || game.banner.isEmpty()) return;
        p.setTextAlign(Paint.Align.CENTER);
        p.setFakeBoldText(true);
        p.setTextSize(17f);
        float y = game.topBarH + 26f;
        p.setColor(0xAA000000);
        c.drawText(game.banner, vw / 2f + 1f, y + 1f, p);
        p.setColor(0xFFFFFFFF);
        c.drawText(game.banner, vw / 2f, y, p);
        p.setFakeBoldText(false);
    }

    private void drawEndScreens(Canvas c) {
        if (game.state != Game.State.GAME_OVER && game.state != Game.State.WIN) return;
        p.setStyle(Paint.Style.FILL);
        p.setColor(0xCC000000);
        c.drawRect(0, 0, vw, vh, p);
        p.setTextAlign(Paint.Align.CENTER);
        p.setFakeBoldText(true);
        p.setTextSize(38f);
        boolean win = game.state == Game.State.WIN;
        p.setColor(win ? 0xFF69F0AE : 0xFFFF5252);
        c.drawText(win ? "VICTORY!" : "GAME OVER", vw / 2f, vh * 0.42f, p);
        p.setFakeBoldText(false);
        p.setTextSize(16f);
        p.setColor(0xFFFFFFFF);
        String msg = win ? "All 5 bosses popped!" : "Reached wave " + game.wave + " of " + Game.TOTAL_WAVES;
        c.drawText(msg, vw / 2f, vh * 0.42f + 30f, p);
        c.drawText("Tap to play again", vw / 2f, vh * 0.42f + 56f, p);
    }

    // --------------------------------------------------------------- helpers

    private void drawButton(Canvas c, RectF r, String label, String sub, boolean enabled, int color) {
        p.setStyle(Paint.Style.FILL);
        p.setColor(color);
        c.drawRoundRect(r, 7f, 7f, p);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(1.5f);
        p.setColor(enabled ? 0x66FFFFFF : 0x33FFFFFF);
        c.drawRoundRect(r, 7f, 7f, p);
        p.setStyle(Paint.Style.FILL);

        p.setColor(enabled ? 0xFFFFFFFF : 0xFFBDBDBD);
        p.setTextAlign(Paint.Align.CENTER);
        p.setFakeBoldText(true);
        if (sub == null) {
            p.setTextSize(Math.min(15f, r.height() * 0.5f));
            c.drawText(label, r.centerX(), r.centerY() + p.getTextSize() * 0.35f, p);
        } else {
            p.setTextSize(13f);
            c.drawText(label, r.centerX(), r.centerY() - 1f, p);
            p.setFakeBoldText(false);
            p.setTextSize(11f);
            p.setColor(0xFFFFE082);
            c.drawText(sub, r.centerX(), r.centerY() + 14f, p);
        }
        p.setFakeBoldText(false);
    }

    private void drawWrapped(Canvas c, String text, float x, float y, float maxW, float lineH, int color) {
        p.setColor(color);
        p.setTextAlign(Paint.Align.LEFT);
        p.setTextSize(11f);
        String[] words = text.split(" ");
        StringBuilder line = new StringBuilder();
        float yy = y;
        for (String w : words) {
            String test = line.length() == 0 ? w : line + " " + w;
            if (p.measureText(test) > maxW && line.length() > 0) {
                c.drawText(line.toString(), x, yy, p);
                yy += lineH;
                line = new StringBuilder(w);
            } else {
                line = new StringBuilder(test);
            }
        }
        if (line.length() > 0) c.drawText(line.toString(), x, yy, p);
    }

    private static int dim(int color) {
        int r = (int) (((color >> 16) & 0xFF) * 0.45f);
        int g = (int) (((color >> 8) & 0xFF) * 0.45f);
        int b = (int) ((color & 0xFF) * 0.45f);
        return 0xFF000000 | (r << 16) | (g << 8) | b;
    }
}
