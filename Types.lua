--!native
--!optimize 2

--$MODULE

export type GitConfigData = {
	token: string | nil;
	repository: string | nil;
	path: string | nil;
	branch: string | nil;
	message: string | nil;
	base: string;
}

export type GitDirectiveData = {
	config: GitConfigData,

	files: { -- [script absolute file path from game]: {upload data}
		[string]: {
			name: string | nil;
			token: string | nil;
			repository: string | nil;
			path: string | nil;
			branch: string | nil;
			message: string | nil;
		}
	}
}

return {}