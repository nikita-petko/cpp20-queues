target("template-app")
    set_kind("binary")
    add_headerfiles("**.h")
    add_files("**.cc")
    add_includedirs(".")
	
	if is_mode("debug") then
        set_symbols("debug")
	end

    if is_mode("release") then
        set_optimize("fastest")
    end
