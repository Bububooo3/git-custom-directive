# Git Custom Directive

## Basic Info

Using text alone, Roblox programmers are able to version-control their scripts.

To run, make sure all the scripts are pointing to each other correctly and then run this in Roblox's CLI:

```lua
Public.run( SCHEMA SCRIPT LOCATION )
```

> [!NOTE]
> The token entry is a hazard (if you want to upload the schema), but it's there because this tool/library is part of a larger future plugin (I made this as a favor), which will store the token securely using built-in methods from the plugin library.
> The comments can exist alongside code, although in the examples the file schema is only comments.

<hr>
<br>

## Files

### [Functions.lua](Functions.lua)
The nitty-gritty "backend" functions used by `GitFxns` for easier reading.

### [GitFxns.lua](GitFxns.lua)
The push, pull, config, mechanisms defined as functions to take input directly from the parser.

### [Keywords.lua](Keywords.lua)
A dictionary of words associated with each script class for informed estimates when no explcit indicator (`--$MODULE`, `--$SERVER`, `--$CLIENT`) is available.

### [Parser.lua](Parser.lua)
A parser generated using Claude Sonnet to implement my schema design.

### [Public.lua](Public.lua)
A public-facing module with a method that takes a script as an argument and runs the application.

### [Test.lua](Test.lua)
A script with an example schema used to test the application.

### [Types.lua](Types.lua)
A module with types to make programming the application simpler, since normal Lua is dynamically typed. 

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

