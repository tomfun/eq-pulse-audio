#!/bin/bash

check_sink_remote() {
    event=$1
    if [[ -n $event ]] && ! grep -q "Event 'remove' on module" <<< "$event"; then
        return
    fi
    remote_sink_name="eq_n_comp"
    remote_address="10.50.10.6"
    sink_name='slim_book_eq_n_comp'
    if pactl list short modules | grep -q "sink_name=$sink_name"; then
        return
    fi
    echo "[ -> ]" $event
#    pactl load-module module-tunnel-sink sink_name=$sink_name server=$remote_address sink=$remote_sink_name
    while true; do
        pactl load-module module-tunnel-sink sink_name=$sink_name server=$remote_address sink=$remote_sink_name && {
            echo "[ ✔ ] Module loaded successfully."
            break
        }

        # Wait until remote responds to ping
        while ! ping -c1 -W1 $remote_address >/dev/null 2>&1; do
            echo "[ .. ] No ping response, retrying in 5 seconds..."
            sleep 5
        done

        sleep 5
    done
}

# Function to handle subscription and reconnection
subscribe_and_handle() {
    check_sink_remote
    while true; do
        pactl subscribe | grep --line-buffered 'remove' | while read -r line; do
            check_sink_remote "$line"
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

