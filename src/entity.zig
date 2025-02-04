const std = @import("std");
const rl = @import("raylib");
const voxel = @import("voxel.zig");

const math = std.math;
const World = voxel.World;
const Chunk = voxel.Chunk;
const GRAVITY: f32 = 9.8;
const JUMP_VELOCITY_INITIAL: f32 = 12.0; // Initial jump velocity (still tweakable)
const JUMP_DURATION: f32 = 0.5;
const FALL_GRAVITY_MULTIPLIER: f32 = 3;

pub const Player = struct {
    height: f32,
    width: f32,
    position: rl.Vector3,
    direction: rl.Vector3,
    speed: f32,
    mouse_sensitivity: f32,
    yaw: f32,
    pitch: f32,
    velocity_y: f32,
    is_jumping: bool,
    jump_time: f32,

    pub fn update(p: *Player, w: *World, mouse_delta: rl.Vector2) !void {
        p.updatePosition(w);
        p.updateDirection(mouse_delta);
    }

    pub fn updatePosition(p: *Player, w: *World) void {
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

        if ((rl.isKeyDown(.space) or rl.isKeyDown(.backspace)) and !p.is_jumping) {
            p.velocity_y = JUMP_VELOCITY_INITIAL;
            p.is_jumping = true;
            p.jump_time = 0.0;
        }

        if (p.is_jumping) {
            p.jump_time += rl.getFrameTime();

            if (p.jump_time < JUMP_DURATION) {
                const jump_progress = p.jump_time / JUMP_DURATION;
                const eased_velocity_y = JUMP_VELOCITY_INITIAL * (1.0 - jump_progress);
                p.velocity_y = eased_velocity_y;
            }

            var current_gravity = GRAVITY;
            if (p.velocity_y < 0) {
                current_gravity *= FALL_GRAVITY_MULTIPLIER;
            }
            p.velocity_y -= current_gravity * rl.getFrameTime();
        } else {
            p.velocity_y -= GRAVITY * rl.getFrameTime();
        }

        if (p.verticalCollisionCheck(w)) {
            if (p.velocity_y < 0) {
                p.position.y = @as(f32, @floatFromInt(@as(World.Position.coordinateType, @intFromFloat(p.position.y))));
                p.velocity_y = 0;
                p.is_jumping = false;
            } else if (p.velocity_y > 0) {
                p.velocity_y = 0;
            }
        } else {
            p.position.y += p.velocity_y * rl.getFrameTime();
        }
    }

    pub fn updateDirection(p: *Player, mouse_delta: rl.Vector2) void {
        p.yaw += mouse_delta.x * p.mouse_sensitivity;
        p.pitch -= mouse_delta.y * p.mouse_sensitivity;

        if (p.pitch > std.math.degreesToRadians(89.0)) p.pitch = std.math.degreesToRadians(89.0);
        if (p.pitch < std.math.degreesToRadians(-89.0)) p.pitch = std.math.degreesToRadians(-89.0);

        p.direction.x = @cos(p.yaw) * @cos(p.pitch);
        p.direction.y = @sin(p.pitch);
        p.direction.z = @sin(p.yaw) * @cos(p.pitch);
        p.direction = p.direction.normalize();
    }

    pub fn verticalCollisionCheck(p: *Player, w: *World) bool {
        const potential_y_position = p.position.y + p.velocity_y * rl.getFrameTime();

        const half_height = p.height / 2.0;

        const feet_world_position = .{
            .x = @as(World.Position.coordinateType, @intFromFloat(p.position.x)),
            .y = @as(World.Position.coordinateType, @intFromFloat(potential_y_position - half_height)),
            .z = @as(World.Position.coordinateType, @intFromFloat(p.position.z)),
        };

        const feet_voxel_volume = w.getVoxel(feet_world_position);

        if (feet_voxel_volume) |volume| {
            switch (volume) {
                .full => {
                    return true;
                },
                .divided => {
                    return false;
                }, // TODO: granular collision detection for divideded voxels
            }
        }

        const head_world_position = .{
            .x = @as(World.Position.coordinateType, @intFromFloat(p.position.x)),
            .y = @as(World.Position.coordinateType, @intFromFloat(potential_y_position + half_height)),
            .z = @as(World.Position.coordinateType, @intFromFloat(p.position.z)),
        };

        const head_voxel_volume = w.getVoxel(head_world_position);

        if (head_voxel_volume) |volume| {
            switch (volume) {
                .full => {
                    return true;
                },
                .divided => {
                    return false;
                },
            }
        }

        return false;
    }

    pub fn horizontalCollisionCheck(p: *Player, w: *World, direction: rl.Vector3) bool {
        const potential_x_position = p.position.x + direction.x * p.speed * rl.getFrameTime();
        const potential_z_position = p.position.z + direction.z * p.speed * rl.getFrameTime();

        const half_height = p.height / 2.0;
        const half_width = p.width / 2.0;

        const center_feet_level_world_position = .{
            .x = @as(World.Position.coordinateType, @intFromFloat(potential_x_position)),
            .y = @as(World.Position.coordinateType, @intFromFloat(p.position.y - half_height)),
            .z = @as(World.Position.coordinateType, @intFromFloat(potential_z_position)),
        };

        const center_feet_level_voxel_volume = w.getVoxel(center_feet_level_world_position);

        if (center_feet_level_voxel_volume) |volume| {
            switch (volume) {
                .full => return true,
                .divided => {},
            }
        }

        var offset_feet_level_world_position = center_feet_level_world_position;
        offset_feet_level_world_position.x += direction.x * half_width;
        offset_feet_level_world_position.z += direction.z * half_width;

        const offset_feet_level_voxel_volume = w.getVoxel(offset_feet_level_world_position);

        if (offset_feet_level_voxel_volume) |volume| {
            switch (volume) {
                .full => return true,
                .divided => {},
            }
        }

        return false;
    }
};
