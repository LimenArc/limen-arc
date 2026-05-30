package com.limenarc.balloonpop.model;

/** A placed dart launcher (tower) with its own upgrade level and cooldown. */
public class DartLauncher {
    public final LauncherType type;
    public final float x, y;
    public int level = 1;           // 1..MAX_LEVEL
    public int invested;            // total cash spent (for sell value)
    public float cooldownLeft = 0f;
    public float aimAngle = -1.5708f; // for drawing the barrel
    public float muzzleFlash = 0f;    // brief flash timer after firing

    public static final int MAX_LEVEL = 4;

    public DartLauncher(LauncherType type, float x, float y) {
        this.type = type;
        this.x = x;
        this.y = y;
        this.invested = type.cost;
    }

    public float range() {
        return type.range * (1f + 0.12f * (level - 1));
    }

    public int damage() {
        return type.damage + (level - 1);
    }

    public float fireCooldown() {
        return type.fireCooldown * (float) Math.pow(0.85, level - 1);
    }

    public boolean canUpgrade() {
        return level < MAX_LEVEL;
    }

    public int upgradeCost() {
        return Math.round(type.cost * 0.75f * level);
    }

    public int sellValue() {
        return Math.round(invested * 0.7f);
    }

    public void upgrade() {
        invested += upgradeCost();
        level++;
    }
}
