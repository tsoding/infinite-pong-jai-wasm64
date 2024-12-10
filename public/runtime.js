
let ctx;
let allocated; // A global reference of the WASM’s memory area so that we can look up pointers
let function_table;
let update_frame = () => {};

function clamp(low, high, value) {
    return Math.min(Math.max(low, value), high);
}

function parseColor(color) {
    const r = ((color>>8*0)&0xFF).toString(16).padStart(2, 0);
    const g = ((color>>8*1)&0xFF).toString(16).padStart(2, 0);
    const b = ((color>>8*2)&0xFF).toString(16).padStart(2, 0);
    const a = ((color>>8*3)&0xFF).toString(16).padStart(2, 0);
    return '#'+r+g+b+a;
}


// These are all the functions that we declared as "#foreign" in our Jai code.
// They let you interact with the JS and DOM world from within Jai.
// If you forget to implement one, the Proxy below will log a nice error.
const exported_js_functions = {
    set_canvas_size: (width, height) => {
        ctx.canvas.width = width;
        ctx.canvas.height = height;
    },
    clear_with_color: (color) => {
        ctx.fillStyle = parseColor(color);
        ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);
    },
    fill_rect: (x, y, w, h, color) => {
        ctx.fillStyle = parseColor(color);
        ctx.fillRect(x, y, w, h);
    },
    fill_circle: (x, y, radius, color) => {
        ctx.fillStyle = parseColor(color);
        ctx.beginPath();
        ctx.arc(x, y, radius, 0, 2*Math.PI);
        ctx.fill()
    },
    set_update_frame: (f) => {
        update_frame = function_table.get(Number(f));
        console.log(update_frame);
    },
    wasm_write_string: (s_count, s_data, to_standard_error) => {
        const string = js_string_from_jai_string(s_data, s_count);
        write_to_console_log(string, to_standard_error);
    },
    wasm_debug_break: () => {
        debugger;
    },
}

// Create the environment for the WASM file,
// which includes the exported JS functions for the WASM:
const imports = {
    "env": new Proxy(exported_js_functions, {
        get(target, prop, receiver) {
            if (target.hasOwnProperty(prop)) {
                return target[prop];
            }

            return () => { throw new Error("Missing function: " + prop); };
        },
    }),
}

// Load the WASM file we compiled and run its main.
WebAssembly.instantiateStreaming(fetch("main.wasm"), imports).then(
    (obj) => {
        allocated = obj.instance.exports.memory;
        function_table = obj.instance.exports.__indirect_function_table;
        console.log(obj);
        const canvas = document.getElementById("game");
        if (canvas) ctx = canvas.getContext("2d");
        obj.instance.exports.main(0, BigInt(0));
        let prevTimestamp;
        function frame(timestamp) {
            const deltaTime = (timestamp - prevTimestamp)*0.001;
            prevTimestamp = timestamp;
            update_frame(BigInt(0), deltaTime);
            window.requestAnimationFrame(frame);
        }
        window.requestAnimationFrame((timestamp) => {
            prevTimestamp = timestamp;
            window.requestAnimationFrame(frame);
        });
    }
);

const text_decoder = new TextDecoder();
function js_string_from_jai_string(pointer, length) {
    const u8 = new Uint8Array(allocated.buffer)
    const bytes = u8.subarray(Number(pointer), Number(pointer) + Number(length));
    return text_decoder.decode(bytes);
}

// console.log and console.error always add newlines so we need to buffer the output from write_string
// to simulate a more basic I/O behavior. We’ll flush it after a certain time so that you still
// see the last line if you forget to terminate it with a newline for some reason.
let console_buffer = "";
let console_buffer_is_standard_error;
let console_timeout;
const FLUSH_CONSOLE_AFTER_MS = 3;

function write_to_console_log(str, to_standard_error) {
    if (console_buffer && console_buffer_is_standard_error != to_standard_error) {
        flush_buffer();
    }

    console_buffer_is_standard_error = to_standard_error;
    const lines = str.split("\n");
    for (let i = 0; i < lines.length - 1; i++) {
        console_buffer += lines[i];
        flush_buffer();
    }

    console_buffer += lines[lines.length - 1];

    clearTimeout(console_timeout);
    if (console_buffer) {
        console_timeout = setTimeout(() => {
            flush_buffer();
        }, FLUSH_CONSOLE_AFTER_MS);
    }

    function flush_buffer() {
        if (!console_buffer) return;

        if (console_buffer_is_standard_error) {
            console.error(console_buffer);
        } else {
            console.log(console_buffer);
        }

        console_buffer = "";
    }
}
