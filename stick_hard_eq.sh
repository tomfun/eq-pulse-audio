#!/bin/bash


load_sven_eq() {
  #pacmd load-module module-equalizer-sink sink_name=EQ_SvenSPS sink_properties="'"device.master_device="alsa_output.pci-0000_05_00.1.hdmi-stereo-extra1"device.description="EQ_SvenSPS HDMI""'"
  pacmd load-module module-equalizer-sink sink_name=EQ_SvenSPS
  move_sink_input "EQ_SvenSPS" "alsa_output.pci-0000_05_00.1.hdmi-stereo-extra1"
}

# Function to get the sink index by name
get_sink_index_by_module_name() {
    local module_name=$1
    # Find the module ID for the given module name
    local pactl_output
    local module_id
    pactl_output=$(pactl list modules short)
    if [ $? -ne 0 ]; then
        echo "Error listing modules."
        return 1
    fi
    module_id=$(echo "$pactl_output" | grep "$module_name" | head -n 1 | cut -f1)
    if [ $? -ne 0 ]; then
        echo "Error filtering modules."
        return 2
    fi
    if [ -z "$module_id" ]; then
        echo "Module $module_name not found."
        return 4
    fi

    # Find the sink input that corresponds to this module ID
    pactl_output=$(pactl list sink-inputs)
    if [ $? -ne 0 ]; then
        echo "Error listing sink-inputs."
        return 1
    fi
    local sink_input=$(echo "$pactl_output" | grep -B5 "Owner Module: $module_id" | grep "Sink Input #" | head -n1 | cut -d'#' -f2 | tr -d ' ')
    if [ -z "$sink_input" ]; then
        echo "No sink input found for module $module_name."
        return 5
    fi

    echo "$sink_input"
    return 0
}

# Function to update the master of a sink
move_sink_input() {
    local sink_name=$1
    local target_master_name=$2
    local sink_index
    local exit_sub
    sink_index=$(get_sink_index_by_module_name "$sink_name")
    exit_sub=$?
    if [ $exit_sub -eq 4 ]; then
        echo "$sink_index"
        echo "Sink input index for $sink_name not found."
        return 4
    fi
    if [ $exit_sub -eq 0 ]; then
        echo "Sink input index for $sink_name is $sink_index."
    else
        echo "$sink_index"
        echo "Failed to find sink input index for $sink_name."
        return 1
    fi
    pactl move-sink-input "$sink_index" "$target_master_name"
}

move_sink_or_load() {
    local sink_name=$1
    local target_master_name=$2
    local load_func=$3
    local exit_sub
    local out_sub
    out_sub=$(move_sink_input "$sink_name" "$target_master_name")
    exit_sub=$?
    echo "$out_sub"
    if [ $exit_sub -eq 4 ]; then
        echo "Load module"
        $load_func
        return 0
    fi
    return $exit_sub
}

# Function to handle subscription and reconnection
subscribe_and_handle() {
    move_sink_or_load "EQ_SvenSPS" "alsa_output.pci-0000_05_00.1.hdmi-stereo-extra1" load_sven_eq
    move_sink_input "shw_sc4" "eq_after_comp"
    move_sink_input "eq_n_comp" "shw_sc4"
    while true; do
#                update_sink_master "eq_after_comp" "alsa_output.pci-0000_05_00.1.hdmi-stereo-extra1"
        pactl subscribe | grep --line-buffered 'sink ' | while read -r line; do
            if echo "$line" | grep -q 'change'; then
                move_sink_or_load "EQ_SvenSPS" "alsa_output.pci-0000_05_00.1.hdmi-stereo-extra1" load_sven_eq
                move_sink_input "shw_sc4" "eq_after_comp"
                move_sink_input "eq_n_comp" "shw_sc4"
            fi
        done
        echo "Connection to PulseAudio lost. Attempting to reconnect in 60 seconds..."
        sleep 60
    done
}

# Start the subscription and handling function
subscribe_and_handle
#update_sink_master "EQ_SvenSPS" "alsa_output.pci-0000_05_00.1.hdmi-stereo-extra1"

