add_rules("mode.debug", "mode.release")

set_languages("cxx20")

includes("src", "test")

task("bundle")
    set_menu {
        usage = "xmake bundle",
        description = "Create Zip bundle from binaries",
        options = {}
    }
    on_run(function ()
        import("scripts.bundle")
        bundle()
    end)

task("test")
    set_menu {
        usage = "xmake runtest",
        description = "Run Zen tests",
        options = {
            {'r', "run", "kv", "all", "Run test(s)", " - all"}
        }
    }
    on_run(function()
        import("core.base.option")
        
        local testname = option.get("run")
        local available_tests = {
            default = "template-app-test",
        }

        local arch
        if is_host("windows") then
            arch = "x64"
        else
            arch = "x86_64"
        end
        
        print(os.exec("xmake config -c -m debug -a "..arch))
        print(os.exec("xmake"))
        
        local tests = {}
        for name, test in pairs(available_tests) do
            if name == testname or testname == "all" then
                tests[name] = test
            end
        end
        
        for name, test in pairs(tests) do
            printf("=== %s ===\n", test)
            local cmd = string.format("xmake run %s", test)
            if name == "server" then
                cmd = string.format("xmake run %s test", test)
            end
            print(os.exec(cmd))
        end
    end)