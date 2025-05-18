#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 1, local_size_z = 1) in;

// current gen
layout(set = 0, binding = 0) restrict readonly buffer CurrentGen{
    int current_gen[];
};

// next gen
layout(set = 1, binding = 0) restrict writeonly buffer NextGen{
    int next_gen[];
};

// width and height
layout(push_constant) uniform Parameters{
    int width;
    int height;
};

// The code we want to execute in each invocation
void main() {
    int x = int(gl_GlobalInvocationID.x) % width;
    int y = int(gl_GlobalInvocationID.x) / width;

    // count neighbours
    int neighbours = 0;
    for (int dx=-1; dx<=1; dx++){
        for (int dy=-1; dy<=1; dy++){
            int nx = x + dx;
            int ny = y + dy;
            // if cell is not itself and is on the board
            if (!(nx == x && ny == y) && nx >= 0 && nx <= width-1 && ny >= 0 && ny <= height-1){
                neighbours += int(current_gen[ny * width + nx]);
            }
        }
    }

    // update next gen
    int cell_state = int(current_gen[y * width + x]);
    if (
        (cell_state == 1 && neighbours != 2 && neighbours != 3)
        || (cell_state == 0 && neighbours != 3)
    ){
        next_gen[gl_GlobalInvocationID.x] = 0;
    } else{
        next_gen[gl_GlobalInvocationID.x] = 1;
    }
}