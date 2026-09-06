#macro TOOL_AMT 4
#macro RING_AMT 3
#macro POUCH_AMT 1
#macro COMBAT_AMT 5
#macro FARM_BLDG_AMT 2
#macro GREENHOUSE_AMT 1
#macro KITCHEN_AMT 2

function ap_rando_check_items(json_path) {
    var _rt = __ap_rando_runtime();

    // read items.json as pending_items struct
    // e.g. { "4000": 1, "2500": 1 }
    var pending_items = try_read_json_file(json_path, undefined, false);
    if (!pending_items) {
        ap_rando_log_info("Couldn't access items.json");
        return;
    }

    // get all ap_item_ids as array
    // e.g. ["4000", "2500"]
    var pending_ap_ids = struct_get_names(pending_items);

    // for all the ids in pending_ap_ids:
    for (var i = 0; i < array_length(pending_ap_ids); i += 1) {
        // ensure the id exists in item_reference struct by getting its ap_local_id
        var ap_local_id = struct_get(global.item_reference, "_" + string(pending_ap_ids[i]))
        if (!ap_local_id) {
            // note that the ap_local_id doesn't exist in item_reference, then exit
            ap_rando_log_info("Couldn't find ap_id " + pending_ap_ids[i] + " in item_reference.");
            return;
        }

        // get the ap_item_amt of the ap_id
        var ap_item_amt = struct_get(pending_items, pending_ap_ids[i]);

        // check if item_inventory/inventory.json exists
        var item_inventory = try_read_json_file(AP_RANDO_MOD_PATH + "seeds/"+ _rt.seed + "/inventory.json", undefined, false);
        if (!item_inventory) {
            // this means that we have nothing in inventory.json; therefore, send the item in full
            ap_rando_send_item(ap_local_id, ap_item_amt);
        } else {
            // since inventory.json exists, we need to get the item_inventory ids as an array
            // e.g. ("season_spring", "prog_axe")
            var inv_local_ids = struct_get_names(item_inventory);
            
            // iterate over item_inventory to see if ap_local_id exists in inv_local_ids
            var in_inv_local_ids = false;
            for (var j = 0; j < array_length(inv_local_ids); j += 1) {
                if(string_pos(ap_local_id, inv_local_ids[j]) == 1) {
                    // if the ap_local_id exists in inv_local_id[j], check if the amounts are NOT equal
                    in_inv_local_ids = true;
                    if (struct_get(item_inventory, inv_local_ids[j]) < ap_item_amt) {
                        // find the difference between the item_inventory, then send that amount
                        var pending_item_amt = ap_item_amt - struct_get(item_inventory, inv_local_ids[j]);
                        ap_rando_send_item(ap_local_id, pending_item_amt);
                    }
                }
            }

            // if ap_local_id never existed in inv_local_id, send the full amount
            if (!in_inv_local_ids) {
                ap_rando_send_item(ap_local_id, ap_item_amt);
            }
        }

    }
    ap_rando_log_info(string(ARI.inbox.contents));
    ap_rando_log_info(string(LETTERS));
    ap_rando_update_inventory(_rt.inventory);
}

