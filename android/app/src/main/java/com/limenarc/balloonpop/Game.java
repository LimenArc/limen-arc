package com.limenarc.balloonpop;

import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;

import com.limenarc.balloonpop.model.Balloon;
import com.limenarc.balloonpop.model.BossType;
import com.limenarc.balloonpop.model.Dart;
import com.limenarc.balloonpop.model.DartLauncher;
import com.limenarc.balloonpop.model.LauncherType;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Random;

/**
 * Core game state, simulation and world rendering. UI chrome (top bar, shop,
 * upgrade panel, end screens) is drawn by {@link GameView}.
 */
public class Game {
    public enum State { READY, RUNNING, GAME_OVER, WIN }

    public static final int TOTAL_WAVES = 25;
    public static final LauncherType[] SHOP = LauncherType.values();

    public static final int START_CASH = 650;
    public static final int START_LIVES = 120;

    public int cash = START_CASH;
    public int lives = START_LIVES;
    public int wave = 0;
    public State state = State.READY;
    public String banner = "";          // transient status text for the top bar
    public float bannerTimer = 0f;

    public final List<DartLauncher> towers = new ArrayList<>();
    public final List<Balloon> balloons = new ArrayList<>();
    public final List<Dart> darts = new ArrayList<>();

    // Layout / path
    private int width, height;
    public float topBarH, shopBarH;
    public static final float TOWER_RADIUS = 22f;
    private static final float PATH_WIDTH = 46f;
    private final List<float[]> waypoints = new ArrayList<>();
    private float[] segLen = new float[0];
    private float totalLen = 0f;
    private Path pathCache;

    private final Random rng = new Random();
    private final float[] tmp = new float[2];

