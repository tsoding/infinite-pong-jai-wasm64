#import "Basic";
#import "Compiler";

#run {
    set_build_options_dc(.{do_output = false});

    w := compiler_create_workspace("Wasm");
    options := get_build_options(w);
    copy_commonly_propagated_fields(get_build_options(), *options);

    options.output_type                         = .EXECUTABLE;
    options.backend                             = .LLVM; // WASM only works with the LLVM backend, obviously.
    options.os_target                           = .WASM;
    options.cpu_target                          = .CUSTOM;
    options.emit_debug_info                     = .DWARF;
    options.backtrace_on_crash                  = .OFF; // Runtime_Support_Crash_Handler doesn’t support WASM (yet?)
    options.output_path                         = "./public/";
    options.output_executable_name              = "main";
    options.llvm_options.target_system_features = "+bulk-memory"; // "This options is needed so that "memcpy" and "memset" are mapped to "memory.copy" and "memory.fill" instructions in WASM.
    options.llvm_options.enable_split_modules   = false;
    options.llvm_options.function_sections      = true; // To get around "LLVM ERROR: section already has a defining function: .text"

    import_paths: [..]string;
    // Add our own modules folder first so that we can override modules with our own version, if necessary.
    array_add(*import_paths, tprint("%modules", #filepath));
    for options.import_path array_add(*import_paths, it);
    options.import_path = import_paths;

    options.additional_linker_arguments = .["--export-table"];

    set_build_options(options, w);

    remap_import(w, "*", "Default_Allocator", "Urmomocator");

    add_build_file("main.jai", w);
}
