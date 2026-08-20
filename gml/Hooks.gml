//TODO: Add archipelago icon :D

#macro AP_RANDO_DEBUG_MSG_KEY "mods/ap_rando/notifications/debug_msg"
#macro AP_RANDO_ITEM_KEY "mods/ap_rando/notifications/item_received"
#macro AP_RANDO_MODIFY_GOLD_KEY "mods/ap_rando/notifications/modify_gold"
#macro AP_RANDO_MAIL_KEY "mods/ap_rando/letters/"
#macro AP_RANDO_DEFAULT_BUTTON "DEL"
#macro AP_RANDO_NAMESPACE "Archipelago Randomizer"
#macro AP_RANDO_VERSION "0.0.1-alpha"
#macro AP_RANDO_CONNECTED_KEY "mods/ap_rando/notifications/connected"
#macro AP_RANDO_DISCONNECTED_KEY "mods/ap_rando/notifications/disconnected"
#macro AP_RANDO_MOD_PATH string(CONFIG_DIRECTORY) + "/mod_data/ap_rando/"


function __ap_rando_runtime() {
    if (global[$ "__ap_rando"] == undefined) {
        global.__ap_rando = {
            config:             undefined,
            config_loaded:      false,
            hotkey_registered:  false,

            session_started:    false,
            ap_connected:       false,
            seed:               undefined,
            damagelink:         false,
            traplink:           false,
            deathlink:          false,

            latest_sender:      undefined,
            latest_item:        undefined,

            renown_lvl:         0, 
            renown_rank:        0,
            
            registered_hooks:   undefined,
            frame_count:        0,
            
            farming_lvl:        1,
            fishing_lvl:        1,
            ranching_lvl:       1,
            mining_lvl:         1,
            combat_lvl:         1,
            archaeology_lvl:    1,
            cooking_lvl:        1,
            smithing_lvl:       1,
            crafting_lvl:       1
        };
    }
    return global.__ap_rando;
}

function ap_rando_ready() {
    if (!__ap_rando_runtime()) return;
    
    var _rt = __ap_rando_runtime();
    return instance_exists(obj_ari) && _rt.ap_connected;
}

function ap_rando_on_clock_tick(_ctx) { 
    // _ctx contains Clock struct whose update() is running
    //  read clock state from it directly (e.g. _ctx.time_stopped)    

    // cheapest check to get out early
    if (!__ap_rando_runtime()) return;

    var _rt = __ap_rando_runtime();

    _rt.frame_count ++;

    if (_rt.frame_count % (FPS*3) == 0) {
        //check all conditions for connection

        if (!ap_rando_ready()) {
            // either ari doesnt exist or the runtime doesnt think we're connected
            // try connecting
            if(!ap_rando_check_connection()){
                ap_rando_log_info("Could not connect, trying again in 3 seconds.")
                return;
            }
            
            ap_rando_log_info("AP client connected, seed: " + string(_rt.seed));
            create_notification(AP_RANDO_CONNECTED_KEY);
        }

        if (!ap_rando_check_connection()) {
            // runtime thinks we're connected, but status.json disagrees (meaning the client has disconnected)
            ap_rando_log_info("AP client disconnected");
            create_notification(AP_RANDO_DISCONNECTED_KEY);
            _rt.ap_connected = false;
            return;
        }
    }

    //now that we're sure we're connected, check items.json every second to see if we have anything new
    if (_rt.frame_count % FPS == 0 && ap_rando_check_connection() && ap_rando_ready()) ap_rando_check_items(AP_RANDO_MOD_PATH +"seeds/" + _rt.seed + "/items.json");
}

function ap_rando_room_transition_post(_ctx) {
    // relevant _ctx is to_room
    if (!__ap_rando_runtime()) return;
    var _rt = __ap_rando_runtime();

    // we don't need to run the rest again
    if (_rt.session_started) return;
    if(location_id_to_string(gm_room_to_location_id(_ctx.to_room)) == "player_home") {
        _rt.session_started = true;
        ap_rando_log_info("Starting a new save for AP - checking to connect...")
        if(!ap_rando_check_connection()) ap_rando_log_info("AP not connected for new save.");
    }
}

