#!/usr/bin/env python
# pulse-set-eq
import os,math,sys
import dbus

# Source adapted from utils/qpaeq of PulseAudio

def connect(): # copied from qpaeq
    try:
        if 'PULSE_DBUS_SERVER' in os.environ:
            address = os.environ['PULSE_DBUS_SERVER']
        else:
            bus = dbus.SessionBus() # Should be UserBus, but D-Bus doesn't implement that yet.
            server_lookup = bus.get_object('org.PulseAudio1', '/org/pulseaudio/server_lookup1')
            address = server_lookup.Get('org.PulseAudio.ServerLookup1', 'Address', dbus_interface='org.freedesktop.DBus.Properties')
        return dbus.connection.Connection(address)
    except Exception as e:
        sys.stderr.write('There was an error connecting to pulseaudio, '
                         'please make sure you have the pulseaudio dbus '
                         'module loaded, exiting...\n')
        sys.exit(-1)

def get_sink(str):
    connection=connect()
    path='/org/pulseaudio/core1/sink%s'%str
    sink=connection.get_object(object_path=path)
    return sink

args = sys.argv[1:]
if len(args)<5:
    print("Usage: "+sys.argv[0]+" SINK_NUM CHANNEL_NUM PREAMP_VALUE FREQ1 COEF1 [FREQ2 COEF2...]")
    sys.exit()


sinknum = args.pop(0);
sink = get_sink(sinknum);

prop_iface='org.freedesktop.DBus.Properties'
eq_iface='org.PulseAudio.Ext.Equalizing1.Equalizer'
sink_props=dbus.Interface(sink,dbus_interface=prop_iface)

def get_eq_attr(attr):
    return sink_props.Get(eq_iface,attr)

sample_rate=get_eq_attr('SampleRate')
filter_rate=get_eq_attr('FilterSampleRate')
nchannels=get_eq_attr('NChannels')

sys.stderr.write('channels %d, sample rate: %f, filter sample rate: %f\n'%
    (nchannels, sample_rate, filter_rate))

channel = int(args.pop(0));
preamp = float(args.pop(0));

freqs = [];
coeffs = [];
while len(args) > 0:
    if len(args)==1:
        sys.stderr.write('Odd number of frequency/amplification arguments (%d)\n'%(len(freqs)*2+1))
        sys.exit(-1)
    sys.stderr.write('(%s, %s)\n'%(args[0],args[1]))
    freqs.append(float(args.pop(0)))
    coeffs.append(float(args.pop(0)))

#sys.stderr.write("freqs: "+str(freqs)+'\n');

freqs = list([int(round(x*filter_rate/sample_rate)) for x in freqs])
#sys.stderr.write("translated freqs: "+str(freqs)+'\n');

freqs = [0]+freqs+[filter_rate//2];
coeffs = [coeffs[0]]+coeffs+[coeffs[-1]];
#sys.stderr.write("proper freqs: "+str(freqs)+'\n');

# for some reason this fixes the types of the arguments to SeedFilter
sink=dbus.Interface(sink,dbus_interface=eq_iface)

# set the filter coefficients
sink.SeedFilter(channel,freqs,coeffs,preamp)

