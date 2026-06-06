Config = Config or {}

--- Rolling Station NUI (grind + roll phases). Consumes buds + rolling papers → strain joint items.
Config.RollingMinigame = {
    Enabled = true,

    --- USE this item → opens Rolling Station (`client.event = 'w2f-weed:client:startRollingMinigameFromTray'` in items.lua).
    --- Tray is kept; buds + papers are consumed on successful rolls.
    OpenItemKey = 'rolling_tray',

    --- Bud stacks removed when you collect a rolled joint (`BudsPerJoint` each roll).
    --- ox_inventory rolling paper item consumed per joint (`PapersPerJoint`).
    BudsPerJoint = 3,
    PapersPerJoint = 1,

    --- ox_inventory item removed on successful craft; set RequirePaper false to disable.
    PaperItem = 'rolling_papers',
    RequirePaper = true,

    --- 0–100; below this a roll does not consume items / does not reward (player
    --- can simply retry). The NUI's worst roll is ~55, so a low value here is a
    --- safety floor; the skill payoff comes from BonusJoint below.
    MinimumQuality = 20,

    --- Reward minigame skill: a high-quality roll has a chance to yield a second
    --- joint from the same buds/papers. Set Chance = 0 to disable.
    BonusJoint = {
        Threshold = 85, -- quality at/above this is eligible (Excellent+)
        Chance = 35,    -- percent chance to receive the bonus joint
    },

    --- `/weed_roll` opens practice mode with every strain selectable (no items).
    DebugCommand = true,

    --- Strain catalogue id → ox_inventory joint item (must exist in inventory data).
    JointItems = {
        purple_runtz = 'joint_purple_runtz',
        exotic = 'joint_exotic_weed',
        hybrid = 'joint_hybrid',
        skunk = 'joint_skunk',
        purple_palm_tree_delight = 'joint_purple_palm_tree_delight',
    },
}
