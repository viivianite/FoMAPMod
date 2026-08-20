
function ap_rando_check_items(json_path) {
    var pending_items = try_read_json_file(json_path, undefined, false);
    if (!pending_items) {
        ap_rando_log_info("Couldn't access items.json");
        return;
    }
    
    // pull ap item_ids as an array
    var pending_item_ids = struct_get_names(pending_items);

    for (var i = 0; i < array_length(pending_item_ids); i += 1) {
        ap_rando_log_info(string(pending_item_ids[i]));
        // check if they exist in item_reference (they should!!!!)
        
    // get the name of the item

    //switch case for the item, send off to the appropriate function
    }
}

function ap_rando_send_mail(item) {
    if (ap_rando_ready()) {
        ARI.inbox.push_mail(AP_RANDO_MAIL_KEY + item);
    }
}

function ap_rando_send_tess() {
    if (ap_rando_ready()) {
        ARI.modify_gold(500);
        create_notification(AP_RANDO_MODIFY_GOLD_KEY);
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
    return true;
}