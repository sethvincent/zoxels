const std = @import("std");
const rl = @import("raylib");
const voxel = @import("voxel.zig");

const math = std.math;
const World = voxel.World;
const Chunk = voxel.Chunk;

pub const Player = struct {
    position: rl.Vector3,
    direction: rl.Vector3,
    speed: f32,
    mouse_sensitivity: f32,
    yaw: f32,
    pitch: f32,
    velocity_y: f32,

    pub fn update(p: *Player, mouse_delta: rl.Vector2) !void {
        p.updatePosition();
        p.updateDirection(mouse_delta);
    }

    pub fn updatePosition(p: *Player) void {
        if (rl.isKeyDown(.w)) {
            p.position.x += p.direction.x * p.speed * rl.getFrameTime();
            p.position.z += p.direction.z * p.speed * rl.getFrameTime();
        }

        if (rl.isKeyDown(.s)) {
            p.position.x -= p.direction.x * p.speed * rl.getFrameTime();
            p.position.z -= p.direction.z * p.speed * rl.getFrameTime();
        }

        if (rl.isKeyDown(.a)) {
            const normalized = p.direction.crossProduct(
                rl.Vector3{ .x = 0, .y = 1, .z = 0 },
            ).normalize();
            p.position.x -= normalized.x * p.speed * rl.getFrameTime();
            p.position.z -= normalized.z * p.speed * rl.getFrameTime();
        }

        if (rl.isKeyDown(.d)) {
            const normalized = p.direction.crossProduct(
                rl.Vector3{ .x = 0, .y = 1, .z = 0 },
            ).normalize();
            p.position.x += normalized.x * p.speed * rl.getFrameTime();
            p.position.z += normalized.z * p.speed * rl.getFrameTime();
        }

        p.velocity_y -= 9.8 * rl.getFrameTime();
        p.position.y += p.velocity_y * rl.getFrameTime();

        if (p.position.y < 16) {
            p.position.y = 16;
            p.velocity_y = 0;
        }
    }

    pub fn updateDirection(p: *Player, mouse_delta: rl.Vector2) void {
        p.yaw += mouse_delta.x * p.mouse_sensitivity;
        p.pitch -= mouse_delta.y * p.mouse_sensitivity;

        // if (p.pitch > math.degreesToRadians(89)) {
        //     p.pitch = math.degreesToRadians(89);
        // }

        // if (p.pitch < math.degreesToRadians(-89)) {
        //     p.pitch = math.degreesToRadians(-89);
        // }

        p.direction.x = @cos(p.yaw) * @cos(p.pitch);
        p.direction.y = @sin(p.pitch);
        p.direction.z = @sin(p.yaw) * @cos(p.pitch);
        p.direction = p.direction.normalize();
    }
};
