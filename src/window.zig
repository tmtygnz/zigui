const sokol = @import("sokol");
const sapp = sokol.app;
const sg = sokol.gfx;
const sgl = sokol.gl;
const std = @import("std");
const widget = @import("./widgets/widget.zig");
const texts = @import("widgets/label_widget.zig");

pub const WindowInstanceOptions = struct {
    initial_width: i32,
    initial_height: i32,
    title: [*c]const u8,
    allocator: std.mem.Allocator,
    io: std.Io,
    app_font: *texts.FontProvider,
};

pub const WindowInstance = struct {
    width: i32,
    height: i32,
    title: [*c]const u8,

    // Mouse status
    mouse_position: @Vector(2, f32),
    mouse_down: bool = false,

    // Components
    components: std.ArrayListUnmanaged(widget.Widget) = .empty,
    component_allocator: std.mem.Allocator,
    app_font: *texts.FontProvider,

    // Io
    Io: std.Io,

    const Self = @This();

    /// Initializes a WindowInstance
    ///
    /// This functions sets up all of the necessary information to create a window
    /// it will return a WindowInstance where in `WindowInstance.run` can be called to start the application loop.
    pub fn init(options: WindowInstanceOptions) Self {
        return .{
            .width = options.initial_width,
            .height = options.initial_height,
            .title = options.title,
            .mouse_position = .{ 0.0, 0.0 },
            .component_allocator = options.allocator,
            .Io = options.io,
            .app_font = options.app_font,
        };
    }

    pub fn addComponent(self: *Self, component: widget.Widget) !void {
        try self.components.append(self.component_allocator, component);
    }

    // Starts the application loop.
    //
    // This function starts the application loop and load UI components added to
    // the `WindowInstance` instance every frame.
    pub fn run(self: *Self) void {
        sapp.run(.{
            .init_cb = sokol_init,
            .frame_cb = sokol_frame,
            .cleanup_cb = sokol_cleanup,
            .width = self.width,
            .height = self.height,
            .event_cb = sokol_event,
            .window_title = self.title,
            .user_data = self,
            .high_dpi = true,
        });
    }

    // Call once by sokol at startup.
    fn sokol_init() callconv(.c) void {
        const self: *Self = @ptrCast(@alignCast(sapp.userdata()));
        sg.setup(.{
            .environment = sokol.glue.environment(),
        });
        sgl.setup(.{});

        self.app_font.rasterizeGlyphs() catch {
            return;
        };
        self.app_font.consolidateGlyphsToAtlas() catch {
            return;
        };
    }

    // Function called every frame.
    fn sokol_frame() callconv(.c) void {
        const self: *Self = @ptrCast(@alignCast(sapp.userdata()));

        sgl.defaults();
        sgl.matrixModeProjection();
        sgl.loadIdentity();
        sgl.ortho(0.0, sapp.widthf(), sapp.heightf(), 0.0, -1.0, 1.0);

        var pass_action = sg.PassAction{};

        // Setup only the first color attachment (the backbuffer)
        pass_action.colors[0] = .{
            .load_action = .CLEAR,
            .clear_value = .{ .r = 0.075, .g = 0.075, .b = 0.075, .a = 1.0 },
        };

        sg.beginPass(.{ .action = pass_action, .swapchain = sokol.glue.swapchain() });

        for (self.components.items) |*component| {
            component.*.render_step(self.mouse_position);
        }

        sgl.draw();
        sg.endPass();
        sg.commit();
    }
    fn sokol_event(event: [*c]const sapp.Event) callconv(.c) void {
        const e = event.*;

        const self: *Self = @ptrCast(@alignCast(sapp.userdata()));
        if (e.type == .MOUSE_MOVE) {
            self.mouse_position = .{ @as(f32, e.mouse_x), @as(f32, e.mouse_y) };
        }

        if (e.type == .MOUSE_DOWN) {
            self.mouse_down = true;
        } else if (e.type == .MOUSE_LEAVE) {
            self.mouse_down = false;
        } else {
            self.mouse_down = false;
        }

        for (self.components.items) |*component| {
            component.window_event_callback(event);
        }
    }

    fn sokol_cleanup() callconv(.c) void {
        sg.shutdown();
    }
};
