package com.limenarc.balloonpop.model;

/**
 * The 5 water-balloon bosses. They appear on waves 5, 10, 15, 20 and 25
 * (see {@link com.limenarc.balloonpop.Game}). The Leviathan on wave 25 is the
 * final boss; popping it wins the run.
 */
public enum BossType {
    //          name          wave  hp     speed radius reward armor regen  special      color
    SPLASHER   ("Splasher",     5,   650,   58f,  46f,   260,   0,    0f,   Special.NONE,  0xFF1565C0L),
    BUBBLER    ("Bubbler",     10,   980,   62f,  48f,   340,   0,    0f,   Special.SPLIT, 0xFF6A1B9AL),
    TSUNAMI    ("Tsunami",     15,  1500,  100f,  44f,   460,   0,   14f,   Special.REGEN, 0xFF00838FL),
    HAILSTORM  ("Hailstorm",   20,  2400,   62f,  52f,   620,   2,    0f,   Special.ARMOR, 0xFF37474FL),
    LEVIATHAN  ("Leviathan",   25,  5600,   50f,  66f,  1600,   1,   10f,   Special.FINAL, 0xFFB71C1CL);

    public enum Special { NONE, SPLIT, REGEN, ARMOR, FINAL }

    public final String name;
    public final int wave;
    public final int hp;
    public final float speed;
    public final float radius;
    public final int reward;
    public final int armor;
    public final float regenPerSec;
    public final Special special;
    public final int color;

    BossType(String name, int wave, int hp, float speed, float radius, int reward,
             int armor, float regenPerSec, Special special, long color) {
        this.name = name;
        this.wave = wave;
        this.hp = hp;
        this.speed = speed;
        this.radius = radius;
        this.reward = reward;
        this.armor = armor;
        this.regenPerSec = regenPerSec;
        this.special = special;
        this.color = (int) color;
    }

    /** Returns the boss scheduled for the given wave, or null if none. */
    public static BossType forWave(int wave) {
        for (BossType b : values()) {
            if (b.wave == wave) return b;
        }
        return null;
    }
}
