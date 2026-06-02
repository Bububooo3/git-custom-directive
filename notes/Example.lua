--$MODULE

-- EXAMPLE INPUT
--[[
[=[
    git-config = [
        token: "ghp_globalToken999";
        repository: "myorg/monorepo";
        branch: "main";
        commit-message: "Auto-push from Studio";
        base: "main";
    ];

    git-push = [
        <config>
            token: "ghp_pushToken123";
            path: "src";
            branch: "dev";
            commit-message: "feat: studio sync";
        </config>

        <files>
            game.ServerScriptService.GameManager: {
                name: "GameManager";
            };

            game.ServerScriptService.DataHandler: {
                name: "DataHandler";
                repository: "myorg/other-repo";
                path: "services";
                branch: "main";
                commit-message: "Updated data handler";
            };

            game.ReplicatedStorage.Shared: {
                name: "Shared";
                path: "src/shared";
            };
        </files>
    ];

    git-pull = [
        <config>
            token: "ghp_pullToken456";
            repository: "myorg/monorepo";
            path: "src";
            branch: "dev";
        </config>

        <files>
            game.StarterPlayer.StarterPlayerScripts.ClientMain: {
                path: "src/client";
                branch: "dev";
            };

            game.ReplicatedStorage.Shared: {
                path: "src/shared";
            };
        </files>
    ];
]=]
]]

-- EXAMPLE OUTPUT
return {
    config = {
        token      = "ghp_globalToken999",
        repository = "myorg/monorepo",
        branch     = "main",
        message    = "Auto-push from Studio",
        base       = "main",
    },

    push = {
        config = {
            token   = "ghp_pushToken123",
            path    = "src",
            branch  = "dev",
            message = "feat: studio sync",
            -- repository: nil, falls back to global "myorg/monorepo"
        },
        files = {
            ["game.ServerScriptService.GameManager"] = {
                name = "GameManager",
                -- all else nil, resolved via push config then global config:
                -- token      -> "ghp_pushToken123"
                -- repository -> "myorg/monorepo"
                -- path       -> "src"
                -- branch     -> "dev"
                -- message    -> "feat: studio sync"
            },
            ["game.ServerScriptService.DataHandler"] = {
                name       = "DataHandler",
                repository = "myorg/other-repo",
                path       = "services",
                branch     = "main",
                message    = "Updated data handler",
                -- token nil, falls back to push config "ghp_pushToken123"
            },
            ["game.ReplicatedStorage.Shared"] = {
                name = "Shared",
                path = "src/shared",
                -- token      -> "ghp_pushToken123"
                -- repository -> "myorg/monorepo"
                -- branch     -> "dev"
                -- message    -> "feat: studio sync"
            },
        },
    },

    pull = {
        config = {
            token      = "ghp_pullToken456",
            repository = "myorg/monorepo",
            path       = "src",
            branch     = "dev",
        },
        files = {
            ["game.StarterPlayer.StarterPlayerScripts.ClientMain"] = {
                path   = "src/client",
                branch = "dev",
                -- token      -> "ghp_pullToken456"
                -- repository -> "myorg/monorepo"
            },
            ["game.ReplicatedStorage.Shared"] = {
                path          = "src/shared",
                -- token      -> "ghp_pullToken456"
                -- repository -> "myorg/monorepo"
                -- branch     -> "dev"
            },
        },
    },
}

--[[
    
]]