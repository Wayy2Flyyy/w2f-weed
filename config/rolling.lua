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

    --- 0–100; below this rolls do not consume items / do not reward (still allowed to retry UI).
    MinimumQuality = 0,

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
