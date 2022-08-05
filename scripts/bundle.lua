-- Execute a command.
local function _exec(cmd, ...)
    local args = {}
    for _, v in pairs({...}) do
        if v then
            table.insert(args, v)
        end
    end

    print("--", cmd, table.unpack(args))
    local ret = os.execv(cmd, args)
    print()
    return ret
end

local function _build(target, arch, debug, config_args)
    variant = debug and "debug" or "release"

    local ret = _exec(
        "xmake",
        "config",
        "--yes",
        "--clean",
        "--mode="..variant,
        "--arch="..arch,
        config_args
    )

    if ret > 0 then
        raise("Failed to configure xmake")
    end

    ret = _exec("xmake", "clean", "--yes", target)
    if ret > 0 then
        raise("Failed to clean target "..target)
    end

    ret = _exec("xmake", "build", "--yes", target)
    if ret > 0 then
        raise("Failed to build target "..target)
    end
end

local function _zip(store_only, zip_path, ...)
    -- Here's the rules; if len(...) is 1 and it is a dir then create a zip with
    -- archive paths like this;
    --
    --   glob(foo/bar/**) -> foo/bar/abc, foo/bar/dir/123 -> zip(abc, dir/123)
    --
    -- Otherwise assume ... is file paths and add without leading directories;
    --
    --   foo/abc, bar/123 -> zip(abc, 123)

    -- convert zip_path back slashes to forward slashes
    zip_path = zip_path:gsub("\\", "/")

    zip_path = path.absolute(zip_path)
    os.tryrm(zip_path)

    local inputs = {...}

    local source_dir = nil
    if #inputs == 1 and os.isdir(inputs[1]) then
        source_dir = inputs[1]:gsub("\\", "/")
    end

    import("detect.tools.find_7z")
    local cmd = find_7z()
    if cmd then
        input_paths = {}
        if source_dir then
            -- Suffixing a directory path with a "/." will have 7z set the path
            -- for archived files relative to the directory.
            input_paths = { path.join(source_dir, "."):gsub("\\", "/") }
        else
            for _, input_path in pairs(inputs) do
                -- If there is a "/./" anywhere in file paths then 7z drops all
                -- directory information and just archives the file by its name.
                input_path = path.relative(input_path, ".")
                if input_path:sub(2, 2) ~= ":" then 
                    input_path = "./" .. input_path:gsub("\\", "/")
                end
                table.insert(input_paths, input_path)
            end
        end

        compression_level = "-mx1"
        if store_only then
            compression_level = "-mx0"
        end

        local ret = _exec(cmd, "a", "-r", compression_level, zip_path, table.unpack(input_paths))
        if ret > 0 then
            raise("Failed to create zip file "..zip_path)
        end
        return
    end
    print("WARNING: 7z not found, try to use zip instead")

    import("detect.tools.find_zip")
    cmd = find_zip()
    if cmd then 
        local input_paths = inputs
        local cwd = os.curdir()
        if source_dir then
            os.cd(source_dir)
            input_paths = { ":" }
        end

        compression_level = "-1"
        if store_only then
            compression_level = "-0"
        end

        local strip_leading_path = nil
        if not source_dir then
            strip_leading_path = "--junk-paths"
        end

        local ret = _exec(cmd, "-r", compression_level, strip_leading_path, zip_path, table.unpack(input_paths))
        if ret > 0 then
            raise("Failed to create zip file "..zip_path)
        end

        os.cd(cwd)
        return
    end
    print("WARNING: zip not found, unable to create zip file")

    raise("Failed to create zip file "..zip_path)
end

local function _find_vcpkg_binary(triple, port, binary)
    import("detect.sdks.find_vcpkgdir")
    local root_dir = find_vcpkgdir()
    if root_dir == nil or root_dir == "" then
        raise("Failed to find vcpkg root directory")
    end

    bin_path = root_dir .. "/installed/" .. triple .. "/tools/" .. port .. "/" .. binary
    if not os.isfile(bin_path) then
        raise("Failed to find vcpkg binary "..bin_path)
    end

    return bin_path
end 

local function main_windows() 
    zip_path = "build/template-app-win64.zip"

    _build("template-app", "x64", false)

    local mode = "release"
    if is_mode("debug") then
        mode = "debug"
    end

    local output_base_name = "build/windows/x64/" .. mode .. "/template-app"

    local exe_path = output_base_name .. ".exe"
    local pdb_path = output_base_name .. ".pdb"

    local zip_paths = {exe_path}

    if os.isfile(pdb_path) then
        table.insert(zip_paths, pdb_path)
    end

    _zip(false, zip_path, table.unpack(zip_paths))
end

local function main_linux()
    zip_path = "build/template-app-linux.zip"

    _build("template-app", "x86_64")

    local mode = "release"
    if is_mode("debug") then
        mode = "debug"
    end

    local output_base_name = "build/linux/x86_64/" .. mode .. "/template-app"
    local zip_paths = {output_base_name}
    _zip(false, zip_path, table.unpack(zip_paths))
end

local function main_mac()
    -- Build and universalify
    _build("template-app", "x86_64", false, "--target_minver=10.15")
    _build("template-app", "arm64", false, "--target_minver=10.15")

    os.mkdir("build/macosx/universal/release/")
	local ret = _exec(
        "lipo",
        "-create",
        "-output", "build/macosx/universal/release/template-app",
        "build/macosx/x86_64/release/template-app",
        "build/macosx/arm64/release/template-app"
    )
    if ret > 0 then
        raise("Failed creating universal binary")
    end

    -- Zip
    _zip(
        false,
        "build/template-app-macos.zip",
        "build/macosx/universal/release/template-app",
        crashpad_handler_path
    )
end

function main() 
    if is_host("windows") then
        main_windows()

        return
    end

    if is_host("linux") then
        main_linux()

        return
    end

    if is_host("mac") then
        main_mac()

        return
    end

    raise("Unsupported host")
end