function ap_rando_send_item(item, amt){
    _rt = __ap_rando_runtime();

    //placeholder - eventually, pass in a sender string var that will replace archipelago
    _rt.latest_sender = "Archipelago";
    
    ap_rando_log_info("attempting to send " + string(amt) + " of " + item);

    if (string_starts_with(item, "season")) {
        // TODO: implement season logic
        ap_rando_log_info("SEASON");
    }

    else if (string_starts_with(item, "perk")) {
        // perk
        var perk_local = string_trim(item, ["perk_"]);
        ARI.acquire_perk(string_to_perk(perk_local));
        ap_rando_log_info("PERK: " + perk_local);
        _rt.latest_item = local_get("perks/" + perk_local + "/name")
        create_notification(AP_RANDO_PERK_KEY);
    }
    
    else if (string_starts_with(item, "spell")) {
        // spell
        var spell_local = string_trim(item, ["spell_"]);
        ARI.learn_spell(string_to_spell(spell_local));
        ap_rando_log_info("SPELL: " + spell_local);
        _rt.latest_item = local_get("spells/" + spell_local + "/name")
        create_notification(AP_RANDO_SPELL_KEY);
    }

    else if (item == "tesserae") {
        ap_rando_log_info("TESSERAE");
        // tesserae
        ARI.modify_gold(500 * amt);
        create_notification(AP_RANDO_MODIFY_GOLD_KEY);
    }

    else if (item == "renown_increase") {
        ap_rando_log_info("RENOWN");
        // renown
        ARI.modify_renown(60 * amt);
        create_notification(AP_RANDO_RENOWN_KEY);
    }

    else if (item == "horse_statue") {
        ap_rando_log_info("HORSE STATUE");
        fulfill_requirement(string_to_requirement("repaired_horse_statue"), true);
        create_notification(AP_RANDO_HORSE_KEY);
    }
    
    else if (string_starts_with(item, "quest")) {
        // quest
        var quest_local = string_trim(item, ["quest_"]);
        ap_rando_log_info("QUEST: " + quest_local);
        ARI.inbox.push_mail(quest_local);
    }

    else if (string_starts_with(item, "prog")) {
        // buildings, tools, and armor all have progression logic - pass it into its own fn        
        ap_rando_send_prog_item(item, amt);
    }

    else {
        ap_rando_log_info("FILLER: " + item + "("+ string(amt) +")");
        // farm items, seeds, resources, and consumables all have item_id match letters.toml key
        for (var i = 0; i < amt; i++) {
            ARI.inbox.push_mail(item);
        }
    }
    //check if it doesnt exist in runtime inventory - if no, set to 1, if yes, update amt
    if (!struct_exists(_rt.inventory, item) && struct_get(_rt.inventory,item) != 0) {
        struct_set(_rt.inventory, item, amt);
    }
    else struct_set(_rt.inventory, item, (struct_get(_rt.inventory,item) + amt));
}

