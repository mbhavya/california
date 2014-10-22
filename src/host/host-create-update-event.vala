/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Host {

/**
 * A blank "form" of widgets for the user to enter or update event details.
 *
 * Message IN: If creating a new event, send Component.Event.blank() (pre-filled with any known
 * details).  If updating an existing event, send Component.Event.clone().
 */

[GtkTemplate (ui = "/org/yorba/california/rc/create-update-event.ui")]
public class CreateUpdateEvent : Gtk.Grid, Toolkit.Card {
    public const string ID = "CreateUpdateEvent";
    
    private const int START_HOUR = 0;
    private const int END_HOUR = 23;
    private const int MIN_DIVISIONS = 15;
    
    private const string FAMILY_NORMAL = "normal";
    private const string FAMILY_RECURRING = "recurring";
    
    public string card_id { get { return ID; } }
    
    public string? title { get { return null; } }
    
    public Gtk.Widget? default_widget { get { return accept_button; } }
    
    public Gtk.Widget? initial_focus { get { return summary_entry; } }
    
    [GtkChild]
    private Gtk.Entry summary_entry;
    
    [GtkChild]
    private Gtk.Label time_summary_label;
    
    [GtkChild]
    private Gtk.Entry location_entry;
    
    [GtkChild]
    private Gtk.TextView description_textview;
    
    [GtkChild]
    private Gtk.ComboBoxText calendar_combo;
    
    [GtkChild]
    private Gtk.Label recurring_explanation_label;
    
    [GtkChild]
    private Gtk.Box rotating_button_box_container;
    
    public bool is_update { get; set; default = false; }
    
    private new Component.Event event = new Component.Event.blank();
    private EventTimeSettings.Message? dt = null;
    private Backing.CalendarSource? original_calendar_source = null;
    private Toolkit.ComboBoxTextModel<Backing.CalendarSource> calendar_model;
    
    private Toolkit.RotatingButtonBox rotating_button_box = new Toolkit.RotatingButtonBox();
    private Toolkit.EntryClearTextConnector clear_text_connector = new Toolkit.EntryClearTextConnector();
    
    private Gtk.Button accept_button = new Gtk.Button();
    private Gtk.Button cancel_button = new Gtk.Button.with_mnemonic(_("_Cancel"));
    private Gtk.Button update_all_button = new Gtk.Button.with_mnemonic(_("Save A_ll Events"));
    private Gtk.Button update_this_button = new Gtk.Button.with_mnemonic(_("Save _This Event"));
    private Gtk.Button cancel_recurring_button = new Gtk.Button.with_mnemonic(_("_Cancel"));
    
    public CreateUpdateEvent() {
        // create button is active only if summary is filled out; all other fields (so far)
        // guarantee valid values at all times
        clear_text_connector.connect_to(summary_entry);
        summary_entry.bind_property("text", accept_button, "sensitive", BindingFlags.SYNC_CREATE,
            transform_summary_to_accept);
        
        clear_text_connector.connect_to(location_entry);
        
        // use model to control calendars combo box
        calendar_model = build_calendar_source_combo_model(calendar_combo);
        
        accept_button.can_default = true;
        accept_button.has_default = true;
        accept_button.get_style_context().add_class("suggested-action");
        
        accept_button.clicked.connect(on_accept_button_clicked);
        cancel_button.clicked.connect(on_cancel_button_clicked);
        update_all_button.clicked.connect(on_update_all_button_clicked);
        update_this_button.clicked.connect(on_update_this_button_clicked);
        cancel_recurring_button.clicked.connect(on_cancel_recurring_button_clicked);
        
        rotating_button_box.pack_end(FAMILY_NORMAL, cancel_button);
        rotating_button_box.pack_end(FAMILY_NORMAL, accept_button);
        
        rotating_button_box.pack_end(FAMILY_RECURRING, cancel_recurring_button);
        rotating_button_box.pack_end(FAMILY_RECURRING, update_all_button);
        rotating_button_box.pack_end(FAMILY_RECURRING, update_this_button);
        
        // The cancel-recurring-update button looks big compared to other buttons, so allow for the
        // ButtonBox to reduce it in size
        rotating_button_box.get_family_container(FAMILY_RECURRING).child_set_property(cancel_recurring_button,
            "non-homogeneous", true);
        
        rotating_button_box.expand = true;
        rotating_button_box.halign = Gtk.Align.FILL;
        rotating_button_box.valign = Gtk.Align.END;
        rotating_button_box_container.add(rotating_button_box);
        
        Calendar.System.instance.is_24hr_changed.connect(on_update_time_summary);
    }
    
    ~CreateUpdateEvent() {
        Calendar.System.instance.is_24hr_changed.disconnect(on_update_time_summary);
    }
    
    private bool transform_summary_to_accept(Binding binding, Value source_value, ref Value target_value) {
        target_value = summary_entry.text_length > 0 && (event != null ? event.is_valid(false) : false);
        
        return true;
    }
    
    public void jumped_to(Toolkit.Card? from, Toolkit.Card.Jump reason, Value? message) {
        // if no message, leave everything as it is
        if (message == null)
            return;
        
        if (message.type() == typeof(EventTimeSettings.Message)) {
            dt = (EventTimeSettings.Message) message;
        } else {
            event = (Component.Event) message;
            if (dt == null)
                dt = new EventTimeSettings.Message.from_event(event);
            
            original_calendar_source = event.calendar_source;
        }
        
        update_controls();
    }
    
    private void update_controls() {
        if (event.summary != null)
            summary_entry.text = event.summary;
        else
            summary_entry.text = "";
        
        on_update_time_summary();
        
        // set combo to event's calendar
        if (event.calendar_source != null) {
            calendar_model.set_item_active(event.calendar_source);
        } else {
            calendar_model.set_item_default_active();
            is_update = false;
        }
        
        location_entry.text = event.location ?? "";
        description_textview.buffer.text = event.description ?? "";
        
        Component.Event master = event.is_master_instance ? event : (Component.Event) event.master;
        
        // if RecurrenceRule.explain() returns null, means it cannot express the RRULE, which
        // should be made clear here
        string? explanation = null;
        if (master.rrule != null) {
            explanation = master.rrule.explain(master.get_event_date_span(Calendar.Timezone.local).start_date);
            if (explanation == null)
                explanation = _("It's complicated…");
        }
        
        recurring_explanation_label.label = explanation ?? _("Never");
        
        accept_button.label = is_update ? _("_Save") : _("C_reate");
        accept_button.use_underline = true;
        
        rotating_button_box.family = FAMILY_NORMAL;
    }
    
    private void on_update_time_summary() {
        // use the Message, not the Event, to load this up
        time_summary_label.visible = true;
        if (dt.date_span != null) {
            time_summary_label.label = dt.date_span.to_pretty_string(Calendar.Date.PrettyFlag.NONE);
        } else if (dt.exact_time_span != null) {
            time_summary_label.label = dt.exact_time_span.to_timezone(Calendar.Timezone.local).to_pretty_string(
                Calendar.Date.PrettyFlag.NONE, Calendar.ExactTimeSpan.PrettyFlag.NONE);
        } else {
            time_summary_label.visible = false;
        }
    }
    
    [GtkCallback]
    private void on_recurring_button_clicked() {
        // update the component with what's in the controls now
        update_component(event, true);
        
        // send off to recurring editor
        jump_to_card_by_name(CreateUpdateRecurring.ID, event);
    }
    
    [GtkCallback]
    private void on_edit_time_button_clicked() {
        if (dt == null)
            dt = new EventTimeSettings.Message.from_event(event);
        
        // save changes with what's in the component now
        update_component(event, true);
        
        jump_to_card_by_name(EventTimeSettings.ID, dt);
    }
    
    private void on_accept_button_clicked() {
        if (calendar_model.active == null)
            return;
        
        // if updating a recurring event, need to ask about update scope
        if (event.is_generated_instance && is_update) {
            rotating_button_box.family = FAMILY_RECURRING;
            
            return;
        }
        
        // create/update this instance of the event
        create_update_event(event, true);
    }
    
    // TODO: Now that a clone is being used for editing, can directly bind controls properties to
    // Event's properties and update that way ... doesn't quite work when updating the master event,
    // however
    private void update_component(Component.Event target, bool replace_dtstart) {
        target.calendar_source = calendar_model.active;
        target.summary = summary_entry.text;
        target.location = location_entry.text;
        target.description = description_textview.buffer.text;
        
        // if updating the master, don't replace the dtstart/dtend, but do want to adjust it from
        // DATE to DATE-TIME or vice-versa
        if (!replace_dtstart) {
            if (target.is_all_day != dt.is_all_day) {
                if (dt.is_all_day) {
                    target.timed_to_all_day_event();
                } else {
                    target.all_day_to_timed_event(
                        dt.exact_time_span.start_exact_time.to_wall_time(),
                        dt.exact_time_span.end_exact_time.to_wall_time(),
                        Calendar.Timezone.local
                    );
                }
                
                return;
            }
        }
        
        if (dt.is_all_day)
            target.set_event_date_span(dt.date_span);
        else
            target.set_event_exact_time_span(dt.exact_time_span);
    }
    
    private void create_update_event(Component.Event target, bool replace_dtstart) {
        update_component(target, replace_dtstart);
        
        if (is_update)
            update_event_async.begin(target, null);
        else
            create_event_async.begin(target, null);
    }
    
    private void on_cancel_button_clicked() {
        notify_user_closed();
    }
    
    private void on_update_all_button_clicked() {
        create_update_event(event.is_master_instance ? event : (Component.Event) event.master, false);
    }
    
    private void on_update_this_button_clicked() {
        create_update_event(event, true);
    }
    
    private void on_cancel_recurring_button_clicked() {
        rotating_button_box.family = FAMILY_NORMAL;
    }
    
    private async void create_event_async(Component.Event target, Cancellable? cancellable) {
        if (target.calendar_source == null) {
            report_error(_("Unable to create event: calendar must be specified"));
            
            return;
        }
        
        Gdk.Cursor? cursor = Toolkit.set_busy(this);
        
        Error? create_err = null;
        try {
            yield target.calendar_source.create_component_async(target, cancellable);
        } catch (Error err) {
            create_err = err;
        }
        
        Toolkit.set_unbusy(this, cursor);
        
        if (create_err == null)
            notify_success();
        else
            report_error(_("Unable to create event: %s").printf(create_err.message));
    }
    
    private async void update_event_async(Component.Event target, Cancellable? cancellable) {
        if (target.calendar_source == null) {
            report_error(_("Unable to update event: calendar must be specified"));
            
            return;
        }
        
        // no original calendar source, then not an update or a move but a create
        if (original_calendar_source == null) {
            yield create_event_async(target, cancellable);
            
            return;
        }
        
        Gdk.Cursor? cursor = Toolkit.set_busy(this);
        
        Error? update_err = null;
        if (target.calendar_source == original_calendar_source) {
            // straight-up update
            try {
                yield target.calendar_source.update_component_async(target, cancellable);
            } catch (Error err) {
                update_err = err;
            }
        } else {
            // move event from one calendar to another ... start with create on new calendar
            try {
                yield target.calendar_source.create_component_async(target, cancellable);
            } catch (Error err) {
                update_err = err;
            }
            
            // only delete old one if new one created
            if (update_err == null) {
                try {
                    yield original_calendar_source.remove_all_instances_async(target.uid, cancellable);
                } catch (Error err) {
                    update_err = err;
                }
            }
        }
        
        Toolkit.set_unbusy(this, cursor);
        
        if (update_err == null)
            notify_success();
        else
            report_error(_("Unable to update event: %s").printf(update_err.message));
    }
    
}

}
