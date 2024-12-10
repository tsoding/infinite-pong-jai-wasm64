#import "Basic";
#import "Math";

Color :: struct {
    r: u8;
    g: u8;
    b: u8;
    a: u8;
}

Player :: enum {
    ONE;
    TWO;
};

// Stolen from Raylib
color_from_hsv :: (hue: float, saturation: float, value: float) -> Color {
    color := Color.{ 0, 0, 0, 255 };

    // Red channel
    k := fmod_cycling(5.0 + hue/60.0, 6);
    t := 4.0 - k;
    k = ifx t < k then t else k;
    k = ifx k < 1 then k else 1;
    k = ifx k > 0 then k else 0;
    color.r = xx ((value - value*saturation*k)*255.0);

    // Green channel
    k = fmod_cycling((3.0 + hue/60.0), 6);
    t = 4.0 - k;
    k = ifx t < k then t else k;
    k = ifx k < 1 then k else 1;
    k = ifx k > 0 then k else 0;
    color.g = xx ((value - value*saturation*k)*255.0);

    // Blue channel
    k = fmod_cycling((1.0 + hue/60.0), 6);
    t = 4.0 - k;
    k = ifx t < k then t else k;
    k = ifx k < 1 then k else 1;
    k = ifx k > 0 then k else 0;
    color.b = xx ((value - value*saturation*k)*255.0);

    return color;
}

color_of_player :: (player: Player) -> Color {
    saturation :: 0.9;
    value :: 0.8;
    base_hue :: 30;
    if #complete player == {
        case .ONE; return .{0x18, 0x18, 0x18, 0xFF};
        case .TWO; return .{0xff, 0xdd, 0x33, 0xFF};
    }
}

opposite_player :: (player: Player) -> Player {
    if #complete player == {
        case .ONE; return .TWO;
        case .TWO; return .ONE;
    }
}

rect_circle_collision :: (l: float, r: float, t: float, b: float, cx: float, cy: float, rad: float) -> bool {
    x := min(max(l, cx), r);
    y := min(max(t, cy), b);
    dx := cx - x;
    dy := cy - y;
    return dx*dx + dy*dy <= rad*rad;
}

board: [BOARD_HEIGHT][BOARD_WIDTH]Player;

BOARD_HEIGHT     :: 20;
BOARD_WIDTH      :: BOARD_HEIGHT*2; #assert(BOARD_WIDTH%2 == 0);
CELL_SIZE        :: 20;
SCREEN_WIDTH     :: BOARD_WIDTH*CELL_SIZE;
SCREEN_HEIGHT    :: BOARD_HEIGHT*CELL_SIZE;
PLAYER_RADIUS    :: SCREEN_HEIGHT*.05;
PLAYER_SPEED     :: 500.0;
RECT_WIDTH       :: 100;
RECT_HEIGHT      :: 100;
BACKGROUND_COLOR :: Color.{0x18, 0x18, 0x18, 0xFF};
FOREGROUND_COLOR :: Color.{0x18, 0xFF, 0x18, 0xFF};

set_canvas_size :: (width: u32, height: u32) #foreign "set_canvas_size";
clear_with_color :: (color: Color) #foreign "clear_with_color";
fill_rect :: (x: float, y: float, w: float, h: float, color: Color) #foreign "fill_rect";
fill_circle :: (x: float, y: float, radius: float, color: Color) #foreign "fill_circle";
set_update_frame :: (f: (dt: float)) #foreign "set_update_frame";

Player_State :: struct {
    position: Vector2;
    velocity: Vector2;
    kind: Player;
}

player_eats_enemy_cell :: (cx: float, cy: float, kind: Player) -> bool {
    bx : int = xx floor((cx - PLAYER_RADIUS)/CELL_SIZE);
    by : int = xx floor((cy - PLAYER_RADIUS)/CELL_SIZE);
    tx : int = xx floor((cx + PLAYER_RADIUS)/CELL_SIZE);
    ty : int = xx floor((cy + PLAYER_RADIUS)/CELL_SIZE);
    for x: bx..tx {
        for y: by..ty {
            l : float = xx (x*CELL_SIZE);
            r : float = xx ((x + 1)*CELL_SIZE);
            t : float = xx (y*CELL_SIZE);
            b : float = xx ((y + 1)*CELL_SIZE);
            if rect_circle_collision(l, r, t, b, cx, cy, PLAYER_RADIUS) && board[y][x] == opposite_player(kind) {
                board[y][x] = kind;
                return true;
            }
        }
    }
    return false;
}

player_update :: (using player: *Player_State, dt: float) {
    nx := position.x + velocity.x*dt;
    if nx - PLAYER_RADIUS < 0 || nx + PLAYER_RADIUS >= SCREEN_WIDTH || player_eats_enemy_cell(nx, position.y, kind) {
        velocity.x *= -1;
    } else {
        position.x = nx;
    }

    ny := position.y + velocity.y*dt;
    if ny - PLAYER_RADIUS < 0 || ny + PLAYER_RADIUS >= SCREEN_HEIGHT || player_eats_enemy_cell(position.x, ny, kind) {
        velocity.y *= -1;
    } else {
        position.y = ny;
    }
}

player1: Player_State;
player2: Player_State;

update_frame :: (dt: float) {
    player_update(*player1, dt);
    player_update(*player2, dt);

    clear_with_color(BACKGROUND_COLOR);
    for by: 0..BOARD_HEIGHT-1 {
        for bx: 0..BOARD_WIDTH-1 {
            x: float = xx (bx*CELL_SIZE);
            y: float = xx (by*CELL_SIZE);
            w: float = xx CELL_SIZE;
            h: float = xx CELL_SIZE;
            fill_rect(x, y, w, h, color_of_player(board[by][bx]));
        }
    }
    fill_circle(player1.position.x, player1.position.y, PLAYER_RADIUS, color_of_player(.TWO));
    fill_circle(player2.position.x, player2.position.y, PLAYER_RADIUS, color_of_player(.ONE));
}

main :: () {
    set_canvas_size(SCREEN_WIDTH, SCREEN_HEIGHT);
    for bx: 0..BOARD_WIDTH/2-1 {
        for by: 0..BOARD_HEIGHT-1 {
            board[by][bx]                 = .ONE;
            board[by][bx + BOARD_WIDTH/2] = .TWO;
        }
    }
    player1.position = .{SCREEN_WIDTH/4.0, SCREEN_HEIGHT/2.0};
    player1.velocity = .{cos(PI*.25), sin(PI*.25)}*PLAYER_SPEED;
    player1.kind = .ONE;
    player2.position = .{SCREEN_WIDTH/2.0 + SCREEN_WIDTH/4.0, SCREEN_HEIGHT/2.0};
    player2.velocity = .{cos(PI*1.25), sin(PI*1.25)}*PLAYER_SPEED;
    player2.kind = .TWO;
    set_update_frame(update_frame);
}
