local Translations = {
    -- Contact menu
    ['menu_ask_shipment'] = 'Ask About Shipment',
    ['menu_ask_shipment_desc'] = 'Ask the contact for a seed shipment lead. Cooldown: %s',
    ['menu_check_loyalty'] = 'Check Loyalty',
    ['menu_check_loyalty_desc'] = 'See where you stand with the contact.',
    ['menu_bribe_contact'] = 'Bribe Contact',
    ['menu_bribe_contact_desc'] = 'Offer some product to build trust.',
    ['menu_cancel_shipment'] = 'Cancel Active Shipment',
    ['menu_cancel_shipment_desc'] = 'Abandon your current shipment lead.',

    -- Contact interactions
    ['contact_unavailable'] = 'The contact doesn\'t want to talk right now.',
    ['tip_unavailable'] = 'Can\'t get a price right now.',
    ['loyalty_unavailable'] = 'Can\'t check loyalty right now.',

    -- Confirm tip
    ['confirm_tip_header'] = 'Shipment Tip',
    ['confirm_tip_content'] = 'The contact wants $%s (%s) for a shipment lead. Pay up?',

    -- Loyalty display
    ['loyalty_header'] = 'Loyalty Status',
    ['loyalty_content'] = 'Level: %s - %s\nSuccessful runs: %s\nFailed runs: %s',
    ['loyalty_runner_smoke_tip'] = 'Yeah, you\'re a real runner. Go check that location on your map — contractor supplies got empty planter boxes and weed work benches.',

    -- Bribe menu
    ['bribe_menu_title'] = 'Bribe Options',
    ['bribe_option_desc'] = 'Offer %sx %s to the contact.',
    ['bribe_success'] = 'The contact appreciates the gesture. Trust increased.',
    ['bribe_failed'] = 'Bribe failed.',
    ['bribe_cooldown'] = 'You\'ve already offered recently. Give it some time.',
    ['bribe_no_items'] = 'You don\'t have enough product to offer.',
    ['bribe_distance'] = 'You\'re not close enough to the contact.',

    -- Shipment
    ['shipment_blip_label'] = 'Shipment Area',
    ['shipment_started'] = 'The contact gave you a lead: "%s". Search the marked zone until you find the stash — it may take several tries.',
    ['no_active_shipment'] = 'You don\'t have an active shipment.',
    ['shipment_too_far'] = 'Nothing here. Move deeper into the marked area.',
    ['searching_shipment'] = 'Searching for shipment...',
    ['search_cancelled'] = 'Search cancelled.',
    ['shipment_search_progress'] = 'You search the area… %d / %d.',
    ['shipment_search_hint'] = 'The stash won\'t show up on the first try — keep searching this zone.',
    ['shipment_completed'] = 'Shipment found! Check your inventory.',
    ['shipment_expired'] = 'Your shipment lead expired. The drop is gone.',
    ['shipment_cancelled'] = 'Shipment lead cancelled.',
    ['already_has_shipment'] = 'You already have an active lead. Handle that first.',

    -- Payment
    ['payment_failed'] = 'You can\'t afford the tip right now.',

    -- Cooldowns
    ['contact_cooldown'] = 'The contact needs some time. Try again in %s.',

    -- Errors
    ['shipment_create_failed'] = 'Couldn\'t get a lead right now. Try again later.',
    ['shipment_complete_failed'] = 'Couldn\'t verify the shipment. Get closer and try again.',
    ['feature_disabled'] = 'This isn\'t available right now.',

    -- Cancel
    ['cancel_shipment_header'] = 'Cancel Shipment',
    ['cancel_shipment_content'] = 'Are you sure you want to abandon this lead? You won\'t get your money back.',

    -- Zones
    ['zone_entered'] = 'You\'re in the drop zone. Press [E] to search.',
    ['zone_exited'] = 'You left the search area.',

    -- Placeable module
    ['placeable_help']            = '[E] Place  •  [Q / →] Rotate  •  [BACKSPACE] Cancel',
    ['placeable_not_placeable']   = 'This item cannot be placed.',
    ['placeable_cancelled']       = 'Placement cancelled.',
    ['placeable_placed']          = 'Object placed.',
    ['placeable_too_far']         = 'You are too far away.',
    ['placeable_invalid_ground']  = 'Could not find a valid ground position.',
    ['placeable_missing_item']    = 'You no longer have this item.',
    ['placeable_picked_up']       = 'Object picked up.',
    ['placeable_not_owner']       = 'You do not own this object.',
    ['placeable_limit_reached']   = 'You have reached the placement limit.',
    ['placeable_too_close']       = 'Too close to another placed object.',
    ['placeable_loaded']          = 'Placeables loaded.',
    ['placeable_in_vehicle']      = 'You cannot place this from a vehicle.',
    ['placeable_in_water']        = 'You cannot place this on water.',
    ['placeable_inventory_full']  = 'Your inventory is full.',
    ['placeable_invalid_model']   = 'Invalid prop model for this item.',
    ['placeable_server_rejected'] = 'Placement was rejected by the server.',

    -- Placeable target labels
    ['target_placeable_pickup'] = 'Pick Up %s',

    -- Planter / growth system
    ['planter_help_planter']     = '[E] Place  •  [Q / →] Rotate  •  [BACKSPACE] Cancel  —  Planter',
    ['planter_help_plant']       = '[WASD] Move  •  [E] Place  •  [Q / →] Rotate  •  [BACKSPACE] Cancel  —  Plant Seed',
    ['planter_placed']           = 'Planter placed.',
    ['planter_picked_up']        = 'Planter picked up.',
    ['planter_has_plants']       = 'You must harvest or remove all plants first.',
    ['planter_soil_added']       = 'Soil added to planter.',
    ['planter_no_soil_bag']      = 'You do not have a soil bag.',
    ['planter_already_filled']   = 'This planter is already filled.',
    ['planter_not_filled']       = 'This planter has no soil yet.',
    ['planter_no_seeds']         = 'You do not have any seeds.',
    ['planter_seed_planted']     = 'Seed planted!',
    ['planter_outside_soil']     = 'Plant placement is outside the soil area.',
    ['planter_too_close']        = 'Too close to another plant.',
    ['planter_max_plants']       = 'This planter is full.',
    ['planter_too_far']          = 'You are too far away.',
    ['planter_in_vehicle']       = 'You cannot do that from a vehicle.',
    ['planter_in_water']         = 'You cannot place this on water.',
    ['planter_not_owner']        = 'You do not own this planter.',
    ['planter_inventory_full']   = 'Your inventory is full.',
    ['planter_harvest_not_ready'] = 'This plant is not ready yet.',
    ['planter_harvest_complete'] = 'Plant harvested.',
    ['planter_invalid_strain']   = 'Invalid seed.',
    ['planter_loaded']           = 'Planters loaded.',

    -- Planter target labels
    ['target_planter_addsoil']   = 'Add Soil',
    ['target_planter_plant']     = 'Plant Seed',
    ['target_planter_inspect']   = 'Inspect Planter',
    ['target_planter_pickup']    = 'Pick Up Planter',
    ['target_plant_inspect']     = 'Inspect Plant',
    ['target_plant_harvest']     = 'Harvest Plant',

    -- Rolling Station NUI (craft joints)
    ['rolling_menu_title']       = 'Rolling Station',
    ['rolling_success_fmt']       = 'Packed a joint — spent %d buds and %d rolling papers.',
    ['rolling_err_disabled']     = 'Rolling station is disabled.',
    ['rolling_err_no_buds']       = 'You don\'t have enough bud for that roll.',
    ['rolling_err_no_papers']     = 'You need rolling papers.',
    ['rolling_open_need_papers']  = 'Add rolling papers to your inventory to pick a strain.',
    ['rolling_blocked_need_papers'] = 'Need rolling papers in your inventory.',
    ['rolling_blocked_need_buds'] = 'You need %d buds for this strain (you have %d).',
    ['rolling_err_config']       = 'Rolling station setup is incomplete (check server logs).',
    ['rolling_err_generic']       = 'You can\'t do that right now.',
    ['rolling_err_quality']      = 'That roll wasn\'t good enough — try again.',
    ['rolling_err_carry']        = 'You can\'t carry the joint.',
    ['rolling_err_strain']       = 'Invalid strain selection.',
}

if GetConvar then
    Locale = Locale or function(str, ...)
        local text = Translations[str]
        if not text then return str end
        if select('#', ...) > 0 then
            return text:format(...)
        end
        return text
    end
end
