# Git Custom Directive

## Basic Info

Using text alone, Roblox programmers are able to version-control their scripts.

> [!NOTE]
> The token entry is a hazard, but it's there because this tool/library is part of a larger future plugin (I made this as a favor), which will store the token securely using built-in methods from the plugin library.
> The comments can exist alongside code, although in the examples the file schema is only comments

<hr>
<br>

## Documentation

> [!TIP]
> Config can be changed on a global, function, and per-file level. Each missing entry falls back according to the hierarchy. Therefore redundancy is unnecessary.

```lua
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
				};
			</files>
		];
	]=]
]]
```

