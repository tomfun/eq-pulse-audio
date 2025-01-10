# Compress audio similiar for people perception
We don't feel much low and very high frequencies

This is example of setup pulseaudio and dirty script to stick to a sink for some plugin

# Use

sudo nano /etc/pulse/default.pa && systemctl restart --user pulseaudio.service; journalctl --user -u pulseaudio.service --since "-1m" -f

```pa
### Some stuff
# sudo apt install pulseaudio-equalizer
load-module module-equalizer-sink sink_name=EQ_SvenSPS sink_master=alsa_output.pci-0000_05_00.1.hdmi-stereo-extra1 sink_properties='device.master_device="alsa_output.pci-0000_05_00.1.hdmi-stereo-extra1"device.description="EQ_SvenSPS HDMI"'
load-module module-dbus-protocol
# qpaeq
#load-module module-combine-sink sink_name=combined slaves=GuiEQ_hdmi,alsa_output.pci-0000_05_00.6.analog-stereo

### Compress
load-module module-ladspa-sink sink_name=eq_after_comp plugin=mbeq_1197 label=mbeq control=19.38,12.46,8.77,6.69,4.62,3.23,2.31,2.31,3.69,3.69,0.92,0.00,2.77,9.23,30.00
load-module module-ladspa-sink sink_name=shw_sc4 sink_master=eq_after_comp plugin=sc4_1882 label=sc4 control=0.2,20,500,-30,8,5,
load-module module-ladspa-sink sink_name=eq_n_comp sink_master=shw_sc4 plugin=mbeq_1197 label=mbeq control=-19.38,-12.46,-8.77,-6.69,-4.62,-3.23,-2.31,-2.31,-3.69,-3.69,-0.92,0.00,-2.77,-9.23,-30.00

```

# Stick sink

```shell
mkdir -p ~/.config/systemd/user/
ln -sv $PWD/stick_hard_eq.service ~/.config/systemd/user/stick_hard_eq.service
systemctl --user daemon-reload
systemctl --user enable  stick_hard_eq
systemctl --user start  stick_hard_eq
journalctl --user-unit stick_hard_eq -f
```

debug: `pactl list`

sudo apt install paprefs
sudo apt install swh-plugins

# See useful links

https://gist.github.com/lightrush/4fc5b36e01db8fae534b0ea6c16e347f?permalink_comment_id=4044948  
https://wiki.archlinux.org/title/PulseAudio  
https://github.com/pulseaudio-equalizer-ladspa/equalizer  
https://unix.stackexchange.com/questions/164476/how-to-control-equalizer-within-command-line
https://docs.google.com/spreadsheets/d/1GnOPVUUzfdaRjbs9BIm6P46LktGWWqUxGIAmK37uvSg/edit?usp=sharing  