function ap_rando_send_prog_item(item, amt) {
    ap_rando_log_info("PROGRESSIVE LOGIC RUNNING -------");

    var _rt = __ap_rando_runtime();
    // check *which* prog item we're working with
    var item_type = string_trim(item, ["prog_"]);
    var tools = ["axe", "hoe", "net", "watering_can", "pick_axe", "fishing_rod", "shovel"];
    var combat = ["sword", "helmet", "armor", "legplates", "greaves"];
    var total_item_amt;
    var ind_start = 0;
    var quality_types = ["copper", "iron", "silver", "gold", "mistril", "dragonsworn"];

    if (array_get_index(tools, item_type) >= 0) {
        total_item_amt = TOOL_AMT;

        //check if the item exists in _rt.inv - if true, figure out which ind to start from
        if (struct_exists(_rt.inventory, item)) ind_start = struct_get(_rt.inventory, item);
    }
    else if (array_get_index(combat, item_type) >= 0) {
        total_item_amt = COMBAT_AMT;
        
        //check if the item exists in _rt.inv - if true, figure out which ind to start from
        if (struct_exists(_rt.inventory, item)) ind_start = struct_get(_rt.inventory, item);
    }
    
    switch item_type {
        // for tools + combat, we did the legwork of figuring out where to start from in the arr
        case "axe":
            for (var i = ind_start; i < ind_start + amt; i += 1) {
                ap_rando_log_info("AXE: " + item_type + "_" + quality_types[i]);
                ARI.inbox.push_mail(item_type + "_" + quality_types[i]);
                _rt.latest_item = "a Progressive Axe";
                create_notification(AP_RANDO_ITEM_KEY);
            }
            break;
        case "hoe":
            for (var i = ind_start; i < ind_start + amt; i += 1) {
                ap_rando_log_info("HOE: " + item_type + "_" + quality_types[i]);
                ARI.inbox.push_mail(item_type + "_" + quality_types[i]);
                _rt.latest_item = "a Progressive Hoe";
                create_notification(AP_RANDO_ITEM_KEY);
            }
            break;
        case "net":
            for (var i = ind_start; i < ind_start + amt; i += 1) {
                ap_rando_log_info("NET: " + item_type + "_" + quality_types[i]);
                ARI.inbox.push_mail(item_type + "_" + quality_types[i]);
                _rt.latest_item = "a Progressive Net";
                create_notification(AP_RANDO_ITEM_KEY);
            }
            break;
        case "watering_can":
            for (var i = ind_start; i < ind_start + amt; i += 1) {
                ap_rando_log_info("CAN: " + item_type + "_" + quality_types[i]);
                ARI.inbox.push_mail(item_type + "_" + quality_types[i]);
                _rt.latest_item = "a Progressive Watering Can";
                create_notification(AP_RANDO_ITEM_KEY);
            }
            break;
        case "pick_axe":
            for (var i = ind_start; i < ind_start + amt; i += 1) {
                ap_rando_log_info("PICKAXE: " + item_type + "_" + quality_types[i]);
                ARI.inbox.push_mail(item_type + "_" + quality_types[i]);
                _rt.latest_item = "a Progressive Pickaxe";
                create_notification(AP_RANDO_ITEM_KEY);
            }
            break;
        case "fishing_rod":
            for (var i = ind_start; i < ind_start + amt; i += 1) {
                ap_rando_log_info("ROD: " + item_type + "_" + quality_types[i]);
                ARI.inbox.push_mail(item_type + "_" + quality_types[i]);
                _rt.latest_item = "a Progressive Fishing Rod";
                create_notification(AP_RANDO_ITEM_KEY);
            }
            break;
        case "shovel":
            for (var i = ind_start; i < ind_start + amt; i += 1) {
                ap_rando_log_info("SHOVEL: " + item_type + "_" + quality_types[i]);
                ARI.inbox.push_mail(item_type + "_" + quality_types[i]);
                _rt.latest_item = "a Progressive Shovel";
                create_notification(AP_RANDO_ITEM_KEY);
            }
            break;
        case "pouch":
            total_item_amt = POUCH_AMT;
        
            //check if the item exists in _rt.inv - if true, figure out which ind to start from
            if (struct_exists(_rt.inventory, item)) ind_start = struct_get(_rt.inventory, item);

            for (var i = ind_start; i < ind_start + amt; i += 1) {
                ap_rando_log_info("POUCH: " + item_type + "_" + quality_types[i]);
                ARI.inbox.push_mail(item_type + "_" + quality_types[i]);
                _rt.latest_item = "an Inventory Upgrade";
                create_notification(AP_RANDO_ITEM_KEY);
            }
            break;
        case "sword":
            for (var i = ind_start; i < ind_start + amt; i += 1) {
                ap_rando_log_info("SWORD: " + item_type + "_" + quality_types[i]);
                // sword_dragon_forged exception
                if (i == total_item_amt) ARI.inbox.push_mail(item_type + "_dragon_forged");
                else ARI.inbox.push_mail(item_type + "_" + quality_types[i]);
                _rt.latest_item = "a Progressive Sword";
                create_notification(AP_RANDO_ITEM_KEY);
            }
            break;
        case "helmet":
            for (var i = ind_start; i < ind_start + amt; i += 1) {
                ap_rando_log_info("HELMET: " + item_type + "_" + quality_types[i]);
                // dragonsworn exception
                if (i == total_item_amt) ARI.inbox.push_mail(quality_types[i]+"_"+item_type+"_equipment");
                else ARI.inbox.push_mail(quality_types[i] + "_" + item_type);
                _rt.latest_item = "a Progressive Helmet";
                create_notification(AP_RANDO_ITEM_KEY);
            }
            break;
        case "armor":
            for (var i = ind_start; i < ind_start + amt; i += 1) {
                ap_rando_log_info("ARMOR: " + quality_types[i]+"_"+item_type);
                // dragonforged exception
                if (i == total_item_amt) ARI.inbox.push_mail(quality_types[i]+"_"+item_type+"_equipment");
                else ARI.inbox.push_mail(quality_types[i] + "_" + item_type);
                _rt.latest_item = "Progressive Armor";
                create_notification(AP_RANDO_ITEM_KEY);
            }
            break;
        case "legplates":
            for (var i = ind_start; i < ind_start + amt; i += 1) {
                ap_rando_log_info("PANTS: " + quality_types[i]+"_"+item_type);
                // dragonforged exception
                if (i == total_item_amt) ARI.inbox.push_mail(quality_types[i]+"_"+item_type+"_equipment");
                else ARI.inbox.push_mail(quality_types[i] + "_" + item_type);
                _rt.latest_item = "Progressive Legplates";
                create_notification(AP_RANDO_ITEM_KEY);
            }
            break;
        case "greaves":
            for (var i = ind_start; i < ind_start + amt; i += 1) {
                ap_rando_log_info("BOOTS: " + item_type + "_" + quality_types[i]);
                // dragonforged exception
                if (i == total_item_amt) ARI.inbox.push_mail(quality_types[i]+"_greaves_equipment");
                // for whatever reason, mistril greaves are still boots lol
                else if (i == total_item_amt - 1) ARI.inbox.push_mail(quality_types[i] + "_boots")
                else ARI.inbox.push_mail(quality_types[i] + "_greaves");
                _rt.latest_item = "Progressive Greaves";
                create_notification(AP_RANDO_ITEM_KEY);
            }
            break;

        // since accessory is unique, we pull from the macro var
        case "ring":
            total_item_amt = RING_AMT;
        
            //check if the item exists in _rt.inv - if true, figure out which ind to start from
            if (struct_exists(_rt.inventory, item)) ind_start = struct_get(_rt.inventory, item);

            for (var i = ind_start; i < ind_start + amt; i += 1) {
                ap_rando_log_info("RING: " + quality_types[i] + "_" + item_type);
                ARI.inbox.push_mail(quality_types[i] + "_" + item_type);
                _rt.latest_item = "a Progressive Accessory";
                create_notification(AP_RANDO_ITEM_KEY);
            }
            break;
        
        case "barn":
            total_item_amt = FARM_BLDG_AMT;

            //check if the item exists in _rt.inv - if true, figure out which ind to start from
            if (struct_exists(_rt.inventory, item)) ind_start = struct_get(_rt.inventory, item);

            for (var i = ind_start; i < ind_start + amt; i += 1) {
                ap_rando_log_info("BARN: " + item_type + "_" + string(i));
                ARI.inbox.push_mail(item_type + "_" + string(i));
                _rt.latest_item = "a Progressive Barn";
                create_notification(AP_RANDO_ITEM_KEY);
            }
            break;
        case "coop":
            total_item_amt = FARM_BLDG_AMT;

            //check if the item exists in _rt.inv - if true, figure out which ind to start from
            if (struct_exists(_rt.inventory, item)) ind_start = struct_get(_rt.inventory, item);

            for (var i = ind_start; i < ind_start + amt; i += 1) {
                ap_rando_log_info("COOP: " + item_type + "_" + string(i));
                ARI.inbox.push_mail(item_type + "_" + string(i));
                _rt.latest_item = "a Progressive Coop";
                create_notification(AP_RANDO_ITEM_KEY);
            }
            break;
        case "greenhouse":
            total_item_amt = GREENHOUSE_AMT;

            //check if the item exists in _rt.inv - if true, figure out which ind to start from
            if (struct_exists(_rt.inventory, item)) ind_start = struct_get(_rt.inventory, item);

            for (var i = ind_start; i < ind_start + amt; i += 1) {
                ap_rando_log_info("GREENHOUSE: " + item_type + "_" + string(i));
                ARI.inbox.push_mail(item_type + "_" + string(i));
                _rt.latest_item = "a Progressive Greenhouse";
                create_notification(AP_RANDO_ITEM_KEY);
            }
            break;
        case "kitchen":
            total_item_amt = KITCHEN_AMT;

            //check if the item exists in _rt.inv - if true, figure out which ind to start from
            if (struct_exists(_rt.inventory, item)) ind_start = struct_get(_rt.inventory, item);

            for (var i = ind_start; i < ind_start + amt; i += 1) {
                
                ap_rando_log_info("KITCHEN: " + item_type + "_" + string(i));
                ARI.inbox.push_mail(item_type + "_" + string(i));
                _rt.latest_item = "a Progressive Kitchen";
                create_notification(AP_RANDO_ITEM_KEY);
            }
            break;
        default:
            ap_rando_log_info("tried to send item of progressive type but couldn't determine item_type");
            break;
    }
}

