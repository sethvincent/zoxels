const std = @import("std");
const rl = @import("raylib");

fn lerpColor(a: rl.Color, b: rl.Color, t: f32) rl.Color {
    return .{
        .r = @intFromFloat(@as(f32, @floatFromInt(a.r)) * (1 - t) + @as(f32, @floatFromInt(b.r)) * t),
        .g = @intFromFloat(@as(f32, @floatFromInt(a.g)) * (1 - t) + @as(f32, @floatFromInt(b.g)) * t),
        .b = @intFromFloat(@as(f32, @floatFromInt(a.b)) * (1 - t) + @as(f32, @floatFromInt(b.b)) * t),
        .a = 255,
    };
}

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "zoxels");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    var camera = rl.Camera3D{
        .position = rl.Vector3.init(2, 2, 2),
        .target = rl.Vector3.init(0, 0, 0),
        .up = rl.Vector3.init(0, 1, 0),
        .fovy = 45.0,
        .projection = .perspective,
    };

    const world_x = 4;
    const world_y = 4;
    const world_z = 4;

    const VoxelData = struct {
        current_color: rl.Color,
        target_color: rl.Color,
        transition_progress: f32,
    };

    const VoxelWorld = [world_x][world_y][world_z]VoxelData;
    var voxel_world: VoxelWorld = undefined;

    var prng = std.rand.DefaultPrng.init(@intFromFloat(@as(f64, @floatFromInt(std.time.timestamp()))));
    var rand = prng.random();

    const transition_speed = 0.2;

    const pastel_colors = [_]rl.Color{
        .{ .r = 255, .g = 182, .b = 193, .a = 255 }, // pink
        .{ .r = 173, .g = 216, .b = 230, .a = 255 }, // blue
        .{ .r = 198, .g = 226, .b = 199, .a = 255 }, // green
        .{ .r = 255, .g = 218, .b = 185, .a = 255 }, // peach
    };

    for (0..world_x) |x| {
        for (0..world_y) |y| {
            for (0..world_z) |z| {
                const initial_color_index = rand.uintAtMost(usize, pastel_colors.len - 1);
                const target_color_index = rand.uintAtMost(usize, pastel_colors.len - 1);
                voxel_world[x][y][z] = .{
                    .current_color = pastel_colors[initial_color_index],
                    .target_color = pastel_colors[target_color_index],
                    .transition_progress = 0,
                };
            }
        }
    }

    const cubePosition = rl.Vector3.init(0, 1, 0);
    const cubeSize = rl.Vector3.init(2, 2, 2);

    var ray: rl.Ray = undefined; // Picking line ray
    var collision: rl.RayCollision = undefined; // Ray collision hit info

    // rl.disableCursor(); // Limit cursor to relative movement inside the window
    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
        //----------------------------------------------------------------------------------
        if (rl.isCursorHidden()) {
            rl.updateCamera(&camera, .first_person);
        }

        // Toggle camera controls
        if (rl.isMouseButtonPressed(.right)) {
            if (rl.isCursorHidden()) rl.enableCursor() else rl.disableCursor();
        }

        if (rl.isMouseButtonPressed(.left)) {
            if (!collision.hit) {
                ray = rl.getScreenToWorldRay(rl.getMousePosition(), camera);

                // Check collision between ray and box
                collision = rl.getRayCollisionBox(ray, rl.BoundingBox{
                    .max = rl.Vector3.init(
                        cubePosition.x - cubeSize.x / 2,
                        cubePosition.y - cubeSize.y / 2,
                        cubePosition.z - cubeSize.z / 2,
                    ),
                    .min = rl.Vector3.init(
                        cubePosition.x + cubeSize.x / 2,
                        cubePosition.y + cubeSize.y / 2,
                        cubePosition.z + cubeSize.z / 2,
                    ),
                });
            } else collision.hit = false;
        }

        for (0..world_x) |x| {
            for (0..world_y) |y| {
                for (0..world_z) |z| {
                    voxel_world[x][y][z].transition_progress += rl.getFrameTime() * transition_speed;
                }
            }
        }

        const time = @as(f32, @floatCast(rl.getTime()));
        const bounce_height: f32 = 0.2 * @sin(time);

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.ray_white);

        {
            camera.begin();
            defer camera.end();

            if (collision.hit) {
                rl.drawCube(cubePosition, cubeSize.x, cubeSize.y, cubeSize.z, rl.Color.red);
                rl.drawCubeWires(cubePosition, cubeSize.x, cubeSize.y, cubeSize.z, rl.Color.maroon);

                rl.drawCubeWires(cubePosition, cubeSize.x + 0.2, cubeSize.y + 0.2, cubeSize.z + 0.2, rl.Color.green);
            } else {
                rl.drawCube(cubePosition, cubeSize.x, cubeSize.y, cubeSize.z, rl.Color.gray);
                rl.drawCubeWires(cubePosition, cubeSize.x, cubeSize.y, cubeSize.z, rl.Color.dark_gray);
            }

            // Draw ground
            rl.drawPlane(rl.Vector3.init(0, 0, 0), rl.Vector2.init(32, 32), rl.Color.light_gray);

            for (&voxel_world, world_x..) |*layer_y, x_index| {
                for (layer_y, world_y..) |*layer_z, y_index| {
                    for (layer_z, world_z..) |*voxel, z_index| {
                        const position = rl.Vector3.init(
                            @as(f32, @floatFromInt(x_index)),
                            @as(f32, @floatFromInt(y_index)),
                            @as(f32, @floatFromInt(z_index)),
                        );

                        const bouncy_position = rl.Vector3.init(position.x, position.y + bounce_height * (rand.float(f32) * 2.1), position.z);

                        if (voxel.transition_progress >= 1.0) {
                            voxel.current_color = voxel.target_color;
                            const new_color_index = rand.uintAtMost(usize, pastel_colors.len - 1);
                            voxel.target_color = pastel_colors[new_color_index];
                            voxel.transition_progress = 0;
                        }

                        const display_color = lerpColor(
                            voxel.current_color,
                            voxel.target_color,
                            voxel.transition_progress,
                        );

                        rl.drawCube(bouncy_position, 0.5, 0.5, 0.5, display_color);
                    }
                }
            }

            rl.drawRay(ray, rl.Color.maroon);
            rl.drawGrid(10, 1);
        }
    }
}
