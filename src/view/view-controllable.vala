/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.View {

/**
 * All views need to offer this interface in their host, giving them a generic interface for the
 * controller window to manipulate.
 *
 * The Controllable is expected to maintain a current date, which can be manipulated through this
 * interface and report itself via properties.
 */

public interface Controllable : Object {
    public const string PROP_CURRENT_LABEL = "current-label";
    public const string PROP_IS_VIEWING_TODAY = "is-viewing-today";
    public const string PROP_DEFAULT_DATE = "default-date";
    public const string PROP_FIRST_OF_WEEK = "first-of-week";
    
    /**
     * A user-visible string representing the current calendar view.
     */
    public abstract string current_label { get; protected set; }
    
    /**
     * Flag indicating if the current calendar unit matches the unit the {@link today} method
     * could jump to.
     *
     * This value should update dynamically as {@link Calendar.System.today} changes.  There's no
     * requirement for the {@link Controllable} to change its view as the day changes, however.
     */
    public abstract bool is_viewing_today { get; protected set; }
    
    /**
     * Default {@link Calendar.Date} for the calendar unit in view.
     */
    public abstract Calendar.Date default_date { get; protected set; }
    
    /**
     * The first day of the week.
     */
    public abstract Calendar.FirstOfWeek first_of_week { get; set; }
    
    /**
     * Signal from the {@link Controllable} that a DATE-TIME {@link Component.Event} should be
     * created with the specified initial parameters.
     */
    public signal void request_create_timed_event(Calendar.ExactTimeSpan initial, Gtk.Widget relative_to,
        Gdk.Point? for_location);
    
    /**
     * Signal from the {@link Controllable} that a DATE {@link Component.Event} should be
     * created with the specified initial parameters.
     */
    public signal void request_create_all_day_event(Calendar.DateSpan initial, Gtk.Widget relative_to,
        Gdk.Point? for_location);
    
    /**
     * Signal from the {@link Controllable} to display a {@link Component.Event}.
     */
    public signal void request_display_event(Component.Event event, Gtk.Widget relative_to,
        Gdk.Point? for_location);
    
    /**
     * Move forward one calendar unit.
     */
    public abstract void next();
    
    /**
     * Move backward one calendar unit.
     */
    public abstract void prev();
    
    /**
     * Jump to calendar unit representing the current date.
     *
     * Returns the Gtk.Widget displaying the current date.
     */
    public abstract Gtk.Widget today();
    
    /**
     * If the view supports a notion of selection, this unselects all selected items.
     *
     * The view controller will use this to clear selection after completing a request (for example,
     * when creating or displaying events).
     */
    public abstract void unselect_all();
}

}

