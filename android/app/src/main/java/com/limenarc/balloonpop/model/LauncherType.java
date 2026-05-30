package com.limenarc.balloonpop.model;

/**
 * The 7 unique dart launchers. Each constant carries its base stats; per-tower
 * upgrades scale these values at runtime (see {@link DartLauncher}).
 */
public enum LauncherType {
    //            display          short   cost  range   cd(s)  dmg  spd  pierce splash slowF slowDur darts  color        description
    PIN_SLINGER  ("Pin Slinger",   "PIN",   100,  150f,  0.80f,  1,  520f,  1,    0f,   0f,   0f,     1,  0xFF8D6E63L, "Cheap, reliable single dart. Your bread and butter."),
    SPIKE_BURST  ("Spike Burst",   "SPK",   280,   98f,  1.05f,  1,  470f,  1,    0f,   0f,   0f,     8,  0xFFAD1457L, "Fires darts in 8 directions. Owns chokepoints."),
    LONG_SHOT    ("Long Shot",     "SNP",   360, 9000f,  1.55f,  5, 1200f,  1,    0f,   0f,   0f,     1,  0xFF2E7D32L, "Sniper. Hits anywhere on screen, big single hit."),
    BOUNCER      ("Bouncer",       "BNC",   320,  168f,  1.00f,  2,  500f,  4,    0f,   0f,   0f,     1,  0xFFF57F17L, "Boomerang dart pierces up to 4 balloons."),
    FROST_POPPER ("Frost Popper",  "FRZ",   340,  122f,  1.00f,  1,  520f,  2,    0f,  0.45f, 1.6f,   1,  0xFF00ACC1L, "Chills balloons, slowing them to a crawl."),
    SPLASH_CANNON("Splash Cannon", "BMB",   480,  132f,  1.70f,  3,  360f,  1,   64f,   0f,   0f,     1,  0xFF455A64L, "Explodes on impact, soaking a whole cluster."),
    STORM_TOWER  ("Storm Tower",   "STM",  1300,  178f,  0.15f,  2,  720f,  2,    0f,   0f,   0f,     1,  0xFF4527A0L, "Elite rapid-fire turret. Pricey but devastating.");

    public final String displayName;
    public final String shortName;
    public final int cost;
    public final float range;
    public final float fireCooldown;   // seconds between shots
    public final int damage;
    public final float projectileSpeed; // px / s
    public final int pierce;            // balloons a single dart can pass through
    public final float splashRadius;    // 0 = no splash
    public final float slowFactor;      // 0 = no slow; e.g. 0.45 => target moves at 45%
    public final float slowDuration;    // seconds
    public final int darts;             // darts launched per shot (radial when > 1)
    public final int color;
    public final String description;

    LauncherType(String displayName, String shortName, int cost, float range, float fireCooldown,
                 int damage, float projectileSpeed, int pierce, float splashRadius,
                 float slowFactor, float slowDuration, int darts, long color, String description) {
        this.displayName = displayName;
        this.shortName = shortName;
        this.cost = cost;
        this.range = range;
        this.fireCooldown = fireCooldown;
        this.damage = damage;
        this.projectileSpeed = projectileSpeed;
        this.pierce = pierce;
        this.splashRadius = splashRadius;
        this.slowFactor = slowFactor;
        this.slowDuration = slowDuration;
        this.darts = darts;
        this.color = (int) color;
        this.description = description;
    }
}
