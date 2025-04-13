#!/bin/bash

pa_config_sven=$(cat <<EOF
   load-module module-equalizer-sink sink_name=EQ_SvenSPS sink_properties='device.master_device="alsa_output.pci-0000_05_00.1.hdmi-stereo-extra1"device.description="EQ_SvenSPS HDMI"'
EOF
)
load_sven_eq() {
  echo $pa_config_sven | pacmd
  move_sink_input "module" "EQ_SvenSPS" "$sink_hdmi"
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
        echo "No sink input found for module "$module_name"."
        return 5
    fi

    echo "$sink_input"
    return 0
}

# Function to get the sink index by application.name property
get_sink_index_by_application_name() {
    local application_name=$1
    local pactl_output

    # Find the sink input that corresponds to this application
    pactl_output=$(pactl list sink-inputs)
    if [ $? -ne 0 ]; then
        echo "Error listing sink-inputs."
        return 1
    fi
    local sink_input=$(echo "$pactl_output" | grep -B22 'application.name = "'"$application_name"'"' | grep "Sink Input #" | head -n1 | cut -d'#' -f2 | tr -d ' ')
    if [ -z "$sink_input" ]; then
        echo "No sink input found for application \"$application_name\"."
        return 5
    fi

    echo "$sink_input"
    return 0
}

# Function to update the master of a sink
move_sink_input() {
    local get_sync_by=$1
    local arg_name=$2
    local target_master_name=$3
    local sink_index
    local exit_sub
    if [ "$get_sync_by" == "module" ]; then
      sink_index=$(get_sink_index_by_module_name "$arg_name")
    elif [ "$get_sync_by" == "application" ]; then
      sink_index=$(get_sink_index_by_application_name "$arg_name")
    fi
    exit_sub=$?
    if [ $exit_sub -eq 4 ]; then
        echo "$sink_index"
        echo "Sink input index for $arg_name not found."
        return 4
    fi
    if [ $exit_sub -eq 0 ]; then
        echo "Sink input index for $arg_name is $sink_index."
    else
        echo "$sink_index"
        echo "Failed to find sink input index for $arg_name."
        return 1
    fi
    pactl move-sink-input "$sink_index" "$target_master_name"
}

move_sink_or_load() {
    local get_sync_by=$1
    local arg_name=$2
    local target_master_name=$3
    local load_func=$4
    local exit_sub
    local out_sub
    out_sub=$(move_sink_input "$get_sync_by" "$arg_name" "$target_master_name")
    exit_sub=$?
    echo "$out_sub"
    if [ $exit_sub -eq 4 ]; then
        echo "Load module"
        $load_func
        return 0
    fi
    return $exit_sub
}

check_sink_hdmi() {
    sink_hdmi=$(pactl list short sinks | grep .hdmi | head -n 1 | cut -f2)
    if [ "$sink_hdmi" == "" ]; then
#        sink_hdmi="@DEFAULT_SINK@"
        sink_hdmi="alsa_output.pci-0000_00_1f.3.analog-stereo"
    fi
}

init_pa() {
  pactl list short modules | grep 'sink_name=virtual_null' \
    || pactl load-module module-null-sink sink_name=virtual_null sink_properties='device.description="For_Manual_Record"' rate=48000
  pactl list short modules | grep '10.50.10.0/23' \
    || pactl load-module module-native-protocol-tcp 'auth-ip-acl=10.50.10.0/23;192.168.0.183;192.168.0.138' auth-anonymous=true
}

# Function to handle subscription and reconnection
subscribe_and_handle() {
    check_sink_hdmi
    move_sink_or_load "module" "EQ_SvenSPS" "$sink_hdmi" load_sven_eq
    move_sink_input "module" "shw_sc4" "eq_after_comp"
    move_sink_input "module" "eq_n_comp" "shw_sc4"
#    move_sink_input "application" "application name" "device name"
    while true; do
        init_pa
#                update_sink_master "eq_after_comp" "alsa_output.pci-0000_05_00.1.hdmi-stereo-extra1"
        pactl subscribe | grep --line-buffered 'sink ' | while read -r line; do
            if echo "$line" | grep -q 'change'; then
                check_sink_hdmi
                move_sink_or_load "module" "EQ_SvenSPS" "$sink_hdmi" load_sven_eq
                move_sink_input "module" "shw_sc4" "eq_after_comp"
                move_sink_input "module" "eq_n_comp" "shw_sc4"
            fi
        done
        if [ "$infinite_loop" == "run" ]; then
            echo "Connection to PulseAudio lost. Attempting to reconnect in 60 seconds..."
            sleep 60
        else
            return 0
        fi
    done
}

trap ctrl_c INT
trap ctrl_c TERM

ctrl_c() {
  infinite_loop="stop"
}

# Start the subscription and handling function
subscribe_and_handle
#update_sink_master "EQ_SvenSPS" "alsa_output.pci-0000_05_00.1.hdmi-stereo-extra1"

