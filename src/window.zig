const sokol = @import("sokol");
const sapp = sokol.app;
const sg = sokol.gfx;
const sgl = sokol.gl;
const std = @import("std");

pub const WindowInstance = struct {
    width: i32,
    height: i32,
    title: [*c]const u8,

    const Self = @This();

    /// Initializes a WindowInstance
    ///
    /// This functions sets up all of the necessary information to create a window
    /// it will return a WindowInstance where in `WindowInstance.run` can be called to start the application loop.
    pub fn init(initial_width: i32, initial_height: i32, title: [*c]const u8) Self {
        return .{ .width = initial_width, .height = initial_height, .title = title };
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
            .window_title = self.title,
        });
    }

    // Call once by sokol at startup.
    fn sokol_init() callconv(.c) void {
        sg.setup(.{
            .environment = sokol.glue.environment(),
        });
    }

    // Function called every frame.
    fn sokol_frame() callconv(.c) void {
        sg.beginPass(.{ .swapchain = sokol.glue.swapchain() });
        sg.endPass();
        sg.commit();
    }

    fn sokol_cleanup() callconv(.c) void {
        sg.shutdown();
    }
};