    // Wave spawning
    private boolean waveActive = false;
    private int regularToSpawn = 0;
    private float spawnTimer = 0f;
    private float spawnInterval = 0.8f;
    private int spawnHp = 1;
    private float spawnSpeed = 75f;
    private BossType pendingBoss = null;
    private boolean bossSpawned = false;

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);

    // ----------------------------------------------------------------- layout

    public void layout(int w, int h) {
        this.width = w;
        this.height = h;
        topBarH = h * 0.085f;
        shopBarH = h * 0.20f;
        buildPath();
    }

    public boolean isLaidOut() {
        return width > 0 && height > 0 && totalLen > 0;
    }

    private void buildPath() {
        waypoints.clear();
        float top = topBarH + 30f;
        float bot = height - shopBarH - 30f;
        float left = width * 0.14f;
        float right = width * 0.86f;
        float[] ys = new float[4];
        for (int i = 0; i < 4; i++) {
            ys[i] = top + (bot - top) * i / 3f;
        }
        add(-50f, ys[0]);
        add(right, ys[0]);
        add(right, ys[1]);
        add(left, ys[1]);
        add(left, ys[2]);
        add(right, ys[2]);
        add(right, ys[3]);
        add(left, ys[3]);
        add(left, height + 60f);

        segLen = new float[waypoints.size() - 1];
        totalLen = 0f;
        for (int i = 0; i < segLen.length; i++) {
            float[] a = waypoints.get(i);
            float[] b = waypoints.get(i + 1);
            segLen[i] = (float) Math.hypot(b[0] - a[0], b[1] - a[1]);
            totalLen += segLen[i];
        }

        pathCache = new Path();
        float[] first = waypoints.get(0);
        pathCache.moveTo(first[0], first[1]);
        for (int i = 1; i < waypoints.size(); i++) {
            float[] p = waypoints.get(i);
            pathCache.lineTo(p[0], p[1]);
        }
    }

    private void add(float x, float y) {
        waypoints.add(new float[]{x, y});
    }

    /** Writes the world position for a given distance into {@code out}. */
    private void positionAt(float dist, float[] out) {
        if (dist <= 0f) {
            out[0] = waypoints.get(0)[0];
            out[1] = waypoints.get(0)[1];
            return;
        }
        float acc = 0f;
        for (int i = 0; i < segLen.length; i++) {
            if (dist <= acc + segLen[i] || i == segLen.length - 1) {
                float t = segLen[i] == 0f ? 0f : (dist - acc) / segLen[i];
                if (t > 1f) t = 1f;
                float[] a = waypoints.get(i);
                float[] b = waypoints.get(i + 1);
                out[0] = a[0] + (b[0] - a[0]) * t;
                out[1] = a[1] + (b[1] - a[1]) * t;
                return;
            }
            acc += segLen[i];
        }
    }

    private float distanceToPath(float px, float py) {
        float best = Float.MAX_VALUE;
        for (int i = 0; i < segLen.length; i++) {
            float[] a = waypoints.get(i);
            float[] b = waypoints.get(i + 1);
            best = Math.min(best, pointToSegment(px, py, a[0], a[1], b[0], b[1]));
        }
        return best;
    }

    private static float pointToSegment(float px, float py, float ax, float ay, float bx, float by) {
        float dx = bx - ax, dy = by - ay;
        float len2 = dx * dx + dy * dy;
        float t = len2 == 0f ? 0f : ((px - ax) * dx + (py - ay) * dy) / len2;
        if (t < 0f) t = 0f;
        else if (t > 1f) t = 1f;
        float cx = ax + dx * t, cy = ay + dy * t;
        return (float) Math.hypot(px - cx, py - cy);
    }

    // -------------------------------------------------------------- placement

    public boolean isValidPlacement(float x, float y) {
        if (y < topBarH + TOWER_RADIUS || y > height - shopBarH - TOWER_RADIUS) return false;
        if (x < TOWER_RADIUS || x > width - TOWER_RADIUS) return false;
        if (distanceToPath(x, y) < PATH_WIDTH / 2f + TOWER_RADIUS - 4f) return false;
        for (DartLauncher t : towers) {
            if (Math.hypot(t.x - x, t.y - y) < TOWER_RADIUS * 2f) return false;
        }
        return true;
    }

    public DartLauncher towerAt(float x, float y) {
        DartLauncher best = null;
        float bestD = TOWER_RADIUS + 14f;
        for (DartLauncher t : towers) {
            float d = (float) Math.hypot(t.x - x, t.y - y);
            if (d < bestD) {
                bestD = d;
                best = t;
            }
        }
        return best;
    }

    public boolean tryPlaceTower(LauncherType type, float x, float y) {
        if (cash < type.cost) {
            flash("Not enough cash");
            return false;
        }
        if (!isValidPlacement(x, y)) {
            flash("Can't build there");
            return false;
        }
        cash -= type.cost;
        towers.add(new DartLauncher(type, x, y));
        return true;
    }

    public boolean upgradeTower(DartLauncher t) {
        if (t == null || !t.canUpgrade()) {
            flash("Max level");
            return false;
        }
        int c = t.upgradeCost();
        if (cash < c) {
            flash("Not enough cash");
            return false;
        }
        cash -= c;
        t.upgrade();
        return true;
    }

    public void sellTower(DartLauncher t) {
        if (t == null) return;
        cash += t.sellValue();
        towers.remove(t);
    }

    // ------------------------------------------------------------------ waves

    public boolean canStartWave() {
        return state == State.READY && wave < TOTAL_WAVES;
    }

    public void startWave() {
        if (!canStartWave()) return;
        wave++;
        state = State.RUNNING;
        waveActive = true;
        pendingBoss = BossType.forWave(wave);
        bossSpawned = false;
        regularToSpawn = pendingBoss != null ? 6 + wave : 8 + wave * 2;
        spawnInterval = Math.max(0.28f, 0.85f - wave * 0.02f);
        spawnTimer = 0.3f;
        spawnHp = 1 + Math.round(wave * 0.9f);
        spawnSpeed = 70f;
        flash("Wave " + wave + (pendingBoss != null ? " — " + pendingBoss.name + "!" : ""));
    }

    private void endWave() {
        waveActive = false;
        cash += 40 + wave * 12;
        if (wave >= TOTAL_WAVES) {
            state = State.WIN;
            flash("YOU WIN!");
        } else {
            state = State.READY;
            flash("Wave cleared! +$" + (40 + wave * 12));
        }
    }

    private void spawnRegular() {
        int hp = spawnHp;
        if (rng.nextFloat() < Math.min(0.5f, 0.05f + wave * 0.02f)) hp *= 2;
        float speed = spawnSpeed + rng.nextInt(35);
        float radius = 15f + Math.min(16f, hp * 0.7f);
        Balloon b = Balloon.regular(hp, speed, colorForHp(hp), radius);
        balloons.add(b);
    }

    private void spawnBoss(BossType type) {
        Balloon b = Balloon.boss(type, 1f);
        balloons.add(b);
        flash(type.name + " incoming!");
    }

    private int colorForHp(int hp) {
        if (hp <= 1) return 0xFFE53935;       // red
        if (hp <= 3) return 0xFF1E88E5;       // blue
        if (hp <= 6) return 0xFF43A047;       // green
        if (hp <= 10) return 0xFFFDD835;      // yellow
        if (hp <= 16) return 0xFFEC407A;      // pink
        if (hp <= 26) return 0xFF8E24AA;      // purple
        return 0xFF263238;                    // near-black (lead)
    }

    private void spawnSplit(Balloon parent) {
        int childHp = Math.max(3, wave);
        for (int i = 0; i < 4; i++) {
            Balloon c = Balloon.regular(childHp, parent.baseSpeed * 1.25f,
                    colorForHp(childHp), 16f);
            c.dist = Math.max(0f, parent.dist - i * 16f);
            balloons.add(c);
        }
    }

    // ----------------------------------------------------------------- update

    public void update(float dt) {
        if (bannerTimer > 0f) bannerTimer -= dt;

        if (state != State.RUNNING) return;

        // spawning
        if (waveActive) {
            if (regularToSpawn > 0) {
                spawnTimer -= dt;
                if (spawnTimer <= 0f) {
                    spawnRegular();
                    regularToSpawn--;
                    spawnTimer = spawnInterval;
                }
            } else if (pendingBoss != null && !bossSpawned) {
                spawnBoss(pendingBoss);
                bossSpawned = true;
            }
        }

        updateBalloons(dt);
        updateTowers(dt);
        updateDarts(dt);
        removeDeadBalloons();

        if (state == State.RUNNING && waveActive && regularToSpawn == 0
                && (pendingBoss == null || bossSpawned) && balloons.isEmpty()) {
            endWave();
        }
    }

    private void updateBalloons(float dt) {
        Iterator<Balloon> it = balloons.iterator();
        while (it.hasNext()) {
            Balloon b = it.next();
            b.tick(dt);
            b.dist += b.currentSpeed() * dt;
            if (b.dist >= totalLen) {
                lives -= b.leakDamage;
                it.remove();
                if (lives <= 0) {
                    lives = 0;
                    state = State.GAME_OVER;
                    flash("GAME OVER");
                }
                continue;
            }
            positionAt(b.dist, tmp);
            b.x = tmp[0];
            b.y = tmp[1];
        }
    }

    private void updateTowers(float dt) {
        for (DartLauncher t : towers) {
            if (t.cooldownLeft > 0f) t.cooldownLeft -= dt;
            if (t.muzzleFlash > 0f) t.muzzleFlash -= dt;
            if (t.cooldownLeft > 0f) continue;
            Balloon target = firstInRange(t);
            if (target == null) continue;
            fire(t, target);
            t.cooldownLeft = t.fireCooldown();
        }
    }

    private Balloon firstInRange(DartLauncher t) {
        Balloon best = null;
        float bestDist = -1f;
        float range = t.range();
        for (Balloon b : balloons) {
            if (!b.alive) continue;
            float d = (float) Math.hypot(b.x - t.x, b.y - t.y);
            if (d <= range + b.radius && b.dist > bestDist) {
                bestDist = b.dist;
                best = b;
            }
        }
        return best;
    }

    private void fire(DartLauncher t, Balloon target) {
        LauncherType lt = t.type;
        float ang = (float) Math.atan2(target.y - t.y, target.x - t.x);
        t.aimAngle = ang;
        t.muzzleFlash = 0.07f;
        int dmg = t.damage();
        if (lt.darts > 1) {
            for (int i = 0; i < lt.darts; i++) {
                float a = (float) (i * 2 * Math.PI / lt.darts);
                spawnDart(t, a, dmg);
            }
        } else {
            spawnDart(t, ang, dmg);
        }
    }

    private void spawnDart(DartLauncher t, float angle, int dmg) {
        LauncherType lt = t.type;
        float vx = (float) Math.cos(angle) * lt.projectileSpeed;
        float vy = (float) Math.sin(angle) * lt.projectileSpeed;
        Dart d = new Dart(t.x, t.y, vx, vy, dmg, Math.max(1, lt.pierce),
                lt.splashRadius, lt.slowFactor, lt.slowDuration, lt.color);
        darts.add(d);
    }

    private void updateDarts(float dt) {
        Iterator<Dart> it = darts.iterator();
        while (it.hasNext()) {
            Dart d = it.next();
            d.update(dt);
            if (!d.alive || d.x < -60 || d.x > width + 60 || d.y < -60 || d.y > height + 60) {
                it.remove();
                continue;
            }
            for (Balloon b : balloons) {
                if (!b.alive || d.alreadyHit.contains(b)) continue;
                float dd = (float) Math.hypot(b.x - d.x, b.y - d.y);
                if (dd <= b.radius + 5f) {
                    handleHit(d, b);
                    if (!d.alive) break;
                }
            }
            if (!d.alive) it.remove();
        }
    }

    private void handleHit(Dart d, Balloon hitBalloon) {
        if (d.splashRadius > 0f) {
            for (Balloon b : balloons) {
                if (!b.alive) continue;
                float dd = (float) Math.hypot(b.x - d.x, b.y - d.y);
                if (dd <= d.splashRadius + b.radius) {
                    damageBalloon(b, d.damage);
                }
            }
            d.alive = false;
        } else {
            damageBalloon(hitBalloon, d.damage);
            if (d.slowDuration > 0f) hitBalloon.applySlow(d.slowFactor, d.slowDuration);
            d.alreadyHit.add(hitBalloon);
            d.pierceLeft--;
            if (d.pierceLeft <= 0) d.alive = false;
        }
    }

    private void damageBalloon(Balloon b, int dmg) {
        boolean killed = b.hit(dmg);
        if (killed) {
            cash += b.reward;
            if (b.isBoss && b.bossType.special == BossType.Special.SPLIT) {
                spawnSplit(b);
            }
        }
    }

    private void removeDeadBalloons() {
        Iterator<Balloon> it = balloons.iterator();
        while (it.hasNext()) {
            if (!it.next().alive) it.remove();
        }
    }

    private void flash(String msg) {
        banner = msg;
        bannerTimer = 2.2f;
    }

    public void reset() {
        cash = START_CASH;
        lives = START_LIVES;
        wave = 0;
        state = State.READY;
        towers.clear();
        balloons.clear();
        darts.clear();
        waveActive = false;
        regularToSpawn = 0;
        pendingBoss = null;
        bossSpawned = false;
        flash("Tap a launcher, then the field to build");
    }

    // ------------------------------------------------------------- rendering

    /** Draws the world: background, track, towers, balloons and darts. */
    public void draw(Canvas c) {
        c.drawColor(0xFF4CAF50); // grass

        // subtle field stripes
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(0x1AFFFFFF);
        for (float y = topBarH; y < height - shopBarH; y += 56f) {
            c.drawRect(0, y, width, y + 28f, paint);
        }

        // track
        if (pathCache != null) {
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeCap(Paint.Cap.ROUND);
            paint.setStrokeJoin(Paint.Join.ROUND);
            paint.setColor(0xFF5D4037);
            paint.setStrokeWidth(PATH_WIDTH + 10f);
            c.drawPath(pathCache, paint);
            paint.setColor(0xFFD7B98E);
            paint.setStrokeWidth(PATH_WIDTH);
            c.drawPath(pathCache, paint);
        }

        drawTowers(c);
        drawBalloons(c);
        drawDarts(c);
    }

    private void drawTowers(Canvas c) {
        paint.setStyle(Paint.Style.FILL);
        for (DartLauncher t : towers) {
            // base
            paint.setColor(0xFF37474F);
            c.drawCircle(t.x, t.y, TOWER_RADIUS, paint);
            // top
            paint.setColor(t.type.color);
            c.drawCircle(t.x, t.y, TOWER_RADIUS - 5f, paint);
            // barrel
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(7f);
            paint.setStrokeCap(Paint.Cap.ROUND);
            paint.setColor(0xFF263238);
            float bx = t.x + (float) Math.cos(t.aimAngle) * (TOWER_RADIUS + 8f);
            float by = t.y + (float) Math.sin(t.aimAngle) * (TOWER_RADIUS + 8f);
            c.drawLine(t.x, t.y, bx, by, paint);
            paint.setStyle(Paint.Style.FILL);
            if (t.muzzleFlash > 0f) {
                paint.setColor(0xFFFFF59D);
                c.drawCircle(bx, by, 6f, paint);
            }
            // level pips
            paint.setColor(0xFFFFFFFF);
            for (int i = 0; i < t.level; i++) {
                c.drawCircle(t.x - 9f + i * 6f, t.y + TOWER_RADIUS - 4f, 2.4f, paint);
            }
            // short-name label
            paint.setColor(0xFFFFFFFF);
            paint.setTextAlign(Paint.Align.CENTER);
            paint.setTextSize(11f);
            paint.setFakeBoldText(true);
            c.drawText(t.type.shortName, t.x, t.y - TOWER_RADIUS - 4f, paint);
            paint.setFakeBoldText(false);
        }
    }

    private void drawBalloons(Canvas c) {
        paint.setTextAlign(Paint.Align.CENTER);
        for (Balloon b : balloons) {
            paint.setStyle(Paint.Style.FILL);
            // knot
            paint.setColor(darken(b.color));
            c.drawCircle(b.x, b.y + b.radius * 0.92f, b.radius * 0.22f, paint);
            // body
            paint.setColor(b.color);
            c.drawCircle(b.x, b.y, b.radius, paint);
            // highlight
            paint.setColor(0x66FFFFFF);
            c.drawCircle(b.x - b.radius * 0.32f, b.y - b.radius * 0.34f, b.radius * 0.26f, paint);
            // frost ring
            if (b.slowTimer > 0f) {
                paint.setStyle(Paint.Style.STROKE);
                paint.setStrokeWidth(3f);
                paint.setColor(0xFF80DEEA);
                c.drawCircle(b.x, b.y, b.radius + 3f, paint);
                paint.setStyle(Paint.Style.FILL);
            }
            if (b.isBoss) {
                // outline
                paint.setStyle(Paint.Style.STROKE);
                paint.setStrokeWidth(4f);
                paint.setColor(0xFFFFFFFF);
                c.drawCircle(b.x, b.y, b.radius, paint);
                paint.setStyle(Paint.Style.FILL);
                // hp bar
                float w = b.radius * 2f;
                float bx = b.x - b.radius;
                float by = b.y - b.radius - 14f;
                paint.setColor(0xAA000000);
                c.drawRect(bx, by, bx + w, by + 7f, paint);
                paint.setColor(0xFFE53935);
                c.drawRect(bx, by, bx + w * Math.max(0f, (float) b.hp / b.maxHp), by + 7f, paint);
                // name
                paint.setColor(0xFFFFFFFF);
                paint.setTextSize(13f);
                paint.setFakeBoldText(true);
                c.drawText(b.bossType.name, b.x, by - 4f, paint);
                paint.setFakeBoldText(false);
            }
        }
    }

    private void drawDarts(Canvas c) {
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(4f);
        for (Dart d : darts) {
            paint.setColor(d.color);
            float a = d.angle();
            float tx = d.x + (float) Math.cos(a) * 9f;
            float ty = d.y + (float) Math.sin(a) * 9f;
            float bx = d.x - (float) Math.cos(a) * 5f;
            float by = d.y - (float) Math.sin(a) * 5f;
            c.drawLine(bx, by, tx, ty, paint);
        }
        paint.setStyle(Paint.Style.FILL);
    }

    private static int darken(int color) {
        int a = (color >>> 24) & 0xFF;
        int r = (int) (((color >> 16) & 0xFF) * 0.7f);
        int g = (int) (((color >> 8) & 0xFF) * 0.7f);
        int b = (int) ((color & 0xFF) * 0.7f);
        return (a << 24) | (r << 16) | (g << 8) | b;
    }
}
