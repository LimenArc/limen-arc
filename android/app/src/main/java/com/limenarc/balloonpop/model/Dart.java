package com.limenarc.balloonpop.model;

import java.util.HashSet;
import java.util.Set;

/** A projectile launched by a {@link DartLauncher}. */
public class Dart {
    public float x, y;
    public float vx, vy;
    public int damage;
    public int pierceLeft;
    public float splashRadius;
    public float slowFactor;
    public float slowDuration;
    public float life;          // seconds before it expires
    public int color;
    public final Set<Balloon> alreadyHit = new HashSet<>();

    public boolean alive = true;

    public Dart(float x, float y, float vx, float vy, int damage, int pierce,
                float splashRadius, float slowFactor, float slowDuration, int color) {
        this.x = x;
        this.y = y;
        this.vx = vx;
        this.vy = vy;
        this.damage = damage;
        this.pierceLeft = pierce;
        this.splashRadius = splashRadius;
        this.slowFactor = slowFactor;
        this.slowDuration = slowDuration;
        this.life = 2.5f;
        this.color = color;
    }

    public void update(float dt) {
        x += vx * dt;
        y += vy * dt;
        life -= dt;
        if (life <= 0f) alive = false;
    }

    public float angle() {
        return (float) Math.atan2(vy, vx);
    }
}