function ap_rando_home_trap() {
    // borrowed from BuggerInitialize.gml, to tp the player to bed
    var pos = player_wake_position();
    goto_location_id(pos.location_id, true)
        .set_exact_position(pos.pos.x, pos.pos.y);
}

function ap_rando_send_mail(item) {
    if (ap_rando_ready()) {
        ARI.inbox.push_mail(AP_RANDO_MAIL_KEY + item);
    }
}

function ap_rando_check_connection() {

    // try reading status.json if it exists
    var connection_status = try_read_json_file(AP_RANDO_MOD_PATH + "seeds/status.json", undefined, false);

    if (!connection_status) return false;
    if (!connection_status.connected) return false;

    var _rt = __ap_rando_runtime();
    _rt.ap_connected = connection_status.connected;
    _rt.seed = connection_status.seed_name;
    if (ap_rando_ready() && !_rt.seen_connect) {
        create_notification(AP_RANDO_CONNECTED_KEY);
        ap_rando_log_info("AP client connected, seed: " + string(_rt.seed));
        _rt.seen_connect = true;
    }
    return true;
}

function ap_rando_update_inventory(item_json) {
    var _rt = __ap_rando_runtime();
    // try reading inventory.json if it exists
    var inventory = try_read_json_file(AP_RANDO_MOD_PATH + "seeds/" + _rt.seed + "/inventory.json");

    if(!inventory) {
        ap_rando_log_info("Creating inventory.json for the first time.")
    }
    save_json_file(AP_RANDO_MOD_PATH + "seeds/" + _rt.seed + "/inventory.json", item_json);
}

