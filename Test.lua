--$SERVER
--[[
[=[
    git-config = [
        token: "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";
        repository: "Bububooo3/git-custom-directive";
        // branch: "test"; <-- (doesn't make new branches. Will throw warning and quit. Will not revert to main bc that's dangerous)
        branch: "main";
        commit-message: "Stable Version Upload";
    ];
    
    // git-pull = [
    // 	<files>
    // 		game.Workspace.Script: {
    // 			path: "directive12";
    // 		};
    // 		
    // 		game.Workspace.testdirectory1: {
    // 			path: "ref/Functions.lua";
    // 		};
    // 	</files>
    // ]
    
    git-push = [ // Updates and uploads both work and are handled mostly automatically by GitHub API
    	<files>
    		game.ReplicatedStorage.Stable: {
    			path: "";
    		};
    		
    		// script: { <-- (No relative paths >:C)
    		// 	path: "ref";
    		// };
    	</files>
    ]
]=]
]]