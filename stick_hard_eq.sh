#!/bin/bash

# Function to get the sink index by name
get_sink_index_by_module_name() {
    local module_name=$1
    # Find the module ID for the given module name
    local module_id=$(pactl list modules short | grep "$module_name" | head -n 1 | cut -f1)
    if [ -z "$module_id" ]; then
        echo "Module $module_name not found."
        return 1
    fi

    # Find the sink input that corresponds to this module ID
    local sink_input=$(pactl list sink-inputs | grep -B5 "Owner Module: $module_id" | grep "Sink Input #" | head -n1 | cut -d'#' -f2 | tr -d ' ')
    if [ -z "$sink_input" ]; then
        echo "No sink input found for module $module_name."
        return 1
    fi

    echo "$sink_input"
    return 0
}

# Function to update the master of a sink
update_sink_master() {
    local sink_name=$1
    local target_master_name=$2
    local sink_index=$(get_sink_index_by_module_name "$sink_name")
    if [ $? -eq 0 ]; then
        echo "Sink input index for $sink_name is $sink_index."
    else
        echo "Failed to find sink input index for $sink_name."
    fi
    pactl move-sink-input "$sink_index" "$target_master_name"
}

# Function to handle subscription and reconnection
subscribe_and_handle() {
    while true; do
        update_sink_master "EQ_SvenSPS" "alsa_output.pci-0000_05_00.1.hdmi-stereo-extra1"
        pactl subscribe | grep --line-buffered 'sink ' | while read -r line; do
            if echo "$line" | grep -q 'change'; then
                update_sink_master "EQ_SvenSPS" "alsa_output.pci-0000_05_00.1.hdmi-stereo-extra1"
                update_sink_master "shw_sc4" "eq_after_comp"
                update_sink_master "eq_n_comp" "shw_sc4"
            fi
        done
        echo "Connection to PulseAudio lost. Attempting to reconnect in 30 seconds..."
        sleep 30
    done
}

# Start the subscription and handling function
subscribe_and_handle

