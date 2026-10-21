// Exercise device selection with the production manager and a disappearing Audio service.
[DBus (name = "io.elementary.settings_daemon.Audio")]
public class SelectionAudio : Object {
    public signal void state_changed ();

    public Sound.EchoCancellation.Status get_status () throws DBusError, IOError {
        return { true, true, false, "", "physical_input", "physical_output" };
    }
}

int main () {
    assert (Environment.get_variable ("PULSE_SERVER").has_prefix ("unix:/tmp/vale-sound-"));
    assert (Environment.get_variable ("GSETTINGS_BACKEND") == "memory");
    var loop = new MainLoop ();
    var audio = new SelectionAudio ();
    uint owner = Bus.own_name (SESSION, "io.elementary.settings-daemon", NONE, (connection) => {
        try {
            connection.register_object ("/io/elementary/settings_daemon", audio);
        } catch (Error e) {
            error (e.message);
        }
    });
    var manager = Sound.PulseAudioManager.get_default ();
    manager.start ();
    var pulse_loop = new PulseAudio.GLibMainLoop ();
    var context = new PulseAudio.Context (pulse_loop.get_api (), "Selection regression");
    PulseAudio.Stream? playback = null;
    context.set_state_callback ((c) => {
        if (c.get_state () == PulseAudio.Context.State.READY) {
            var sample = PulseAudio.SampleSpec () {
                format = PulseAudio.SampleFormat.S16NE,
                rate = 48000,
                channels = 2
            };
            playback = new PulseAudio.Stream (c, "Selection regression", sample);
            playback.connect_playback ("physical_output", null, PulseAudio.Stream.Flags.START_CORKED);
        }
    });
    context.connect (null, PulseAudio.Context.Flags.NOAUTOSPAWN);
    bool selecting = false;
    bool completed = false;
    int64 lost_at = 0;
    Timeout.add (20, () => {
        if (!selecting && manager.context != null && manager.context.get_state () == PulseAudio.Context.State.READY &&
            manager.echo_cancellation.enabled && playback != null &&
            playback.get_state () == PulseAudio.Stream.State.READY && manager.apps.get_n_items () == 1) {
            selecting = true;
            var device = new Sound.Device ("fixture", 42, "fixture") {
                input = false,
                card_active_profile_name = "fixture",
                card_sink_port_name = "fixture",
                sink_name = "physical_output2"
            };
            device.profiles.add ("fixture");
            manager.set_default_device.begin (device, (obj, result) => {
                manager.set_default_device.end (result);
                completed = true;
            });
            // Keep the old processing master until selection is awaiting the new one.
            Timeout.add (250, () => {
                assert (!completed && manager.echo_cancellation.enabled);
                lost_at = get_monotonic_time ();
                Bus.unown_name (owner);
                return Source.REMOVE;
            });
        }
        if (lost_at != 0) {
            assert (get_monotonic_time () - lost_at < 2000000);
            if (completed && playback.get_device_name () == "physical_output2") {
                print ("PASS daemon loss wakes device selection and restores the playback route\n");
                loop.quit ();
                return Source.REMOVE;
            }
        }
        return Source.CONTINUE;
    });
    Timeout.add_seconds (10, () => {
        error ("Device selection did not complete");
    });
    loop.run ();
    playback.disconnect ();
    context.disconnect ();
    return 0;
}
