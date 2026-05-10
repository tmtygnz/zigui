const std = @import("std");
const sokol = @import("sokol");
const saap = sokol.app;
const widget_collection = @import("widget_collection.zig");

pub const WidgetOptions = struct {
    position: @Vector(2, f32),
    bbox_dimensions: @Vector(2, f32),
    render_callback: *const fn (ctx: *anyopaque, widget: *Widget) void, // Component's function that handles rendering.
    component_context: *anyopaque, // Component's self.
    event_callback: *const fn (ctx: *anyopaque, widget: *Widget, event: [*c]const saap.Event) void, // Component's function that handles event.
};

pub const Widget = struct {
    position: @Vector(2, f32),
    bbox_dimensions: @Vector(2, f32),

    hovering: bool = false,
    pressed: bool = false,

    render_callback: *const fn (ctx: *anyopaque, widget: *Widget) void,
    component_context: *anyopaque,

    /// Will be called inside the `sokol_event` function within the windowing struct.
    event_callback: *const fn (ctx: *anyopaque, widget: *Widget, event: [*c]const saap.Event) void,

    const Self = @This();

    pub fn init(widgetOptions: WidgetOptions) Widget {
        return .{
            .position = widgetOptions.position,
            .bbox_dimensions = widgetOptions.bbox_dimensions,
            .render_callback = widgetOptions.render_callback,
            .component_context = widgetOptions.component_context,
            .event_callback = widgetOptions.event_callback,
        };
    }

    /// This function calls the component's (not the widget) event callback function.
    pub fn window_event_callback(self: *Self, event: [*c]const saap.Event) void {
        const e = event.*;
        if (self.hovering and e.mouse_button == saap.Mousebutton.LEFT and e.type == saap.EventType.MOUSE_DOWN) {
            self.pressed = true;
        }
        if (self.pressed and e.mouse_button == saap.Mousebutton.LEFT and e.type == saap.EventType.MOUSE_UP) {
            self.pressed = false;
        }

        // Call components event callback for component specific handlers.
        self.event_callback(self.component_context, self, event);
    }

    /// This function changes the bounding box size used to determine focus state of the widget.
    pub fn set_bbox_size(self: *Self, size: @Vector(2, f32)) void {
        self.bbox_dimensions = size;
    }

    /// This function renders the component.
    /// The function calls the check mouse collision first to update the widget state
    /// then passes it to the `render_callback` function of the component with the current widget state.
    pub fn render_step(self: *Self, mouse_position: @Vector(2, f32)) void {
        self.check_mouse_collisions(mouse_position);
        self.render_callback(self.component_context, self);
    }

    // Checks wether mouse cursor is within the minimum and maximum
    // boundaries of both axis.
    fn check_mouse_collisions(self: *Self, mouse_position: @Vector(2, f32)) void {
        const min_x = self.position[0];
        const min_y = self.position[1];
        const max_x = min_x + self.bbox_dimensions[0];
        const max_y = min_y + self.bbox_dimensions[1];

        if (min_x <= mouse_position[0] and mouse_position[0] <= max_x and min_y <= mouse_position[1] and mouse_position[1] <= max_y) {
            self.hovering = true;
        } else {
            self.hovering = false;
        }
    }
};
