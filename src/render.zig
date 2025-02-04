const std = @import("std");
const rl = @import("raylib");
const voxel = @import("voxel.zig");

const Voxel = voxel.Voxel;

pub const VoxelRenderer = struct {
    prng: std.rand.DefaultPrng,
    transition_speed: f32,
    color_states: std.AutoHashMap(Voxel.Id, ColorState),

    pub const ColorState = struct {
        current: rl.Color,
        target: rl.Color,
        transition_progress: f32,
    };

    const pastel_colors = [_]rl.Color{
        .{ .r = 255, .g = 182, .b = 193, .a = 255 }, // pink
        .{ .r = 173, .g = 216, .b = 230, .a = 255 }, // blue
        .{ .r = 198, .g = 226, .b = 199, .a = 255 }, // green
        .{ .r = 255, .g = 218, .b = 185, .a = 255 }, // peach
    };

    pub fn init(allocator: std.mem.Allocator, seed: u64, transition_speed: f32) !VoxelRenderer {
        return .{
            .prng = std.rand.DefaultPrng.init(seed),
            .transition_speed = transition_speed,
            .color_states = std.AutoHashMap(Voxel.Id, ColorState).init(allocator),
        };
    }

    pub fn deinit(self: *VoxelRenderer) void {
        self.color_states.deinit();
    }

    pub fn getColor(self: *VoxelRenderer, id: Voxel.Id) rl.Color {
        if (self.color_states.get(id)) |state| {
            var color = state;
            color.transition_progress += rl.getFrameTime() * self.transition_speed;

            if (color.transition_progress >= 1.0) {
                color.current = color.target;
                const index = self.prng.random().uintAtMost(
                    usize,
                    pastel_colors.len - 1,
                );
                color.target = pastel_colors[index];
                color.transition_progress = 0;
            }

            self.color_states.put(id, color) catch unreachable;

            return lerpColor(
                color.current,
                color.target,
                color.transition_progress,
            );
        } else {
            const current = self.prng.random().uintAtMost(
                usize,
                pastel_colors.len - 1,
            );

            const target = self.prng.random().uintAtMost(
                usize,
                pastel_colors.len - 1,
            );

            const state = ColorState{
                .current = pastel_colors[current],
                .target = pastel_colors[target],
                .transition_progress = 0,
            };

            self.color_states.put(id, state) catch unreachable;
            return state.current;
        }
    }
};

fn lerpColor(a: rl.Color, b: rl.Color, t: f32) rl.Color {
    return .{
        .r = @intFromFloat(@as(f32, @floatFromInt(a.r)) * (1 - t) + @as(f32, @floatFromInt(b.r)) * t),
        .g = @intFromFloat(@as(f32, @floatFromInt(a.g)) * (1 - t) + @as(f32, @floatFromInt(b.g)) * t),
        .b = @intFromFloat(@as(f32, @floatFromInt(a.b)) * (1 - t) + @as(f32, @floatFromInt(b.b)) * t),
        .a = 255,
    };
}
