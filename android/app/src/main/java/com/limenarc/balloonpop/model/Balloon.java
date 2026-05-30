package com.limenarc.balloonpop.model;

/**
 * A water balloon travelling along the track. Regular balloons are created with
 * {@link #regular}; bosses with {@link #boss}. Position is derived from {@link
 * #dist} (distance travelled along the path) by the Game each frame.
 */
public class Balloon {
    public float dist;          // distance travelled along the path (px)
    public float x, y;          // cached world position, updated each frame
    public float baseSpeed;     // px / s
    public int hp;
    public int maxHp;
    public float radius;
    public int color;
    public int reward;          // cash granted when fully popped
    public int leakDamage;      // lives lost if it reaches the exit

    public boolean isBoss;
    public BossType bossType;
    public int armor;
    public float regenPerSec;
    private float regenCarry;

    // Frost effect
    public float slowTimer;
    public float slowFactor = 1f;

    public boolean alive = true;
    public boolean leaked = false;

    public static Balloon regular(int hp, float speed, int color, float radius) {
        Balloon b = new Balloon();
        b.hp = hp;
        b.maxHp = hp;
        b.baseSpeed = speed;
        b.color = color;
        b.radius = radius;
        b.reward = hp + 2;
        b.leakDamage = Math.max(1, hp / 2);
        return b;
    }

    public static Balloon boss(BossType type, float hpScale) {
        Balloon b = new Balloon();
        b.isBoss = true;
        b.bossType = type;
        b.hp = Math.round(type.hp * hpScale);
        b.maxHp = b.hp;
        b.baseSpeed = type.speed;
        b.color = type.color;
        b.radius = type.radius;
        b.reward = type.reward;
        b.leakDamage = 40;
        b.armor = type.armor;
        b.regenPerSec = type.regenPerSec;
        return b;
    }

    /** Current effective movement speed, accounting for any active frost. */
    public float currentSpeed() {
        return slowTimer > 0f ? baseSpeed * slowFactor : baseSpeed;
    }

    public void applySlow(float factor, float duration) {
        // Strongest active slow wins; refresh its timer.
        if (factor < slowFactor || slowTimer <= 0f) {
            slowFactor = factor;
        }
        slowTimer = Math.max(slowTimer, duration);
    }

    /** Advances timers (frost, regen). Movement is handled by the Game. */
    public void tick(float dt) {
        if (slowTimer > 0f) {
            slowTimer -= dt;
            if (slowTimer <= 0f) slowFactor = 1f;
        }
        if (regenPerSec > 0f && hp < maxHp && alive) {
            regenCarry += regenPerSec * dt;
            int whole = (int) regenCarry;
            if (whole > 0) {
                hp = Math.min(maxHp, hp + whole);
                regenCarry -= whole;
            }
        }
    }

    /** Applies a hit, returns true if this pop killed the balloon. */
    public boolean hit(int damage) {
        int effective = Math.max(1, damage - armor);
        hp -= effective;
        if (hp <= 0) {
            alive = false;
            return true;
        }
        return false;
    }
}