function ap_rando_save_game_loaded(_ctx) {
    // _ctx contains { save_path }
    
    if (!__ap_rando_runtime()) return;
    var _rt = __ap_rando_runtime();

    _rt.session_started = true;
    ap_rando_log_info("Successfully loaded game for AP - checking to connect...");

    if(!ap_rando_check_connection()) ap_rando_log_info("AP not connected for loaded save?.")
}

// dynamically replaces text
function ap_rando_local_get_filter(_value, _ctx) {
    // _value is resolved text, _ctx is lookup key
    switch(_ctx) {
        case AP_RANDO_DEBUG_MSG_KEY:
            // debug
            if(local_language() == "eng") return "Hello world!";
            break;
        case AP_RANDO_ITEM_KEY:
            // notif on receiving items:
            if (local_language() == "eng") {
                var ap_sender = "viivianite"
                var item = "an item."
                return (ap_sender + _value + item);
            }
            break;
        case AP_RANDO_MODIFY_GOLD_KEY:
            if (local_language() == "eng") {
                var ap_sender = "viivianite";
                return ap_sender + _value;
            }
            break;

        default:
            // returning undefined keeps game value
            return undefined;
    }
}

function ap_rando_on_donate_item(_ctx) {
    // _ctx is { item_id }
    ap_rando_log_info("donated "+ item_id_to_string(_ctx.item_id) + " to museum, sending check");
}

function ap_rando_player_died(_ctx) {
    // _ctx is { self }
    ap_rando_log_info("player died");
    
}

function ap_rando_pass_out(_ctx) {
    // _ctx is { faint }
    ap_rando_log_info("player passed out at eod");
    
}

function ap_rando_quest_complete(_ctx) {
    // _ctx is { ActiveQuest as quest }
    ap_rando_log_info("completed quest: " + string(_ctx.quest.quest_name));
    
}

function ap_rando_level_gained(_ctx) {
    // _ctx is { level }
    
    // need to access runtime var, ensure it exists
    if (!__ap_rando_runtime()) return;

    // does ari exist?
    if (!ap_rando_ready()) return;

    var _rt = __ap_rando_runtime();
    if (_rt.renown_lvl < _ctx.level) {
        _rt.renown_lvl = _ctx.level;
        ap_rando_log_info("hit new renown level: " + string(_ctx.level));
        
    }
}

function ap_rando_renown_rank_gained(_ctx) {
    // _ctx is { rank } TODO refine seam
    // need to access runtime var, ensure it exists
    if (!__ap_rando_runtime()) return;

    // does ari exist?
    if (!ap_rando_ready()) return;

    var _rt = __ap_rando_runtime();
    if (_rt.renown_rank < _ctx.rank) {
        _rt.renown_rank = _ctx.rank;
        ap_rando_log_info("hit new renown rank: " + string(_ctx.rank));
        
    }
}

function ap_rando_dungeon_floor_enter(_ctx) {
    // relevant _ctx is { floor }, with index start @ 0
    ap_rando_log_info("current mines floor: " + string(_ctx.floor+1));
    
}