function ap_rando_runtime_inventory() {
    var _rt = __ap_rando_runtime();
    var inventory = try_read_json_file(AP_RANDO_MOD_PATH + "seeds/" + _rt.seed + "/inventory.json");
    if(!inventory) {
        ap_rando_log_info("Couldn't access inventory.json to update runtime inventory.")
        return;
    }

    _rt.inventory = inventory;
}

function ap_rando_send_location(loc_id) {
    var _rt = __ap_rando_runtime();
    var loc_json = try_read_json_file(AP_RANDO_MOD_PATH + "seeds/" + _rt.seed + "/locations.json", undefined, false);
    if (!loc_json) {
        ap_rando_log_info("Couldn't access locations.json, tried "+ AP_RANDO_MOD_PATH + "seeds/" + string(_rt.seed) + "/locations.json")
        return;
    }

    var loc_arr = loc_json.locations;

    ap_rando_log_info("locations.json: " + string(loc_arr));
    ap_rando_log_info("AP location id: " + string(loc_id));
    array_push(loc_arr, loc_id);

    loc_json.locations = loc_arr;
    save_json_file(AP_RANDO_MOD_PATH + "seeds/" + _rt.seed + "/locations.json", loc_json);
}

function string_starts_with(str, substr) {
    return string_pos(substr, str) == 1;
}