local tokens = {
    ["[=["] = function()

    end
}

function gitParse(raw: string)
    local lines = raw:split("\n")
    local bracketStack = {}
    local data = {}
    local mode -- 0, 1, 2 -> config, push, pull

    for _, line in pairs(lines) do
        for _, word: string in pairs(line:split(" ")) do
            for token, callback in pairs(tokens) do
                if (word:lower()):find(token, 1, true) then

                end
            end

            

            if word == "[=[" then
                table.insert(bracketStack, word)
                continue
            end

            mode = ((word=="git-config") and 0) or ((word=="git-push") and 1) or ((word=="git-pull") and 2) or mode
        end
    end
end

--[[
	[=[
		git-config = [ // This is global config (act as back-ups if failure occurs also)
			token: [TOKEN];
			repository: [REPO];
			username: [USERNAME];
			target-directory: [GITHUB PATH];
			branch: [BRANCH];
			commit-message: [COMMIT MESSAGE];
		];

		git-push = [
			<config> // this is quick-config for local changes/setup
				token: [TOKEN];
				repository: [REPO];
				path: [GITHUB PATH];
				branch: [BRANCH];
				commit-message: [COMMIT MESSAGE];
			</config>

			<files>
				workspace.Script: {
					name: "Example";

					token: "12345678910";
					repository: "username/reponame";
					path: "subfolder/double-sub-folder/";
					branch: "main";
					commit-message: "We did it!";
				};

				workspace.Folder: { // In the parser it will identify & report scripts automatically so that data is still {BaseScript}
					name: "Example";

					token: "12345678910";
					repository: "username/reponame";
					path: "";
					branch: "main";
					commit-message: "We did it!";
				};
			</files>
		];

		git-pull = [
			<config>
				token: [TOKEN];
				repository: [REPO];
				path: [GITHUB PATH];
				branch: [BRANCH];
			</config>

			<files>
				workspace.Script: {
					token: "12345678910";
					repository: "username/reponame";
					path: "";
					branch: "main";
				};

				workspace.Folder: {
					token: "12345678910";
					repository: "username/reponame";
					path: "";
					branch: "main";
					output-enabled: false;
				};
			</files>
		];
	]=]
]]