function ap_rando_skill_leveled(_ctx) {
    // _ctx is { skill (array pos), level }
    // skill pos references that found in "gml/scripts/UI/Anchor/Menus/PlayerMenu.gml
    
    // need to access runtime var, ensure it exists
    if (!__ap_rando_runtime()) return;

    // does ari exist?
    if (!ap_rando_ready()) return;

    var _rt = __ap_rando_runtime();
    
    // all skill levels start at 2, we adjust for that
    var skill_lvl = _ctx.level - 1 ;
    
    // figure out which skill is being accessed - if its not the same as our information, send that check
    switch (_ctx.skill) {
        case Skill.Farming:
            if (_rt.farming_lvl < skill_lvl) {
                _rt.farming_lvl = skill_lvl;
                ap_rando_log_info("new skill level: farming level " + string(skill_lvl));
            }
            break;
        case Skill.Fishing:
            if (_rt.fishing_lvl < skill_lvl) {
                _rt.fishing_lvl = skill_lvl;
                ap_rando_log_info("new skill level: fishing level " + string(skill_lvl));
            }
            break;
        case Skill.Ranching:
            if (_rt.ranching_lvl < skill_lvl) {
                _rt.ranching_lvl = skill_lvl;
                ap_rando_log_info("new skill level: ranching level " + string(skill_lvl));
            }
            break;
        case Skill.Cooking:
            if (_rt.cooking_lvl < skill_lvl) {
                _rt.cooking_lvl = skill_lvl;
                ap_rando_log_info("new skill level: cooking level " + string(skill_lvl));
            }
            break;
        case Skill.Mining:
            if (_rt.mining_lvl < skill_lvl) {
                _rt.mining_lvl = skill_lvl;
                ap_rando_log_info("new skill level: mining level " + string(skill_lvl));
            }
            break;
        case Skill.Combat:
            if (_rt.combat_lvl < skill_lvl) {
                _rt.combat_lvl = skill_lvl;
                ap_rando_log_info("new skill level: combat level " + string(skill_lvl));
            }
            break;
        case Skill.Archaeology:
            if (_rt.archaeology_lvl < skill_lvl) {
                _rt.archaeology_lvl = skill_lvl;
                ap_rando_log_info("new skill level: archaeology level " + string(skill_lvl));
            }
            break;
        case Skill.Blacksmithing:
            if (_rt.smithing_lvl < skill_lvl) {
                _rt.smithing_lvl = skill_lvl;
                ap_rando_log_info("new skill level: blacksmithing level " + string(skill_lvl));
            }
            break;
        case Skill.Woodcrafting:
            if (_rt.crafting_lvl < skill_lvl) {
                _rt.crafting_lvl = skill_lvl;
                ap_rando_log_info("new skill level: woodcrafting level " + string(skill_lvl));
            }
            break;
        default:
            break;
    }
}

function ap_rando_acquire_perk(_ctx) {
    // _ctx is perk obj
    ap_rando_log_info("acquired perk: " + perk_to_string(_ctx.perk));
    create_notification(AP_RANDO_ITEM_KEY);
}

function ap_rando_tutorial_guard(_ctx) {
    // _ctx is tutorial obj
    
    if (!__ap_rando_runtime()) return undefined;
    else {
        ap_rando_log_info("tutorial blocked: " + string(_ctx.tutorial));
        return false; //vetos tutorial
    }
    return undefined; //allow tutorial to play
}

function ap_rando_register_callbacks() {
    var _rt = __ap_rando_runtime();
    if (_rt.registered_hooks != undefined) return _rt.registered_hooks;

    // EVENT hook registration
    mmapi_on("save.game_loaded", ap_rando_save_game_loaded);
    mmapi_on("game.room_transition_post", ap_rando_room_transition_post);
    mmapi_on("game.clock_tick", ap_rando_on_clock_tick);
    mmapi_on("museum.donate_item", ap_rando_on_donate_item);
    mmapi_on("player.died", ap_rando_player_died);
    mmapi_on("player.pass_out", ap_rando_pass_out);
    mmapi_on("quest.complete", ap_rando_quest_complete);
    mmapi_on("renown.level_gained", ap_rando_level_gained);
    mmapi_on("renown.rank_gained", ap_rando_renown_rank_gained);
    mmapi_on("dungeon.floor_enter", ap_rando_dungeon_floor_enter);
    mmapi_on("player.skill_leveled", ap_rando_skill_leveled);
    mmapi_on("player.acquire_perk", ap_rando_acquire_perk);
    
    // FILTER registration
    mmapi_filter("local.get", ap_rando_local_get_filter);

    // GUARD registration
    mmapi_guard("ui.spawn_tutorial_guard", ap_rando_tutorial_guard);

    _rt.registered_hooks = ["save.game_loaded", "local.get"]
}

function ap_rando_log_info(msg) {
    mmapi_log_info("ap_rando", msg);
    mmapi_log_flush("ap_rando");
}

mmapi_mod_declare("ap_rando", AP_RANDO_VERSION);
ap_rando_log_info(AP_RANDO_NAMESPACE + " " + AP_RANDO_VERSION + " initiating.")
ap_rando_register_callbacks();